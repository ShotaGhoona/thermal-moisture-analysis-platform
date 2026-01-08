"""
    BalanceEquation

収支方程式モジュール。
壁体セル・室空気の温度・水分更新式を提供。

移行元:
- legacy-julia/module/function/flux_and_balance_equation.jl
- legacy-julia/module/cell.jl
- legacy-julia/module/air.jl
"""
module BalanceEquation

using ..PhysicsConstants: RHO_WATER, C_WATER, C_DRY_AIR, C_VAPOR
using ..HeatTransfer: latent_heat

export update_temp_cell, update_miu_cell, update_phi_cell
export update_temp_air, update_ah_air

#=============================================================================
  壁体セルの状態更新
=============================================================================#

"""
    update_temp_cell(;
        crow::Float64,
        temp::Float64,
        dq::Float64,
        W::Float64,
        dx::Float64,
        dt::Float64
    ) -> Float64

壁体セルの温度を更新する（前進オイラー法）。

熱収支: ρc * ∂T/∂t = -∂q/∂x + r * W

# Arguments
- `crow`: 容積熱容量 [J/(m³·K)]
- `temp`: 現在の温度 [K]
- `dq`: 熱流の収支 q_out - q_in [W/m²]（正: 熱の流出）
- `W`: 水蒸気蒸発量 [kg/(m³·s)]（正: 蒸発、負: 凝縮）
- `dx`: セル厚さ [m]
- `dt`: タイムステップ [s]

# Returns
- 次のステップの温度 [K]

# Note
蒸発時（W > 0）は潜熱を吸収するため温度が下がる。
"""
function update_temp_cell(;
    crow::Float64,
    temp::Float64,
    dq::Float64,
    W::Float64,
    dx::Float64,
    dt::Float64)

    r = latent_heat(temp)
    # dq: 流出 - 流入 = q_pls - q_mns
    # r * W: 蒸発による熱吸収
    return temp + (-dq + r * W * dx) / crow * (dt / dx)
end

"""
    update_miu_cell(;
        dphi::Float64,
        miu::Float64,
        djw::Float64,
        dx::Float64,
        dt::Float64
    ) -> Float64

壁体セルの水分化学ポテンシャルを更新する（前進オイラー法）。

水分収支: ∂w/∂t = -∂jw/∂x

# Arguments
- `dphi`: 含水率の水分化学ポテンシャル微分 ∂φ/∂μ [kg/m³ / (J/kg)]
- `miu`: 現在の水分化学ポテンシャル [J/kg]
- `djw`: 水分流の収支 jw_out - jw_in [kg/(m²·s)]（正: 水分の流出）
- `dx`: セル厚さ [m]
- `dt`: タイムステップ [s]

# Returns
- 次のステップの水分化学ポテンシャル [J/kg]
"""
function update_miu_cell(;
    dphi::Float64,
    miu::Float64,
    djw::Float64,
    dx::Float64,
    dt::Float64)

    # djw: 流出 - 流入
    # dphi: dφ/dμ
    return miu + (-djw / dx) / dphi * dt
end

"""
    update_phi_cell(;
        phi::Float64,
        djw::Float64,
        dx::Float64,
        dt::Float64
    ) -> Float64

壁体セルの含水率を更新する（前進オイラー法）。

水分収支: ∂φ/∂t = -∂jw/∂x

# Arguments
- `phi`: 現在の含水率 [kg/m³]
- `djw`: 水分流の収支 jw_out - jw_in [kg/(m²·s)]
- `dx`: セル厚さ [m]
- `dt`: タイムステップ [s]

# Returns
- 次のステップの含水率 [kg/m³]
"""
function update_phi_cell(;
    phi::Float64,
    djw::Float64,
    dx::Float64,
    dt::Float64)

    return phi + (-djw / dx) * dt
end

#=============================================================================
  室空気の状態更新
=============================================================================#

"""
    update_temp_air(;
        temp::Float64,
        ah::Float64,
        vol::Float64,
        Hw::Float64,
        Hv::Float64,
        Hi::Float64,
        dt::Float64
    ) -> Float64

室空気の温度を更新する（前進オイラー法）。

熱収支: ρ * ca * V * ∂T/∂t = Hw + Hv + Hi

# Arguments
- `temp`: 現在の温度 [K]
- `ah`: 絶対湿度 [kg/kg']
- `vol`: 室容積 [m³]
- `Hw`: 壁からの熱流量 [W]（正: 室への流入）
- `Hv`: 換気による熱流量 [W]（正: 室への流入）
- `Hi`: 内部発熱 [W]
- `dt`: タイムステップ [s]

# Returns
- 次のステップの温度 [K]
"""
function update_temp_air(;
    temp::Float64,
    ah::Float64,
    vol::Float64,
    Hw::Float64,
    Hv::Float64,
    Hi::Float64,
    dt::Float64)

    # 湿り空気の比熱
    ca = C_DRY_AIR + C_VAPOR * ah
    # 空気密度（ボイル・シャルルの法則）
    rho = 353.25 / temp
    # 熱容量
    C_air = ca * rho * vol

    return temp + (Hw + Hv + Hi) / C_air * dt
end

"""
    update_ah_air(;
        temp::Float64,
        ah::Float64,
        vol::Float64,
        Jw::Float64,
        Jv::Float64,
        Ji::Float64,
        dt::Float64
    ) -> Float64

室空気の絶対湿度を更新する（前進オイラー法）。

水分収支: ρ * V * ∂ah/∂t = Jw + Jv + Ji

# Arguments
- `temp`: 温度 [K]
- `ah`: 現在の絶対湿度 [kg/kg']
- `vol`: 室容積 [m³]
- `Jw`: 壁からの水分流量 [kg/s]（正: 室への流入）
- `Jv`: 換気による水分流量 [kg/s]（正: 室への流入）
- `Ji`: 内部発湿 [kg/s]
- `dt`: タイムステップ [s]

# Returns
- 次のステップの絶対湿度 [kg/kg']
"""
function update_ah_air(;
    temp::Float64,
    ah::Float64,
    vol::Float64,
    Jw::Float64,
    Jv::Float64,
    Ji::Float64,
    dt::Float64)

    # 空気密度
    rho = 353.25 / temp
    # 空気質量
    M_air = rho * vol

    return ah + (Jw + Jv + Ji) / M_air * dt
end

end # module
