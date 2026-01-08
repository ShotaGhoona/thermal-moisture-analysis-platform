"""
    LiquidTransfer

液水移動計算モジュール。
液水伝導（毛管伝導）を提供。

移行元:
- legacy-julia/module/transfer_in_media.jl
- legacy-julia/module/function/flux_and_balance_equation.jl
"""
module LiquidTransfer

using ..PhysicsConstants: GRAVITY

export liquid_conduction_potential, liquid_conduction_potential_diff

#=============================================================================
  液水伝導（毛管伝導）
=============================================================================#

"""
    liquid_conduction_potential(
        ldml::Float64, dmiu::Float64, dx::Float64, nx::Float64=0.0
    ) -> Float64

液水伝導流束を計算する（水分化学ポテンシャル駆動）。

jl = -λ'μl * (∂μ/∂x - nx * g) [kg/(m²·s)]

# Arguments
- `ldml`: 液水伝導率 [kg/(m·s·J/kg)]
- `dmiu`: 水分化学ポテンシャル差 μ₂ - μ₁ [J/kg]
- `dx`: 距離 [m]
- `nx`: 鉛直方向の方向余弦 [-]（上向きが正、水平面は0）

# Returns
- 液水流束 [kg/(m²·s)]

# Note
- nx = 0: 水平方向（重力項なし）
- nx = 1: 上向き（重力に逆らう）
- nx = -1: 下向き（重力で加速）
"""
liquid_conduction_potential(ldml::Float64, dmiu::Float64,
    dx::Float64, nx::Float64=0.0) =
    -ldml * (dmiu / dx - nx * GRAVITY)

"""
    liquid_conduction_potential_diff(;
        ldml_mns::Float64, ldml_pls::Float64,
        miu_mns::Float64, miu_pls::Float64,
        dx2_mns::Float64, dx2_pls::Float64,
        nx::Float64=0.0
    ) -> Float64

差分法による質点間の液水伝導流束を計算する。

# Arguments
- `ldml_mns`: マイナス側セルの液水伝導率 [kg/(m·s·J/kg)]
- `ldml_pls`: プラス側セルの液水伝導率 [kg/(m·s·J/kg)]
- `miu_mns`: マイナス側セルの水分化学ポテンシャル [J/kg]
- `miu_pls`: プラス側セルの水分化学ポテンシャル [J/kg]
- `dx2_mns`: マイナス側セルの半厚さ [m]
- `dx2_pls`: プラス側セルの半厚さ [m]
- `nx`: 鉛直方向の方向余弦 [-]

# Returns
- 液水流束 [kg/(m²·s)]
"""
function liquid_conduction_potential_diff(;
    ldml_mns::Float64, ldml_pls::Float64,
    miu_mns::Float64, miu_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64,
    nx::Float64=0.0)

    # 液水伝導率の調和平均
    ldml = (dx2_mns + dx2_pls) / (dx2_mns / ldml_mns + dx2_pls / ldml_pls)
    return liquid_conduction_potential(
        ldml, miu_pls - miu_mns, dx2_mns + dx2_pls, nx)
end

end # module
