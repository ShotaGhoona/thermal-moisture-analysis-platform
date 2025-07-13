using CSV
using DataFrames
using Dates
using StringEncodings
include("air.jl")
include("solar_radiation.jl")
include("./function/vapour.jl")

# 気象の構造
Base.@kwdef mutable struct Climate
    date::DateTime  = DateTime( 2000, 1, 1, 0, 0, 0 )           # 日時
    location::Dict{String, Any} = Dict( "city"  =>  "Kyoto",    # 都市名
                                        "lon"   =>  135.678,    # 緯度
                                        "phi"   =>  34.983,     # 経度
                                        "lons"  =>  135.0)      # 地方標準時の地点の経度
    air::Air        = Air(name = "climate")     # 温度・湿度等の情報
    Jp::Float64     = 0.0       # 降水量[mm/h]
    Js::Float64     = 0.0       # 積雪量[mm/h]
    WS::Float64     = 0.0       # 風速[m/s]
    WD::String      = "東"       # 風向（N,NNE,NE,ENE,E,ESE,SE,SSE,S,SSW,SW,WSW,W,WNW,NW,NNW）
    tau::Float64    = 0.0       # 大気透過率[-]
    solar::Dict{String, Float64}    = Dict( "SOLDN" => 0.0,
                                            "SOLSN" => 0.0,
                                            "LATI"  => 0.0,
                                            "ALTI"  => 0.0)
    rho::Float64    = 0.0       # 地表面日射反射率[-]
    cloudiness::Int = 0       # 雲量[-]
    input_data::DataFrame   = DataFrame()   # 入力する外気気象データ
    input_data_type::Array{Symbol,1}   = [] # 入力する外気気象データの種類
    logging_interval::Int   = 0             # 外気気象データの測定間隔
end

#### 方位に関する定義
direction = Dict(   "N" => 0.0, "NNE" => 22.5, "NE" => 45.0, "ENE" => 67.5, 
                    "E" => 90.0, "ESE" => 112.5, "SE" => 135.0, "SSE" => 157.5, 
                    "S" => 180.0, "SSW" => 202.5, "SW" => 225.0, "WSW" => 247.5, 
                    "W" => 270.0, "WNW" => 292.5, "NW" => 315.0, "NNW" => 337.5)

                    
direction_JP = Dict("北" => 0.0, "北北東" => 22.5, "北東" => 45.0, "東北東" => 67.5, 
                    "東" => 90.0, "東南東" => 112.5, "南東" => 135.0, "南南東" => 157.5, 
                    "南" => 180.0, "南南西" => 202.5, "南西" => 225.0, "西南西" => 247.5, 
                    "西" => 270.0, "西北西" => 292.5, "北西" => 315.0, "北北西" => 337.5,
                    "静穏" => 0.0)

cal_direction( direction_name::String ) = direction[direction_name]

########################################
# 出力用の関数
date(climate::Climate)  = climate.date
location(climate::Climate) = climate.location
air(climate::Climate)   = climate.air
temp(climate::Climate)  = temp(climate.air)
rh(climate::Climate)    = rh(climate.air)
ah(climate::Climate)    = ah(climate.air)
pv(climate::Climate)    = pv(climate.air)
p_atm(climate::Climate) = p_atm(climate.air)
Jp(climate::Climate)    = climate.Jp
Js(climate::Climate)    = climate.Js
WS(climate::Climate)    = climate.WS
WD(climate::Climate)    = climate.WD
θwd(climate::Climate)   = direction_JP[WD(climate)]
tau(climate::Climate)     = climate.tau
solar(climate::Climate) = climate.solar
rho(climate::Climate)   = climate.rho
cloudiness(climate::Climate)        = climate.cloudiness
input_data(climate::Climate)        = climate.input_data
input_data_type(climate::Climate)   = climate.input_data_type
logging_interval(climate::Climate)  = climate.logging_interval

########################################
# 入力用の関数
function set_date(climate::Climate, date::DateTime) 
    climate.date        = date  end
function set_location(climate::Climate, location::Dict{String, Any}) 
    climate.location    = location  end
