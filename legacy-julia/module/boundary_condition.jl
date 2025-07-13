include("./air.jl")
include("./cell.jl")
include("./function/lewis_relation.jl")
include("wind_driven_rain.jl")

Base.@kwdef mutable struct BC_Dirichlet
    name::String = "NoName"
    cell::Cell   = Cell()
end

temp(state::BC_Dirichlet)= temp(state.cell)
miu(state::BC_Dirichlet) = miu(state.cell)
rh(state::BC_Dirichlet) = rh(state.cell)
pv(state::BC_Dirichlet)  = pv(state.cell)
ah(state::BC_Dirichlet)  = ah(state.cell)
phi(state::BC_Dirichlet)  = phi(state.cell)

Base.@kwdef mutable struct BC_Neumann
    name::String = "NoName"
    q::Float64  = 0.0
    jv::Float64 = 0.0
    jl::Float64 = 0.0
end

temp(state::BC_Neumann)= 0.0
miu(state::BC_Neumann) = 0.0
rh(state::BC_Neumann) = 0.0
pv(state::BC_Neumann)  = 0.0
ah(state::BC_Neumann)  = 0.0
phi(state::BC_Neumann)  = 0.0

Base.@kwdef mutable struct BC_Robin
    name::String        = "NoName"
    air::Air            = Air()
    #wall::Cell          = Cell()    # 名称はcellの方が正しい
    cell::Cell          = Cell()
    q_added::Float64    = 0.0
    jv_added::Float64   = 0.0
    jl_added::Float64   = 0.0
    jl_surf::Float64    = 0.0 # 表面水（結露水）
    alpha::Float64      = 9.3
    alphac::Float64     = 4.9
    alphar::Float64     = 4.4
    aldm::Float64       = 3.2e-8
    θ::Dict{String, Float64}    = Dict( "a" => 0.0, # 方位角：azimuth
                                        "e" => 0.0, # 仰角　：elevation
                                        "LATIs" => -180.0,  # 日射が当たり始める方位　  ：LATI_started
                                        "LATIl" =>  360.0,  # 日射が当たる限界の方位　  ：LATI_limited
                                        "ALTIs" => -180.0,  # 日射が当たり始める高度    ：ALTI_started
                                        "ALTIl" =>  360.0)  # 日射が当たる限界の高度    ：ALTI_limited
    ar::Float64 = 0.0  # 日射吸収率（absorption rate）
    er::Float64 = 0.0  # 放射率（emissivity）
end

# 熱水分状態量
temp(state::BC_Robin)= state.air.temp
rh(state::BC_Robin) = state.air.rh
miu(state::BC_Robin) = convertRH2Miu( temp = temp(state.air), rh = rh(state.air) )
pv(state::BC_Robin)  = convertRH2Pv( temp = temp(state.air), rh = rh(state.air) )
ah(state::BC_Robin)  = convertPv2AH( patm = p_atm(state.air), pv = pv(state.air) )
patm(state::BC_Robin)= state.air.p_atm
vol(state::BC_Robin)= state.air.vol
material_name(state::BC_Dirichlet)= typeof(state)
material_name(state::BC_Neumann)= typeof(state)
material_name(state::BC_Robin)= typeof(state)

# 移動係数
alpha(state::BC_Robin) = state.alphac + state.alphar
aldm(state::BC_Robin)  = state.aldm
aldt(state::BC_Robin)  = aldm(state) * cal_DPvDT( temp = temp(state.air), miu = miu(state.air) )
aldmu(state::BC_Robin) = aldm(state) * cal_DPvDMiu( temp = temp(state.air), miu = miu(state.air) )
aldm_by_alphac(state::BC_Robin) = Lewis_relation.cal_aldm( alpha = state.alphac , temp = temp(state.air) )

θa(state::BC_Robin)     = state.θ["a"]
θe(state::BC_Robin)     = state.θ["e"]
LATI_started(state::BC_Robin)   = state.θ["LATIs"]
LATI_limited(state::BC_Robin)   = state.θ["LATIl"]
ALTI_started(state::BC_Robin)   = state.θ["ALTIs"]
ALTI_limited(state::BC_Robin)   = state.θ["ALTIl"]
ar(state::BC_Robin)     = state.ar
er(state::BC_Robin)     = state.er

# 値のセット
function set_air(state::BC_Robin, air::Air)
    state.air = air end
function set_cell(state::BC_Robin, cell::Cell)
    state.cell = cell end
