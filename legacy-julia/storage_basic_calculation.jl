# 小型物置1D解析：パターン1（基本仕様）計算スクリプト

using Dates
using CSV
using DataFrames

# 必要なモジュールを読み込む
include("./module/cell.jl")
include("./module/air.jl")
include("./module/boundary_condition.jl")
include("./module/transfer_in_media.jl")
include("./module/climate.jl")
include("./logger.jl")

# inputファイルから壁体構成を読み込む
input_file = "./input_data/1D_model/storage_basic.CSV"

println("パターン1（基本仕様）計算開始...")
println("入力ファイル: ", input_file)

# CSVファイルの読み込み
df = CSV.read(input_file, DataFrame, header=3)

# 壁体モデルの構築
target_model = []

for row in eachrow(df)
    if row.type == "BC_Robin"
        # 境界条件の作成
        bc = BC_Robin()
        bc.air.name = row.name
        bc.air.temp = row.temp + 273.15
        bc.air.rh = row.rh / 100.0
        if !ismissing(row.alpha)
            bc.alpha = row.alpha
        end
        if !ismissing(row.alphac)
            bc.alphac = row.alphac
        end
        if !ismissing(row.alphar)
            bc.alphar = row.alphar
        end
        bc.aldm = aldm_by_alphac(bc)
        push!(target_model, bc)
    elseif row.type == "Cell"
        # セルの作成
        cell = Cell()
        cell.i = [row.i, 1, 1]
        cell.dx = row.dx
        cell.dx2 = row.dx2
        cell.temp = row.temp + 273.15
        cell.rh = row.rh / 100.0
        cell.miu = convertRH2Miu(temp = cell.temp, rh = cell.rh)
        cell.material_name = row.name
        push!(target_model, cell)
    end
end

println("壁体モデル構築完了。要素数: ", length(target_model))

# 流量計算関数の定義
function cal_new_temp_miu_neumann(target_model, dt)
    # 壁体内部の流量計算
    q = [cal_q(target_model[i], target_model[i+1]) for i = 1:length(target_model)-1]
    jv = [cal_jv(target_model[i], target_model[i+1]) for i = 1:length(target_model)-1]
    jl = [cal_jl(target_model[i], target_model[i+1], 0.0) for i = 1:length(target_model)-1]

    # 熱・水分の収支計算
    ntemp = [cal_newtemp(target_model[i+1], q[i] - q[i+1], -(jv[i] - jv[i+1]), dt) for i = 1:length(target_model)-2]
    nmiu = [cal_newmiu(target_model[i+1], jv[i] - jv[i+1], jl[i] - jl[i+1], dt) for i = 1:length(target_model)-2]
    
    return ntemp, nmiu
end

# 計算条件設定
dt = 60.0  # 1分間隔
date = DateTime(2024, 12, 1, 0, 0, 0)  # 冬季開始
end_date = DateTime(2024, 12, 8, 0, 0, 0)  # 1週間計算

println("計算期間: ", date, " - ", end_date)
println("時間刻み: ", dt, " 秒")

# 気象データの読み込み
climate_data_in = input_climate_data(
    file_name = "./input_data/climate_data/sample_climate_data.csv",
    header = 3
)
climate_data_in.air = target_model[1].air

climate_data_out = input_climate_data(
    file_name = "./input_data/climate_data/sample_climate_data.csv", 
    header = 3
)
climate_data_out.air = target_model[end].air

# ロガーの設定
logger_room = set_logger("storage_basic_result", 10.0, ["temp","rh","ah"], target_model)
write_header_to_logger(logger_room)
write_data_to_logger(logger_room, date)

println("計算開始...")

# メインループ計算
step = 0
while date ≠ end_date
    step += 1
    
    # 環境データの更新
    reset_climate_data(climate_data_in)
    reset_climate_data(climate_data_out)

    # 新値の計算
    ntemp, nmiu = cal_new_temp_miu_neumann(target_model, dt)
    
    # 値の上書き（境界条件以外のセル）
    for i = 1:length(ntemp)
        target_model[i+1].temp = ntemp[i]
        target_model[i+1].miu = nmiu[i]
    end
    
    # 時間経過
    date = date + Second(Int(dt))
    climate_data_in.date = date
    climate_data_out.date = date
    
    # データのロギング
    if mod(minute(date), 10) == 0 && second(date) == 0
        write_data_to_logger(logger_room, date)
    end
    
    # 進捗表示
    if mod(step, 1440) == 0  # 1日ごと
        println("計算進捗: ", Dates.format(date, "yyyy/mm/dd HH:MM"))
    end
end

# ファイルクローズ
close(logger_room.file[1])

println("パターン1計算完了")
println("結果ファイル: ./output_data/storage_basic_result.csv")