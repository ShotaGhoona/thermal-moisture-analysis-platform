"""
    VentilationFlux

換気による熱・水分流量計算モジュール。
開口を通じた換気流量および熱・水分輸送を計算。

移行元:
- legacy-julia/module/flux_ventilation.jl
- legacy-julia/run/main.jl: cal_network_flux_of_ventilation
"""
module VentilationFlux

using ...Model: Opening, OpeningKind, Room, BuildingNetwork
using ...Model: gap, window, constant, fan, height

export calculate_ventilation_flux!
export ventilation_heat_flux, ventilation_moisture_flux

#=============================================================================
  物理定数
=============================================================================#

const C_DRY_AIR = 1005.0   # 乾き空気の比熱 [J/(kg·K)]
const C_VAPOR = 1846.0     # 水蒸気の比熱 [J/(kg·K)]
const GRAVITY = 9.80665    # 重力加速度 [m/s²]

#=============================================================================
  湿度計算（簡易版）
=============================================================================#

"""絶対湿度の計算 [kg/kg']（簡易版）"""
function calculate_ah(temp::Float64, rh::Float64, p_atm::Float64=101325.0)::Float64
    # Tetens式による飽和水蒸気圧
    T_C = temp - 273.15
    pvs = 611.2 * exp(17.67 * T_C / (T_C + 243.5))
    pv = rh * pvs
    return 0.622 * pv / (p_atm - pv)
end

"""空気密度の計算 [kg/m³]"""
function air_density(temp::Float64)::Float64
    return 353.25 / temp
end

"""湿り空気の比熱 [J/(kg·K)]"""
function moist_air_capacity(ah::Float64)::Float64
    return C_DRY_AIR + C_VAPOR * ah
end

#=============================================================================
  換気流量の計算
=============================================================================#

"""
    calculate_flow_rate(opening::Opening, room_plus::Room, room_minus::Room) -> Tuple{Float64, Float64}

開口を通じた体積流量を計算 [m³/s]。

# Returns
- (Q_up, Q_down): プラス方向流量とマイナス方向流量 [m³/s]

# Note
- constantタイプ: 固定流量を返す
- gap/windowタイプ: 圧力差から流量を計算
"""
function calculate_flow_rate(opening::Opening, room_plus::Room, room_minus::Room)
    if opening.kind == constant || opening.kind == fan
        # 固定流量
        return (opening.Q_plus, opening.Q_minus)

    elseif opening.kind == gap || opening.kind == window
        # 圧力差から流量を計算
        return calculate_natural_ventilation_flow(opening, room_plus, room_minus)
    else
        return (0.0, 0.0)
    end
end

"""
    calculate_natural_ventilation_flow(opening, room_plus, room_minus) -> Tuple{Float64, Float64}

自然換気流量を計算（等温/非等温対応）。

# Note
温度差がある場合は非等温換気として浮力効果を考慮
"""
function calculate_natural_ventilation_flow(opening::Opening, room_plus::Room, room_minus::Room)
    # 空気密度
    rho_plus = air_density(room_plus.air.temp)
    rho_minus = air_density(room_minus.air.temp)
    rho_mean = (rho_plus + rho_minus) / 2.0

    # 圧力差（床面圧力 + 温度差による浮力）
    dp_floor = room_plus.air.p_floor - room_minus.air.p_floor

    # 開口中心高さでの圧力差
    h_center = (opening.height_top + opening.height_bottom) / 2.0
    dp_buoyancy = (rho_minus - rho_plus) * GRAVITY * h_center

    dp_total = dp_floor + dp_buoyancy

    # 流量計算（オリフィス式）
    A = opening.area > 0.0 ? opening.area : opening.width * height(opening)
    alpha = opening.flow_coefficient > 0.0 ? opening.flow_coefficient : 0.6

    if dp_total > 0.0
        # プラス方向流れ
        Q = alpha * A * sqrt(2.0 * abs(dp_total) / rho_mean)
        return (Q, 0.0)
    elseif dp_total < 0.0
        # マイナス方向流れ
        Q = alpha * A * sqrt(2.0 * abs(dp_total) / rho_mean)
        return (0.0, Q)
    else
        return (0.0, 0.0)
    end
end

#=============================================================================
  換気による熱・水分流量
=============================================================================#

