include("air.jl")

include("air.jl")

Base.@kwdef mutable struct Room
    num::Int        = 0         # 室番号
    name::String    = "no name" # 名称
    air::Air        = Air()     # 温度・湿度等の情報
    pf::Float64     = 0.0       # 床面圧力[Pa]
    ps::Float64     = 0.0       # 起圧力[Pa]
    Hight::Float64  = 0.0       # 床面高さ
    Qs::Float64     = 0.0       # 発熱量[W]
    Js::Float64     = 0.0       # 発湿量[kg/s]
    DWW::Float64     = 0.0      # 室への流入する正味の空気流量[kg/s]
    AC::String      = "OFF"     # エアコンの有無
end

########################################
# 出力用の関数
num(room::Room)     = room.num
name(room::Room)    = room.name
air(room::Room)     = room.air
pf(room::Room)      = room.pf
ps(room::Room)      = room.ps
Hight(room::Room)   = room.Hight
Qs(room::Room)      = room.Ws
Js(room::Room)      = room.Js
DWW(room::Room)     = room.DWW
AC(room::Room)      = room.AC

# air内の値の取得
temp(room::Room)    = room.air.temp
rh(room::Room)      = room.air.rh
miu(room::Room)     = convertRH2Miu( temp = room.air.temp, rh = room.air.rh )
pv(room::Room)      = convertRH2Pv( temp = room.air.temp, rh = room.air.rh )
ah(room::Room)      = convertPv2AH( patm = room.air.p_atm, pv = pv(room.air) )
p_atm(room::Room)   = room.air.p_atm
dx(room::Room)      = room.air.dx
dy(room::Room)      = room.air.dy
dz(room::Room)      = room.air.dz
vol(room::Room)     = room.air.vol
H_in(room::Room)    = room.air.H_in
H_wall(room::Room)  = room.air.H_wall
H_vent(room::Room)  = room.air.H_vent
J_in(room::Room)    = room.air.J_in
J_wall(room::Room)  = room.air.J_wall
J_vent(room::Room)  = room.air.J_vent

########################################
# 入力用の関数
function set_num(room::Room, num::Int) 
    room.num    = num end
function set_name(room::Room, num::String) 
    room.name   = name end
function set_air(room::Room, air::Air) 
    room.air    = air end
function set_temp(room::Room, temp::Float64) 
    room.air.temp   = temp  end
function set_rh(room::Room, rh::Float64) 
    room.air.rh     = rh    end
function set_pv(room::Room, pv::Float64) 
    room.air.pv     = pv    end
function set_ah(room::Room, ah::Float64) 
    room.air.ah     = ah    end
function set_p_atm(room::Room, p_atm::Float64) 
    room.air.p_atm  = p_atm end
function set_pf(room::Room, pf::Float64) 
    room.pf     = pf end
function set_ps(room::Room, ps::Float64) 
    room.ps     = ps end
function set_Hight(room::Room, Hight::Float64) 
    room.Hight  = Hight end
function set_Qs(room::Room, Qs::Float64) 
    room.Qs     = Qs end
function set_Js(room::Room, Js::Float64) 
    room.Js     = Js end
function set_AC(room::Room, AC::String) 
    room.AC     = AC end    
function set_H_in(room::Room, H_in::Float64) 
    room.air.H_in   = H_in end    
function set_H_wall(room::Room, H_wall::Float64) 
    room.air.H_wall = H_wall end    
function set_H_vent(room::Room, H_vent::Float64) 
    room.air.H_vent = H_vent end    
function set_J_in(room::Room, J_in::Float64) 
    room.air.J_in   = J_in end    
function set_J_wall(room::Room, J_wall::Float64) 
    room.air.J_wall = J_wall end    
function set_J_vent(room::Room, J_vent::Float64) 
    room.air.J_vent = J_vent end            

########################################
# 積算用の関数
function add_H_in(room::Room, H_in::Float64) 
    room.air.H_in   = room.air.H_in + H_in end    
function add_H_wall(room::Room, H_wall::Float64) 
    room.air.H_wall = room.air.H_wall + H_wall end    
function add_H_vent(room::Room, H_vent::Float64) 
    room.air.H_vent = room.air.H_vent + H_vent end    
function add_J_in(room::Room, J_in::Float64) 
    room.air.J_in   = room.air.J_in + J_in end    
function add_J_wall(room::Room, J_wall::Float64) 
    room.air.J_wall = room.air.J_wall + J_wall end    
function add_J_vent(room::Room, J_vent::Float64) 
    room.air.J_vent = room.air.J_vent + J_vent end            

function input_room_data(file_name::String, header::Int = 3)

    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./")
        file_directory = file_name
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv")
        file_directory = "../input_data/building_network_model/"*string(file_name)
    # ファイル名のみが書かれている場合、
    else
        file_directory = "../input_data/building_network_model/"*string(file_name)*".csv"        
    end

    # 入力ファイルの読み込み
    input_data = CSV.File( file_directory, header = header) |> DataFrame
    
    # 空の空気データを作成
    data = [ Room() for i = 1 : length(input_data.num) ]
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.num)
        data[i].num = Int(input_data.num[i])
        data[i].name= input_data.name[i]
        data[i].air.name= input_data.name[i]
        data[i].air.temp= input_data.temp[i] + 273.15
        data[i].air.rh  = input_data.rh[i] / 100.0
        data[i].air.vol = Float64(input_data.vol[i])
        try data[i].Hight   = input_data.Hight[i] catch end
        data[i].Qs  = Float64(input_data.Qs[i])
        data[i].Js  = Float64(input_data.Js[i])
        data[i].AC  = String(input_data.AC[i])
    end
    
    return data
end