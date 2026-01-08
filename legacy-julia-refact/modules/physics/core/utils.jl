"""
    PhysicsUtils

物理計算ユーティリティモジュール。
抵抗値の合成、ルイス関係式などの共通関数を提供。

移行元:
- legacy-julia/module/transfer_in_media.jl
- legacy-julia/module/function/lewis_relation.jl
"""
module PhysicsUtils

using ..PhysicsConstants: LEWIS_NUMBER, C_DRY_AIR, R_VAPOR

export harmonic_mean, weighted_mean
export transmittance
export lewis_aldm

#=============================================================================
  抵抗値の合成
=============================================================================#

"""
    harmonic_mean(;
        val_mns::Float64, val_pls::Float64,
        len_mns::Float64, len_pls::Float64
    ) -> Float64

抵抗の調和平均（直列抵抗の合成）を計算する。

λ_eff = (L₁ + L₂) / (L₁/λ₁ + L₂/λ₂)

# Arguments
- `val_mns`: マイナス側の伝導率
- `val_pls`: プラス側の伝導率
- `len_mns`: マイナス側の長さ
- `len_pls`: プラス側の長さ

# Returns
- 合成伝導率

# Note
熱伝導率、透湿率、液水伝導率など、
直列に並んだ抵抗を合成する際に使用。
"""
function harmonic_mean(;
    val_mns::Float64, val_pls::Float64,
    len_mns::Float64, len_pls::Float64)

    return (len_mns + len_pls) / (len_mns / val_mns + len_pls / val_pls)
end

"""
    weighted_mean(;
        val_mns::Float64, val_pls::Float64,
        len_mns::Float64, len_pls::Float64
    ) -> Float64

加重平均を計算する。

val_avg = (val₁ * L₁ + val₂ * L₂) / (L₁ + L₂)

# Arguments
- `val_mns`: マイナス側の値
- `val_pls`: プラス側の値
- `len_mns`: マイナス側の長さ（重み）
- `len_pls`: プラス側の長さ（重み）

# Returns
- 加重平均値
"""
function weighted_mean(;
    val_mns::Float64, val_pls::Float64,
    len_mns::Float64, len_pls::Float64)

    return (val_mns * len_mns + val_pls * len_pls) / (len_mns + len_pls)
end

#=============================================================================
  貫流係数
=============================================================================#

"""
    transmittance(;
        alpha::Float64,
        lam::Float64,
        dx2::Float64
    ) -> Float64

貫流係数を計算する（表面伝達 + 材料内伝導の直列抵抗）。

U = 1 / (1/α + dx/(2λ))

# Arguments
- `alpha`: 表面伝達率 [W/(m²·K)] or [kg/(m²·s·Pa)]
- `lam`: 伝導率 [W/(m·K)] or [kg/(m·s·Pa)]
- `dx2`: 質点から表面までの距離（セル半厚さ）[m]

# Returns
- 貫流係数

# Note
境界条件（BC_Robin）での熱・水蒸気流束計算に使用。
"""
function transmittance(;
    alpha::Float64,
    lam::Float64,
    dx2::Float64)

    return 1.0 / (1.0 / alpha + dx2 / lam)
end

#=============================================================================
  ルイス関係式
=============================================================================#

"""
    lewis_aldm(;
        alpha::Float64,
        temp::Float64,
        rho::Float64=1.293
    ) -> Float64

ルイス関係式により湿気伝達率を計算する。

α'dm = α / (Le * cp * ρ * Rv * T)

# Arguments
- `alpha`: 対流熱伝達率 [W/(m²·K)]
- `temp`: 温度 [K]
- `rho`: 空気密度 [kg/m³]（デフォルト: 1.293）

# Returns
- 湿気伝達率 [kg/(m²·s·Pa)]

# Note
ルイス数 Le ≈ 1 の場合、熱と物質の類推関係から
湿気伝達率を熱伝達率から推定できる。
"""
function lewis_aldm(;
    alpha::Float64,
    temp::Float64,
    rho::Float64=1.293)

    return alpha / (LEWIS_NUMBER * C_DRY_AIR * rho * R_VAPOR * temp)
end

end # module
