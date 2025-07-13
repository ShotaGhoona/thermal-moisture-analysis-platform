using CSV
using DataFrames
include("calendar_module.jl")
include("./module_function/vapour.jl")

# データのロギングインターバル[分数]（仮に1時間（）（60分とした））
cd_logging_interval = Int(60)

# データのロギング間隔を取得する関数
function cal_logging_interval_min( data::DataFrame )
    return Int(( data.hour[2] - data.hour[1] ) * 60 + ( data.min[2] - data.min[1] ))
end

# 気象データをinputする関数
function input_climate_data(; file_name::String, header::Int = 1)
    
    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./")
        file_directory = file_name
        
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv")
        file_directory = "./input_data/climate_data/cell_data/"*string(file_name)
        
    # ファイル名のみが書かれている場合、
    else
        file_directory = "./input_data/climate_data/cell_data/"*string(file_name)*".csv"        
    end
    
    # 入力ファイルの読み込み
    input_data = CSV.File(file_directory, header = header) |> DataFrame
    
    # データのロギングインターバルの変更
    global cd_logging_interval = cal_logging_interval_min( input_data )
    
    # 入力ファイルを水蒸気圧・絶対湿度を含む形に成形    
    added_climate_data = DataFrame( year = input_data.year, 
        month = input_data.month, 
        day   = input_data.day, 
        hour  = input_data.hour, 
        min   = input_data.min,  
        sec   = try; input_data.sec; catch; [ 0 for i = 1 : length(input_data.temp) ]; end,
        temp  = input_data.temp,
        rh    = input_data.rh, 
        pv    = [ convertRH2Pv( temp = input_data.temp[i] + 273.15, rh = input_data.rh[i]/100 ) for i = 1 : length(input_data.temp) ],
        #ah    = [ convertRH2AH( temp = climate_data.temp[i] + 273.15, rh = climate_data.rh[i]/100 ) for i = 1 : length(climate_data.temp) ],; 未実装
        )
    
    return added_climate_data
end

function extract_temp_by_climate_data( climate_data::DataFrame, calendar::Calendar )
    return climate_data.temp[
        (climate_data.year.==calendar.year).&
        (climate_data.month.==calendar.month).&
        (climate_data.day.==calendar.day).&
        (climate_data.hour.==calendar.hour).&
        (climate_data.min.==calendar.min).&
        (climate_data.sec.==calendar.sec),:][1] #[1]はmatrixをスカラーに変換するため
end

function extract_rh_by_climate_data( climate_data::DataFrame, calendar::Calendar )
    return climate_data.rh[
        (climate_data.year.==calendar.year).&
        (climate_data.month.==calendar.month).&
        (climate_data.day.==calendar.day).&
        (climate_data.hour.==calendar.hour).&
        (climate_data.min.==calendar.min).&
        (climate_data.sec.==calendar.sec),:][1]
end

function extract_pv_by_climate_data( climate_data::DataFrame, calendar::Calendar )
    return climate_data.pv[
        (climate_data.year.==calendar.year).&
        (climate_data.month.==calendar.month).&
        (climate_data.day.==calendar.day).&
        (climate_data.hour.==calendar.hour).&
        (climate_data.min.==calendar.min).&
        (climate_data.sec.==calendar.sec),:][1]
end

function cal_lerp(; y1::Float64, y2::Float64, t1::Float64, t2::Float64, ti::Float64 )
    return y1 + ( y2 - y1 ) * ( ti - t1 ) / ( t2 - t1 )
end

function cal_lerp(; y1::Float64, y2::Float64, interval::Float64, remainder::Float64 )
    return y1 + ( y2 - y1 ) * ( remainder ) / ( interval )
end

cal_lerp( y1 = 0.0, y2 = 10.0, interval = 10.0, remainder = 7.0 )

function cal_before_date( date::Calendar, logging_interval_min::Int )
    return date_before = construct_Calendar( 
        year  = date.year, 
        month = date.month, 
        day   = date.day, 
        hour  = date.hour, 
        min   = 
        if logging_interval_min == 60
            0 
        else 
            date.min - mod(date.min, logging_interval_min)
        end,
        sec   = 0 )
end

function cal_after_date( date::Calendar, logging_interval_min::Int )
    date_after = construct_Calendar( 
        year  = date.year, 
        month = date.month, 
        day   = date.day, 
        hour  = date.hour, 
        min   = date.min,
        sec   = date.sec )
    date_after  = cal_time_after_dt( date = date_after, dt = float(logging_interval_min * 60) )   
end

function cal_temp_rh_pv_by_climate_data( climate_data::DataFrame, date::Calendar, logging_interval_min::Int = cd_logging_interval )
    
    # 直前の測定データの日時を求める
    date_before = cal_before_date( date, logging_interval_min )
    
    # 直後の測定データの日時を求める
    date_after  = cal_after_date( date_before, logging_interval_min )
    
    # 直線内挿による現在の値の入力
    temp = cal_lerp(
        y1 = extract_temp_by_climate_data( climate_data, date_before ), 
        y2 = extract_temp_by_climate_data( climate_data, date_after ),
        interval  = float(logging_interval_min),
        remainder = float(mod(date.min, logging_interval_min) ))
    
    pv = cal_lerp(
        y1 = extract_pv_by_climate_data( climate_data, date_before ), 
        y2 = extract_pv_by_climate_data( climate_data, date_after ),
        interval  = float(logging_interval_min),
        remainder = float(mod(date.min, logging_interval_min) ))
    
    rh = convertPv2RH( temp = temp + 273.15, pv = pv )
    return temp, pv, rh
end