function set_q_added(state::BC_Robin, q_added::Float64)
    state.q_added = q_added end
function set_jv_added(state::BC_Robin, jv_added::Float64)
    state.jv_added = jv_added end
function set_jl_added(state::BC_Robin, jl_added::Float64)
    state.jl_added = jl_added end
function set_jl_surf(state::BC_Robin, jl_surf::Float64)
    state.jl_surf = jl_surf end
function set_alpha(state::BC_Robin, alpha::Float64)
    state.alpha = alpha end
function set_alphac(state::BC_Robin, alphac::Float64)
    state.alphac = alphac end
function set_alphar(state::BC_Robin, alphar::Float64)
    state.alphar = alphar end
function set_aldm(state::BC_Robin, aldm::Float64)
    state.aldm = aldm end
function set_θa(state::BC_Robin, θa::Float64)
    state.θ["a"] = θa end
function set_θe(state::BC_Robin, θe::Float64)
    state.θ["e"] = θe end
function set_LATI_started(state::BC_Robin, LATI_started::Float64)
    state.θ["LATIs"] = LATI_started end
function set_LATI_limited(state::BC_Robin, LATI_limited::Float64)
    state.θ["LATIl"] = LATI_limited end
function set_ALTI_started(state::BC_Robin, ALTI_started::Float64)
    state.θ["ALTIs"] = ALTI_started end
function set_ALTI_limited(state::BC_Robin, ALTI_limited::Float64)
    state.θ["ALTIl"] = ALTI_limited end
function set_ar(state::BC_Robin, ar::Float64)
    state.ar = ar end
function set_er(state::BC_Robin, er::Float64)
    state.er = er end

# 値のセット
function add_q_added(state::BC_Robin, q_added::Float64)
    state.q_added = state.q_added + q_added end
function add_jv_added(state::BC_Robin, jv_added::Float64)
    state.jv_added = state.jv_added + jv_added end
function add_jl_added(state::BC_Robin, jl_added::Float64)
    state.jl_added = state.jl_added + jl_added end
function add_jl_surf(state::BC_Robin, jl_surf::Float64)
    state.jl_surf = state.jl_surf + jl_surf end

# 直達日射量の計算
function cal_direct_solar_radiation_at_wall(climate::Climate, BC_Robin::BC_Robin)
    Jdi = cal_direct_solar_radiation_at_wall(
        SOLDN   = climate.solar["SOLDN"], 
        ALTI    = climate.solar["ALTI"], 
        LATI    = climate.solar["LATI"],
        θe      = θe(BC_Robin),
        θa      = θa(BC_Robin))
    return Jdi
end

# 天空日射量の計算
function cal_diffused_solar_radiation_at_wall(climate::Climate, BC_Robin::BC_Robin)
    Jsi = cal_diffused_solar_radiation_at_wall(
        SOLSN   = climate.solar["SOLSN"],
        θe      = θe(BC_Robin))
    return Jsi
end

# 地面からの反射日射の計算  
function cal_reflected_solar_radiation_by_ground(climate::Climate, BC_Robin::BC_Robin)
    Jr  = cal_reflected_solar_radiation_by_ground( 
        SOLDN   = climate.solar["SOLDN"], 
        SOLSN   = climate.solar["SOLDN"],
        θe      = θe(BC_Robin),
        rho     = rho(climate) )
    return Jr
end

# 実効放射（夜間放射）の計算
function cal_effective_thermal_radiation_at_wall(climate::Climate, BC_Robin::BC_Robin)
    Jer = cal_effective_thermal_radiation_at_wall( 
        temp_wall   = temp(BC_Robin.cell),
        temp_air    = temp(climate.air), 
        ε           = er(BC_Robin), 
        pv          = pv(BC_Robin.air), 
        n           = cloudiness(climate),
        θe          = θe(BC_Robin))
    return Jer
end 

# 壁面に当たる降水量の計算
function cal_effective_rainfall_at_wall(climate::Climate, BC_Robin::BC_Robin, α::Float64 = 0.222)
    Rh = climate.Jp / 3600.0    # 1sあたり降水量に変換
    Rwdr = cal_WDR_at_wall( Rh, WS(climate), θa(BC_Robin) - θwd(climate) , α )
    return Rh * cosd(θe(BC_Robin)) + Rwdr * sind(θe(BC_Robin))
end
cal_WDR_at_wall(; climate::Climate, BC_Robin::BC_Robin, α::Float64 = 0.222) = cal_WDR_at_wall(climate, BC_Robin, α)