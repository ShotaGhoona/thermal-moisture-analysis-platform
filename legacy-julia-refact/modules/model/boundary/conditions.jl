"""
    BoundaryConditions

境界条件の型定義モジュール。
壁体境界の3種類の境界条件を提供。

移行元: legacy-julia/module/boundary_condition.jl（struct部分のみ）
"""
module BoundaryConditions

export AbstractBoundaryCondition
export BCDirichlet, BCNeumann, BCRobin
export alpha_total

"""
    AbstractBoundaryCondition

境界条件の抽象型。
BCDirichlet, BCNeumann, BCRobin の親型。
"""
abstract type AbstractBoundaryCondition end

#=============================================================================
  第一種境界条件（ディリクレ）
=============================================================================#

"""
    BCDirichlet

第一種境界条件（ディリクレ条件）。
温度・水分ポテンシャルを固定値で指定。

# フィールド
- `temp`: 固定温度 [K]
- `miu`: 固定水分化学ポテンシャル [J/kg]
"""
struct BCDirichlet <: AbstractBoundaryCondition
    temp::Float64   # 固定温度 [K]
    miu::Float64    # 固定水分化学ポテンシャル [J/kg]
end

# デフォルトコンストラクタ
BCDirichlet() = BCDirichlet(293.15, 0.0)

#=============================================================================
  第二種境界条件（ノイマン）
=============================================================================#

"""
    BCNeumann

第二種境界条件（ノイマン条件）。
熱・水分流束を指定。

# フィールド
- `q`: 熱流束 [W/m²]
- `jv`: 水蒸気流束 [kg/(m²·s)]
- `jl`: 液水流束 [kg/(m²·s)]
"""
struct BCNeumann <: AbstractBoundaryCondition
    q::Float64    # 熱流束 [W/m²]
    jv::Float64   # 水蒸気流束 [kg/(m²·s)]
    jl::Float64   # 液水流束 [kg/(m²·s)]
end

# デフォルトコンストラクタ（断熱・不透湿）
BCNeumann() = BCNeumann(0.0, 0.0, 0.0)

#=============================================================================
  第三種境界条件（ロビン）
=============================================================================#

"""
    BCRobin

第三種境界条件（ロビン条件）。
対流伝達を考慮した境界条件。

# フィールド
## 参照状態
- `air_temp`: 参照空気温度 [K]
- `air_rh`: 参照空気相対湿度 [-]

## 伝達係数
- `alpha_conv`: 対流熱伝達率 [W/(m²·K)]
- `alpha_rad`: 放射熱伝達率 [W/(m²·K)]
- `alpha_moisture`: 湿気伝達率 [kg/(m²·s·Pa)]

## 壁面方位
- `azimuth`: 方位角 [°]（南=0, 東=90）
- `elevation`: 仰角 [°]（90=垂直壁, 0=水平面）

## 日射特性
- `absorptance`: 日射吸収率 [-]
- `emissivity`: 放射率 [-]

## 追加流束
- `q_added`: 追加熱流束 [W/m²]（日射等）
- `jv_added`: 追加水蒸気流束 [kg/(m²·s)]
- `jl_added`: 追加液水流束 [kg/(m²·s)]（降雨等）
"""
Base.@kwdef mutable struct BCRobin <: AbstractBoundaryCondition
    # 参照状態（solver側で動的に更新）
    air_temp::Float64 = 293.15
    air_rh::Float64 = 0.5

    # 伝達係数
    alpha_conv::Float64 = 4.9       # 対流熱伝達率 [W/(m²·K)]
    alpha_rad::Float64 = 4.4        # 放射熱伝達率 [W/(m²·K)]
    alpha_moisture::Float64 = 3.2e-8 # 湿気伝達率 [kg/(m²·s·Pa)]

    # 壁面方位
    azimuth::Float64 = 0.0      # 方位角 [°]
    elevation::Float64 = 90.0   # 仰角 [°]（90=垂直壁）

    # 日射特性
    absorptance::Float64 = 0.0  # 日射吸収率 [-]
    emissivity::Float64 = 0.0   # 放射率 [-]

    # 追加流束（日射・降雨等、solver側で計算・設定）
    q_added::Float64 = 0.0
    jv_added::Float64 = 0.0
    jl_added::Float64 = 0.0
end

#=============================================================================
  アクセサ関数
=============================================================================#

"""総合熱伝達率 [W/(m²·K)]"""
alpha_total(bc::BCRobin) = bc.alpha_conv + bc.alpha_rad

"""追加流束をリセット"""
function reset_added_flux!(bc::BCRobin)
    bc.q_added = 0.0
    bc.jv_added = 0.0
    bc.jl_added = 0.0
end

end # module
