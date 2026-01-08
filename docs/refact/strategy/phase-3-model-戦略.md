# Phase 3: modules/model/ 整理戦略

## 概要

Phase 3では、既存のlegacy-juliaコードから**モデル構造体**を整理し、`modules/model/`に配置します。

### 目標

- 構造体定義を整理・簡素化
- 責務の明確な分離（型定義 / IO / 計算）
- 将来の拡張に備えた設計

---

## 分析結果

### 調査したファイル

| ファイル | 行数 | 主な内容 |
|---------|-----|---------|
| `cell.jl` | 316 | Cell構造体、アクセサ関数、収支方程式、CSV入力 |
| `air.jl` | 116 | Air構造体、アクセサ関数、収支方程式 |
| `room.jl` | 142 | Room構造体、アクセサ関数、CSV入力 |
| `wall.jl` | 211 | Wall構造体、アクセサ関数、CSV入力 |
| `opening.jl` | 120 | Opening構造体、アクセサ関数、CSV入力 |
| `climate.jl` | 293 | Climate構造体、データ補間、CSV入力 |
| `boundary_condition.jl` | 178 | BC_Dirichlet/Neumann/Robin、日射計算 |
| `building_network_model.jl` | 73 | BNM構造体、モデル構築 |

**合計: 約1,450行**

### 現状の問題点

```
1. 責務の混在
   └── 各ファイルに構造体定義・アクセサ・計算・IO機能が混在

2. 依存関係の複雑さ
   ├── cell.jl → property_conversion.jl, vapour.jl を include
   ├── air.jl → vapour.jl, lewis_relation.jl を include
   ├── climate.jl → air.jl, solar_radiation.jl を include
   └── 循環的な include が発生しやすい構造

3. 冗長なアクセサ関数
   └── temp(state::Cell), temp(state::Air), temp(state::Room) など
       同名関数が多数存在し、多重ディスパッチが複雑

4. 収支方程式の重複
   └── cal_newtemp が cell.jl と air.jl の両方に存在
       → Phase 2 で physics/balance.jl に移行済み

5. CSV入力関数の分散
   └── input_cell_data, input_room_data 等が各ファイルに散在
       → Phase 6 で io/loader.jl に統合予定
```

---

## 現状の構造体一覧

### Cell（壁体セル）

```julia
Base.@kwdef mutable struct Cell
    # 位置・寸法
    i::Array{Int, 1}      = [1, 1, 1]     # 位置番号
    xyz::Array{Float64,1} = [0.0, 0.0, 0.0] # 位置座標
    dx::Float64  = 1.0    # 幅x
    dy::Float64  = 1.0    # 高さy
    dz::Float64  = 1.0    # 奥行z
    dx2::Float64 = 1.0    # 質点からセル端までの距離
    dy2::Float64 = 1.0
    dz2::Float64 = 1.0

    # 状態量
    temp::Float64 = 0.0   # 温度 [K]
    miu::Float64  = 0.0   # 水分化学ポテンシャル [J/kg]
    rh::Float64   = 0.0   # 相対湿度 [-]（計算値）
    pv::Float64   = 0.0   # 水蒸気圧 [Pa]（計算値）
    phi::Float64  = 0.0   # 含水率 [kg/m³]（計算値）
    p_atm::Float64 = 101325.0  # 大気圧 [Pa]

    # 材料
    material_name::String = "NoName"

    # 流量（計算中間値）
    Q::Array{Array{Float64,1},1}  = [[0.0,0.0,0.0],[0.0,0.0,0.0]]
    Jv::Array{Array{Float64,1},1} = [[0.0,0.0,0.0],[0.0,0.0,0.0]]
    Jl::Array{Array{Float64,1},1} = [[0.0,0.0,0.0],[0.0,0.0,0.0]]
end
```

### Air（室空気）

