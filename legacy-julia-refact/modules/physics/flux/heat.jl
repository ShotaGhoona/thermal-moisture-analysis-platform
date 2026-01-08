"""
    HeatTransfer

熱移動計算モジュール。
熱伝導（フーリエ則）、熱伝達（ニュートンの冷却則）、潜熱を提供。

移行元:
- legacy-julia/module/transfer_in_media.jl
- legacy-julia/module/function/flux_and_balance_equation.jl
"""
module HeatTransfer

using ..PhysicsConstants: C_WATER

export latent_heat
export heat_conduction, heat_conduction_diff
export heat_transfer, heat_transfer_diff

#=============================================================================
  潜熱
=============================================================================#

"""
    latent_heat(temp::Float64) -> Float64

水の蒸発潜熱を計算する。

# Arguments
- `temp`: 温度 [K]

# Returns
- 蒸発潜熱 [J/kg]

# Note
r = (597.5 - 0.559 * (T - 273.15)) * Cw
0℃で約2501 kJ/kg、100℃で約2257 kJ/kg
"""
latent_heat(temp::Float64) = (597.5 - 0.559 * (temp - 273.15)) * C_WATER

#=============================================================================
  熱伝導（フーリエ則）
=============================================================================#

"""
    heat_conduction(lam::Float64, dT::Float64, dx::Float64) -> Float64

熱伝導流束を計算する（フーリエ則）。

q = -λ * ∂T/∂x [W/m²]

# Arguments
- `lam`: 熱伝導率 [W/(m·K)]
- `dT`: 温度差 T₂ - T₁ [K]
- `dx`: 距離 [m]

# Returns
- 熱流束 [W/m²]（正: T₁ → T₂ 方向）
"""
heat_conduction(lam::Float64, dT::Float64, dx::Float64) = -lam * dT / dx

"""
    heat_conduction_diff(;
        lam_mns::Float64, lam_pls::Float64,
        temp_mns::Float64, temp_pls::Float64,
        dx2_mns::Float64, dx2_pls::Float64
    ) -> Float64

差分法による質点間の熱伝導流束を計算する。

# Arguments
- `lam_mns`: マイナス側セルの熱伝導率 [W/(m·K)]
- `lam_pls`: プラス側セルの熱伝導率 [W/(m·K)]
- `temp_mns`: マイナス側セルの温度 [K]
- `temp_pls`: プラス側セルの温度 [K]
- `dx2_mns`: マイナス側セルの半厚さ [m]
- `dx2_pls`: プラス側セルの半厚さ [m]

# Returns
- 熱流束 [W/m²]

# Note
熱抵抗の直列接続として合成:
λ_eff = (dx₁ + dx₂) / (dx₁/λ₁ + dx₂/λ₂)
"""
function heat_conduction_diff(;
    lam_mns::Float64, lam_pls::Float64,
    temp_mns::Float64, temp_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    # 熱抵抗の調和平均
    lam = (dx2_mns + dx2_pls) / (dx2_mns / lam_mns + dx2_pls / lam_pls)
    return heat_conduction(lam, temp_pls - temp_mns, dx2_mns + dx2_pls)
end

#=============================================================================
  熱伝達（ニュートンの冷却則）
=============================================================================#

"""
    heat_transfer(alpha::Float64, dT::Float64) -> Float64

対流熱伝達流束を計算する（ニュートンの冷却則）。

q = -α * ΔT [W/m²]

# Arguments
- `alpha`: 対流熱伝達率 [W/(m²·K)]
- `dT`: 温度差 T_surface - T_air [K]

# Returns
- 熱流束 [W/m²]（正: 空気 → 表面 方向）
"""
heat_transfer(alpha::Float64, dT::Float64) = -alpha * dT

"""
    heat_transfer_diff(alpha::Float64, temp_mns::Float64, temp_pls::Float64) -> Float64

差分法による対流熱伝達流束を計算する。

# Arguments
- `alpha`: 対流熱伝達率 [W/(m²·K)]
- `temp_mns`: マイナス側の温度 [K]
- `temp_pls`: プラス側の温度 [K]

# Returns
- 熱流束 [W/m²]
"""
heat_transfer_diff(alpha::Float64, temp_mns::Float64, temp_pls::Float64) =
    heat_transfer(alpha, temp_pls - temp_mns)

end # module
