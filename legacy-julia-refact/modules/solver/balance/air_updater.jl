"""
    AirUpdater

室空気の状態更新モジュール。
熱・水分収支から温度・相対湿度を更新。

移行元:
- legacy-julia/module/air.jl: cal_newtemp, cal_newRH
- legacy-julia/run/main.jl: cal_new_value_ver_network（室空気部分）
"""
module AirUpdater

using ...Model: Air, Room
using ...Physics: BalanceEquation, Psychrometrics

export update_air!, update_room_air!
export ah_from_rh, rh_from_ah

#=============================================================================
  湿度変換関数
=============================================================================#

"""
    ah_from_rh(temp::Float64, rh::Float64, p_atm::Float64=101325.0) -> Float64

相対湿度から絶対湿度を計算 [kg/kg']。

# Arguments
- `temp`: 温度 [K]
- `rh`: 相対湿度 [-]
- `p_atm`: 大気圧 [Pa]

# Returns
- 絶対湿度 [kg/kg']（乾き空気1kgあたりの水蒸気質量）
"""
function ah_from_rh(temp::Float64, rh::Float64, p_atm::Float64=101325.0)::Float64
    pvs = Psychrometrics.cal_Pvs(temp)
    pv = rh * pvs
    # 絶対湿度 = 0.622 * pv / (p_atm - pv)
    return 0.622 * pv / (p_atm - pv)
end

"""
    rh_from_ah(temp::Float64, ah::Float64, p_atm::Float64=101325.0) -> Float64

絶対湿度から相対湿度を計算 [-]。

# Arguments
- `temp`: 温度 [K]
- `ah`: 絶対湿度 [kg/kg']
- `p_atm`: 大気圧 [Pa]

# Returns
- 相対湿度 [-]（0.0-1.0）
"""
function rh_from_ah(temp::Float64, ah::Float64, p_atm::Float64=101325.0)::Float64
    # 水蒸気分圧を絶対湿度から逆算
    pv = p_atm * ah / (0.622 + ah)

    # 飽和水蒸気圧
    pvs = Psychrometrics.cal_Pvs(temp)

    # 相対湿度
    rh = pv / pvs

    # 0.0-1.0の範囲にクリップ
    return clamp(rh, 0.0, 1.0)
end

#=============================================================================
  室空気の状態更新
=============================================================================#

"""
    update_air!(air::Air, dt::Float64)

室空気の温度・相対湿度を更新する。

# Arguments
- `air`: 更新対象の室空気
- `dt`: タイムステップ [hour]

# Note
- Forward Euler法（陽解法）による時間積分
- 収支値（H_wall, H_vent, H_internal, J_wall, J_vent, J_internal）から計算
- dtはhour単位、内部でsecに変換
"""
function update_air!(air::Air, dt::Float64)
    # hour → sec
    dt_sec = dt * 3600.0

    # 現在の絶対湿度
    ah = ah_from_rh(air.temp, air.rh, air.p_atm)

    # 温度更新
    new_temp = BalanceEquation.update_temp_air(
        temp = air.temp,
        ah = ah,
        vol = air.volume,
        Hw = air.H_wall,
        Hv = air.H_vent,
        Hi = air.H_internal,
        dt = dt_sec
    )

    # 絶対湿度更新
    new_ah = BalanceEquation.update_ah_air(
        temp = air.temp,
        ah = ah,
        vol = air.volume,
        Jw = air.J_wall,
        Jv = air.J_vent,
        Ji = air.J_internal,
        dt = dt_sec
    )

    # 相対湿度に変換
    new_rh = rh_from_ah(new_temp, new_ah, air.p_atm)

    # 状態を更新
    air.temp = new_temp
    air.rh = new_rh
end

"""
    update_room_air!(room::Room, dt::Float64)

室の空気状態を更新する。

# Arguments
- `room`: 更新対象の室
- `dt`: タイムステップ [hour]
"""
function update_room_air!(room::Room, dt::Float64)
    update_air!(room.air, dt)
end

#=============================================================================
  空気密度計算
=============================================================================#

"""
    air_density(temp::Float64) -> Float64

空気密度を計算 [kg/m³]。

# Note
ボイル・シャルルの法則による近似:
ρ = 353.25 / T
"""
function air_density(temp::Float64)::Float64
    return 353.25 / temp
end

"""
    moist_air_heat_capacity(ah::Float64) -> Float64

湿り空気の比熱を計算 [J/(kg·K)]。

# Note
ca = 1005 + 1846 * ah
乾き空気の比熱 + 水蒸気の比熱 × 絶対湿度
"""
function moist_air_heat_capacity(ah::Float64)::Float64
    C_DRY_AIR = 1005.0
    C_VAPOR = 1846.0
    return C_DRY_AIR + C_VAPOR * ah
end

end # module