```julia
Base.@kwdef mutable struct Air
    num::Int      = 0         # 室番号
    name::String  = "NoName"  # 名称
    dx::Float64   = 0.0       # 幅x
    dy::Float64   = 0.0       # 高さy
    dz::Float64   = 0.0       # 奥行z
    vol::Float64  = 0.0       # 体積 [m³]
    temp::Float64 = 0.0       # 温度 [K]
    rh::Float64   = 0.0       # 相対湿度 [-]
    pv::Float64   = 0.0       # 水蒸気圧 [Pa]
    ah::Float64   = 0.0       # 絶対湿度 [kg/kg']
    p_atm::Float64= 101325.0  # 大気圧 [Pa]
    CO2::Float64  = 0.0       # CO2濃度
    pf::Float64   = 0.0       # 床面圧力 [Pa]
    ps::Float64   = 0.0       # 起圧力 [Pa]

    # 熱・水分収支の中間値
    H_in::Float64   = 0.0     # 発熱源による熱流量
    H_wall::Float64 = 0.0     # 壁体からの熱流量
    H_vent::Float64 = 0.0     # 換気による熱流量
    J_in::Float64   = 0.0     # 発湿量
    J_wall::Float64 = 0.0     # 壁体からの水分流量
    J_vent::Float64 = 0.0     # 換気による水分流量
end
```

### Room（室）

```julia
Base.@kwdef mutable struct Room
    num::Int       = 0           # 室番号
    name::String   = "no name"   # 名称
    air::Air       = Air()       # 空気状態
    pf::Float64    = 0.0         # 床面圧力 [Pa]
    ps::Float64    = 0.0         # 起圧力 [Pa]
    Hight::Float64 = 0.0         # 床面高さ [m]
    Qs::Float64    = 0.0         # 発熱量 [W]
    Js::Float64    = 0.0         # 発湿量 [kg/s]
    DWW::Float64   = 0.0         # 正味空気流量 [kg/s]
    AC::String     = "OFF"       # エアコン
end
```

### Wall（壁体）

```julia
Base.@kwdef mutable struct Wall
    num::Int       = 1           # 壁番号
    name::String   = "NoName"
    IP::Int        = 1           # 上流側室番号
    IM::Int        = 1           # 下流側室番号
    ION::Float64   = 0.0         # 壁の向き [°]
    thickness::Float64 = 0.0     # 壁の厚み [m]
    area::Float64  = 0.0         # 壁の面積 [m²]
    K::Float64     = 0.0         # 熱貫流率
    Kp::Float64    = 0.0         # 湿気貫流率

    cell::Array{Cell,1} = [Cell()]  # セル配列
    BC_IP::Union{BC_Dirichlet, BC_Neumann, BC_Robin} = BC_Robin()
    BC_IM::Union{BC_Dirichlet, BC_Neumann, BC_Robin} = BC_Robin()
    target_model::Array = []
end
```

### Opening（開口）

```julia
Base.@kwdef mutable struct Opening
    BC::Int       = 1         # 枝番号
    IP::Int       = 1         # 上流側室番号
    IM::Int       = 1         # 下流側室番号
    Type::String  = "NaN"     # 計算タイプ
    Qup::Float64  = 0.0       # 上流方向流量 [m³/s]
    Qdw::Float64  = 0.0       # 下流方向流量 [m³/s]
    ION::String   = "NaN"     # 壁の向き
    # ... 多数の開口パラメータ

    room_IP::Union{Room, Climate} = Room()
    room_IM::Union{Room, Climate} = Room()
    dP::Float64 = 0.0         # 圧力差
    flux::Dict{String, Float64} = Dict(...)
end
```

### Climate（気象）

```julia
Base.@kwdef mutable struct Climate
    date::DateTime = DateTime(2000, 1, 1, 0, 0, 0)
    location::Dict{String, Any} = Dict(
        "city" => "Kyoto", "lon" => 135.678,
        "phi" => 34.983, "lons" => 135.0)
    air::Air = Air(name = "climate")

    # 気象データ
    Jp::Float64 = 0.0         # 降水量 [mm/h]
    Js::Float64 = 0.0         # 積雪量 [mm/h]
    WS::Float64 = 0.0         # 風速 [m/s]
    WD::String  = "東"        # 風向
    tau::Float64 = 0.0        # 大気透過率
    solar::Dict{String, Float64} = Dict(...)
    rho::Float64 = 0.0        # 地表面日射反射率
    cloudiness::Int = 0       # 雲量

    input_data::DataFrame = DataFrame()
    input_data_type::Array{Symbol,1} = []
    logging_interval::Int = 0
end
```

