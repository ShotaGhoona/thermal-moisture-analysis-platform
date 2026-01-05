"""
    VaporTransfer

水蒸気移動計算モジュール。
水蒸気伝導（フィック則）、水蒸気伝達を提供。
圧力駆動・ポテンシャル駆動の両方に対応。

移行元:
- legacy-julia/module/transfer_in_media.jl
- legacy-julia/module/function/flux_and_balance_equation.jl
"""
module VaporTransfer

export vapor_permeance_pressure, vapor_permeance_pressure_diff
export vapor_permeance_potential, vapor_permeance_potential_diff
export vapor_transfer_pressure, vapor_transfer_pressure_diff
export vapor_transfer_potential, vapor_transfer_potential_diff

#=============================================================================
  水蒸気伝導（圧力駆動）
=============================================================================#

"""
    vapor_permeance_pressure(dp::Float64, dPv::Float64, dx::Float64) -> Float64

水蒸気伝導流束を計算する（圧力駆動、フィック則）。

jv = -δp * ∂Pv/∂x [kg/(m²·s)]

# Arguments
- `dp`: 透湿率 [kg/(m·s·Pa)]
- `dPv`: 水蒸気分圧差 Pv₂ - Pv₁ [Pa]
- `dx`: 距離 [m]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
vapor_permeance_pressure(dp::Float64, dPv::Float64, dx::Float64) =
    -dp * dPv / dx

"""
    vapor_permeance_pressure_diff(;
        dp_mns::Float64, dp_pls::Float64,
        pv_mns::Float64, pv_pls::Float64,
        dx2_mns::Float64, dx2_pls::Float64
    ) -> Float64

差分法による質点間の水蒸気伝導流束を計算する（圧力駆動）。

