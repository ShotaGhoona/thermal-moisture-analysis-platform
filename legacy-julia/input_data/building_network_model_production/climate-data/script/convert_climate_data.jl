#=
気象データ変換スクリプト
生データ（月,日,時,気温,絶対湿度,...）を
プログラム用フォーマット（date,temp,rh,...）に変換
=#

using CSV
using DataFrames
using StringEncodings

"""飽和水蒸気圧を計算 [Pa] - Tetens式"""
function saturation_vapor_pressure(temp_c)
    return 610.78 * exp(17.27 * temp_c / (temp_c + 237.3))
end

"""絶対湿度から相対湿度への変換
ah_g_kg: 絶対湿度 [g/kg dry air]
temp_c: 温度 [°C]
p_atm_pa: 大気圧 [Pa]
returns: 相対湿度 [%]
"""
function absolute_to_relative_humidity(ah_g_kg, temp_c, p_atm_pa)
    # g/kg → kg/kg
    ah_kg_kg = ah_g_kg / 1000.0

    # 水蒸気圧を計算: pv = ah * p / (0.622 + ah)
    pv = ah_kg_kg * p_atm_pa / (0.622 + ah_kg_kg)

    # 飽和水蒸気圧
    pvs = saturation_vapor_pressure(temp_c)

    # 相対湿度
    rh = (pv / pvs) * 100.0

    # 0-100の範囲に制限
    return clamp(rh, 0.0, 100.0)
end

"""風向（度）を日本語方位に変換"""
function wind_direction_to_jp(deg)
    directions = [
        "北", "北北東", "北東", "東北東",
        "東", "東南東", "南東", "南南東",
        "南", "南南西", "南西", "西南西",
        "西", "西北西", "北西", "北北西"
    ]
    # 360度を16方位に分割
    idx = Int(floor(mod(deg + 11.25, 360) / 22.5)) + 1
    return directions[idx]
end

"""生データを変換してプログラム用フォーマットに出力"""
function convert_weather_data(input_file, output_file; year=2020)

    println("Reading: $input_file")

    # UTF-8で読み込み（ヘッダーあり）
    df = CSV.read(input_file, DataFrame)

    println("Columns: $(names(df))")
    println("Rows: $(nrow(df))")

    # カラム名を取得（位置ベースでアクセスするため）
    cols = names(df)

    # 生データのカラム（位置ベース）
    month_col = df[!, cols[1]]
    day_col = df[!, cols[2]]
    hour_col = df[!, cols[3]]
    temp = df[!, cols[4]]         # 気温 [°C]
    ah = df[!, cols[5]]           # 絶対湿度 [g/kg]
    p_atm = df[!, cols[10]]       # 気圧 [Pa]
    precipitation = df[!, cols[11]] # 降水量 [mm]
    wind_speed = df[!, cols[12]]  # 風速 [m/s]
    wind_dir_deg = df[!, cols[13]] # 風向 [度]
    direct_radiation = df[!, cols[16]]  # 法線面直達日射量
    diffuse_radiation = df[!, cols[17]] # 水平面天空日射量

    n = nrow(df)

    # 出力用配列
    date_str = Vector{String}(undef, n)
    rh = Vector{Float64}(undef, n)
    wind_dir_jp = Vector{String}(undef, n)
    tau = Vector{Float64}(undef, n)
    total_solar = Vector{Float64}(undef, n)

    for i in 1:n
        # 日付文字列
        m = Int(month_col[i])
        d = Int(day_col[i])
        h = Int(hour_col[i])
        date_str[i] = "$year/$m/$d $h:00"

        # 相対湿度の計算
        rh[i] = absolute_to_relative_humidity(ah[i], temp[i], p_atm[i])

        # 風向を日本語に変換
        wind_dir_jp[i] = wind_direction_to_jp(wind_dir_deg[i])

        # 全天日射量
        total_solar[i] = direct_radiation[i] + diffuse_radiation[i]

        # tauを概算
        if total_solar[i] > 0
            tau[i] = clamp(total_solar[i] / 1000.0, 0.01, 0.95)
        else
            tau[i] = 1e-50
        end
    end

    # 出力DataFrame作成
    # Note: Qs列は空にする（Climate構造体にQsフィールドがないため）
    output_df = DataFrame(
        date = date_str,
        temp = round.(temp, digits=1),
        rh = Int.(round.(rh)),
        p_atm = fill("", n),
        Jp = round.(precipitation, digits=1),
        Js = fill("", n),
        WS = round.(wind_speed, digits=1),
        WD = wind_dir_jp,
        Qs = fill("", n),  # 空にする（プログラムがQsを扱えないため）
        tau = tau,
        cloudiness = fill("", n)
    )

    # ヘッダー行を含めてShift_JISで出力
    println("Writing: $output_file")

    open(output_file, enc"Shift_JIS", "w") do io
        # 3行のヘッダー
        write(io, "日時,気温,相対湿度,気圧,降水量,降雪量,風速,風向,全天日射量,大気透過率,雲量\n")
        write(io, "y/m/d HH:MM,℃,%,Pa,mm,mm,m/s,-,W/m2,-,-\n")
        write(io, "date,temp,rh,p_atm,Jp,Js,WS,WD,Qs,tau,cloudiness\n")

        # データ行
        for i in 1:nrow(output_df)
            row = output_df[i, :]
            line = "$(row.date),$(row.temp),$(row.rh),$(row.p_atm),$(row.Jp),$(row.Js),$(row.WS),$(row.WD),$(row.Qs),$(row.tau),$(row.cloudiness)\n"
            write(io, line)
        end
    end

    println("Converted $(nrow(output_df)) rows")
    println("Temperature range: $(minimum(temp)) ~ $(maximum(temp)) °C")
    println("RH range: $(minimum(rh)) ~ $(maximum(rh)) %")
    println()
end

function main()
    script_dir = dirname(@__FILE__)
    raw_dir = joinpath(script_dir, "..", "raw")
    output_dir = joinpath(script_dir, "..")

    # 各都市のデータを変換（2020年として）
    cities = [
        ("weather_Kyoto.csv", "climate_data_kyoto.csv"),
        ("weather_Okinawa.csv", "climate_data_okinawa.csv"),
        ("weather_Sapporo.csv", "climate_data_sapporo.csv"),
    ]

    for (input_name, output_name) in cities
        input_path = joinpath(raw_dir, input_name)
        output_path = joinpath(output_dir, output_name)

        if isfile(input_path)
            convert_weather_data(input_path, output_path, year=2020)
        else
            println("Warning: $input_path not found")
        end
    end

    println("Output directory: $output_dir")
end

main()