### 境界条件

```julia
Base.@kwdef mutable struct BC_Dirichlet
    name::String = "NoName"
    cell::Cell   = Cell()
end

Base.@kwdef mutable struct BC_Neumann
    name::String = "NoName"
    q::Float64   = 0.0    # 熱流束
    jv::Float64  = 0.0    # 水蒸気流束
    jl::Float64  = 0.0    # 液水流束
end

Base.@kwdef mutable struct BC_Robin
    name::String = "NoName"
    air::Air     = Air()
    cell::Cell   = Cell()
    q_added::Float64  = 0.0   # 追加熱流
    jv_added::Float64 = 0.0   # 追加水蒸気流
    jl_added::Float64 = 0.0   # 追加液水流
    jl_surf::Float64  = 0.0   # 表面水
    alpha::Float64    = 9.3   # 総合熱伝達率
    alphac::Float64   = 4.9   # 対流熱伝達率
    alphar::Float64   = 4.4   # 放射熱伝達率
    aldm::Float64     = 3.2e-8 # 湿気伝達率
    θ::Dict{String, Float64} = Dict(...)  # 角度情報
    ar::Float64 = 0.0  # 日射吸収率
    er::Float64 = 0.0  # 放射率
end
```

### BNM（ビルディングネットワークモデル）

```julia
Base.@kwdef mutable struct BNM
    rooms::Array{Room, 1}       = []
    walls::Array{Wall, 1}       = []
    openings::Array{Opening, 1} = []
    climate::Climate            = Climate()
    IC_walls::Array{Int}        = []     # 壁インシデンス行列
    IC_openings::Array{Int}     = []     # 開口インシデンス行列
end
```

---

## 新しいディレクトリ構造

```
modules/model/
├── Model.jl                # 統合モジュール
├── types/                  # 型定義
│   ├── cell.jl             # Cell
│   ├── air.jl              # Air
│   ├── room.jl             # Room
│   ├── wall.jl             # Wall
│   ├── opening.jl          # Opening
│   └── climate.jl          # Climate
├── boundary/               # 境界条件
│   └── conditions.jl       # BC_Dirichlet, BC_Neumann, BC_Robin
└── network/                # ネットワークモデル
    └── bnm.jl              # BNM
```

---

## 各ファイルの詳細設計

### types/cell.jl

**役割**: 壁体セルの型定義

```julia
module CellType

export Cell

"""
壁体セル。壁体を構成する最小単位。
"""
Base.@kwdef mutable struct Cell
    # 位置
    index::NTuple{3, Int} = (1, 1, 1)  # 位置番号 (i, j, k)

    # 寸法
    dx::Float64 = 0.0     # x方向厚さ [m]
    dy::Float64 = 1.0     # y方向幅 [m]
    dz::Float64 = 1.0     # z方向高さ [m]
    dx2::Float64 = 0.0    # 質点からセル境界までの距離 [m]

    # 状態量（独立変数）
    temp::Float64 = 293.15  # 温度 [K]
    miu::Float64  = 0.0     # 水分化学ポテンシャル [J/kg]

    # 材料
    material::Symbol = :unknown

    # 計算用中間値
    Q_in::Float64  = 0.0   # 流入熱量 [W/m²]
    Q_out::Float64 = 0.0   # 流出熱量 [W/m²]
    Jw_in::Float64 = 0.0   # 流入水分量 [kg/(m²·s)]
    Jw_out::Float64= 0.0   # 流出水分量 [kg/(m²·s)]
end

# 基本アクセサ
volume(c::Cell) = c.dx * c.dy * c.dz
area_yz(c::Cell) = c.dy * c.dz
area_xz(c::Cell) = c.dx * c.dz
area_xy(c::Cell) = c.dx * c.dy

end # module
```

**変更点**:
- `i::Array{Int,1}` → `index::NTuple{3,Int}` （型安定性向上）
- `material_name::String` → `material::Symbol` （高速比較）
- `Q, Jv, Jl` の3次元配列 → `Q_in, Q_out` 等のスカラー（1次元計算に特化）
- 計算値（rh, pv, phi）はアクセサで動的計算

