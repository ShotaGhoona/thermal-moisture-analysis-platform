include("./function/vapour.jl")
include("./function/lewis_relation.jl")

Base.@kwdef mutable struct Air
    num::Int       = 0     #= 室番号 =#
    name::String   = "NoName"  #= 名称  =#
    dx::Float64    = 0.0   #= 幅x   =#
    dy::Float64    = 0.0   #= 高さy =#
    dz::Float64    = 0.0   #= 奥行z =#
    vol::Float64   = 0.0   #= 体積  =#
    temp::Float64  = 0.0   #= 温度  =#
    rh::Float64    = 0.0   #= 相対湿度  =#
    pv::Float64    = 0.0   #= 水蒸気圧  =#
    ah::Float64    = 0.0   #= 絶対湿度  =#
    p_atm::Float64 = 101325.0 #= 空気の全圧（≒大気圧）=# 
    CO2::Float64   = 0.0   #= CO2濃度  =#
    pf::Float64    = 0.0    #= 床面圧力[Pa] =#
    ps::Float64    = 0.0    #= 起圧力[Pa] =#
    H_in::Float64  = 0.0      #= 発熱源による発熱量 =#
    H_wall::Float64 = 0.0     #= 壁体からの熱流量 =#
    H_vent::Float64 = 0.0     #= 換気による熱流量 =#
    J_in::Float64   = 0.0     #= 発熱源による発湿量 =#
    J_wall::Float64 = 0.0     #= 壁体からの水分流量 =#
    J_vent::Float64 = 0.0     #= 換気による水分流量 =#
end 

# 構造体パラメーター
num(state::Air)= state.num
name(state::Air)= state.name
vol(state::Air)= state.vol
material_name(state::Air)= typeof(state)

# 熱水分状態量
temp(state::Air)= state.temp
rh(state::Air) = state.rh
miu(state::Air) = convertRH2Miu( temp = state.temp, rh = state.rh )
pv(state::Air)  = convertRH2Pv( temp = state.temp, rh = state.rh )
ah(state::Air)  = convertPv2AH( patm = state.p_atm, pv = pv(state) )
p_atm(state::Air)= state.p_atm

# 流入熱量
H_in(state::Air)   = state.H_in
H_wall(state::Air) = state.H_wall
H_vent(state::Air) = state.H_vent
J_in(state::Air)   = state.J_in
J_wall(state::Air) = state.J_wall
J_vent(state::Air) = state.J_vent

########################################
# 入力用の関数
function set_num(air::Air, num::Int) 
    air.num    = num end
function set_name(air::Air, num::String) 
    air.name   = name end
function set_temp(air::Air, temp::Float64) 
    air.temp   = temp  end
function set_rh(air::Air, rh::Float64) 
    air.rh     = rh    end
function set_pv(air::Air, pv::Float64) 
    air.pv     = pv    end
function set_ah(air::Air, ah::Float64) 
    air.ah     = ah    end
function set_p_atm(air::Air, p_atm::Float64) 
    air.p_atm  = p_atm end
function set_H_in(air::Air, H_in::Float64) 
    air.H_in   = H_in end    
function set_H_wall(air::Air, H_wall::Float64) 
    air.H_wall = H_wall end    
function set_H_vent(air::Air, H_vent::Float64) 
    air.H_vent = H_vent end    
function set_J_in(air::Air, J_in::Float64) 
    air.J_in   = J_in end    
function set_J_wall(air::Air, J_wall::Float64) 
    air.J_wall = J_wall end    
function set_J_vent(air::Air, J_vent::Float64) 
    air.J_vent = J_vent end            

########################################
# 積算用の関数
function add_H_in(air::Air, H_in::Float64) 
    air.H_in   = air.H_in + H_in end    
function add_H_wall(air::Air, H_wall::Float64) 
    air.H_wall = air.H_wall + H_wall end    
function add_H_vent(air::Air, H_vent::Float64) 
    air.H_vent = air.H_vent + H_vent end    
function add_J_in(air::Air, J_in::Float64) 
    air.J_in   = air.J_in + J_in end    
function add_J_wall(air::Air, J_wall::Float64) 
    air.J_wall = air.J_wall + J_wall end    
function add_J_vent(air::Air, J_vent::Float64) 
    air.J_vent = air.J_vent + J_vent end            

# 基礎式
function cal_energy_balance(temp::Float64, ah::Float64, vol::Float64, Hw::Float64, Hv::Float64, Hi::Float64, dt::Float64)
    ca = 1005.0 + 1846.0 * ah # 乾き空気＋水蒸気の比熱
    rho=  353.25 / temp # ボイルシャルルの法則より
    return temp + ( Hw + Hv + Hi ) / ( ca * rho * vol / dt )   
end

# air構造体を用いた式
cal_energy_balance(air::Air, dt::Float64) = cal_energy_balance(temp(air), ah(air), vol(air), H_wall(air), H_vent(air), H_in(air), dt)
cal_newtemp(air::Air, dt::Float64) = cal_energy_balance(air, dt)

# 基礎式
function cal_moisture_balance( temp::Float64, ah::Float64, vol::Float64, Jw::Float64, Jv::Float64, Ji::Float64, dt::Float64)
    rho=  353.25 / temp
    return ah + ( Jw + Jv + Ji ) / ( rho * vol / dt )   
end

# air構造体を用いた式
cal_moisture_balance(air::Air, dt::Float64) = cal_moisture_balance( temp(air), ah(air), vol(air), J_wall(air), J_vent(air), J_in(air), dt)
cal_newRH(air::Air, dt::Float64) = convertAH2RH( temp = temp(air), patm = p_atm(air), ah = cal_moisture_balance(air, dt))