"""
    ventilation_heat_flux(Q::Float64, room_from::Room, room_to::Room) -> Float64

換気による熱流量を計算 [W]。

# Arguments
- `Q`: 体積流量 [m³/s]（room_from → room_to方向）
- `room_from`: 流出側の室
- `room_to`: 流入側の室

# Returns
- 熱流量 [W]（正: room_toへの熱流入）
"""
function ventilation_heat_flux(Q::Float64, room_from::Room, room_to::Room)
    if Q <= 0.0
        return 0.0
    end

    # 流出側の空気状態
    temp_from = room_from.air.temp
    ah_from = calculate_ah(temp_from, room_from.air.rh, room_from.air.p_atm)
    rho_from = air_density(temp_from)
    ca_from = moist_air_capacity(ah_from)

    # 流入側の空気状態
    temp_to = room_to.air.temp
    ah_to = calculate_ah(temp_to, room_to.air.rh, room_to.air.p_atm)
    ca_to = moist_air_capacity(ah_to)

    # 熱流量 = 質量流量 × 比熱 × 温度差
    # room_toへの流入を正とする
    return Q * rho_from * ca_from * (temp_from - temp_to)
end

"""
    ventilation_moisture_flux(Q::Float64, room_from::Room, room_to::Room) -> Float64

換気による水分流量を計算 [kg/s]。

# Arguments
- `Q`: 体積流量 [m³/s]（room_from → room_to方向）
- `room_from`: 流出側の室
- `room_to`: 流入側の室

# Returns
- 水分流量 [kg/s]（正: room_toへの水分流入）
"""
function ventilation_moisture_flux(Q::Float64, room_from::Room, room_to::Room)
    if Q <= 0.0
        return 0.0
    end

    # 流出側の空気状態
    temp_from = room_from.air.temp
    ah_from = calculate_ah(temp_from, room_from.air.rh, room_from.air.p_atm)
    rho_from = air_density(temp_from)

    # 流入側の空気状態
    temp_to = room_to.air.temp
    ah_to = calculate_ah(temp_to, room_to.air.rh, room_to.air.p_atm)

    # 水分流量 = 質量流量 × 絶対湿度差
    return Q * rho_from * (ah_from - ah_to)
end

#=============================================================================
  ネットワーク全体の換気流量計算
=============================================================================#

"""
    calculate_ventilation_flux!(network::BuildingNetwork)

ネットワーク全体の換気による熱・水分流量を計算。
各室の収支値（H_vent, J_vent）を更新する。

# Note
- 室の換気収支値を初期化してから計算
- 各開口について流量を計算し、両側の室に熱・水分を配分
"""
function calculate_ventilation_flux!(network::BuildingNetwork)
    # 室の換気による収支値を初期化
    for room in network.rooms
        room.air.H_vent = 0.0
        room.air.J_vent = 0.0
    end

    # 各開口について流量計算
    for opening in network.openings
        calculate_single_opening_flux!(opening, network)
    end
end

"""
    calculate_single_opening_flux!(opening::Opening, network::BuildingNetwork)

単一開口の熱・水分流量を計算し、室の収支値に加算。
"""
function calculate_single_opening_flux!(opening::Opening, network::BuildingNetwork)
    # 接続室の取得
    room_plus = get_room_or_climate(network, opening.room_id_plus)
    room_minus = get_room_or_climate(network, opening.room_id_minus)

    # 流量計算
    Q_up, Q_down = calculate_flow_rate(opening, room_plus, room_minus)

    # プラス方向流れ（plus → minus）
    if Q_up > 0.0
        # room_plusからroom_minusへの流れ
        H_up = ventilation_heat_flux(Q_up, room_plus, room_minus)
        J_up = ventilation_moisture_flux(Q_up, room_plus, room_minus)

        # room_plusからの流出
        room_plus.air.H_vent -= H_up
        room_plus.air.J_vent -= J_up

        # room_minusへの流入
        room_minus.air.H_vent += H_up
        room_minus.air.J_vent += J_up
    end

    # マイナス方向流れ（minus → plus）
    if Q_down > 0.0
        # room_minusからroom_plusへの流れ
        H_down = ventilation_heat_flux(Q_down, room_minus, room_plus)
        J_down = ventilation_moisture_flux(Q_down, room_minus, room_plus)

        # room_minusからの流出
        room_minus.air.H_vent -= H_down
        room_minus.air.J_vent -= J_down

        # room_plusへの流入
        room_plus.air.H_vent += H_down
        room_plus.air.J_vent += J_down
    end
end

#=============================================================================
  ヘルパー関数
=============================================================================#

"""室またはclimateを取得"""
function get_room_or_climate(network::BuildingNetwork, room_id::Int)
    if room_id == 0 || room_id > length(network.rooms)
        return network.rooms[1]  # 外気として扱う
    else
        return network.rooms[room_id]
    end
end

end # module
