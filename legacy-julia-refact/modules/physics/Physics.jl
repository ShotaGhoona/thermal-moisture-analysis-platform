"""
    Physics

物理法則モジュール群。
熱・水分移動計算で使用する純粋な物理計算関数を提供。

## サブモジュール

- `PhysicsConstants`: 物理定数
- `PhysicsUtils`: ユーティリティ関数
- `Psychrometrics`: 湿り空気の物性
- `HeatTransfer`: 熱移動（伝導・伝達）
- `VaporTransfer`: 水蒸気移動
- `LiquidTransfer`: 液水移動
- `BalanceEquation`: 収支方程式

## 使用例

```julia
include("modules/physics/Physics.jl")
using .Physics

# 飽和水蒸気圧
pvs = Psychrometrics.cal_Pvs(293.15)  # 20℃

# 熱伝導
q = HeatTransfer.heat_conduction(1.6, 10.0, 0.1)

# ルイス関係式
aldm = PhysicsUtils.lewis_aldm(alpha=9.0, temp=293.15)
```

## 設計方針

1. 構造体（Cell, Air, BC_Robin等）に依存しない純粋関数
2. 全て Float64 の引数・戻り値
3. 単体テスト可能
4. 物理的意味の明確なドキュメント

移行元: legacy-julia/module/
"""
module Physics

#=============================================================================
  core/ - 基盤モジュール
=============================================================================#

# 物理定数（他のモジュールの基盤）
include("core/constants.jl")
using .PhysicsConstants

# ユーティリティ関数
include("core/utils.jl")
using .PhysicsUtils

#=============================================================================
  properties/ - 物性計算
=============================================================================#

# 湿り空気の物性
include("properties/psychrometrics.jl")
using .Psychrometrics

#=============================================================================
  flux/ - 流量計算
=============================================================================#

# 熱移動
include("flux/heat.jl")
using .HeatTransfer

# 水蒸気移動
include("flux/vapor.jl")
using .VaporTransfer

# 液水移動
include("flux/liquid.jl")
using .LiquidTransfer

#=============================================================================
  balance/ - 収支方程式
=============================================================================#

# 収支方程式
include("balance/balance.jl")
using .BalanceEquation

#=============================================================================
  エクスポート
=============================================================================#

# 全サブモジュールをエクスポート
export PhysicsConstants
export PhysicsUtils
export Psychrometrics
export HeatTransfer
export VaporTransfer
export LiquidTransfer
export BalanceEquation

end # module
