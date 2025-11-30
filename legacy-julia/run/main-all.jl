#=
================================================================================
建物内温湿度環境解析ネットワークモデル - 全パターン一括実行
================================================================================

使い方:
    julia run/main-all.jl

機能:
    - 5(wall) × 5(opening) × 3(climate) = 75パターンを自動実行
    - 進捗管理ファイルで状況確認可能
    - エラー発生時も続行し、後で確認可能
    - 中断後の再開機能（完了済みパターンはスキップ）

出力先:
    output_data/batch_all/
    ├── _progress.txt          # 進捗状況（人間可読）
    ├── _batch_log.txt         # 実行ログ
    ├── _summary.csv           # 全パターンの結果一覧
    ├── _completed.txt         # 完了済みパターンリスト（再開用）
    │
    ├── w01-base_o01-base_kyoto/
    │   ├── settings.txt
    │   ├── result_all_rooms.csv
    │   └── ...
    └── ...
=#

using Dates
using Printf

# スクリプトのディレクトリとプロジェクトルートを取得
const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)

#=============================================================================
                           パターン定義
=============================================================================#

# 壁体パターン
const WALL_PATTERNS = [
    (id="w01-base",    file="01-base-model.csv",                    name="RC単体"),
    (id="w02-inner",   file="02-rc-inner-insulation.csv",           name="RC内断熱"),
    (id="w03-outer",   file="03-rc-outer-insulation.csv",           name="RC外断熱"),
    (id="w04-hygro",   file="04-rc-inner-insulation-hygroscopic.csv", name="RC内断熱+調湿"),
    (id="w05-mud",     file="05-mud-wall.csv",                      name="土壁"),
]

# 換気パターン
const OPENING_PATTERNS = [
    (id="o01-base",    file="01-base-model.csv",              name="基準換気"),
    (id="o02-low",     file="02-low-ventilation-model.csv",   name="低換気"),
    (id="o03-high",    file="03-high-ventilation-model.csv",  name="高換気"),
    (id="o04-none",    file="04-no-ventilation-model.csv",    name="無換気"),
    (id="o05-storage", file="05-storage-ventilation-model.csv", name="蔵換気"),
]

# 気候パターン
const CLIMATE_PATTERNS = [
    (id="kyoto",   file="climate_data_kyoto.csv",   name="京都", lon=135.768, phi=35.012),
    (id="okinawa", file="climate_data_okinawa.csv", name="沖縄", lon=127.681, phi=26.212),
    (id="sapporo", file="climate_data_sapporo.csv", name="札幌", lon=141.347, phi=43.064),
]

# 室条件（固定）
const ROOM_FILE = "01-base-model.csv"

#=============================================================================
                           計算条件
=============================================================================#

const DT = 0.1                                      # 時間刻み [hour]
const START_DATE = DateTime(2020, 4, 1, 0, 0, 0)    # 計算開始時刻
const END_DATE   = DateTime(2020, 10, 1, 0, 0, 0)   # 計算終了時刻
const OUTPUT_INTERVAL = 10.0                        # 出力間隔 [hour]
const LONS = 135.0                                  # 地方標準時の経度

# 出力設定
const OUTPUT_BASE_DIR = "output_data"
const BATCH_DIR_NAME = "batch_all"

#=============================================================================
                           起動メッセージ
=============================================================================#

println()
println("🚀 ════════════════════════════════════════════════════════════════")
println("🚀  建物内温湿度環境解析ネットワークモデル")
println("🚀  全パターン一括実行 (Batch Runner)")
println("🚀 ════════════════════════════════════════════════════════════════")
println("🚀  起動時刻: ", now())
println("🚀  スクリプト: ", SCRIPT_DIR)
println("🚀  プロジェクト: ", PROJECT_DIR)
println("🚀 ════════════════════════════════════════════════════════════════")
println()

#=============================================================================
                           モジュール読み込み
=============================================================================#

