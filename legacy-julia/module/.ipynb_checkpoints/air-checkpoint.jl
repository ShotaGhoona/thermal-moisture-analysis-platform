include("./module_function/vapour.jl")
include("./module_function/lewis_relation.jl")

mutable struct Air
    name::String  #= 名称  =#
    vol::Float64  #= 体積  =#
    temp::Float64
    rh::Float64
    alpha::Float64
    alphac::Float64
    alphar::Float64
    aldm::Float64
    Air() = new()
end 

# 構造体パラメーター
name(state::Air)= state.name
vol(state::Air)= state.vol

# 熱水分状態量
temp(state::Air)= state.temp
rh(state::Air) = state.rh
miu(state::Air) = convertRH2Miu( temp = state.temp, rh = state.rh )
pv(state::Air)  = convertRH2Pv( temp = state.temp, rh = state.rh )

# 移動係数
alpha(state::Air) = state.alphac + state.alphar
aldm(state::Air)  = state.aldm
aldt(state::Air)  = aldm(state) * cal_DPvDT( temp = state.temp, miu = miu(state) )
aldmu(state::Air) = aldm(state) * cal_DPvDMiu( temp = state.temp, miu = miu(state) )
aldm_by_alphac(state::Air) = Lewis_relation.cal_aldm( alpha = state.alphac , temp = state.temp )

function air_construction(; name::String = "No Name", 
        vol::Float64 = 1.0, temp::Float64, miu::Float64 = 0.0, rh::Float64 = 0.0, 
        alphac::Float64 = 4.9, alphar::Float64 = 4.4, aldm::Float64 = 0.0 )
    air = Air()
    air.name  = name
    air.vol = vol
    air.temp= temp
    air.alpha = alphac + alphar # 総合熱伝達率
    air.alphac= alphac # 対流熱伝達率
    air.alphar= alphar # 放射熱伝達率
    
    # 湿気伝達率
    if aldm == 0.0
        air.aldm = aldm_by_alphac(air)
    else
        air.aldm = aldm
    end
    
    if miu == 0.0
        air.rh = rh
    else
        air.rh = convertMiu2RH( temp = temp, miu = miu )
    end
    return air
end

#air_test = air_construction(temp = 20.0 + 293.15)

#air_test.temp = 300.0
#air_test.rh   = 0.65
#air_test.alpha= 9.3
#air_test.aldm

#air_test.alphac
