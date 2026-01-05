#=
================================================================================
Git Push テスト用 - 計算を極限まで減らしたバージョン
================================================================================

使い方:
    julia run/main-all-git-test.jl

機能:
    - 1パターン × 1ステップのみ実行
    - Git Pushが正常に動作するかテスト用

=#

using Dates
using Printf

# スクリプトのディレクトリとプロジェクトルートを取得
const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)

#=============================================================================
                          パターン定義（最小構成）
=============================================================================#

# 壁体パターン（1つだけ）
const WALL_PATTERNS = [
    (id="w01-base", file="01-base-model.csv", name="RC単体"),
]

# 換気パターン（1つだけ）
const OPENING_PATTERNS = [
    (id="o01-base", file="01-base-model.csv", name="基準換気"),
]

# 気候パターン（1つだけ）
const CLIMATE_PATTERNS = [
    (id="kyoto", file="climate_data_kyoto.csv", name="京都", lon=135.768, phi=35.012),
]

# 室条件（固定）
const ROOM_FILE = "01-base-model.csv"

#=============================================================================
                          計算条件（最小構成）
=============================================================================#

const DT = 1.0                                      # 時間刻み [hour] - 1時間
const START_DATE = DateTime(2022, 4, 1, 0, 0, 0)    # 計算開始時刻
const END_DATE   = DateTime(2022, 4, 1, 1, 0, 0)    # 計算終了時刻（1時間後 = 1ステップのみ）
const OUTPUT_INTERVAL = 1.0                         # 出力間隔 [hour]
const LONS = 135.0                                  # 地方標準時の経度

# 出力設定
const OUTPUT_BASE_DIR = "output_data"
const BATCH_DIR_NAME = "batch_test"
const DATE_STAMP = Dates.format(now(), "mmdd_HHMM")  # 時刻も追加

#=============================================================================
                          起動メッセージ
=============================================================================#

println()
println("🧪 ════════════════════════════════════════════════════════════════")
println("🧪  Git Push テスト用 - 最小構成バージョン")
println("🧪 ════════════════════════════════════════════════════════════════")
println("🧪  起動時刻: ", now())
println("🧪  計算: 1パターン × 1ステップのみ")
println("🧪 ════════════════════════════════════════════════════════════════")
println()

#=============================================================================
                          モジュール読み込み
=============================================================================#

println("📂 作業ディレクトリ変更...")
cd(PROJECT_DIR)
println("   └─ ", pwd())
println()

println("📦 モジュール読み込み...")
include(joinpath(PROJECT_DIR, "module", "building_network_model.jl"))
include(joinpath(PROJECT_DIR, "module", "transfer_in_media.jl"))
include(joinpath(SCRIPT_DIR, "logger.jl"))
println("   └─ ✅ 完了")
println()

#=============================================================================
                          ユーティリティ関数
=============================================================================#

function get_batch_dir()
    return joinpath(PROJECT_DIR, OUTPUT_BASE_DIR, BATCH_DIR_NAME, DATE_STAMP)
end

function git_push_results(batch_dir::String, case_id::String)
    println()
    println("   📤 GitHub Push...")

    try
        run(`git add $batch_dir`)
        commit_msg = "test: $case_id 完了"
        run(`git commit -m $commit_msg`)
        run(`git push`)
        println("      └─ ✅ Push完了")
        return true
    catch e
        println("      └─ ⚠️ Push失敗: $e")
        return false
    end
end

#=============================================================================
                     壁体・換気計算関数
=============================================================================#

