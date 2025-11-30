#=
建物内温湿度環境解析ネットワークモデル
メイン実行ファイル

使い方:
1. 下記「設定セクション」のパラメータを編集
2. julia run/main.jl または julia legacy-julia/run/main.jl で実行
=#

using Dates

# スクリプトのディレクトリとプロジェクトルートを取得
const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)  # legacy-julia/

#=============================================================================
                            設定セクション
=============================================================================#

# --- 入力ファイルパス（PROJECT_DIRからの相対パス） ---
const INPUT_ROOM    = "input_data/building_network_model_production/01/room-condition/01-base-model.csv"
const INPUT_WALL    = "input_data/building_network_model_production/01/wall-condition/01-base-model.csv"
const INPUT_OPENING = "input_data/building_network_model_production/01/opening-condition/01-base-model.csv"
const INPUT_CLIMATE = "input_data/building_network_model_production/climate-data/climate_data_kyoto.csv"

# --- 計算条件 ---
const DT = 0.1                                      # 時間刻み [hour]
const START_DATE = DateTime(2020, 4, 1, 0, 0, 0)    # 計算開始時刻
const END_DATE   = DateTime(2020, 10, 1, 0, 0, 0)   # 計算終了時刻（または下記で期間指定）
# const END_DATE = START_DATE + Month(6)            # 開始から6ヶ月後

# --- 出力設定 ---
const OUTPUT_INTERVAL = 10.0                        # 出力間隔 [hour]
const OUTPUT_BASE_DIR = "output_data"               # 出力ベースディレクトリ（PROJECT_DIRからの相対パス）
const CASE_NAME = "case_production_01"              # ケース名（出力フォルダ名に使用）

# --- 位置情報（日射計算用） ---
const CITY = "Kyoto"
const LON  = 135.768    # 経度
const PHI  = 35.012     # 緯度
const LONS = 135.0      # 地方標準時の地点の経度

# --- 初期条件（オプション：設定しない場合はCSVの値を使用） ---
const USE_CUSTOM_INITIAL = false    # trueにすると下記の初期値を使用
const INITIAL_TEMP = 25.0           # 初期温度 [℃]
const INITIAL_RH   = 0.50           # 初期相対湿度 [-]

# --- デバッグ設定 ---
const DEBUG_VERBOSE = true          # 詳細ログの有効化


#=============================================================================
                            メイン処理
=============================================================================#

println()
println("🚀 ============================================================")
println("🚀  建物内温湿度環境解析ネットワークモデル")
println("🚀  起動時刻: ", now())
println("🚀  スクリプト: ", SCRIPT_DIR)
println("🚀  プロジェクト: ", PROJECT_DIR)
println("🚀 ============================================================")
println()

# 作業ディレクトリをプロジェクトルートに変更
println("📂 作業ディレクトリ変更...")
println("   ├─ 変更前: ", pwd())
cd(PROJECT_DIR)
println("   └─ 変更後: ", pwd())
println()

# モジュール読み込み（PROJECT_DIRからの絶対パスで指定）
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

# 出力ディレクトリの作成
# logger.jlが "./output_data/" を自動追加するため、それ以降のパスを返す
function create_output_directory()
    println("📁 出力ディレクトリ作成...")
    timestamp = Dates.format(now(), "yyyymmdd_HHMM")
    # logger用パス（output_data/を含まない）
    logger_path = joinpath(CASE_NAME, timestamp)
    # 実際のディレクトリパス
    full_path = joinpath(OUTPUT_BASE_DIR, CASE_NAME, timestamp)
    println("   ├─ ベース: $OUTPUT_BASE_DIR")
    println("   ├─ ケース: $CASE_NAME")
    println("   ├─ タイムスタンプ: $timestamp")
    mkpath(full_path)
    println("   └─ ✅ 作成完了: $(abspath(full_path))")
    return logger_path, full_path
end

# 壁体を通じた熱・水分流量計算
function cal_network_flux_of_wall(network::BNM)
    # 室に加わる熱流量の初期化
    for i = 1:length(network.rooms)
        set_H_wall(network.rooms[i], 0.0)
        set_J_wall(network.rooms[i], 0.0)
    end

    # 壁ごとの計算
    for i = 1:length(network.walls)
        target_model = network.walls[i].target_model

        for j = 1:length(target_model)-1
            # 熱流・水分流の計算
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

            # 流出側
            if typeof(target_model[j]) == Cell
                target_model[j].Q[2][1]  = -q  * dy(target_model[j]) * dz(target_model[j])
                target_model[j].Jv[2][1] = -jv * dy(target_model[j]) * dz(target_model[j])
                target_model[j].Jl[2][1] = -jl * dy(target_model[j]) * dz(target_model[j])
            elseif typeof(target_model[j]) == BC_Robin
                add_H_wall(target_model[j].air, -q * area(network.walls[i]))
                add_J_wall(target_model[j].air, -jv * area(network.walls[i]))
            end
            # 流入側
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