# 作業ディレクトリをプロジェクトルートに変更
println("📂 作業ディレクトリ変更...")
println("   ├─ 変更前: ", pwd())
cd(PROJECT_DIR)
println("   └─ 変更後: ", pwd())
println()

# モジュール読み込み（グローバルスコープで実行）
println("📦 モジュール読み込み開始...")
println("   ├─ building_network_model.jl")
include(joinpath(PROJECT_DIR, "module", "building_network_model.jl"))
println("   │   ✅ 完了")
println("   ├─ transfer_in_media.jl")
include(joinpath(PROJECT_DIR, "module", "transfer_in_media.jl"))
println("   │   ✅ 完了")
println("   └─ logger.jl")
include(joinpath(SCRIPT_DIR, "logger.jl"))
println("       ✅ 完了")
println("📦 モジュール読み込み完了!")
println()

#=============================================================================
                           ユーティリティ関数
=============================================================================#

"""バッチディレクトリのパスを取得"""
function get_batch_dir()
    return joinpath(PROJECT_DIR, OUTPUT_BASE_DIR, BATCH_DIR_NAME)
end

"""ログファイルに書き込み"""
function log_message(batch_dir::String, message::String; also_print=true)
    log_file = joinpath(batch_dir, "_batch_log.txt")
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    line = "[$timestamp] $message"

    open(log_file, "a") do f
        println(f, line)
    end

    if also_print
        println(line)
    end
end

"""進捗ファイルを更新"""
function update_progress(batch_dir::String, current_idx::Int, total::Int,
                         current_case::String, status::String;
                         completed::Int=0, failed::Int=0, skipped::Int=0,
                         start_time::DateTime=now(),
                         estimated_remaining::String="計算中...")

    progress_file = joinpath(batch_dir, "_progress.txt")

    elapsed = now() - start_time
    elapsed_sec = Dates.value(elapsed) / 1000
    elapsed_str = format_duration(elapsed_sec)

    # 進捗率
    progress_pct = round(current_idx / total * 100, digits=1)

    # プログレスバー
    bar_width = 50
    filled = Int(floor(bar_width * current_idx / total))
    bar = "█"^filled * "░"^(bar_width - filled)

    open(progress_file, "w") do f
        println(f, "")
        println(f, "🚀 ════════════════════════════════════════════════════════════════")
        println(f, "🚀  建物内温湿度環境解析 - バッチ実行進捗")
        println(f, "🚀 ════════════════════════════════════════════════════════════════")
        println(f, "")
        println(f, "   [$bar] $progress_pct%")
        println(f, "")
        println(f, "   📊 進捗状況: $current_idx / $total パターン")
        println(f, "")
        println(f, "   ┌──────────────────────────────────────────────────")
        println(f, "   │  ✅ 完了:     $completed")
        println(f, "   │  ❌ 失敗:     $failed")
        println(f, "   │  ⏭️  スキップ: $skipped")
        println(f, "   │  ⏳ 残り:     $(total - current_idx)")
        println(f, "   └──────────────────────────────────────────────────")
        println(f, "")
        println(f, "   🔄 現在実行中: $current_case")
        println(f, "   📝 ステータス: $status")
        println(f, "")
        println(f, "   ⏱️  経過時間: $elapsed_str")
        println(f, "   ⏰ 残り時間: $estimated_remaining")
        println(f, "")
        println(f, "   📅 最終更新: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(f, "")
        println(f, "════════════════════════════════════════════════════════════════════")
    end
end

"""時間をフォーマット"""
function format_duration(seconds::Float64)
    if seconds < 60
        return @sprintf("%.1f秒", seconds)
    elseif seconds < 3600
        mins = Int(floor(seconds / 60))
        secs = Int(round(seconds % 60))
        return @sprintf("%d分%d秒", mins, secs)
    else
        hours = Int(floor(seconds / 3600))
        mins = Int(floor((seconds % 3600) / 60))
        return @sprintf("%d時間%d分", hours, mins)
    end
end

"""残り時間を推定"""
function estimate_remaining(elapsed_sec::Float64, completed::Int, total::Int)
    if completed == 0
        return "計算中..."
    end

    avg_per_case = elapsed_sec / completed
    remaining_cases = total - completed
    remaining_sec = avg_per_case * remaining_cases

    return format_duration(remaining_sec)
end

"""完了済みパターンを読み込み"""
function load_completed(batch_dir::String)
    completed_file = joinpath(batch_dir, "_completed.txt")
    completed = Set{String}()

    if isfile(completed_file)
        for line in readlines(completed_file)
            line = strip(line)
            if !isempty(line) && !startswith(line, "#")
                push!(completed, line)
            end
        end
    end

    return completed
end

"""完了パターンを追記"""
function mark_completed(batch_dir::String, case_id::String)
    completed_file = joinpath(batch_dir, "_completed.txt")
    open(completed_file, "a") do f
        println(f, case_id)
    end
end

"""サマリCSVのヘッダーを書き込み"""
function write_summary_header(batch_dir::String)
    summary_file = joinpath(batch_dir, "_summary.csv")
    if !isfile(summary_file)
        open(summary_file, "w") do f
            println(f, "case_id,wall_id,wall_name,opening_id,opening_name,climate_id,climate_name,status,duration_sec,start_time,end_time,error_message")
        end
    end
end

"""サマリCSVに結果を追記"""
function append_summary(batch_dir::String, case_id::String,
                        wall, opening, climate,
                        status::String, duration_sec::Float64,
                        start_time::DateTime, end_time::DateTime,
                        error_msg::String="")
    summary_file = joinpath(batch_dir, "_summary.csv")

    # エラーメッセージ内のカンマと改行をエスケープ
    error_escaped = replace(replace(error_msg, "," => ";"), "\n" => " ")

    open(summary_file, "a") do f
        println(f, "$case_id,$(wall.id),$(wall.name),$(opening.id),$(opening.name),$(climate.id),$(climate.name),$status,$duration_sec,$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")),$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")),\"$error_escaped\"")
    end