function cal_network_flux_of_wall(network::BNM)
    for i = 1:length(network.rooms)
        set_H_wall(network.rooms[i], 0.0)
        set_J_wall(network.rooms[i], 0.0)
    end

    for i = 1:length(network.walls)
        target_model = network.walls[i].target_model

        for j = 1:length(target_model)-1
            if material_name(target_model[j+1]) == "vented_air_space"
                q  = 1.0 / Rthx(target_model[j+1]) * (temp(target_model[j]) - temp(target_model[j+2]))
                jv = 1.0 / Rdpx(target_model[j+1]) * (pv(target_model[j]) - pv(target_model[j+2]))
                jl = 0.0
            elseif material_name(target_model[j]) == "vented_air_space"
                q  = 1.0 / Rthx(target_model[j]) * (temp(target_model[j-1]) - temp(target_model[j+1]))
                jv = 1.0 / Rdpx(target_model[j]) * (pv(target_model[j-1]) - pv(target_model[j+1]))
                jl = 0.0
            else
                q  = cal_q(target_model[j], target_model[j+1])
                jv = cal_jv(target_model[j], target_model[j+1])
                jl = cal_jl(target_model[j], target_model[j+1], sin(network.walls[i].ION / (180.0/pi)))
            end

            if typeof(target_model[j]) == Cell
                target_model[j].Q[2][1]  = -q  * dy(target_model[j]) * dz(target_model[j])
                target_model[j].Jv[2][1] = -jv * dy(target_model[j]) * dz(target_model[j])
                target_model[j].Jl[2][1] = -jl * dy(target_model[j]) * dz(target_model[j])
            elseif typeof(target_model[j]) == BC_Robin
                add_H_wall(target_model[j].air, -q * area(network.walls[i]))
                add_J_wall(target_model[j].air, -jv * area(network.walls[i]))
            end

            if typeof(target_model[j+1]) == Cell
                target_model[j+1].Q[1][1]  = q  * dy(target_model[j+1]) * dz(target_model[j+1])
                target_model[j+1].Jv[1][1] = jv * dy(target_model[j+1]) * dz(target_model[j+1])
                target_model[j+1].Jl[1][1] = jl * dy(target_model[j+1]) * dz(target_model[j+1])
            elseif typeof(target_model[j+1]) == BC_Robin
                add_H_wall(target_model[j+1].air, q * area(network.walls[i]))
                add_J_wall(target_model[j+1].air, jv * area(network.walls[i]))
            end
        end
    end
end

function cal_network_flux_of_ventilation(network::BNM)
    for i = 1:length(network.rooms)
        set_H_vent(network.rooms[i], 0.0)
        set_J_vent(network.rooms[i], 0.0)
    end

    for i = 1:length(network.openings)
        if network.openings[i].Type == "constant"
            ca_IP  = 1005.0 + 1846.0 * ah(room_IP(network.openings[i]))
            ca_IM  = 1005.0 + 1846.0 * ah(room_IM(network.openings[i]))
            rho_IP = 353.25 / temp(room_IP(network.openings[i]))
            rho_IM = 353.25 / temp(room_IM(network.openings[i]))
            rho    = (rho_IP + rho_IM) / 2.0

            add_H_vent(room_IP(network.openings[i]), Qup(network.openings[i]) * rho * (ca_IM * temp(room_IM(network.openings[i])) - ca_IP * temp(room_IP(network.openings[i]))))
            add_J_vent(room_IP(network.openings[i]), Qup(network.openings[i]) * rho * (ah(room_IM(network.openings[i])) - ah(room_IP(network.openings[i]))))
            add_H_vent(room_IM(network.openings[i]), Qdw(network.openings[i]) * rho * (ca_IP * temp(room_IP(network.openings[i])) - ca_IM * temp(room_IM(network.openings[i]))))
            add_J_vent(room_IM(network.openings[i]), Qdw(network.openings[i]) * rho * (ah(room_IP(network.openings[i])) - ah(room_IM(network.openings[i]))))
        end
    end
end

function cal_new_value_ver_network(network::BNM, dt)
    for i = 1:length(network.walls)
        target_model = network.walls[i].cell

        for j = 1:length(target_model)
            if material_name(target_model[j]) ≠ "vented_air_space"
                target_model[j].temp = cal_newtemp(target_model[j], sum(sum(target_model[j].Q)), -sum(sum(target_model[j].Jv)), dt)
                nmiu = cal_newmiu(target_model[j], sum(sum(target_model[j].Jv)), sum(sum(target_model[j].Jl)), dt)

                if j == 1 || j == length(target_model)
                    BC = j == 1 ? :BC_IP : :BC_IM
                    if nmiu >= -0.1
                        nmiu = -0.1
                        setfield!(getfield(network.walls[i], BC), :jl_surf, sum(sum(target_model[j].Jv)) + sum(sum(target_model[j].Jl)))
                    end
                else
                    if nmiu >= -0.1
                        nmiu = -0.1
                    end
                end

                target_model[j].miu = nmiu

            elseif material_name(target_model[j]) == "vented_air_space"
                target_model[j].temp = (temp(target_model[j-1]) + temp(target_model[j+1])) / 2.0
                target_model[j].miu  = (miu(target_model[j-1]) + miu(target_model[j+1])) / 2.0
            end
        end
    end

    for i = 2:length(network.rooms)
        set_temp(network.rooms[i], cal_newtemp(network.rooms[i].air, dt))
        set_rh(network.rooms[i], cal_newRH(network.rooms[i].air, dt))
    end
