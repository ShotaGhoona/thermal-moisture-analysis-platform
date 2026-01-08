"""
    Solver

計算エンジン統合モジュール。
熱・水分移動シミュレーションの計算エンジンを提供。

## サブモジュール

### flux/ - 流量計算
- `WallFlux`: 壁体を通じた熱・水分流量
- `VentilationFlux`: 換気による熱・水分流量

### balance/ - 収支・更新
- `CellUpdater`: 壁体セルの状態更新
- `AirUpdater`: 室空気の状態更新

### control/ - 制御
- `Condensation`: 結露判定・処理
- `Stepper`: 時間ステップ制御

## 使用例

```julia
include("modules/model/Model.jl")
include("modules/physics/Physics.jl")
include("modules/solver/Solver.jl")

using .Model
using .Physics
using .Solver

# 1タイムステップの計算
results = step!(network, 0.1)  # dt = 0.1 hour

# 複数ステップ実行
run_steps!(network, 0.1, 8760)  # 1年分
```

## 設計方針

1. **Model依存**: 構造体はModelから取得
2. **Physics利用**: 純粋な物理計算はPhysicsから呼び出し
3. **可換性**: サブモジュールは独立にテスト可能
4. **拡張性**: 新しい計算手法を追加しやすい構造

移行元: legacy-julia/module/, legacy-julia/run/
"""
module Solver

# 依存モジュールのロード確認
# Physics と Model が先にロードされている必要がある

#=============================================================================
  flux/ - 流量計算
=============================================================================#

# 壁体流量
include("flux/wall_flux.jl")
using .WallFlux

# 換気流量
include("flux/ventilation_flux.jl")
using .VentilationFlux

#=============================================================================
  balance/ - 収支・更新
=============================================================================#

# セル状態更新
include("balance/cell_updater.jl")
using .CellUpdater

# 空気状態更新
include("balance/air_updater.jl")
using .AirUpdater

#=============================================================================
  control/ - 制御
=============================================================================#

# 結露判定
include("control/condensation.jl")
using .Condensation

# 時間ステップ制御
include("control/stepper.jl")
using .Stepper

#=============================================================================
  エクスポート
=============================================================================#

# サブモジュールをエクスポート
export WallFlux
export VentilationFlux
export CellUpdater
export AirUpdater
export Condensation
export Stepper

# 主要な関数を直接エクスポート（利便性のため）

# WallFlux
export flux_heat, flux_vapor, flux_liquid
export calculate_wall_flux!

# VentilationFlux
export calculate_ventilation_flux!
export ventilation_heat_flux, ventilation_moisture_flux

# CellUpdater
export update_cell!, update_wall_cells!
export cell_crow, cell_dphi

# AirUpdater
export update_air!, update_room_air!
export ah_from_rh, rh_from_ah

# Condensation
export check_condensation!, is_condensing
export CondensationResult

# Stepper
export step!, reset_all_flux!
export run_steps!
export check_cfl_condition, estimate_stable_dt

end # module
