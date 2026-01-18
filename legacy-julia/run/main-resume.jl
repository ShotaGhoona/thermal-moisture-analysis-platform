#=
================================================================================
建物内温湿度環境解析 - 途中再開スクリプト
================================================================================

使い方:
    julia run/main-resume.jl <既存の出力ディレクトリパス>

例:
    julia run/main-resume.jl output_data/batch_all_3/1224/w02-inner_o01-base_sapporo

機能:
    - 既存の計算結果から最後の状態を読み込み
    - その状態から計算を再開
    - 結果を同じディレクトリに追記
=#

using Dates
using Printf
using DelimitedFiles

# スクリプトのディレクトリとプロジェクトルートを取得
const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)

#=============================================================================
                          計算条件
=============================================================================#

const DT = 0.1                                      # 時間刻み [hour]
const END_DATE = DateTime(2023, 4, 1, 0, 0, 0)      # 計算終了時刻
const OUTPUT_INTERVAL = 10.0                        # 出力間隔 [hour]
const LONS = 135.0                                  # 地方標準時の経度

#=============================================================================
                          起動メッセージ
=============================================================================#

println()
println("🔄 ════════════════════════════════════════════════════════════════")
println("🔄  建物内温湿度環境解析 - 途中再開モード")
println("🔄 ════════════════════════════════════════════════════════════════")
println("🔄  起動時刻: ", now())
println("🔄 ════════════════════════════════════════════════════════════════")
println()

#=============================================================================
                          引数処理
=============================================================================#

if length(ARGS) < 1
    println("❌ エラー: 既存の出力ディレクトリパスを指定してください")
    println()
    println("使い方:")
    println("    julia run/main-resume.jl <既存の出力ディレクトリパス>")
    println()
    println("例:")
    println("    julia run/main-resume.jl output_data/batch_all_3/1224/w02-inner_o01-base_sapporo")
    exit(1)
end

const RESUME_DIR = ARGS[1]

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
                          追記モード用のlogger関数
=============================================================================#

"""追記モードでloggerを設定"""
function set_logger_append(file_name::String, logging_interval, data_type::Array{String,1}, logging_data)
    # ファイルを追記モードで開く
    if data_type == ["room_analysis"]
        file = [open("./output_data/" * file_name * string(i) * ".csv", "a") for i = 1:length(logging_data.rooms)]
    else
        file = [open("./output_data/" * file_name * ".csv", "a")]
    end
    logger = Logger(file, file_name, logging_interval, data_type, logging_data)
    return logger
end

#=============================================================================
                          状態復元関数
=============================================================================#

"""settings.txtから設定を読み込む"""
function load_settings(settings_path::String)
    settings = Dict{String, String}()

    for line in readlines(settings_path)
        # Room: ./input_data/... 形式を解析
        if contains(line, "Room:")
            m = match(r"Room:\s+(.+)$", line)
            if m !== nothing
                settings["room_file"] = strip(m.captures[1])
            end
        elseif contains(line, "Wall:") && !contains(line, "Walls:")
            m = match(r"Wall:\s+(.+)$", line)
            if m !== nothing
                settings["wall_file"] = strip(m.captures[1])
            end
        elseif contains(line, "Opening:")
            m = match(r"Opening:\s+(.+)$", line)
            if m !== nothing
                settings["opening_file"] = strip(m.captures[1])
            end
        elseif contains(line, "Climate:") && !contains(line, "気候")
            m = match(r"Climate:\s+(.+)$", line)
            if m !== nothing
                settings["climate_file"] = strip(m.captures[1])
            end
        elseif contains(line, "都市:")
            m = match(r"都市:\s+(.+)$", line)
            if m !== nothing
                settings["city"] = strip(m.captures[1])
            end
        elseif contains(line, "経度:") && !contains(line, "標準時")
            m = match(r"経度:\s+(.+)$", line)
            if m !== nothing
                settings["lon"] = strip(m.captures[1])
            end
        elseif contains(line, "緯度:")
            m = match(r"緯度:\s+(.+)$", line)
            if m !== nothing
                settings["phi"] = strip(m.captures[1])
            end
        end
    end

    return settings
end

"""CSVの最後の行から状態を読み込む"""
function load_last_state(csv_path::String)
    lines = readlines(csv_path)
    last_line = lines[end]

    # カンマで分割
    values = split(last_line, ",")

    return values
end

"""日時文字列をDateTimeに変換"""
function parse_datetime(date_str::AbstractString)
    # "2022/04/13 12:00" 形式
    return DateTime(String(date_str), "yyyy/mm/dd HH:MM")
end

