# テスト用の簡単な1次元計算プログラム
using Dates
include("./module/climate.jl")
include("./module/room.jl")         # Roomを追加
include("./module/cell.jl")
include("./module/air.jl")
include("./module/boundary_condition.jl")
include("./module/transfer_in_media.jl")
include("./logger.jl")

println("=== 材料構成を変更したテスト ===")

# シンプルな3層壁の作成（plywood + mud_wall + plywood → すべてmud_wall）
L = 5
width = 0.01  # 1cm厚の壁
wall = [Cell() for i = 1:L]

# 全層を土壁（mud_wall）に変更
for i = 1:L
    wall[i].i = [i, 1, 1]
    wall[i].dx = width / L
    wall[i].dx2 = wall[i].dx / 2
    wall[i].temp = 20.0 + 273.15  # 20℃
    wall[i].rh = 0.6              # 60%
    wall[i].miu = convertRH2Miu(temp = wall[i].temp, rh = wall[i].rh)
    wall[i].material_name = "mud_wall"  # 全て土壁に統一
end

# 境界条件の設定
air_in = BC_Robin()
air_in.air.name = "indoor"
air_in.air.temp = 20.0 + 273.15
air_in.air.rh = 0.6
air_in.alphac = 9.3
air_in.alphar = 4.4
air_in.alpha = air_in.alphac + air_in.alphar
air_in.aldm = aldm_by_alphac(air_in)

air_out = BC_Robin()
air_out.air.name = "outdoor"
air_out.air.temp = 30.0 + 273.15  # 外気30℃（暑い日を想定）
air_out.air.rh = 0.8              # 80%（湿度高め）
air_out.alphac = 23.0
air_out.alphar = 4.4
air_out.alpha = air_out.alphac + air_out.alphar
air_out.aldm = aldm_by_alphac(air_out)

# モデル結合
target_model = vcat(air_in, wall, air_out)

# 計算条件
dt = 1.0  # 1秒刻み
calc_date = DateTime(2023, 7, 1, 12, 0, 0)
end_date = DateTime(2023, 7, 1, 18, 0, 0)  # 6時間計算

# 流量・収支計算関数
function cal_new_temp_miu_simple(target_model, dt)
    q = [cal_q(target_model[i], target_model[i+1]) for i = 1:length(target_model)-1]
    jv = [cal_jv(target_model[i], target_model[i+1]) for i = 1:length(target_model)-1]
    jl = [cal_jl(target_model[i], target_model[i+1], 0.0) for i = 1:length(target_model)-1]
    
    ntemp = [cal_newtemp(target_model[i+1], q[i] - q[i+1], -(jv[i] - jv[i+1]), dt) for i = 1:length(target_model)-2]
    nmiu = [cal_newmiu(target_model[i+1], jv[i] - jv[i+1], jl[i] - jl[i+1], dt) for i = 1:length(target_model)-2]
    
    return ntemp, nmiu
end

# ロガー設定
logger_test = set_logger("result_mud_wall_test", 10.0, ["temp", "rh"], target_model)
write_header_to_logger(logger_test)
write_data_to_logger(logger_test, calc_date)

println("計算開始: ", calc_date)
println("室内: ", round(air_in.air.temp - 273.15, digits=1), "℃, ", round(air_in.air.rh*100, digits=1), "%")
println("外気: ", round(air_out.air.temp - 273.15, digits=1), "℃, ", round(air_out.air.rh*100, digits=1), "%")

# 計算ループ
step_count = 0
while calc_date != end_date
    global calc_date, step_count  # グローバル変数として明示
    
    ntemp, nmiu = cal_new_temp_miu_simple(target_model, dt)
    
    # 値の更新
    for i = 1:length(wall)
        wall[i].temp = ntemp[i]
        wall[i].miu = nmiu[i]
    end
    
    # 時間更新
    calc_date = calc_date + Millisecond(dt * 1000)
    step_count += 1
    
    # 30分ごとに結果出力
    if minute(calc_date) % 30 == 0 && second(calc_date) == 0
        write_data_to_logger(logger_test, calc_date)
        println("時刻: ", Dates.format(calc_date, "HH:MM"), 
                " 中央温度: ", round(wall[3].temp - 273.15, digits=1), "℃",
                " 相対湿度: ", round(convertMiu2RH(temp=wall[3].temp, miu=wall[3].miu), digits=2))
    end
end

close(logger_test.file)
println("計算完了！ステップ数: ", step_count)
println("結果ファイル: output_data/result_mud_wall_test.csv")