# 換気による熱・水分流量計算
function cal_network_flux_of_ventilation(network::BNM)
    # 初期化
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

# 収支計算・新値更新
function cal_new_value_ver_network(network::BNM, dt)
    # 壁ごとの計算
    for i = 1:length(network.walls)
        target_model = network.walls[i].cell

        for j = 1:length(target_model)
            if material_name(target_model[j]) ≠ "vented_air_space"
                # 熱収支計算
                target_model[j].temp = cal_newtemp(target_model[j], sum(sum(target_model[j].Q)), -sum(sum(target_model[j].Jv)), dt)

                # 水分収支計算
                nmiu = cal_newmiu(target_model[j], sum(sum(target_model[j].Jv)), sum(sum(target_model[j].Jl)), dt)

                # 表面水・結露水の処理
                if j == 1 || j == length(target_model)
                    BC = j == 1 ? :BC_IP : :BC_IM
                    if nmiu >= -0.1
                        nmiu = -0.1
                        setfield!(getfield(network.walls[i], BC), :jl_surf,
                            sum(sum(target_model[j].Jv)) + sum(sum(target_model[j].Jl)))
                    end
                else
                    if nmiu >= -0.1
                        nmiu = -0.1
                        println("⚠️  ", network.climate.date, " 壁体番号[", i, "]の内部のcell[", j, "]にて結露が発生しました。")
                    end
                end

                target_model[j].miu = nmiu

            elseif material_name(target_model[j]) == "vented_air_space"
                target_model[j].temp = (temp(target_model[j-1]) + temp(target_model[j+1])) / 2.0
                target_model[j].miu  = (miu(target_model[j-1]) + miu(target_model[j+1])) / 2.0
            end
        end
    end

    # 空気ごとの計算
    for i = 2:length(network.rooms)
        set_temp(network.rooms[i], cal_newtemp(network.rooms[i].air, dt))
        set_rh(network.rooms[i], cal_newRH(network.rooms[i].air, dt))
    end
end