### types/air.jl

**役割**: 室空気の型定義

```julia
module AirType

export Air

"""
室空気。温湿度・圧力等の状態を保持。
"""
Base.@kwdef mutable struct Air
    # 識別
    name::String = ""

    # 容積
    volume::Float64 = 0.0   # 体積 [m³]

    # 状態量（独立変数）
    temp::Float64 = 293.15  # 温度 [K]
    rh::Float64   = 0.5     # 相対湿度 [-]
    p_atm::Float64= 101325.0 # 大気圧 [Pa]

    # 圧力（換気計算用）
    p_floor::Float64 = 0.0  # 床面圧力 [Pa]

    # 熱・水分収支の蓄積値
    H_wall::Float64 = 0.0   # 壁体からの熱流量 [W]
    H_vent::Float64 = 0.0   # 換気による熱流量 [W]
    H_internal::Float64 = 0.0 # 内部発熱 [W]
    J_wall::Float64 = 0.0   # 壁体からの水分流量 [kg/s]
    J_vent::Float64 = 0.0   # 換気による水分流量 [kg/s]
    J_internal::Float64 = 0.0 # 内部発湿 [kg/s]
end

# 収支値のリセット
function reset_balance!(air::Air)
    air.H_wall = 0.0
    air.H_vent = 0.0
    air.H_internal = 0.0
    air.J_wall = 0.0
    air.J_vent = 0.0
    air.J_internal = 0.0
end

# 収支値の加算
function add_H_wall!(air::Air, H::Float64)
    air.H_wall += H
end

function add_J_wall!(air::Air, J::Float64)
    air.J_wall += J
end

end # module
```

**変更点**:
- `num` を削除（Roomで管理）
- `dx, dy, dz` を削除（`volume`のみ保持）
- `pv, ah` を削除（計算値はアクセサで動的計算）
- `H_in` → `H_internal`（名称明確化）
- `reset_balance!`, `add_*!` 関数を追加

### types/room.jl

**役割**: 室の型定義

```julia
module RoomType

using ..AirType: Air

export Room

"""
室。空気状態と内部発熱・発湿を管理。
"""
Base.@kwdef mutable struct Room
    # 識別
    id::Int = 0
    name::String = ""

    # 空気状態
    air::Air = Air()

    # 位置
    floor_height::Float64 = 0.0  # 床面高さ [m]

    # 内部負荷
    Q_internal::Float64 = 0.0  # 内部発熱 [W]
    J_internal::Float64 = 0.0  # 内部発湿 [kg/s]

    # 空調
    hvac_mode::Symbol = :off  # :off, :cooling, :heating, :auto
end

# 委譲アクセサ
temp(r::Room) = r.air.temp
rh(r::Room) = r.air.rh
volume(r::Room) = r.air.volume

end # module
```

**変更点**:
- `Qs, Js` → `Q_internal, J_internal`（命名統一）
- `AC::String` → `hvac_mode::Symbol`（型安全）
- `pf, ps, DWW` を削除（Airまたは計算で管理）
- 委譲アクセサを簡素化

### types/wall.jl

**役割**: 壁体の型定義

```julia
module WallType

using ..CellType: Cell

export Wall

"""
壁体。複数のセルで構成される。
"""
Base.@kwdef mutable struct Wall
    # 識別
    id::Int = 0
    name::String = ""

    # 接続情報
    room_id_plus::Int = 0   # プラス側室ID（IP）
    room_id_minus::Int = 0  # マイナス側室ID（IM）

    # 形状
    orientation::Float64 = 0.0  # 壁の向き [°]（0:水平, 90:垂直）
    area::Float64 = 0.0         # 面積 [m²]

    # セル配列
    cells::Vector{Cell} = Cell[]

    # 境界条件（solver側で設定）
    # BC_plus, BC_minus は別途管理
end

# アクセサ
thickness(w::Wall) = sum(c.dx for c in w.cells)
n_cells(w::Wall) = length(w.cells)

end # module
```