"""室の状態を復元"""
function restore_room_state!(room, temp_c::Float64, rh::Float64)
    # 温度をケルビンに変換して設定
    set_temp(room, temp_c + 273.15)
    set_rh(room, rh)
end

"""壁体セルの状態を復元"""
function restore_cell_state!(cell, temp_c::Float64, rh::Float64)
    # 温度をケルビンに変換
    cell.temp = temp_c + 273.15

    # 相対湿度から水分化学ポテンシャルを計算
    # μ = Rv * T * ln(rh)  where Rv = 461.5 J/(kg·K)
    Rv = 461.5
    T = cell.temp
    if rh > 0 && rh <= 1
        cell.miu = Rv * T * log(rh)
    else
        cell.miu = -1000.0  # デフォルト値
    end
end

#=============================================================================
                     壁体・換気計算関数
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

#=============================================================================
                          メイン処理
=============================================================================#

function main()
    resume_path = joinpath(PROJECT_DIR, RESUME_DIR)

    println("📁 再開ディレクトリ: $resume_path")
    println()

    # 必要なファイルの存在確認
    settings_file = joinpath(resume_path, "settings.txt")
    rooms_file = joinpath(resume_path, "result_all_rooms.csv")
    wall_file = joinpath(resume_path, "result_wall1.csv")

    if !isfile(settings_file)
        println("❌ settings.txt が見つかりません")
        exit(1)
    end
    if !isfile(rooms_file)
        println("❌ result_all_rooms.csv が見つかりません")
        exit(1)
    end
    if !isfile(wall_file)
        println("❌ result_wall1.csv が見つかりません")
        exit(1)
    end

    # 設定を読み込み
    println("📄 設定ファイル読み込み...")
    settings = load_settings(settings_file)
    println("   ├─ Room: $(get(settings, "room_file", "不明"))")
    println("   ├─ Wall: $(get(settings, "wall_file", "不明"))")
    println("   ├─ Opening: $(get(settings, "opening_file", "不明"))")
    println("   ├─ Climate: $(get(settings, "climate_file", "不明"))")
    println("   └─ 都市: $(get(settings, "city", "不明"))")
    println()

    # 最後の状態を読み込み
    println("📊 最後の状態を読み込み...")

    # result_all_rooms.csv から室の状態
    room_state = load_last_state(rooms_file)
    last_datetime_str = strip(room_state[1])
    last_datetime = parse_datetime(last_datetime_str)

    println("   ├─ 最終時刻: $last_datetime")

    # 室内状態（room2 = indoor）
    # 形式: date, room1_temp, room1_rh, room1_ah, room2_temp, room2_rh, room2_ah
    room2_temp = parse(Float64, room_state[5])
    room2_rh = parse(Float64, room_state[6])
    println("   ├─ 室内温度: $(room2_temp)℃")
    println("   └─ 室内湿度: $(round(room2_rh * 100, digits=1))%")
    println()

    # result_wall1.csv から壁体の状態
    wall_state = load_last_state(wall_file)
    # 形式: date, climate(4cols), wall1(4cols), wall2(4cols), ..., wall21(4cols), indoor(4cols)
    # 各要素: temp, rh, ah, phi

    num_cells = 21  # RC内断熱の場合
    cell_states = []

    for i = 1:num_cells
        # climate(4) + wall_i の位置
        base_idx = 1 + 4 + (i-1) * 4 + 1  # date(1) + climate(4) + previous walls
        temp_str = wall_state[base_idx]
        rh_str = wall_state[base_idx + 1]

        temp_val = parse(Float64, temp_str)
        rh_val = parse(Float64, rh_str)

        push!(cell_states, (temp=temp_val, rh=rh_val))
    end

    println("📊 壁体セル状態 ($(num_cells)セル):")
    println("   ├─ セル1 (外表面): $(cell_states[1].temp)℃, $(round(cell_states[1].rh * 100, digits=1))%")
    println("   ├─ セル11 (中間): $(cell_states[11].temp)℃, $(round(cell_states[11].rh * 100, digits=1))%")
    println("   └─ セル21 (内表面): $(cell_states[21].temp)℃, $(round(cell_states[21].rh * 100, digits=1))%")
    println()

    # BNMモデル作成
    println("🔧 BNMモデル作成...")

    # パスに "./" がなければ追加（climate.jl等の読み込み処理との互換性）
    room_file = startswith(settings["room_file"], "./") ? settings["room_file"] : "./" * settings["room_file"]
    wall_file = startswith(settings["wall_file"], "./") ? settings["wall_file"] : "./" * settings["wall_file"]
    opening_file = startswith(settings["opening_file"], "./") ? settings["opening_file"] : "./" * settings["opening_file"]
    climate_file = startswith(settings["climate_file"], "./") ? settings["climate_file"] : "./" * settings["climate_file"]

    network_model = create_BNM_model(
        file_name_rooms    = room_file,
        file_name_walls    = wall_file,
        file_name_openings = opening_file,
        file_name_climate  = climate_file
    )
    println("   └─ ✅ 完了")
    println()

    # 位置情報設定
    city = get(settings, "city", "札幌")
    lon = parse(Float64, get(settings, "lon", "141.347"))
    phi = parse(Float64, get(settings, "phi", "43.064"))

    network_model.climate.location["city"] = city
    network_model.climate.location["lon"] = lon
    network_model.climate.location["phi"] = phi
    network_model.climate.location["lons"] = LONS

    # 計算開始時刻を最後の時刻 + 1ステップに設定
    resume_datetime = last_datetime + Dates.Minute(Int(DT * 60))
    network_model.climate.date = resume_datetime

    println("⏰ 計算再開設定:")
    println("   ├─ 再開時刻: $resume_datetime")
    println("   └─ 終了時刻: $END_DATE")
    println()

    # 気象データ初期化
    reset_climate_data(network_model.climate)

    # 状態を復元
    println("🔄 状態を復元中...")

    # 室の状態を復元
    restore_room_state!(network_model.rooms[2], room2_temp, room2_rh)
    println("   ├─ 室内状態: ✅")

    # 壁体セルの状態を復元
    for (i, state) in enumerate(cell_states)
        if i <= length(network_model.walls[1].cell)
            restore_cell_state!(network_model.walls[1].cell[i], state.temp, state.rh)
        end
    end
    println("   └─ 壁体状態: ✅")
    println()

    # ロガー設定（追記モード）
    println("📝 ロガー設定（追記モード）...")

    # 相対パスを計算
    relative_output = replace(RESUME_DIR, "output_data/" => "")

    logger_rooms = set_logger_append(
        relative_output * "/result_all_rooms",
        OUTPUT_INTERVAL,
        ["temp", "rh", "ah"],
        network_model.rooms
    )

    logger_walls = [
        set_logger_append(
            relative_output * "/result_wall" * string(i),
            OUTPUT_INTERVAL,
            ["temp", "rh", "ah", "phi"],
            network_model.walls[i].target_model
        )
        for i = 1:length(network_model.walls)
    ]

    logger_room_analysis = set_logger_append(
        relative_output * "/result_room_analysis",
        OUTPUT_INTERVAL,
        ["room_analysis"],
        network_model
    )

    loggers = vcat(logger_rooms, [logger_walls[i] for i = 1:length(logger_walls)], logger_room_analysis)
    println("   └─ ✅ 完了")
    println()

    # 計算ループ
    println("🔄 ══════════════════════════════════════════════════════════════")
    println("🔄  計算ループ再開")
    println("🔄 ══════════════════════════════════════════════════════════════")
    println()
    println("   📅 期間: $resume_datetime → $END_DATE")
    println()

    step_count = 0
    calc_start_time = now()

    while network_model.climate.date ≠ END_DATE
        step_count += 1

        reset_climate_data(network_model.climate)
        cal_network_flux_of_wall(network_model)
        cal_network_flux_of_ventilation(network_model)
        cal_new_value_ver_network(network_model, DT)

        # 日次進捗表示
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

            println("   📅 ", Dates.format(network_model.climate.date, "yyyy/mm/dd"),
                    "  🌤️  外気: ", out_temp, "℃ ", out_rh, "%",
                    "  🏠 室内: ", in_temp, "℃ ", in_rh, "%",
                    "  ⏱️  ", format_duration(elapsed_sec))
        end

        time_elapses(network_model.climate, DT)

        for files in loggers
            write_data_to_logger(files, network_model.climate.date)
        end
    end

    println()

    # ファイルクローズ
    println("📁 ファイルクローズ...")
    for files in loggers
        for i = 1:length(files.file)
            close(files.file[i])
        end
    end
    println("   └─ ✅ 完了")
    println()

    # 完了メッセージ
    calc_end_time = now()
    calc_elapsed = Dates.value(calc_end_time - calc_start_time) / 1000

    println("🎉 ══════════════════════════════════════════════════════════════")
    println("🎉  計算再開完了!")
    println("🎉 ══════════════════════════════════════════════════════════════")
    println()
    println("   📊 統計:")
    println("      ├─ 追加ステップ数: $step_count")
    println("      └─ 計算時間: $(format_duration(calc_elapsed))")
    println()
end

# 実行
main()