# メイン実行関数
function main()
    println("⚙️  ============================================================")
    println("⚙️   設定確認")
    println("⚙️  ============================================================")
    println()

    # 設定表示
    println("📄 入力ファイル:")
    println("   ├─ 🏠 Room:    $INPUT_ROOM")
    println("   ├─ 🧱 Wall:    $INPUT_WALL")
    println("   ├─ 🚪 Opening: $INPUT_OPENING")
    println("   └─ 🌤️  Climate: $INPUT_CLIMATE")
    println()

    println("⏱️  計算条件:")
    println("   ├─ 時間刻み dt: $DT hour")
    println("   ├─ 開始時刻: $START_DATE")
    println("   └─ 終了時刻: $END_DATE")
    println()

    println("📍 位置情報:")
    println("   ├─ 都市: $CITY")
    println("   ├─ 経度: $LON")
    println("   ├─ 緯度: $PHI")
    println("   └─ 標準時経度: $LONS")
    println()

    # 出力ディレクトリ作成
    logger_path, output_dir = create_output_directory()
    println()

    # 設定情報を保存
    println("💾 設定ファイル保存...")
    settings_path = joinpath(output_dir, "settings.txt")
    open(settings_path, "w") do f
        println(f, "=== 計算設定 ===")
        println(f, "実行日時: ", now())
        println(f, "")
        println(f, "[入力ファイル]")
        println(f, "Room: ", INPUT_ROOM)
        println(f, "Wall: ", INPUT_WALL)
        println(f, "Opening: ", INPUT_OPENING)
        println(f, "Climate: ", INPUT_CLIMATE)
        println(f, "")
        println(f, "[計算条件]")
        println(f, "時間刻み: ", DT, " hour")
        println(f, "開始: ", START_DATE)
        println(f, "終了: ", END_DATE)
        println(f, "")
        println(f, "[位置情報]")
        println(f, "都市: ", CITY)
        println(f, "経度: ", LON, " 緯度: ", PHI)
    end
    println("   └─ ✅ 保存完了: $settings_path")
    println()

    # モデル構築
    println("🏗️  ============================================================")
    println("🏗️   モデル構築")
    println("🏗️  ============================================================")
    println()

    println("🔧 BNMモデル作成中...")
    println("   ├─ CSV読み込み...")
    # cd(PROJECT_DIR)済みなので "./" + 相対パスで指定
    network_model = create_BNM_model(
        file_name_rooms    = "./" * INPUT_ROOM,
        file_name_walls    = "./" * INPUT_WALL,
        file_name_openings = "./" * INPUT_OPENING,
        file_name_climate  = "./" * INPUT_CLIMATE
    )
    println("   └─ ✅ BNMモデル作成完了")
    println()

    # モデル情報表示
    println("📊 モデル構成:")
    println("   ├─ 🏠 Rooms: $(length(network_model.rooms)) 室")
    for i = 1:length(network_model.rooms)
        room = network_model.rooms[i]
        println("   │   ├─ [$i] $(room.name)")
        println("   │   │   ├─ 容積: $(room.air.vol) m³")
        println("   │   │   ├─ 温度: $(round(room.air.temp - 273.15, digits=1)) ℃")
        println("   │   │   └─ 湿度: $(round(room.air.rh * 100, digits=0)) %")
    end
    println("   │")
    println("   ├─ 🧱 Walls: $(length(network_model.walls)) 壁")
    for i = 1:length(network_model.walls)
        wall = network_model.walls[i]
        println("   │   ├─ [$i] $(wall.name)")
        println("   │   │   ├─ IP→IM: $(wall.IP) → $(wall.IM)")
        println("   │   │   ├─ 面積: $(wall.area) m²")
        println("   │   │   ├─ 厚さ: $(wall.thickness) m")
        println("   │   │   └─ セル数: $(length(wall.cell))")
    end
    println("   │")
    println("   └─ 🚪 Openings: $(length(network_model.openings)) 開口")
    for i = 1:length(network_model.openings)
        op = network_model.openings[i]
        println("       ├─ [$i] Type: $(op.Type)")
        println("       │   ├─ IP→IM: $(op.IP) → $(op.IM)")
        println("       │   ├─ Qup: $(op.Qup) m³/s")
        println("       │   └─ Qdw: $(op.Qdw) m³/s")
    end
    println()

    # 位置情報の設定
    println("📍 位置情報設定...")
    network_model.climate.location["city"] = CITY
    network_model.climate.location["lon"]  = LON
    network_model.climate.location["phi"]  = PHI
    network_model.climate.location["lons"] = LONS
    println("   └─ ✅ 完了")
    println()

    # 初期条件の設定（オプション）
    if USE_CUSTOM_INITIAL
        println("🌡️  カスタム初期条件適用...")
        println("   ├─ 初期温度: $INITIAL_TEMP ℃")
        println("   ├─ 初期湿度: $(INITIAL_RH * 100) %")
        for i = 1:length(network_model.walls)
            for j = 1:length(network_model.walls[i].cell)
                network_model.walls[i].cell[j].temp = INITIAL_TEMP + 273.15
                network_model.walls[i].cell[j].miu = convertRH2Miu(temp=network_model.walls[i].cell[j].temp, rh=INITIAL_RH)
            end
        end
        for i = 2:length(network_model.rooms)
            set_temp(network_model.rooms[i], INITIAL_TEMP + 273.15)
            set_rh(network_model.rooms[i], INITIAL_RH)
        end
        println("   └─ ✅ 完了")
        println()
    end

    # 計算開始時刻の設定
    println("⏰ 計算時刻設定...")
    network_model.climate.date = START_DATE
    println("   ├─ 開始時刻: $START_DATE")
    reset_climate_data(network_model.climate)
    println("   ├─ 気象データ初期化完了")
    println("   │   ├─ 外気温: $(round(temp(network_model.climate) - 273.15, digits=1)) ℃")
    println("   │   └─ 外気湿度: $(round(rh(network_model.climate) * 100, digits=0)) %")
    println("   └─ ✅ 完了")
    println()

    # ロガーの設定
    println("📝 ============================================================")
    println("📝  ロガー設定")
    println("📝 ============================================================")
    println()

    println("📄 ロガー作成中...")

    # 全ての部屋の温湿度
    # logger.jlが "./output_data/" を追加するので logger_path を使用
    println("   ├─ result_all_rooms (全室の温湿度)")
    logger_rooms = set_logger(
        joinpath(logger_path, "result_all_rooms"),
        OUTPUT_INTERVAL,
        ["temp", "rh", "ah"],
        network_model.rooms
    )
    println("   │   └─ ✅ 作成完了")

    # 壁体内の温湿度
    println("   ├─ result_wall* (壁体内状態)")
    logger_walls = [
        set_logger(
            joinpath(logger_path, "result_wall" * string(i)),
            OUTPUT_INTERVAL,
            ["temp", "rh", "ah", "phi"],
            network_model.walls[i].target_model
        )
        for i = 1:length(network_model.walls)
    ]
    for i = 1:length(logger_walls)
        println("   │   ├─ result_wall$i ✅")
    end

    # 室の形成メカニズム分析
    println("   └─ result_room_analysis (室熱収支)")
    logger_room_analysis = set_logger(
        joinpath(logger_path, "result_room_analysis"),
        OUTPUT_INTERVAL,
        ["room_analysis"],
        network_model
    )
    println("       └─ ✅ 作成完了")
    println()

    # ヘッダー書き込み
    println("📝 ヘッダー書き込み...")
    loggers = vcat(logger_rooms, [logger_walls[i] for i = 1:length(logger_walls)], logger_room_analysis)
    for (idx, files) in enumerate(loggers)
        write_header_to_logger(files)
        write_data_to_logger(files, network_model.climate.date)
    end
    println("   └─ ✅ $(length(loggers)) ファイルに書き込み完了")
    println()

    # 計算ループ
    println("🔄 ============================================================")
    println("🔄  計算ループ開始")
    println("🔄 ============================================================")
    println()
    println("   📅 期間: $START_DATE → $END_DATE")
    println("   ⏱️  時間刻み: $DT hour")
    println("   📊 出力間隔: $OUTPUT_INTERVAL hour")
    println()
    println("   ─────────────────────────────────────────────────────────")

    step_count = 0
    start_time = now()

    while network_model.climate.date ≠ END_DATE
        step_count += 1

        # 1: 外界気象データの再設定
        reset_climate_data(network_model.climate)

        # 2: 流量および収支計算
        cal_network_flux_of_wall(network_model)
        cal_network_flux_of_ventilation(network_model)
        cal_new_value_ver_network(network_model, DT)

        # 3: 日次進捗表示
        if hour(network_model.climate.date) == 0 &&
           minute(network_model.climate.date) == 0 &&
           second(network_model.climate.date) == 0 &&
           millisecond(network_model.climate.date) == 0

            elapsed = now() - start_time
            elapsed_sec = Dates.value(elapsed) / 1000

            out_temp = round(temp(network_model.climate) - 273.15, digits=1)
            out_rh = round(rh(network_model.climate) * 100, digits=0)
            in_temp = round(temp(network_model.rooms[2]) - 273.15, digits=1)
            in_rh = round(rh(network_model.rooms[2]) * 100, digits=0)

            println("   📅 ", Dates.format(network_model.climate.date, "yyyy/mm/dd"),
                    "  🌤️  外気: ", out_temp, "℃ ", out_rh, "%",
                    "  🏠 室内: ", in_temp, "℃ ", in_rh, "%",
                    "  ⏱️  ", round(elapsed_sec, digits=1), "s")
        end

        # 4: 時間経過
        time_elapses(network_model.climate, DT)

        # 5: データのロギング
        for files in loggers
            write_data_to_logger(files, network_model.climate.date)
        end
    end

    println("   ─────────────────────────────────────────────────────────")
    println()

    # ファイルクローズ
    println("📁 ファイルクローズ...")
    for files in loggers
        for i = 1:length(files.file)
            close(files.file[i])
        end
    end
    println("   └─ ✅ 全ファイルクローズ完了")
    println()

    # 完了
    total_elapsed = now() - start_time
    total_sec = Dates.value(total_elapsed) / 1000

    println("🎉 ============================================================")
    println("🎉  計算完了!")
    println("🎉 ============================================================")
    println()
    println("   📊 統計:")
    println("   ├─ 総ステップ数: $step_count")
    println("   ├─ 総計算時間: $(round(total_sec, digits=1)) 秒")
    println("   └─ 平均速度: $(round(step_count / total_sec, digits=1)) step/s")
    println()
    println("   📁 出力先: $(abspath(output_dir))")
    println()
    println("✅ 正常終了")
    println()
end

# 実行
main()