**変更点**:
- `IP, IM` → `room_id_plus, room_id_minus`（命名明確化）
- `ION` → `orientation`（命名明確化）
- `BC_IP, BC_IM` を削除（solver側で管理）
- `target_model` を削除（不要）
- `K, Kp` を削除（計算値）

### types/opening.jl

**役割**: 開口部の型定義

```julia
module OpeningType

export Opening, OpeningType

"""開口のタイプ"""
@enum OpeningKind begin
    gap       # 隙間
    window    # 開口
    constant  # 換気量固定
    fan       # 換気ファン
end

"""
開口部。換気経路を表現。
"""
Base.@kwdef mutable struct Opening
    # 識別
    id::Int = 0
    kind::OpeningKind = gap

    # 接続
    room_id_plus::Int = 0
    room_id_minus::Int = 0

    # 形状
    width::Float64 = 0.0      # 開口幅 [m]
    height_top::Float64 = 0.0 # 上端高さ [m]
    height_bottom::Float64 = 0.0 # 下端高さ [m]
    area::Float64 = 0.0       # 開口面積 [m²]

    # 流量特性
    flow_coefficient::Float64 = 0.0  # 流量係数 α
    gap_characteristic::Float64 = 0.0 # 隙間特性値 M

    # 固定流量（constant/fanタイプ用）
    Q_plus::Float64 = 0.0   # プラス方向流量 [m³/s]
    Q_minus::Float64 = 0.0  # マイナス方向流量 [m³/s]

    # 風圧係数
    wind_pressure_plus::Float64 = 0.0
    wind_pressure_minus::Float64 = 0.0

    # 計算値
    delta_p::Float64 = 0.0  # 圧力差 [Pa]
    mass_flow::Float64 = 0.0 # 質量流量 [kg/s]
end

height(o::Opening) = o.height_top - o.height_bottom

end # module
```

**変更点**:
- `Type::String` → `kind::OpeningKind`（enum化）
- `IP, IM` → `room_id_plus, room_id_minus`
- 多数のパラメータを整理・命名統一
- `room_IP, room_IM` を削除（IDで参照）
- `flux::Dict` → スカラー値

### types/climate.jl

**役割**: 気象条件の型定義

```julia
module ClimateType

using Dates
using ..AirType: Air

export Climate, Location

"""地点情報"""
struct Location
    name::String
    latitude::Float64   # 緯度 [°]
    longitude::Float64  # 経度 [°]
    timezone_longitude::Float64  # 標準時経度 [°]
end

"""
気象条件。外気状態と日射等を管理。
"""
Base.@kwdef mutable struct Climate
    # 時刻
    datetime::DateTime = DateTime(2000, 1, 1)

    # 地点
    location::Location = Location("", 0.0, 0.0, 0.0)

    # 外気状態
    air::Air = Air(name="outdoor")

    # 気象要素
    precipitation::Float64 = 0.0  # 降水量 [mm/h]
    wind_speed::Float64 = 0.0     # 風速 [m/s]
    wind_direction::Float64 = 0.0 # 風向 [°]（北=0）
    cloud_cover::Int = 0          # 雲量 [0-10]

    # 日射
    atmospheric_transmittance::Float64 = 0.0  # 大気透過率 [-]
    direct_normal_irradiance::Float64 = 0.0   # 法線面直達日射量 [W/m²]
    diffuse_horizontal_irradiance::Float64 = 0.0 # 水平面天空日射量 [W/m²]
    solar_altitude::Float64 = 0.0  # 太陽高度 [°]
    solar_azimuth::Float64 = 0.0   # 太陽方位角 [°]

    # 地表面
    ground_reflectance::Float64 = 0.0  # 地表面反射率 [-]
end

# アクセサ（Airへの委譲）
temp(c::Climate) = c.air.temp
rh(c::Climate) = c.air.rh

end # module
```

**変更点**:
- `location::Dict` → `Location` 構造体
- `date` → `datetime`
- `Jp` → `precipitation`
- `WS, WD` → `wind_speed, wind_direction`
- `solar::Dict` → 個別フィールド
- `input_data, input_data_type, logging_interval` を削除（IO側で管理）

### boundary/conditions.jl

**役割**: 境界条件の型定義