# Arguments
- `dp_mns`: マイナス側セルの透湿率 [kg/(m·s·Pa)]
- `dp_pls`: プラス側セルの透湿率 [kg/(m·s·Pa)]
- `pv_mns`: マイナス側セルの水蒸気分圧 [Pa]
- `pv_pls`: プラス側セルの水蒸気分圧 [Pa]
- `dx2_mns`: マイナス側セルの半厚さ [m]
- `dx2_pls`: プラス側セルの半厚さ [m]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
function vapor_permeance_pressure_diff(;
    dp_mns::Float64, dp_pls::Float64,
    pv_mns::Float64, pv_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    dp = (dx2_mns + dx2_pls) / (dx2_mns / dp_mns + dx2_pls / dp_pls)
    return vapor_permeance_pressure(dp, pv_pls - pv_mns, dx2_mns + dx2_pls)
end

#=============================================================================
  水蒸気伝導（ポテンシャル駆動）
=============================================================================#

"""
    vapor_permeance_potential(
        ldmg::Float64, ldtg::Float64,
        dmiu::Float64, dT::Float64, dx::Float64
    ) -> Float64

水蒸気伝導流束を計算する（水分化学ポテンシャル駆動）。

jv = -(λ'μg * ∂μ/∂x + λ'Tg * ∂T/∂x) [kg/(m²·s)]

# Arguments
- `ldmg`: 水分化学ポテンシャル勾配に対する水蒸気伝導率 [kg/(m·s·J/kg)]
- `ldtg`: 温度勾配に対する水蒸気伝導率 [kg/(m·s·K)]
- `dmiu`: 水分化学ポテンシャル差 [J/kg]
- `dT`: 温度差 [K]
- `dx`: 距離 [m]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
vapor_permeance_potential(ldmg::Float64, ldtg::Float64,
    dmiu::Float64, dT::Float64, dx::Float64) =
    -(ldmg * dmiu / dx + ldtg * dT / dx)

"""
    vapor_permeance_potential_diff(;
        ldmg_mns::Float64, ldmg_pls::Float64,
        ldtg_mns::Float64, ldtg_pls::Float64,
        miu_mns::Float64, miu_pls::Float64,
        temp_mns::Float64, temp_pls::Float64,
        dx2_mns::Float64, dx2_pls::Float64
    ) -> Float64

差分法による質点間の水蒸気伝導流束を計算する（ポテンシャル駆動）。

# Arguments
- `ldmg_mns`, `ldmg_pls`: 各セルのλ'μg [kg/(m·s·J/kg)]
- `ldtg_mns`, `ldtg_pls`: 各セルのλ'Tg [kg/(m·s·K)]
- `miu_mns`, `miu_pls`: 各セルの水分化学ポテンシャル [J/kg]
- `temp_mns`, `temp_pls`: 各セルの温度 [K]
- `dx2_mns`, `dx2_pls`: 各セルの半厚さ [m]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
function vapor_permeance_potential_diff(;
    ldmg_mns::Float64, ldmg_pls::Float64,
    ldtg_mns::Float64, ldtg_pls::Float64,
    miu_mns::Float64, miu_pls::Float64,
    temp_mns::Float64, temp_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    ldmg = (dx2_mns + dx2_pls) / (dx2_mns / ldmg_mns + dx2_pls / ldmg_pls)
    ldtg = (dx2_mns + dx2_pls) / (dx2_mns / ldtg_mns + dx2_pls / ldtg_pls)
    return vapor_permeance_potential(
        ldmg, ldtg,
        miu_pls - miu_mns, temp_pls - temp_mns,
        dx2_mns + dx2_pls)
end

#=============================================================================
  水蒸気伝達（圧力駆動）
=============================================================================#

"""
    vapor_transfer_pressure(aldm::Float64, dPv::Float64) -> Float64

水蒸気伝達流束を計算する（圧力駆動）。

jv = -α'dm * ΔPv [kg/(m²·s)]

# Arguments
- `aldm`: 湿気伝達率 [kg/(m²·s·Pa)]
- `dPv`: 水蒸気分圧差 [Pa]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
vapor_transfer_pressure(aldm::Float64, dPv::Float64) = -aldm * dPv

"""
    vapor_transfer_pressure_diff(
        aldm::Float64, pv_mns::Float64, pv_pls::Float64
    ) -> Float64

差分法による水蒸気伝達流束を計算する（圧力駆動）。
"""
vapor_transfer_pressure_diff(aldm::Float64, pv_mns::Float64, pv_pls::Float64) =
    vapor_transfer_pressure(aldm, pv_pls - pv_mns)

#=============================================================================
  水蒸気伝達（ポテンシャル駆動）
=============================================================================#

"""
    vapor_transfer_potential(
        aldmg::Float64, aldtg::Float64,
        dmiu::Float64, dT::Float64
    ) -> Float64

水蒸気伝達流束を計算する（ポテンシャル駆動）。

jv = -α'μg * Δμ - α'Tg * ΔT [kg/(m²·s)]

# Arguments
- `aldmg`: 水分化学ポテンシャル差に対する湿気伝達率 [kg/(m²·s·J/kg)]
- `aldtg`: 温度差に対する湿気伝達率 [kg/(m²·s·K)]
- `dmiu`: 水分化学ポテンシャル差 [J/kg]
- `dT`: 温度差 [K]

# Returns
- 水蒸気流束 [kg/(m²·s)]
"""
vapor_transfer_potential(aldmg::Float64, aldtg::Float64,
    dmiu::Float64, dT::Float64) =
    -aldmg * dmiu - aldtg * dT

"""
    vapor_transfer_potential_diff(
        aldmg::Float64, aldtg::Float64,
        miu_mns::Float64, miu_pls::Float64,
        temp_mns::Float64, temp_pls::Float64
    ) -> Float64

差分法による水蒸気伝達流束を計算する（ポテンシャル駆動）。
"""
vapor_transfer_potential_diff(aldmg::Float64, aldtg::Float64,
    miu_mns::Float64, miu_pls::Float64,
    temp_mns::Float64, temp_pls::Float64) =
    vapor_transfer_potential(aldmg, aldtg, miu_pls - miu_mns, temp_pls - temp_mns)

end # module
