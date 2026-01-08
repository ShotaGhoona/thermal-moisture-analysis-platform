"""
    Model

モデル構造体モジュール群。
熱・水分移動シミュレーションで使用する構造体を提供。

## サブモジュール

### types/ - 基本型定義
- `CellType`: 壁体セル
- `AirType`: 室空気
- `RoomType`: 室
- `WallType`: 壁体
- `OpeningType`: 開口部
- `ClimateType`: 気象条件

### boundary/ - 境界条件
- `BoundaryConditions`: 3種類の境界条件

### network/ - ネットワークモデル
- `NetworkModel`: ビルディングネットワークモデル

## 使用例

```julia
include("modules/model/Model.jl")
using .Model

# セルの作成
cell = CellType.Cell(
    dx = 0.01,
    temp = 293.15,
    material = :concrete
)

# 室の作成
room = RoomType.Room(
    id = 1,
    name = "居室",
    air = AirType.Air(volume = 30.0)
)

# 境界条件の作成
bc = BoundaryConditions.BCRobin(
    alpha_conv = 9.0,
    absorptance = 0.7
)
```

## 設計方針

1. **型定義のみ**: 計算ロジックは含めない（solver/へ）
2. **immutable優先**: 変更が不要な構造体は`struct`
3. **Symbol活用**: 材料名等は`:concrete`のようにSymbol
4. **計算値は動的に**: rh, pv等はアクセサで計算

移行元: legacy-julia/module/
"""
module Model

#=============================================================================
  types/ - 基本型定義
=============================================================================#

# Cell（依存なし）
include("types/cell.jl")
using .CellType

# Air（依存なし）
include("types/air.jl")
using .AirType

# Room（Airに依存）
include("types/room.jl")
using .RoomType

# Wall（Cellに依存）
include("types/wall.jl")
using .WallType

# Opening（依存なし）
include("types/opening.jl")
using .OpeningType

# Climate（Airに依存）
include("types/climate.jl")
using .ClimateType

#=============================================================================
  boundary/ - 境界条件
=============================================================================#

include("boundary/conditions.jl")
using .BoundaryConditions

#=============================================================================
  network/ - ネットワークモデル
=============================================================================#

include("network/bnm.jl")
using .NetworkModel

#=============================================================================
  エクスポート
=============================================================================#

# 全サブモジュールをエクスポート
export CellType
export AirType
export RoomType
export WallType
export OpeningType
export ClimateType
export BoundaryConditions
export NetworkModel

# 主要な型を直接エクスポート（利便性のため）
export Cell, Air, Room, Wall, Opening, Climate, Location
export OpeningKind, gap, window, constant, fan
export AbstractBoundaryCondition, BCDirichlet, BCNeumann, BCRobin
export BuildingNetwork

# Cellのエクスポート
using .CellType: Cell, volume, area_yz

# Airのエクスポート
using .AirType: Air, reset_balance!, add_H_wall!, add_J_wall!

# Roomのエクスポート
using .RoomType: Room

# Wallのエクスポート
using .WallType: Wall, thickness, n_cells

# Openingのエクスポート
using .OpeningType: Opening, OpeningKind, gap, window, constant, fan, height

# Climateのエクスポート
using .ClimateType: Climate, Location

# BoundaryConditionsのエクスポート
using .BoundaryConditions: AbstractBoundaryCondition,
                           BCDirichlet, BCNeumann, BCRobin,
                           alpha_total

# NetworkModelのエクスポート
using .NetworkModel: BuildingNetwork, n_rooms, n_walls, n_openings

end # module