```julia
module BoundaryConditions

using ..CellType: Cell
using ..AirType: Air

export AbstractBoundaryCondition
export BCDirichlet, BCNeumann, BCRobin

"""境界条件の抽象型"""
abstract type AbstractBoundaryCondition end

"""
第一種境界条件（ディリクレ）。
温度・水分ポテンシャルを固定。
"""
struct BCDirichlet <: AbstractBoundaryCondition
    temp::Float64   # 固定温度 [K]
    miu::Float64    # 固定水分化学ポテンシャル [J/kg]
end

"""
第二種境界条件（ノイマン）。
熱・水分流束を指定。
"""
struct BCNeumann <: AbstractBoundaryCondition
    q::Float64    # 熱流束 [W/m²]
    jv::Float64   # 水蒸気流束 [kg/(m²·s)]
    jl::Float64   # 液水流束 [kg/(m²·s)]
end

BCNeumann() = BCNeumann(0.0, 0.0, 0.0)

"""
第三種境界条件（ロビン）。
対流伝達を考慮。
"""
Base.@kwdef mutable struct BCRobin <: AbstractBoundaryCondition
    # 参照先（Air参照はsolver側で管理）
    air_temp::Float64 = 293.15
    air_rh::Float64 = 0.5

    # 伝達係数
    alpha_conv::Float64 = 4.9   # 対流熱伝達率 [W/(m²·K)]
    alpha_rad::Float64 = 4.4    # 放射熱伝達率 [W/(m²·K)]
    alpha_moisture::Float64 = 3.2e-8  # 湿気伝達率 [kg/(m²·s·Pa)]

    # 壁面方位
    azimuth::Float64 = 0.0      # 方位角 [°]
    elevation::Float64 = 90.0   # 仰角 [°]（90=垂直壁）

    # 日射特性
    absorptance::Float64 = 0.0  # 日射吸収率 [-]
    emissivity::Float64 = 0.0   # 放射率 [-]

    # 追加流束（日射・降雨等）
    q_added::Float64 = 0.0
    jv_added::Float64 = 0.0
    jl_added::Float64 = 0.0
end

# 総合熱伝達率
alpha_total(bc::BCRobin) = bc.alpha_conv + bc.alpha_rad

end # module
```

**変更点**:
- 抽象型 `AbstractBoundaryCondition` を導入
- `BC_*` → `BC*`（アンダースコア削除）
- `alphac, alphar` → `alpha_conv, alpha_rad`
- `θ::Dict` → `azimuth, elevation`
- `ar, er` → `absorptance, emissivity`
- `air::Air, cell::Cell` を削除（参照はsolver側で管理）
- immutable化（BCDirichlet, BCNeumann）

### network/bnm.jl

**役割**: ビルディングネットワークモデル

```julia
module NetworkModel

using ..RoomType: Room
using ..WallType: Wall
using ..OpeningType: Opening
using ..ClimateType: Climate

export BuildingNetwork

"""
ビルディングネットワークモデル。
室・壁・開口・気象のネットワーク構造を保持。
"""
struct BuildingNetwork
    # 構成要素
    rooms::Vector{Room}
    walls::Vector{Wall}
    openings::Vector{Opening}
    climate::Climate

    # インシデンス行列
    wall_incidence::Matrix{Int}     # 室×壁
    opening_incidence::Matrix{Int}  # 室×開口
end

# コンストラクタ
function BuildingNetwork(rooms, walls, openings, climate)
    n_rooms = length(rooms)
    n_walls = length(walls)
    n_openings = length(openings)

    # 壁のインシデンス行列
    wall_inc = zeros(Int, n_rooms, n_walls)
    for (j, w) in enumerate(walls)
        if w.room_id_plus > 0
            wall_inc[w.room_id_plus, j] = 1
        end
        if w.room_id_minus > 0
            wall_inc[w.room_id_minus, j] = -1
        end
    end

    # 開口のインシデンス行列
    opening_inc = zeros(Int, n_rooms, n_openings)
    for (j, o) in enumerate(openings)
        if o.room_id_plus > 0
            opening_inc[o.room_id_plus, j] = 1
        end
        if o.room_id_minus > 0
            opening_inc[o.room_id_minus, j] = -1
        end
    end

    return BuildingNetwork(rooms, walls, openings, climate,
                          wall_inc, opening_inc)
end

# アクセサ
n_rooms(bn::BuildingNetwork) = length(bn.rooms)
n_walls(bn::BuildingNetwork) = length(bn.walls)
n_openings(bn::BuildingNetwork) = length(bn.openings)

end # module
```