function set_air(climate::Climate, air::Air) 
    climate.air         = air  end
function set_temp(climate::Climate, temp::Float64) 
    climate.air.temp    = temp  end
function set_rh(climate::Climate, rh::Float64) 
    climate.air.rh      = rh  end
function set_pv(climate::Climate, pv::Float64) 
    climate.air.pv      = pv  end
function set_ah(climate::Climate, ah::Float64) 
    climate.air.ah      = ah  end

########################################
# 時間経過に関する関数
function time_elapses(climate::Climate, dt::Float64)
    climate.date    = climate.date + Millisecond(dt*1000)   end

# データのロギング間隔を取得する関数
function cal_logging_interval_min( data::DataFrame )
    return Int(( hour(data.date[2]) - hour(data.date[1]) ) * 60 + ( minute(data.date[2]) - minute(data.date[1]) ))
end

# 気象データをinputする関数
function input_climate_data(file_name::String, header::Int = 3)

    ###################################
    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./")
        file_directory = file_name
        
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv")
        file_directory = "./input_data/climate_data/"*string(file_name)
        
    # ファイル名のみが書かれている場合、
    else
        file_directory = "./input_data/climate_data/"*string(file_name)*".csv"        
    end
    
    ###################################
    # 入力ファイルの読み込み：日本語対応
    input_data = CSV.File(open(file_directory, enc"Shift_JIS"), header = header) |> DataFrame
    # ⇒ DateTime型への変換
    input_data.date = DateTime.( input_data[!,1], dateformat"y/m/d HH:MM")

    # 入力するデータのタイプの確認
    data_type = []
    for names = names( input_data )
        if input_data[!,names] == 1
            # println( names, " is same")
        elseif all( ismissing, input_data[!,names])
            # println( names, " is missing")
        elseif names == "date"

        else
            # println( names, " is not same")
            push!(data_type, names)
        end
    end
    push!(data_type, :pv) # 水蒸気圧についても更新
    push!(data_type, :ah) # 絶対湿度についても更新

    # 水蒸気圧・絶対湿度の算出
    input_data.pv = [ convertRH2Pv( temp = input_data.temp[i] + 273.15, rh = input_data.rh[i]/100 ) for i = 1 : length(input_data.temp) ]
    input_data.ah = [ convertRH2AH( temp = input_data.temp[i] + 273.15, rh = input_data.rh[i]/100 ) for i = 1 : length(input_data.temp) ]

    # データのロギングインターバルの変更
    logging_interval = cal_logging_interval_min( input_data )

    ##################################
    # 気象構造の設定
    climate = Climate(
        date = input_data.date[1] ,
        input_data = input_data, 
        input_data_type = Symbol.(data_type),
        logging_interval = logging_interval)

    reset_climate_data( climate )

    return climate
end

input_climate_data(; file_name::String, header::Int = 3) = input_climate_data(file_name, header)

# ある時刻におけるすべての列を取得する方法
function get_row_at_date( climate_data::DataFrame, date::DateTime )
    return climate_data[ climate_data[!, :date] .== date, : ]
end

# 指定した列の値を取得する方法
function get_value_by_column_name( data::DataFrame, name::String )
    return data[!, name]
end

# 以下現状（2024/11/21）使わない関数群
# 温度の抽出
function extract_temp_by_climate_data( climate_data::DataFrame, date::DateTime )
    return climate_data.temp[climate_data.date.==date,:][1] #[1]はmatrixをスカラーに変換するため
end

# 相対湿度の抽出
function extract_rh_by_climate_data( climate_data::DataFrame, date::DateTime )
    return climate_data.rh[climate_data.date.==date,:][1]
end

# 水蒸気圧の抽出
function extract_pv_by_climate_data( climate_data::DataFrame, date::DateTime )
    return climate_data.pv[climate_data.date.==date,:][1]
end

function cal_lerp(; y1::Float64, y2::Float64, t1::Float64, t2::Float64, ti::Float64 )
    return y1 + ( y2 - y1 ) * ( ti - t1 ) / ( t2 - t1 )
end