end

#=============================================================================
                           シミュレーション実行
=============================================================================#

"""単一パターンのシミュレーションを実行（詳細ログ付き）"""
function run_single_simulation(wall, opening, climate, output_dir::String, case_idx::Int, total::Int)
    case_id = "$(wall.id)_$(opening.id)_$(climate.id)"

    println()
    println("   🏗️  ──────────────────────────────────────────────────────────")
    println("   🏗️   モデル構築開始")
    println("   🏗️  ──────────────────────────────────────────────────────────")
    println()

    # 入力ファイルパス
    input_room = joinpath("input_data", "building_network_model_production", "01", "room-condition", ROOM_FILE)
    input_wall = joinpath("input_data", "building_network_model_production", "01", "wall-condition", wall.file)
    input_opening = joinpath("input_data", "building_network_model_production", "01", "opening-condition", opening.file)
    input_climate = joinpath("input_data", "building_network_model_production", "climate-data", climate.file)

    println("   📄 入力ファイル:")
    println("      ├─ 🏠 Room:    $input_room")
    println("      ├─ 🧱 Wall:    $input_wall")
    println("      ├─ 🚪 Opening: $input_opening")
    println("      └─ 🌤️  Climate: $input_climate")
    println()

    # 設定ファイル保存
    settings_path = joinpath(output_dir, "settings.txt")
    open(settings_path, "w") do f
        println(f, "🚀 ════════════════════════════════════════════════════════")
        println(f, "🚀  計算設定")
        println(f, "🚀 ════════════════════════════════════════════════════════")
        println(f, "")
        println(f, "📊 パターン情報:")
        println(f, "   ├─ ケースID: $case_id")
        println(f, "   ├─ 🧱 壁体:   $(wall.name) ($(wall.id))")
        println(f, "   ├─ 🚪 換気:   $(opening.name) ($(opening.id))")
        println(f, "   └─ 🌤️  気候:   $(climate.name) ($(climate.id))")
        println(f, "")
        println(f, "📄 入力ファイル:")
        println(f, "   ├─ Room:    $input_room")
        println(f, "   ├─ Wall:    $input_wall")
        println(f, "   ├─ Opening: $input_opening")
        println(f, "   └─ Climate: $input_climate")
        println(f, "")
        println(f, "⏱️  計算条件:")
        println(f, "   ├─ 時間刻み dt: $DT hour")
        println(f, "   ├─ 開始時刻: $START_DATE")
        println(f, "   ├─ 終了時刻: $END_DATE")
        println(f, "   └─ 出力間隔: $OUTPUT_INTERVAL hour")
        println(f, "")
        println(f, "📍 位置情報:")
        println(f, "   ├─ 都市: $(climate.name)")
        println(f, "   ├─ 経度: $(climate.lon)")
        println(f, "   ├─ 緯度: $(climate.phi)")
        println(f, "   └─ 標準時経度: $LONS")
        println(f, "")
        println(f, "════════════════════════════════════════════════════════════")
        println(f, "")
        println(f, "⏰ 実行開始: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    end

    # BNMモデル作成
    println("   🔧 BNMモデル作成中...")
    println("      ├─ CSV読み込み...")
    network_model = create_BNM_model(
        file_name_rooms    = "./" * input_room,
        file_name_walls    = "./" * input_wall,
        file_name_openings = "./" * input_opening,
        file_name_climate  = "./" * input_climate
    )
    println("      └─ ✅ BNMモデル作成完了")
    println()

    # モデル情報表示
    println("   📊 モデル構成:")
    println("      ├─ 🏠 Rooms: $(length(network_model.rooms)) 室")
    for i = 1:length(network_model.rooms)
        room = network_model.rooms[i]
        if i == length(network_model.rooms)
            println("      │   └─ [$i] $(room.name)")
            println("      │       ├─ 容積: $(room.air.vol) m³")
            println("      │       ├─ 温度: $(round(room.air.temp - 273.15, digits=1)) ℃")
            println("      │       └─ 湿度: $(round(room.air.rh * 100, digits=0)) %")
        else
            println("      │   ├─ [$i] $(room.name)")
            println("      │   │   ├─ 容積: $(room.air.vol) m³")
            println("      │   │   ├─ 温度: $(round(room.air.temp - 273.15, digits=1)) ℃")
            println("      │   │   └─ 湿度: $(round(room.air.rh * 100, digits=0)) %")
        end
    end
    println("      │")
    println("      ├─ 🧱 Walls: $(length(network_model.walls)) 壁")
    for i = 1:length(network_model.walls)
        wall_obj = network_model.walls[i]
        if i == length(network_model.walls)
            println("      │   └─ [$i] $(wall_obj.name)")
            println("      │       ├─ IP→IM: $(wall_obj.IP) → $(wall_obj.IM)")
            println("      │       ├─ 面積: $(wall_obj.area) m²")
            println("      │       └─ セル数: $(length(wall_obj.cell))")
        else
            println("      │   ├─ [$i] $(wall_obj.name)")
            println("      │   │   ├─ IP→IM: $(wall_obj.IP) → $(wall_obj.IM)")
            println("      │   │   ├─ 面積: $(wall_obj.area) m²")
            println("      │   │   └─ セル数: $(length(wall_obj.cell))")
        end
    end
    println("      │")
    println("      └─ 🚪 Openings: $(length(network_model.openings)) 開口")
    for i = 1:length(network_model.openings)
        op = network_model.openings[i]
        if i == length(network_model.openings)
            println("          └─ [$i] Type: $(op.Type)")
            println("              ├─ IP→IM: $(op.IP) → $(op.IM)")
            println("              ├─ Qup: $(op.Qup) m³/s")
            println("              └─ Qdw: $(op.Qdw) m³/s")
        else
            println("          ├─ [$i] Type: $(op.Type)")
            println("          │   ├─ IP→IM: $(op.IP) → $(op.IM)")
            println("          │   ├─ Qup: $(op.Qup) m³/s")
            println("          │   └─ Qdw: $(op.Qdw) m³/s")
        end
    end
    println()

    # 位置情報設定
    println("   📍 位置情報設定...")
    network_model.climate.location["city"] = climate.name
    network_model.climate.location["lon"]  = climate.lon
    network_model.climate.location["phi"]  = climate.phi
    network_model.climate.location["lons"] = LONS
    println("      └─ ✅ 完了")
    println()

    # 計算開始時刻設定
    println("   ⏰ 計算時刻設定...")
    network_model.climate.date = START_DATE
    println("      ├─ 開始時刻: $START_DATE")
    reset_climate_data(network_model.climate)
    println("      ├─ 気象データ初期化完了")
    println("      │   ├─ 外気温: $(round(temp(network_model.climate) - 273.15, digits=1)) ℃")
    println("      │   └─ 外気湿度: $(round(rh(network_model.climate) * 100, digits=0)) %")
    println("      └─ ✅ 完了")
    println()

    # ロガー設定
    println("   📝 ロガー設定...")
    relative_output = replace(output_dir, joinpath(PROJECT_DIR, "output_data") * "/" => "")

    logger_rooms = set_logger(
        joinpath(relative_output, "result_all_rooms"),
        OUTPUT_INTERVAL,
        ["temp", "rh", "ah"],
        network_model.rooms
    )
    println("      ├─ result_all_rooms ✅")

    logger_walls = [
        set_logger(
            joinpath(relative_output, "result_wall" * string(i)),
            OUTPUT_INTERVAL,
            ["temp", "rh", "ah", "phi"],
            network_model.walls[i].target_model
        )
        for i = 1:length(network_model.walls)
    ]
    for i = 1:length(logger_walls)
        println("      ├─ result_wall$i ✅")
    end

    logger_room_analysis = set_logger(
        joinpath(relative_output, "result_room_analysis"),
        OUTPUT_INTERVAL,
        ["room_analysis"],
        network_model
    )
    println("      └─ result_room_analysis ✅")
    println()

    loggers = vcat(logger_rooms, [logger_walls[i] for i = 1:length(logger_walls)], logger_room_analysis)

    # ヘッダー書き込み
    println("   📝 ヘッダー書き込み...")
    for files in loggers
        write_header_to_logger(files)
        write_data_to_logger(files, network_model.climate.date)
    end
    println("      └─ ✅ $(length(loggers)) ファイルに書き込み完了")
    println()

    # 計算ループ
    println("   🔄 ══════════════════════════════════════════════════════════")
    println("   🔄  計算ループ開始")
    println("   🔄 ══════════════════════════════════════════════════════════")
    println()
    println("      📅 期間: $START_DATE → $END_DATE")
    println("      ⏱️  時間刻み: $DT hour")
    println("      📊 出力間隔: $OUTPUT_INTERVAL hour")
    println()
    println("      ───────────────────────────────────────────────────────────")

    step_count = 0
    calc_start_time = now()

    while network_model.climate.date ≠ END_DATE
        step_count += 1

        reset_climate_data(network_model.climate)
        cal_network_flux_of_wall(network_model)
        cal_network_flux_of_ventilation(network_model)
        cal_new_value_ver_network(network_model, DT)

        # 日次進捗表示（毎日0時に表示）
        if hour(network_model.climate.date) == 0 &&
           minute(network_model.climate.date) == 0 &&
           second(network_model.climate.date) == 0 &&
           millisecond(network_model.climate.date) == 0

            elapsed = now() - calc_start_time
            elapsed_sec = Dates.value(elapsed) / 1000

            out_temp = round(temp(network_model.climate) - 273.15, digits=1)
            out_rh = round(rh(network_model.climate) * 100, digits=0)
            in_temp = round(temp(network_model.rooms[2]) - 273.15, digits=1)
            in_rh = round(rh(network_model.rooms[2]) * 100, digits=0)

            println("      📅 ", Dates.format(network_model.climate.date, "yyyy/mm/dd"),
                    "  🌤️  外気: ", out_temp, "℃ ", out_rh, "%",
                    "  🏠 室内: ", in_temp, "℃ ", in_rh, "%",
                    "  ⏱️  ", format_duration(elapsed_sec))
        end

        time_elapses(network_model.climate, DT)

        for files in loggers
            write_data_to_logger(files, network_model.climate.date)
        end
    end

    println("      ───────────────────────────────────────────────────────────")
    println()

    # ファイルクローズ
    println("   📁 ファイルクローズ...")
    for files in loggers
        for i = 1:length(files.file)
            close(files.file[i])
        end
    end
    println("      └─ ✅ 全ファイルクローズ完了")
    println()

    # 設定ファイルに完了時刻を追記
    calc_end_time = now()
    calc_elapsed = Dates.value(calc_end_time - calc_start_time) / 1000

    open(settings_path, "a") do f
        println(f, "⏰ 実行完了: $(Dates.format(calc_end_time, "yyyy-mm-dd HH:MM:SS"))")
        println(f, "⏱️  計算時間: $(format_duration(calc_elapsed))")
        println(f, "📊 総ステップ数: $step_count")
    end

    # 完了メッセージ
    println("   🎉 ──────────────────────────────────────────────────────────")
    println("   🎉  パターン完了!")
    println("   🎉 ──────────────────────────────────────────────────────────")
    println()
    println("      📊 統計:")
    println("         ├─ 総ステップ数: $step_count")
    println("         └─ 計算時間: $(format_duration(calc_elapsed))")
    println()

    return calc_elapsed
end

#=============================================================================
                     壁体・換気計算関数（main.jlから移植）
=============================================================================#

"""壁体を通じた熱・水分流量計算"""
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

"""換気による熱・水分流量計算"""
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

"""収支計算・新値更新"""
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
                        # 結露警告は抑制（バッチ実行時）
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
    println()
    println("⚙️  ════════════════════════════════════════════════════════════════")
    println("⚙️   設定確認")
    println("⚙️  ════════════════════════════════════════════════════════════════")
    println()

    # パターン定義表示
    println("📊 パターン定義:")
    println()
    println("   🧱 壁体パターン ($(length(WALL_PATTERNS))種類):")
    for (i, w) in enumerate(WALL_PATTERNS)
        prefix = i == length(WALL_PATTERNS) ? "└─" : "├─"
        println("      $prefix [$(w.id)] $(w.name)")
    end
    println()
    println("   🚪 換気パターン ($(length(OPENING_PATTERNS))種類):")
    for (i, o) in enumerate(OPENING_PATTERNS)
        prefix = i == length(OPENING_PATTERNS) ? "└─" : "├─"
        println("      $prefix [$(o.id)] $(o.name)")
    end
    println()
    println("   🌤️  気候パターン ($(length(CLIMATE_PATTERNS))種類):")
    for (i, c) in enumerate(CLIMATE_PATTERNS)
        prefix = i == length(CLIMATE_PATTERNS) ? "└─" : "├─"
        println("      $prefix [$(c.id)] $(c.name) (経度:$(c.lon), 緯度:$(c.phi))")
    end
    println()

    # 計算条件表示
    println("⏱️  計算条件:")
    println("   ├─ 時間刻み dt: $DT hour ($(Int(DT * 60))分)")
    println("   ├─ 開始時刻: $START_DATE")
    println("   ├─ 終了時刻: $END_DATE")
    println("   └─ 出力間隔: $OUTPUT_INTERVAL hour")
    println()

    # バッチディレクトリ作成
    println("📁 出力ディレクトリ作成...")
    batch_dir = get_batch_dir()
    mkpath(batch_dir)
    println("   └─ ✅ 作成完了: $(abspath(batch_dir))")
    println()

    # 全パターンの組み合わせを生成
    all_cases = []
    for wall in WALL_PATTERNS
        for opening in OPENING_PATTERNS
            for climate in CLIMATE_PATTERNS
                case_id = "$(wall.id)_$(opening.id)_$(climate.id)"
                push!(all_cases, (case_id=case_id, wall=wall, opening=opening, climate=climate))
            end
        end
    end

    total = length(all_cases)

    println("📊 総パターン数:")
    println("   ├─ $(length(WALL_PATTERNS)) (壁体) × $(length(OPENING_PATTERNS)) (換気) × $(length(CLIMATE_PATTERNS)) (気候)")
    println("   └─ = $total パターン")
    println()

    # 完了済みパターンを読み込み
    completed_set = load_completed(batch_dir)
    skipped_count = length(completed_set)

    if skipped_count > 0
        println("🔄 再開モード検出:")
        println("   ├─ 完了済み: $skipped_count パターン")
        println("   └─ 残り: $(total - skipped_count) パターン")
        println()
    end

    # サマリCSVヘッダー
    write_summary_header(batch_dir)

    # 初期ログ
    log_message(batch_dir, "════════════════════════════════════════════════════════", also_print=false)
    log_message(batch_dir, "🚀 バッチ実行開始", also_print=false)
    log_message(batch_dir, "   総パターン数: $total", also_print=false)
    log_message(batch_dir, "   スキップ済み: $skipped_count", also_print=false)
    log_message(batch_dir, "════════════════════════════════════════════════════════", also_print=false)

    # 実行開始
    batch_start_time = now()
    completed_count = skipped_count
    failed_count = 0

    println()
    println("🔄 ════════════════════════════════════════════════════════════════")
    println("🔄  バッチ実行開始")
    println("🔄 ════════════════════════════════════════════════════════════════")
    println()

    for (idx, case) in enumerate(all_cases)
        case_id = case.case_id

        # 進捗更新
        elapsed = Dates.value(now() - batch_start_time) / 1000
        remaining = estimate_remaining(elapsed, completed_count - skipped_count, total - skipped_count)

        update_progress(batch_dir, idx, total, case_id, "準備中",
                       completed=completed_count, failed=failed_count, skipped=skipped_count,
                       start_time=batch_start_time, estimated_remaining=remaining)

        # 完了済みならスキップ
        if case_id in completed_set
            println("⏭️  [$idx/$total] $case_id")
            println("   └─ スキップ（完了済み）")
            println()
            continue
        end

        # 出力ディレクトリ作成
        case_output_dir = joinpath(batch_dir, case_id)
        mkpath(case_output_dir)

        println("🔄 ════════════════════════════════════════════════════════════════")
        println("🔄  [$idx/$total] $case_id")
        println("🔄 ════════════════════════════════════════════════════════════════")
        println()
        println("   📊 パターン詳細:")
        println("      ├─ 🧱 壁体: $(case.wall.name) ($(case.wall.id))")
        println("      ├─ 🚪 換気: $(case.opening.name) ($(case.opening.id))")
        println("      └─ 🌤️  気候: $(case.climate.name) ($(case.climate.id))")

        # 進捗更新
        update_progress(batch_dir, idx, total, case_id, "実行中",
                       completed=completed_count, failed=failed_count, skipped=skipped_count,
                       start_time=batch_start_time, estimated_remaining=remaining)

        log_message(batch_dir, "開始: $case_id", also_print=false)

        case_start_time = now()

        try
            duration = run_single_simulation(case.wall, case.opening, case.climate, case_output_dir, idx, total)

            case_end_time = now()

            completed_count += 1
            mark_completed(batch_dir, case_id)

            append_summary(batch_dir, case_id, case.wall, case.opening, case.climate,
                          "SUCCESS", duration, case_start_time, case_end_time)

            log_message(batch_dir, "完了: $case_id ($(format_duration(duration)))", also_print=false)

            # 全体進捗表示
            elapsed_total = Dates.value(now() - batch_start_time) / 1000
            remaining_est = estimate_remaining(elapsed_total, completed_count - skipped_count, total - skipped_count)

            println("   📊 全体進捗: $completed_count/$total 完了 | 残り時間: $remaining_est")
            println()

        catch e
            case_end_time = now()
            duration = Dates.value(case_end_time - case_start_time) / 1000

            failed_count += 1
            error_msg = sprint(showerror, e)

            append_summary(batch_dir, case_id, case.wall, case.opening, case.climate,
                          "FAILED", duration, case_start_time, case_end_time, error_msg)

            log_message(batch_dir, "❌ 失敗: $case_id - $error_msg")

            println()
            println("   ❌ ──────────────────────────────────────────────────────────")
            println("   ❌  エラー発生")
            println("   ❌ ──────────────────────────────────────────────────────────")
            println()
            println("      $error_msg")
            println()

            # エラーログをケースフォルダにも保存
            error_file = joinpath(case_output_dir, "_error.txt")
            open(error_file, "w") do f
                println(f, "🚨 エラー発生")
                println(f, "")
                println(f, "⏰ 発生時刻: $(Dates.format(case_end_time, "yyyy-mm-dd HH:MM:SS"))")
                println(f, "")
                println(f, "📝 エラーメッセージ:")
                println(f, error_msg)
                println(f, "")
                println(f, "📋 スタックトレース:")
                for (exc, bt) in Base.catch_stack()
                    showerror(f, exc, bt)
                    println(f)
                end
            end
        end
    end

    # 最終進捗更新
    batch_end_time = now()
    total_elapsed = Dates.value(batch_end_time - batch_start_time) / 1000

    update_progress(batch_dir, total, total, "完了", "全パターン処理完了",
                   completed=completed_count, failed=failed_count, skipped=skipped_count,
                   start_time=batch_start_time, estimated_remaining="0秒")

    # 最終ログ
    log_message(batch_dir, "════════════════════════════════════════════════════════", also_print=false)
    log_message(batch_dir, "🎉 バッチ実行完了", also_print=false)
    log_message(batch_dir, "   総時間: $(format_duration(total_elapsed))", also_print=false)
    log_message(batch_dir, "   完了: $completed_count / $total", also_print=false)
    log_message(batch_dir, "   失敗: $failed_count", also_print=false)
    log_message(batch_dir, "════════════════════════════════════════════════════════", also_print=false)

    # 完了メッセージ
    println()
    println("🎉 ════════════════════════════════════════════════════════════════")
    println("🎉  バッチ実行完了!")
    println("🎉 ════════════════════════════════════════════════════════════════")
    println()
    println("   📊 結果サマリ:")
    println("      ├─ 総パターン数:   $total")
    println("      ├─ ✅ 完了:        $completed_count")
    println("      ├─ ❌ 失敗:        $failed_count")
    println("      ├─ ⏭️  スキップ:    $skipped_count")
    println("      └─ ⏱️  総実行時間:  $(format_duration(total_elapsed))")
    println()
    println("   📁 出力先:")
    println("      └─ $(abspath(batch_dir))")
    println()
    println("   📄 確認用ファイル:")
    println("      ├─ _progress.txt    進捗状況")
    println("      ├─ _summary.csv     全パターン結果一覧")
    println("      ├─ _batch_log.txt   実行ログ")
    println("      └─ _completed.txt   完了済みリスト")
    println()

    if failed_count > 0
        println("   ⚠️  注意:")
        println("      └─ $failed_count パターンが失敗しました")
        println("         _summary.csv で詳細を確認してください")
        println()
    end

    println("✅ 正常終了")
    println()
end

# 実行
main()