**変更点**:
- `BNM` → `BuildingNetwork`（略語を避ける）
- `IC_walls` → `wall_incidence`
- immutable化（構成要素は変更されない）
- インシデンス行列の構築をコンストラクタに内包

---

## 移行しないもの（別Phaseで対応）

### Phase 4（solver/）へ移行

- `cal_newtemp`, `cal_newmiu` 等の収支計算（多重ディスパッチ版）
- `cal_energy_balance`, `cal_moisture_balance`
- 熱物性取得関数（`lam(cell)`, `dp(cell)` 等）

### Phase 6（io/）へ移行

- `input_cell_data`
- `input_room_data`
- `input_wall_data`
- `input_opening_data`
- `input_climate_data`
- `reset_climate_data`
- データ補間関数

### 削除

- 重複するアクセサ関数（多くは不要）
- `set_*` 関数（直接アクセスで代替）
- `add_*` 関数（一部を残して整理）

---

## 移行マッピング

| 移行元（legacy-julia） | 移行先（legacy-julia-refact） |
|----------------------|------------------------------|
| cell.jl（struct部分） | types/cell.jl |
| cell.jl（IO部分） | io/loader.jl（Phase 6） |
| cell.jl（計算部分） | solver/（Phase 4） |
| air.jl（struct部分） | types/air.jl |
| air.jl（計算部分） | solver/（Phase 4） |
| room.jl（struct部分） | types/room.jl |
| room.jl（IO部分） | io/loader.jl（Phase 6） |
| wall.jl（struct部分） | types/wall.jl |
| wall.jl（IO部分） | io/loader.jl（Phase 6） |
| opening.jl（struct部分） | types/opening.jl |
| opening.jl（IO部分） | io/loader.jl（Phase 6） |
| climate.jl（struct部分） | types/climate.jl |
| climate.jl（IO部分） | io/loader.jl（Phase 6） |
| climate.jl（補間部分） | io/loader.jl（Phase 6） |
| boundary_condition.jl（struct部分） | boundary/conditions.jl |
| boundary_condition.jl（日射計算） | solver/solar.jl（Phase 4） |
| building_network_model.jl | network/bnm.jl |

---

## 行数見積もり

| ファイル | 推定行数 |
|---------|--------|
| Model.jl | 50 |
| types/cell.jl | 50 |
| types/air.jl | 60 |
| types/room.jl | 40 |
| types/wall.jl | 40 |
| types/opening.jl | 60 |
| types/climate.jl | 70 |
| boundary/conditions.jl | 80 |
| network/bnm.jl | 60 |
| **合計** | **約510行** |

※ 元の関連コード約1,450行から型定義のみを抽出・整理

---

## 依存関係

```
types/cell.jl
    ↓
types/air.jl
    ↓
types/room.jl ─────────────┐
    ↓                      │
types/wall.jl ────────────┼─→ network/bnm.jl
    ↓                      │
types/opening.jl ──────────┤
    ↓                      │
types/climate.jl ──────────┘
    ↓
boundary/conditions.jl
```

---

## 設計原則

1. **型定義のみ**: 計算ロジックは含めない
2. **immutable優先**: 変更が不要な構造体は`struct`
3. **Symbol活用**: 文字列比較を避ける（`:concrete` vs `"concrete"`）
4. **委譲よりも合成**: RoomはAirを持つが、過度な委譲は避ける
5. **計算値は動的に**: `rh`, `pv`, `phi` 等はアクセサで計算

---

## 完了条件

- [ ] 9つのファイルが作成されている
- [ ] 全ての構造体がエクスポートされている
- [ ] 計算ロジックが含まれていない
- [ ] IOコードが含まれていない
- [ ] 型が安定している（Any型を避ける）

---

作成日: 2024年12月26日