function cal_lerp(; y1::Float64, y2::Float64, interval::Float64, remainder::Float64 )
    return y1 + ( y2 - y1 ) * ( remainder ) / ( interval )
end

function cal_before_date( date::DateTime, logging_interval_min::Int )
    min   =  
        if logging_interval_min == 60
            0 
        else 
            minute(date) - mod(minute(date), logging_interval_min)
        end
    return DateTime( year(date), month(date), day(date), hour(date), min, 0 )
end

function cal_after_date( date_before::DateTime, logging_interval_min::Int )
    return date_before + Minute(logging_interval_min)   
end

function cal_temp_rh_pv_by_climate_data( climate::Climate, date::DateTime )
    
    # 直前の測定データの日時を求める
    date_before = cal_before_date( date, climate.logging_interval )
    
    # 直後の測定データの日時を求める
    date_after  = cal_after_date( date_before, climate.logging_interval )
    
    # 直線内挿による現在の値の入力
    temp = cal_lerp(
        y1 = extract_temp_by_climate_data( climate.data, date_before ), 
        y2 = extract_temp_by_climate_data( climate.data, date_after ),
        interval  = float(climate.logging_interval),
        remainder = float(mod(minute(date), climate.logging_interval) ))
    
    pv = cal_lerp(
        y1 = extract_pv_by_climate_data( climate.data, date_before ), 
        y2 = extract_pv_by_climate_data( climate.data, date_after ),
        interval  = float(climate.logging_interval),
        remainder = float(mod(minute(date), climate.logging_interval) ))
    
    rh = convertPv2RH( temp = temp + 273.15 , pv = pv )
    return temp, pv, rh
end

function reset_climate_data( climate::Climate )
    
    # 直前・直後の測定データの日時を求める
    date_before = cal_before_date( climate.date, climate.logging_interval )
    date_after  = cal_after_date( date_before, climate.logging_interval )

    # 直前・直後のデータを取得
    data_before = get_row_at_date( climate.input_data, date_before )
    data_after  = get_row_at_date( climate.input_data, date_after )

    # 現在値を書き換える（オプション情報）
    for field_name = climate.input_data_type
        # temp, rh, p_atmはair構造体の中の変数
        if field_name == :temp
            setfield!( climate.air, field_name, cal_lerp(
                y1 = float(data_before[!,field_name][1]), 
                y2 = float(data_after[!,field_name][1]),
                interval  = float(climate.logging_interval),
                remainder = float(mod(minute(climate.date), climate.logging_interval))) + 273.15)
        elseif field_name == :rh || field_name == :p_atm || field_name == :pv || field_name == :ah
            setfield!( climate.air, field_name, cal_lerp(
                y1 = float(data_before[!,field_name][1]), 
                y2 = float(data_after[!,field_name][1]),
                interval  = float(climate.logging_interval),
                remainder = float(mod(minute(climate.date), climate.logging_interval))))
        # その他はclimate構造体の中の変数
        elseif field_name == :WD
            setfield!( climate, field_name, String(data_before[!,field_name][1]) )         
        else
            setfield!( climate, field_name, cal_lerp(
                y1 = float(data_before[!,field_name][1]), 
                y2 = float(data_after[!,field_name][1]),
                interval  = float(climate.logging_interval),
                remainder = float(mod(minute(climate.date), climate.logging_interval))))
            # 大気透過率を更新する場合、日射量の計算を行う
            if field_name == :tau
                climate.solar["SOLDN"], climate.solar["SOLSN"], climate.solar["LATI"], climate.solar["ALTI"] = 
                    cal_solar_radiation( 
                        year = year(climate.date), month = month(climate.date), day = day(climate.date), 
                        hour = hour(climate.date), min = minute(climate.date), sec = second(climate.date), 
                        PHI = climate.location["phi"], LON = climate.location["lon"], LONS = climate.location["lons"], 
                        P   = climate.tau )
            end
        end
    end
    # 相対湿度に関しては水蒸気圧から再度計算しなおす
    setfield!( climate.air, :rh, convertPv2RH( temp = climate.air.temp , pv = climate.air.pv ) )
end