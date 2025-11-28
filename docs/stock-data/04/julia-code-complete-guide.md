# Julia熱水分同時移動シミュレーション 完全解説

このドキュメントは、卒論で記述した内容と実際のJuliaコードの対応関係を完全に理解するための解説書です。

---

## 目次

1. [プログラム全体構成](#1-プログラム全体構成)
2. [データ構造の詳細](#2-データ構造の詳細)
3. [支配方程式とコードの対応](#3-支配方程式とコードの対応)
4. [物性値変換システム](#4-物性値変換システム)
5. [境界条件の実装](#5-境界条件の実装)
6. [メイン計算ループ](#6-メイン計算ループ)
7. [入出力処理](#7-入出力処理)

---

## 1. プログラム全体構成

### 1.1 ファイル構成

```
legacy-julia/
├── run/
│   └── main.jl                    # メイン実行ファイル
│   └── logger.jl                  # ログ出力
├── module/
│   ├── building_network_model.jl  # BNM構造体とモデル構築
│   ├── transfer_in_media.jl       # 熱・水分移動計算（核心部分）
│   ├── cell.jl                    # セル（計算格子点）構造体
│   ├── wall.jl                    # 壁体構造体
│   ├── room.jl                    # 室構造体
│   ├── air.jl                     # 空気構造体
│   ├── opening.jl                 # 開口部構造体
│   ├── climate.jl                 # 外気条件構造体
│   ├── boundary_condition.jl      # 境界条件構造体
│   ├── property_conversion.jl     # 材料物性変換
│   ├── solar_radiation.jl         # 日射量計算
│   ├── flux_ventilation.jl        # 換気流量計算（詳細版）
│   └── function/
│       ├── vapour.jl              # 水蒸気関連の物性変換
│       ├── lewis_relation.jl      # ルイスの関係式
│       └── flux_and_balance_equation.jl  # 流量・収支式
├── material_property/             # 各材料の物性定義
│   ├── glass_wool_16K.jl
│   ├── plywood.jl
│   ├── concrete_goran.jl
│   └── ... (約25種類)
└── input_data/                    # 入力データ（CSV）
```

### 1.2 プログラムの実行フロー

```
main.jl
  │
  ├─→ building_network_model.jl読み込み
  │     └─→ room.jl, wall.jl, opening.jl, climate.jl を読み込み
  │           └─→ cell.jl, air.jl, boundary_condition.jl を読み込み
  │                 └─→ property_conversion.jl, vapour.jl を読み込み
  │
  ├─→ transfer_in_media.jl読み込み
  │     └─→ 熱・水分流量計算関数を定義
  │
  ├─→ create_BNM_model()でモデル構築
  │     ├─→ CSVファイルから室・壁・開口・気象データ読み込み
  │     └─→ 各構造体間の参照をリンク
  │
  └─→ 計算ループ
        ├─→ reset_climate_data(): 気象データ更新
        ├─→ cal_network_flux_of_wall(): 壁体流量計算
        ├─→ cal_network_flux_of_ventilation(): 換気流量計算
        ├─→ cal_new_value_ver_network(): 収支計算・状態更新
        └─→ time_elapses(): 時間経過
```

---

## 2. データ構造の詳細

### 2.1 BNM（Building Network Model）構造体

**卒論の記述：**
> BNMは建物全体を表す最上位の構造体であり、rooms, walls, openings, climate, IC_walls, IC_openings を保持する。

**コード（building_network_model.jl:9-16）：**

```julia
Base.@kwdef mutable struct BNM
    rooms::Array{Room, 1}       = []  # 室内空間の配列
    walls::Array{Wall, 1}       = []  # 壁体の配列
    openings::Array{Opening, 1} = []  # 開口部の配列
    climate::Climate            = []  # 外気条件
    IC_walls::Array{Int}        = []  # 壁体インシデンス行列
    IC_openings::Array{Int}     = []  # 開口インシデンス行列
end
```

**解説：**
- `Base.@kwdef` はJuliaのマクロで、キーワード引数によるコンストラクタを自動生成
- `mutable struct` は変更可能な構造体を定義（計算中に値が更新されるため）
- `rooms[1]` は常に外気（Climate）のair情報とリンクされる（後述）

**モデル構築処理（building_network_model.jl:18-73）：**

```julia
function create_BNM_model(;file_name_rooms::String, ...)
    # 1. CSVファイルからデータ読み込み
    climate  = input_climate_data(file_name_climate, header_climate)
    rooms    = input_room_data(file_name_rooms, header_room)
    walls    = input_wall_data(file_name_walls, header_wall)
    openings = input_opening_data(file_name_openings, header_opening)

    # 2. rooms[1]を外気とリンク（重要！）
    rooms[1].air = climate.air

    # 3. 壁体の境界条件と室空気をリンク
    for i = 1 : length(walls)
        walls[i].BC_IP.air = rooms[walls[i].IP].air  # 上流側
        walls[i].BC_IM.air = rooms[walls[i].IM].air  # 下流側
    end

    # 4. 開口部と室をリンク
    for i = 1 : length(openings)
        openings[i].room_IP = rooms[openings[i].IP]
        openings[i].room_IM = rooms[openings[i].IM]
    end

    # 5. インシデンス行列作成
    # +1: 流入、-1: 流出を表す
    IC_walls = zeros(length(rooms), length(walls))
    for i = 1 : length(walls)
        IC_walls[walls[i].IP, i] = +1.0
        IC_walls[walls[i].IM, i] = -1.0
    end
    ...
end
```

**ポイント：**
- `rooms[1].air = climate.air` により、外気と室配列の1番目が同じAir構造体を参照
- これにより、壁体のBC_IPが`IP=1`のとき、自動的に外気条件が参照される

---

### 2.2 Room（室）構造体

**卒論の記述：**
> 室空間を表す構造体であり、num, name, air, vol, Qs, Js, H_wall, H_vent, J_wall, J_vent を持つ。

**コード（room.jl:3-12）：**

```julia
Base.@kwdef mutable struct Room
    num::Int                    = 0       # 室番号
    name::String                = ""      # 室の名称
    air::Air                    = Air()   # 室内空気状態（Air構造体を参照）
    Qs::Float64                 = 0.0     # 室内発熱量 [W]
    Js::Float64                 = 0.0     # 室内発湿量 [kg/s]
end
```

**Air構造体（air.jl:3-18）：**

```julia
Base.@kwdef mutable struct Air
    temp::Float64 = 293.15      # 温度 [K]（20℃）
    rh::Float64   = 0.50        # 相対湿度 [-]
    vol::Float64  = 1.0         # 容積 [m³]
    H_wall::Float64 = 0.0       # 壁体からの熱流入量 [W]
    H_vent::Float64 = 0.0       # 換気による熱流入量 [W]
    J_wall::Float64 = 0.0       # 壁体からの水分流入量 [kg/s]
    J_vent::Float64 = 0.0       # 換気による水分流入量 [kg/s]
end
```

**導出量の計算（air.jl:20-30）：**

```julia
# 水蒸気圧：相対湿度と飽和水蒸気圧から計算
pv(air::Air) = convertRH2Pv(temp = air.temp, rh = air.rh)

# 水分化学ポテンシャル
miu(air::Air) = convertRH2Miu(temp = air.temp, rh = air.rh)

# 絶対湿度
ah(air::Air) = convertPv2AH(pv = pv(air))
```

**室空気の収支計算（air.jl:52-64）：**

```julia
# 卒論の式：ρa·ca·V·(dT/dt) = H_wall + H_vent
function cal_newtemp(air::Air, dt)
    ca = 1005.0 + 1846.0 * ah(air)    # 湿り空気の比熱
    rho = 353.25 / temp(air)          # 空気密度（理想気体）
    dtemp = (air.H_wall + air.H_vent) / (ca * rho * air.vol) * dt * 3600.0
    return temp(air) + dtemp
end

# 卒論の式：ρa·V·(dX/dt) = J_wall + J_vent
function cal_newRH(air::Air, dt)
    rho = 353.25 / temp(air)
    dah = (air.J_wall + air.J_vent) / (rho * air.vol) * dt * 3600.0
    new_ah = ah(air) + dah
    return convertAH2RH(temp = temp(air), ah = new_ah)
end
```

**解説：**
- `dt * 3600.0` は時間刻み（hour）を秒に変換
- `353.25 / temp` は理想気体の状態方程式から導かれる空気密度
- 湿り空気の比熱は `1005 + 1846 * X` (Xは絶対湿度)

--- 

### 2.3 Wall（壁体）構造体

**卒論の記述：**
> 壁体を表す構造体であり、num, name, IP, IM, ION, thickness, area, cell, BC_IP, BC_IM を持つ。

**コード（wall.jl:3-23）：**

```julia
Base.@kwdef mutable struct Wall
    num::Int                = 0       # 壁番号
    name::String            = ""      # 壁体名
    IP::Int                 = 0       # 上流側室番号（1=外気）
    IM::Int                 = 0       # 下流側室番号
    ION::Float64            = 90.0    # 壁の傾斜角 [°]（0=水平、90=鉛直）
    BC_IP::Any              = []      # 上流側境界条件
    BC_IM::Any              = []      # 下流側境界条件
    thickness::Float64      = 0.0     # 壁体の総厚 [m]
    area::Float64           = 1.0     # 壁面積 [m²]
    cell::Array{Cell,1}     = []      # セルの配列
    target_model::Array{Any,1} = []   # 計算対象（BC含む）
end
```

**壁体データ読み込み（wall.jl:25-100付近）：**

```julia
function input_wall_data(file_name, header)
    df = CSV.read(file_name, DataFrame, header = header, missingstring = "NA")

    for i = 1:nrow(df)
        # 材料構成を解析（例："glass_wool:0.1,plywood:0.02"）
        material_list = split(df.材料[i], ",")

        for mat in material_list
            material_name, thickness = split(mat, ":")

            # セル数を決定
            if thickness >= 0.05
                num_cell = 5
            elseif thickness >= 0.01
                num_cell = 3
            else
                num_cell = 1
            end

            # セルを生成
            for j = 1:num_cell
                cell = Cell(
                    dx = thickness / num_cell,
                    material_name = material_name,
                    temp = 初期温度,
                    miu = 初期水分化学ポテンシャル
                )
                push!(wall.cell, cell)
            end
        end

        # 境界条件の設定
        wall.BC_IP = BC_Robin(alpha = df.alpha_IP[i], ...)
        wall.BC_IM = BC_Robin(alpha = df.alpha_IM[i], ...)

        # target_model = [BC_IP, cell[1], cell[2], ..., cell[n], BC_IM]
        wall.target_model = vcat([wall.BC_IP], wall.cell, [wall.BC_IM])
    end
end
```

**ポイント：**
- `target_model` は境界条件とセルを一列に並べた配列
- これにより、隣接要素間の熱・水分流量計算が統一的に書ける

---

### 2.4 Cell（セル）構造体

**卒論の記述：**
> セルは壁体内の計算格子点を表す構造体であり、temp, miu, dx, material_name, Q, Jv, Jl を持つ。

**コード（cell.jl:5-25）：**

```julia
Base.@kwdef mutable struct Cell
    i::Array{Int,1}         = [0,0,0]  # セル番号 [ix, iy, iz]
    dx::Float64             = 0.001    # セルの厚さ [m]
    dy::Float64             = 1.0      # セルの幅 [m]
    dz::Float64             = 1.0      # セルの高さ [m]
    dx2::Float64            = 0.0      # 質点から端面までの距離 [m]
    temp::Float64           = 293.15   # 温度 [K]
    miu::Float64            = -1000.0  # 水分化学ポテンシャル [J/kg]
    material_name::String   = ""       # 材料名

    # 熱・水分流入出量 [[入力側], [出力側]]
    Q::Array{Array{Float64,1},1}  = [[0.0,0.0,0.0], [0.0,0.0,0.0]]
    Jv::Array{Array{Float64,1},1} = [[0.0,0.0,0.0], [0.0,0.0,0.0]]
    Jl::Array{Array{Float64,1},1} = [[0.0,0.0,0.0], [0.0,0.0,0.0]]
end
```

**dx2の意味：**
- 境界セル（端）では `dx2 = dx`（質点がセル端面に位置）
- 内部セルでは `dx2 = dx/2`（質点がセル中央に位置）

**物性値取得関数（cell.jl:50-80）：**

```julia
# 熱伝導率 [W/(m·K)]
lam(cell::Cell) = get_lam(cell.material_name, temp(cell), rh(cell))

# 透湿率（水蒸気圧勾配駆動）[kg/(m·s·Pa)]
dp(cell::Cell) = get_dp(cell.material_name, temp(cell), rh(cell))

# 液水伝導率（水分化学ポテンシャル勾配駆動）[kg/(m·s·(J/kg))]
ldml(cell::Cell) = get_ldml(cell.material_name, temp(cell), rh(cell))

# 水蒸気伝導率（水分化学ポテンシャル勾配駆動）
ldmg(cell::Cell) = get_ldmg(cell.material_name, temp(cell), rh(cell))
```

**収支計算（cell.jl:110-130）：**

```julia
# 卒論の式：ρc·(∂T/∂t) = -∂q/∂x + r·W
function cal_newtemp(cell::Cell, dq, dJv, dt)
    r = (597.5 - 0.559 * (temp(cell) - 273.15)) * 4.18605E+3  # 蒸発潜熱
    dtemp = (dq - r * dJv) / (crow(cell) * vol(cell)) * dt * 3600.0
    return temp(cell) + dtemp
end

# 卒論の式：ρw·(∂φ/∂μ)·(∂μ/∂t) = -∂(jv+jl)/∂x
function cal_newmiu(cell::Cell, dJv, dJl, dt)
    djw = dJv + dJl  # 総水分流量
    dmiu = djw / (998.0 * vol(cell) * dphi(cell)) * dt * 3600.0
    return miu(cell) + dmiu
end
```

**解説：**
- `crow(cell)` は体積熱容量 ρc [J/(m³·K)]
- `dphi(cell)` は含水率の水分化学ポテンシャル微分 ∂φ/∂μ
- 蒸発潜熱 `r` は温度依存（0℃で約2500 kJ/kg）

---

### 2.5 Opening（開口部）構造体

**コード（opening.jl:3-15）：**

```julia
Base.@kwdef mutable struct Opening
    BC::Int             = 0       # 開口番号
    IP::Int             = 0       # 上流側室番号
    IM::Int             = 0       # 下流側室番号
    Type::String        = ""      # 計算タイプ（"constant"など）
    Qup::Float64        = 0.0     # 上流室方向への換気量 [m³/s]
    Qdw::Float64        = 0.0     # 下流室方向への換気量 [m³/s]
    room_IP::Room       = Room()  # 上流室への参照
    room_IM::Room       = Room()  # 下流室への参照
end
```

**"constant"モード：**
- 換気量を直接指定するモード
- `Qup`, `Qdw` をCSVから読み込み、そのまま使用

---

### 2.6 Climate（外気条件）構造体

**コード（climate.jl:3-20）：**

```julia
Base.@kwdef mutable struct Climate
    air::Air                = Air()           # 外気の状態
    date::DateTime          = DateTime(2000)  # 現在時刻
    location::Dict          = Dict()          # 位置情報
    input_data::DataFrame   = DataFrame()     # 気象データテーブル
    solar::Dict             = Dict()          # 日射関連データ
end
```

**気象データ更新（climate.jl:40-80）：**

```julia
function reset_climate_data(climate::Climate)
    # 現在時刻から気象データの行を特定
    target_date = climate.date

    # 線形補間で温度・湿度を計算
    # 例：12:30の場合、12:00と13:00のデータを0.5:0.5で補間
    df = climate.input_data

    row1 = findrow(df, floor_hour(target_date))
    row2 = findrow(df, ceil_hour(target_date))

    ratio = minute(target_date) / 60.0

    new_temp = df.temp[row1] * (1-ratio) + df.temp[row2] * ratio + 273.15
    new_rh   = df.rh[row1]   * (1-ratio) + df.rh[row2]   * ratio

    climate.air.temp = new_temp
    climate.air.rh   = new_rh

    # 日射量計算
    SOLDN, SOLSN, LATI, ALTI = cal_solar_radiation(...)
    climate.solar["SOLDN"] = SOLDN  # 直達日射量
    climate.solar["SOLSN"] = SOLSN  # 天空日射量
end
```

---

### 2.7 BC_Robin（第三種境界条件）構造体

**卒論の記述：**
> 壁体表面と空気の熱・水分交換を扱う境界条件であり、air, alpha, aldm などを持つ。

**コード（boundary_condition.jl:5-25）：**

```julia
Base.@kwdef mutable struct BC_Robin
    air::Air              = Air()     # 接する空気への参照
    alpha::Float64        = 9.0       # 総合熱伝達率 [W/(m²·K)]
    alphac::Float64       = 0.0       # 対流熱伝達率
    alphar::Float64       = 0.0       # 放射熱伝達率
    aldm::Float64         = 0.0       # 湿気伝達率 [kg/(m²·s·Pa)]
    jl_surf::Float64      = 0.0       # 表面結露水量 [kg/(m²·s)]
    q_added::Float64      = 0.0       # 追加熱流（日射など）
    jv_added::Float64     = 0.0       # 追加水蒸気流
    jl_added::Float64     = 0.0       # 追加液水流
end
```

**湿気伝達率の計算（lewis_relation.jl）：**

```julia
# ルイスの関係式
# aldm = α / (Le · cp · ρ · Rv · T)
function cal_aldm(; temp::Float64, alpha::Float64)
    Le = 1.0           # ルイス数
    cp = 1006.0        # 乾燥空気の定圧比熱 [J/(kg·K)]
    row = 1.293        # 乾燥空気の密度 [kg/m³]
    Rv = 8.31441/0.01802  # 水蒸気の気体定数

    return alpha / (Le * cp * row * Rv * temp)
end
```

---

## 3. 支配方程式とコードの対応

### 3.1 熱伝導（フーリエの法則）

**卒論の式：**
$$q = -\lambda \frac{\partial T}{\partial x}$$

**コード（transfer_in_media.jl:26-32）：**

```julia
# 基礎式
cal_heat_conduction(;lam::Float64, dtemp::Float64, dx2::Float64) = -lam * dtemp / dx2

# 差分方程式（隣接セル間）
function cal_heat_conduction_diff(;lam_mns, lam_pls, temp_mns, temp_pls, dx2_mns, dx2_pls)
    # 調和平均による有効熱伝導率
    lam = sum_resistance(val_mns=lam_mns, val_pls=lam_pls, len_mns=dx2_mns, len_pls=dx2_pls)
    return cal_heat_conduction(lam=lam, dtemp=temp_pls-temp_mns, dx2=dx2_mns+dx2_pls)
end
```

**調和平均（sum_resistance関数）：**

$$\lambda_{eff} = \frac{\Delta x_i + \Delta x_{i+1}}{\Delta x_i / \lambda_i + \Delta x_{i+1} / \lambda_{i+1}}$$

```julia
function sum_resistance(;val_mns, val_pls, len_mns, len_pls)
    return (len_mns + len_pls) / (len_mns/val_mns + len_pls/val_pls)
end
```

### 3.2 水蒸気伝導（水分化学ポテンシャル駆動）

**卒論の式：**
$$j_v = -\lambda'_{\mu g} \frac{\partial \mu}{\partial x} - \lambda'_{Tg} \frac{\partial T}{\partial x}$$

**コード（transfer_in_media.jl:175-182）：**

```julia
# 基礎式
cal_vapour_permeance_potential(;ldmg, ldtg, dmiu, dtemp, dx2) =
    -(ldmg * dmiu/dx2 + ldtg * dtemp/dx2)

# 差分方程式
function cal_vapour_permeance_potential_diff(;ldmg_mns, ldmg_pls, ldtg_mns, ldtg_pls,
                                              miu_mns, miu_pls, temp_mns, temp_pls,
                                              dx2_mns, dx2_pls)
    ldmg = sum_resistance(val_mns=ldmg_mns, val_pls=ldmg_pls, ...)
    ldtg = sum_resistance(val_mns=ldtg_mns, val_pls=ldtg_pls, ...)
    return cal_vapour_permeance_potential(ldmg=ldmg, ldtg=ldtg,
        dmiu=miu_pls-miu_mns, dtemp=temp_pls-temp_mns, dx2=dx2_mns+dx2_pls)
end
```

### 3.3 液水伝導（重力項含む）

**卒論の式：**
$$j_l = -\lambda'_{\mu l} \left( \frac{\partial \mu}{\partial x} - n_x \cdot g \right)$$

**コード（transfer_in_media.jl:352-358）：**

```julia
const grav = 9.806650  # 重力加速度

# 基礎式
cal_liquid_conduction_potential(;ldml, dmiu, dx2, nx=0.0) =
    -ldml * (dmiu/dx2 - nx * grav)

# 差分方程式
function cal_liquid_conduction_potential_diff(;ldml_mns, ldml_pls, miu_mns, miu_pls,
                                               dx2_mns, dx2_pls, nx=0.0)
    ldml = sum_resistance(val_mns=ldml_mns, val_pls=ldml_pls, ...)
    return cal_liquid_conduction_potential(ldml=ldml, dmiu=miu_pls-miu_mns,
        dx2=dx2_mns+dx2_pls, nx=nx)
end
```

**nxの意味：**
- `nx = sin(ION°)` で壁の傾斜を考慮
- `ION = 90°`（鉛直壁）なら `nx = 1`
- `ION = 0°`（水平面）なら `nx = 0`

### 3.4 表面熱伝達（第三種境界条件）

**卒論の式：**
$$q_{surf} = -\alpha (T_{air} - T_{surf})$$

**コード（transfer_in_media.jl:78-82）：**

```julia
cal_heat_transfer(;alpha, dtemp) = -alpha * dtemp

cal_heat_transfer_diff(;alpha, temp_mns, temp_pls) =
    cal_heat_transfer(alpha=alpha, dtemp=temp_pls-temp_mns)
```

**Cell-BC_Robin間の熱流計算（transfer_in_media.jl:97-102）：**

```julia
# mns側が空気（BC_Robin）、pls側が壁体（Cell）の場合
function cal_q(cell_mns::BC_Robin, cell_pls::Cell)
    return cal_heat_transfer_diff(
        alpha = alpha(cell_mns),           # 熱伝達率
        temp_mns = temp(cell_mns.air),     # 空気温度
        temp_pls = temp(cell_pls)          # 壁体表面温度
    ) + cell_mns.q_added                   # 日射等の追加熱流
end
```

### 3.5 表面湿気伝達

**卒論の式：**
$$j_{v,surf} = -\alpha'_m (p_{v,air} - p_{v,surf})$$

**コード（transfer_in_media.jl:265-268）：**

```julia
function cal_jv(cell_mns::BC_Robin, cell_pls::Cell)
    cal_vapour_transfer_pressure_diff(
        aldm = aldm(cell_mns),         # 湿気伝達率
        pv_mns = pv(cell_mns.air),     # 空気の水蒸気圧
        pv_pls = pv(cell_pls)          # 壁体表面の水蒸気圧
    ) + cell_mns.jv_added              # 追加水蒸気流
end
```

---

## 4. 物性値変換システム

### 4.1 水蒸気関連の変換（vapour.jl）

**飽和水蒸気圧（Tetens式）：**

```julia
function cal_Pvs(;temp)
    if temp > 273.15  # 水面上
        Pvs = 610.78 * exp(17.2694 * (temp - 273.15) / (temp - 35.86))
    else              # 氷面上
        Pvs = 610.78 * exp(21.8746 * (temp - 273.15) / (temp - 7.66))
    end
    return Pvs
end
```

**相対湿度 → 水蒸気圧：**

```julia
convertRH2Pv(;temp, rh) = rh * cal_Pvs(temp=temp)
```

**相対湿度 → 水分化学ポテンシャル：**

$$\mu = R_v \cdot T \cdot \ln(\phi)$$

```julia
const Rv = 8.314 / 0.018  # 水蒸気の気体定数

convertRH2Miu(;temp, rh) = Rv * temp * log(rh)
```

**水蒸気圧 → 絶対湿度：**

```julia
convertPv2AH(;pv, patm=101325.0) = 0.622 * pv / (patm - pv)
```

### 4.2 材料物性変換（property_conversion.jl）

**物性テーブルの構造：**

```julia
prop_list = Dict(
    "glass_wool_16K" => glass_wool_16K,
    "plywood" => plywood,
    "concrete_goran" => concrete_goran,
    ...
)

# 各材料は以下の関数を持つ
get_phi(material, temp, rh)   # 含水率 [m³/m³]
get_lam(material, temp, rh)   # 熱伝導率 [W/(m·K)]
get_dp(material, temp, rh)    # 透湿率 [kg/(m·s·Pa)]
get_ldml(material, temp, rh)  # 液水伝導率
get_ldmg(material, temp, rh)  # 水蒸気伝導率
get_crow(material)            # 体積熱容量 [J/(m³·K)]
```

**例：グラスウール（material_property/glass_wool_16K.jl）：**

```julia
module glass_wool_16K

const rho = 16.0      # 密度 [kg/m³]
const c = 840.0       # 比熱 [J/(kg·K)]
const phi_max = 0.95  # 最大含水率

# 等温吸着線（含水率-相対湿度関係）
function get_phi(temp, rh)
    if rh < 0.5
        return 0.001 * rh
    else
        return 0.001 + 0.01 * (rh - 0.5)^2
    end
end

# 熱伝導率（含水率依存）
function get_lam(temp, rh)
    phi = get_phi(temp, rh)
    return 0.04 + 0.5 * phi  # 乾燥時0.04、含水率増加で上昇
end

# 透湿率（ほぼ空気層と同等）
function get_dp(temp, rh)
    return 1.9e-10  # 高い透湿性
end

...
end
```

---

## 5. 境界条件の実装

### 5.1 多重ディスパッチによる統一的な記述

Juliaの多重ディスパッチを使い、Cell-Cell間、Cell-BC間など異なる組み合わせに対して同じ関数名で異なる処理を実装：

```julia
# Cell-Cell間の熱流
function cal_q(cell_mns::Cell, cell_pls::Cell)
    return cal_heat_conduction_diff(...)
end

# Cell-BC_Robin間の熱流（壁体→空気）
function cal_q(cell_mns::Cell, cell_pls::BC_Robin)
    return cal_heat_transfer_diff(...)
end

# BC_Robin-Cell間の熱流（空気→壁体）
function cal_q(cell_mns::BC_Robin, cell_pls::Cell)
    return cal_heat_transfer_diff(...) + cell_mns.q_added
end

# BC_Robin-BC_Robin間（空気層）
cal_q(cell_mns::BC_Robin, cell_pls::BC_Robin) = 0.0
```

### 5.2 第一種・第二種境界条件

```julia
# 第一種境界条件（温度固定）
mutable struct BC_Dirichlet
    cell::Cell  # 固定値を持つ仮想セル
end

cal_q(cell_mns::Cell, cell_pls::BC_Dirichlet) = cal_q(cell_mns, cell_pls.cell)

# 第二種境界条件（熱流固定）
mutable struct BC_Neumann
    q::Float64   # 熱流束 [W/m²]
    jv::Float64  # 水蒸気流束
    jl::Float64  # 液水流束
end

cal_q(cell_mns::Cell, cell_pls::BC_Neumann) = cell_pls.q
```

---

## 6. メイン計算ループ

### 6.1 壁体を通じた熱・水分流量計算

**コード（main.jl:104-151）：**

```julia
function cal_network_flux_of_wall(network::BNM)
    # 1. 室の熱・水分流入量を初期化
    for i = 1:length(network.rooms)
        set_H_wall(network.rooms[i], 0.0)
        set_J_wall(network.rooms[i], 0.0)
    end

    # 2. 各壁体について計算
    for i = 1:length(network.walls)
        target_model = network.walls[i].target_model
        # target_model = [BC_IP, cell[1], cell[2], ..., cell[n], BC_IM]

        # 隣接要素間のループ
        for j = 1:length(target_model)-1
            # 熱流・水分流の計算
            q  = cal_q(target_model[j], target_model[j+1])
            jv = cal_jv(target_model[j], target_model[j+1])
            jl = cal_jl(target_model[j], target_model[j+1], sin(network.walls[i].ION/57.3))

            # 流出側（target_model[j]）の処理
            if typeof(target_model[j]) == Cell
                target_model[j].Q[2][1]  = -q  * dy(target_model[j]) * dz(target_model[j])
                target_model[j].Jv[2][1] = -jv * ...
                target_model[j].Jl[2][1] = -jl * ...
            elseif typeof(target_model[j]) == BC_Robin
                # 室空気への熱・水分流入
                add_H_wall(target_model[j].air, -q * area(network.walls[i]))
                add_J_wall(target_model[j].air, -jv * area(network.walls[i]))
            end

            # 流入側（target_model[j+1]）の処理
            if typeof(target_model[j+1]) == Cell
                target_model[j+1].Q[1][1]  = q * ...
                ...
            elseif typeof(target_model[j+1]) == BC_Robin
                add_H_wall(target_model[j+1].air, q * area(network.walls[i]))
                add_J_wall(target_model[j+1].air, jv * area(network.walls[i]))
            end
        end
    end
end
```

**処理の流れ：**

```
target_model = [BC_IP, cell[1], cell[2], ..., cell[n], BC_IM]
                  ↓
j=1: BC_IP と cell[1] の間の熱・水分流を計算
     → BC_IP.air（室空気）に流入量を加算
     → cell[1].Q[1], Jv[1], Jl[1] に流入量を設定
                  ↓
j=2: cell[1] と cell[2] の間の熱・水分流を計算
     → cell[1].Q[2], Jv[2], Jl[2] に流出量を設定
     → cell[2].Q[1], Jv[1], Jl[1] に流入量を設定
                  ↓
         ...
                  ↓
j=n+1: cell[n] と BC_IM の間の熱・水分流を計算
     → cell[n].Q[2], Jv[2], Jl[2] に流出量を設定
     → BC_IM.air（室空気）に流入量を加算
```

### 6.2 換気による熱・水分流量計算

**コード（main.jl:154-175）：**

```julia
function cal_network_flux_of_ventilation(network::BNM)
    # 初期化
    for i = 1:length(network.rooms)
        set_H_vent(network.rooms[i], 0.0)
        set_J_vent(network.rooms[i], 0.0)
    end

    for i = 1:length(network.openings)
        if network.openings[i].Type == "constant"
            # 湿り空気の比熱
            ca_IP = 1005.0 + 1846.0 * ah(room_IP(network.openings[i]))
            ca_IM = 1005.0 + 1846.0 * ah(room_IM(network.openings[i]))

            # 空気密度
            rho_IP = 353.25 / temp(room_IP(network.openings[i]))
            rho_IM = 353.25 / temp(room_IM(network.openings[i]))
            rho = (rho_IP + rho_IM) / 2.0

            # 上流室への熱・水分流入（下流室から流入）
            # H = Qup * ρ * (ca_IM * T_IM - ca_IP * T_IP)
            add_H_vent(room_IP(...), Qup(...) * rho * (ca_IM*T_IM - ca_IP*T_IP))
            add_J_vent(room_IP(...), Qup(...) * rho * (ah_IM - ah_IP))

            # 下流室への熱・水分流入（上流室から流入）
            add_H_vent(room_IM(...), Qdw(...) * rho * (ca_IP*T_IP - ca_IM*T_IM))
            add_J_vent(room_IM(...), Qdw(...) * rho * (ah_IP - ah_IM))
        end
    end
end
```

### 6.3 収支計算と状態更新

**コード（main.jl:178-220）：**

```julia
function cal_new_value_ver_network(network::BNM, dt)
    # 壁体セルの更新
    for i = 1:length(network.walls)
        target_model = network.walls[i].cell

        for j = 1:length(target_model)
            # 熱収支 → 新温度
            dq = sum(sum(target_model[j].Q))      # 正味熱流入
            dJv = sum(sum(target_model[j].Jv))    # 正味水蒸気流入
            target_model[j].temp = cal_newtemp(target_model[j], dq, -dJv, dt)

            # 水分収支 → 新水分化学ポテンシャル
            dJl = sum(sum(target_model[j].Jl))
            nmiu = cal_newmiu(target_model[j], dJv, dJl, dt)

            # 結露判定（表面セル）
            if (j == 1 || j == length(target_model))
                if nmiu >= -0.1  # ほぼ飽和（RH≈100%）
                    nmiu = -0.1  # 飽和値に固定
                    # 過剰水分を表面結露水として処理
                    BC = j==1 ? :BC_IP : :BC_IM
                    setfield!(getfield(network.walls[i], BC), :jl_surf, dJv+dJl)
                end
            else
                # 内部結露の警告
                if nmiu >= -0.1
                    nmiu = -0.1
                    println("⚠️ 壁体内部で結露発生")
                end
            end

            target_model[j].miu = nmiu
        end
    end

    # 室空気の更新
    for i = 2:length(network.rooms)  # i=1は外気なのでスキップ
        set_temp(network.rooms[i], cal_newtemp(network.rooms[i].air, dt))
        set_rh(network.rooms[i], cal_newRH(network.rooms[i].air, dt))
    end
end
```

---

## 7. 入出力処理

### 7.1 CSVファイルの形式

**室条件（room-condition.csv）：**

```csv
# 室条件ファイル
# 単位：temp=℃, rh=-, vol=m³
番号,名称,temp,rh,vol,Qs,Js
1,外気,25.0,0.60,99999,0.0,0.0
2,居室,25.0,0.50,50.0,0.0,0.0
```

**壁条件（wall-condition.csv）：**

```csv
# 壁体条件ファイル
番号,名称,IP,IM,ION,面積,材料,alpha_IP,alpha_IM,temp_init,rh_init
1,外壁,1,2,90,10.0,"glass_wool:0.1,plywood:0.012",23.0,9.0,25.0,0.5
```

**開口条件（opening-condition.csv）：**

```csv
# 開口条件ファイル
番号,IP,IM,Type,Qup,Qdw
1,1,2,constant,0.01,0.01
```

**気象データ（climate_data.csv）：**

```csv
# 気象データ（名古屋）
# 単位：temp=℃, rh=-, 日射=W/m²
年,月,日,時,temp,rh,日射
2022,1,1,1,5.2,0.65,0
2022,1,1,2,4.8,0.68,0
...
```

### 7.2 計算結果の出力

**logger.jl の構造：**

```julia
function set_logger(path, interval, properties, targets)
    # interval: 出力間隔 [hour]
    # properties: 出力する物性値 ["temp", "rh", "ah", ...]
    # targets: 対象オブジェクト（rooms, walls, cells, ...）

    # CSVファイルを作成
    for prop in properties
        file = open(path * "_" * prop * ".csv", "w")
        ...
    end
end

function write_data_to_logger(logger, current_date)
    if (hour(current_date) % logger.interval == 0)
        for target in logger.targets
            write(logger.file, string(temp(target)), ",")
            ...
        end
    end
end
```

---

## 付録：主要な定数・関数一覧

### 物理定数

| 定数 | 値 | 単位 | 説明 |
|------|-----|------|------|
| `Rv` | 461.5 | J/(kg·K) | 水蒸気の気体定数 |
| `grav` | 9.80665 | m/s² | 重力加速度 |
| `roww` | 998.0 | kg/m³ | 水の密度 |
| `Cr` | 4186.05 | J/(kg·K) | 水の比熱 |

### 主要関数

| 関数名 | ファイル | 説明 |
|--------|----------|------|
| `cal_q()` | transfer_in_media.jl | 熱流計算（多重ディスパッチ） |
| `cal_jv()` | transfer_in_media.jl | 水蒸気流計算 |
| `cal_jl()` | transfer_in_media.jl | 液水流計算 |
| `cal_newtemp()` | cell.jl / air.jl | 新温度計算 |
| `cal_newmiu()` | cell.jl | 新水分化学ポテンシャル計算 |
| `cal_newRH()` | air.jl | 新相対湿度計算 |
| `reset_climate_data()` | climate.jl | 気象データ更新 |
| `create_BNM_model()` | building_network_model.jl | モデル構築 |

---

## 参考：卒論セクションとコードの対応表

| 卒論セクション | 主要対応ファイル |
|----------------|------------------|
| 411-プログラムの機能 | main.jl, building_network_model.jl |
| 412-支配方程式と離散化 | transfer_in_media.jl, flux_and_balance_equation.jl |
| 413-データ構造 | cell.jl, wall.jl, room.jl, air.jl, opening.jl, climate.jl, boundary_condition.jl |