end

#=============================================================================
                          メイン処理
=============================================================================#

function main()
    batch_dir = get_batch_dir()
    mkpath(batch_dir)

    wall = WALL_PATTERNS[1]
    opening = OPENING_PATTERNS[1]
    climate = CLIMATE_PATTERNS[1]
    case_id = "$(wall.id)_$(opening.id)_$(climate.id)"

    println("🔄 テスト実行: $case_id")
    println()

    # 入力ファイルパス
    input_room = joinpath("input_data", "building_network_model_production", "01", "room-condition", ROOM_FILE)
    input_wall = joinpath("input_data", "building_network_model_production", "01", "wall-condition", wall.file)
    input_opening = joinpath("input_data", "building_network_model_production", "01", "opening-condition", opening.file)
    input_climate = joinpath("input_data", "building_network_model_production", "climate-data", climate.file)

    # BNMモデル作成
    println("   🔧 モデル作成...")
    network_model = create_BNM_model(
        file_name_rooms    = "./" * input_room,
        file_name_walls    = "./" * input_wall,
        file_name_openings = "./" * input_opening,
        file_name_climate  = "./" * input_climate
    )
    println("      └─ ✅ 完了")

    # 位置情報設定
    network_model.climate.location["city"] = climate.name
    network_model.climate.location["lon"]  = climate.lon
    network_model.climate.location["phi"]  = climate.phi
    network_model.climate.location["lons"] = LONS

    # 計算開始時刻設定
    network_model.climate.date = START_DATE
    reset_climate_data(network_model.climate)

    # 出力ディレクトリ
    case_output_dir = joinpath(batch_dir, case_id)
    mkpath(case_output_dir)

    # ロガー設定
    output_data_dir = joinpath(PROJECT_DIR, "output_data")
    relative_output = case_output_dir[length(output_data_dir)+2:end]
    relative_output = replace(relative_output, "\\" => "/")

    logger_rooms = set_logger(
        relative_output * "/result_all_rooms",
        OUTPUT_INTERVAL,
        ["temp", "rh", "ah"],
        network_model.rooms
    )

    loggers = [logger_rooms]

    for files in loggers
        write_header_to_logger(files)
        write_data_to_logger(files, network_model.climate.date)
    end

    # 計算ループ（1回だけ）
    println("   🔄 計算実行（1ステップ）...")

    reset_climate_data(network_model.climate)
    cal_network_flux_of_wall(network_model)
    cal_network_flux_of_ventilation(network_model)
    cal_new_value_ver_network(network_model, DT)
    time_elapses(network_model.climate, DT)

    for files in loggers
        write_data_to_logger(files, network_model.climate.date)
    end

    println("      └─ ✅ 完了")

    # ファイルクローズ
    for files in loggers
        for i = 1:length(files.file)
            close(files.file[i])
        end
    end

    # テスト結果ファイル作成
    open(joinpath(case_output_dir, "_test_result.txt"), "w") do f
        println(f, "Git Push テスト")
        println(f, "実行時刻: $(now())")
        println(f, "ケース: $case_id")
        println(f, "ステータス: 成功")
    end

    println()
    println("   🎉 計算完了!")

    # GitHubにpush
    git_push_results(batch_dir, case_id)

    println()
    println("🧪 ════════════════════════════════════════════════════════════════")
    println("🧪  テスト完了!")
    println("🧪 ════════════════════════════════════════════════════════════════")
    println()
end

main()
