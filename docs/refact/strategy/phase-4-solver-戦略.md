# Phase 4: modules/solver/ 分割戦略

## 概要

| 項目 | 内容 |
|------|------|
| 目的 | 計算エンジンの整理・モジュール化 |
| 移行元 | transfer_in_media.jl, cell.jl, main.jl 等 |
| 移行先 | modules/solver/ |
| 推定行数 | ~600行（4-5ファイル） |

---

## 現状分析

### 計算ロジックの分散状況

現在、計算ロジックが複数ファイルに分散している:

| ファイル | 行数 | 含まれる計算ロジック |
|----------|------|---------------------|
| transfer_in_media.jl | ~850 | cal_q, cal_jv, cal_jl（多重ディスパッチ） |
| cell.jl | ~316 | cal_newtemp, cal_newmiu, cal_newphi |
| flux_ventilation.jl | ~316 | 換気流量計算（6種類のモジュール） |
| multi_ventilation.jl | ~330 | ネットワーク換気計算 |
| main.jl | ~510 | cal_network_flux_of_wall, cal_network_flux_of_ventilation |

### 主要な計算フロー（main.jlより）

```
1. reset_climate_data        → 気象データ更新
2. cal_network_flux_of_wall  → 壁体熱・水分流量計算
3. cal_network_flux_of_ventilation → 換気流量計算
4. cal_new_value_ver_network → 収支計算・状態更新
5. time_elapses              → 時間進行
```

### 流量計算の多重ディスパッチ構造

`transfer_in_media.jl`では以下の組み合わせで多重ディスパッチ:

```julia
# 熱流束 cal_q
cal_q(cell_mns::Cell, cell_pls::Cell)        # Cell-Cell間
cal_q(bc::BC_Robin, cell::Cell)              # BC-Cell間
cal_q(cell::Cell, bc::BC_Robin)              # Cell-BC間

# 水蒸気流束 cal_jv（同様の構造）
# 液水流束 cal_jl（同様の構造）
```

---

## 目標ディレクトリ構造

```
modules/solver/
├── Solver.jl               # 統合モジュール
├── flux/                   # 流量計算
│   ├── wall_flux.jl        # 壁体を通じた熱・水分流量
│   └── ventilation_flux.jl # 換気による熱・水分流量
├── balance/                # 収支・更新
│   ├── cell_updater.jl     # セル状態の更新
│   └── air_updater.jl      # 室空気状態の更新
└── control/                # 制御
    ├── stepper.jl          # 時間進行
    └── condensation.jl     # 結露判定・処理
```

---

## ファイル詳細設計

### 1. flux/wall_flux.jl

**役割**: 壁体を通じた熱・水分流量の計算

**移行元**:
- transfer_in_media.jl: `cal_q`, `cal_jv`, `cal_jl`
- main.jl: `cal_network_flux_of_wall`

**主要関数**:

```julia
module WallFlux

using ..Model: Cell, Wall, BCRobin, BuildingNetwork
using ..Physics: heat_conduction, vapor_permeance_miu, liquid_conduction_potential

export calculate_wall_flux!, flux_heat, flux_vapor, flux_liquid

"""
壁体の熱流束計算 [W/m²]
Cell-Cell間、Cell-BC間の多重ディスパッチ
"""
function flux_heat(cell_minus::Cell, cell_plus::Cell)
    # Physics.jlの純粋関数を使用
end

function flux_heat(bc::BCRobin, cell::Cell)
    # 境界条件からの熱流束
end

"""
壁体の水蒸気流束計算 [kg/(m²·s)]
"""
function flux_vapor(cell_minus::Cell, cell_plus::Cell)
end

"""
壁体の液水流束計算 [kg/(m²·s)]
"""
function flux_liquid(cell_minus::Cell, cell_plus::Cell; inclination::Float64=0.0)
end

"""
ネットワーク全体の壁体流量計算
BuildingNetworkの全壁体について流量を計算し、
各Cellおよび隣接Airの収支値を更新
"""
function calculate_wall_flux!(network::BuildingNetwork)
    # 室の収支値初期化
    for room in network.rooms
        reset_balance!(room.air)
    end

    # 壁ごとに流量計算
    for wall in network.walls
        calculate_single_wall_flux!(wall, network)
    end
end

end # module
```

**設計ポイント**:
- 多重ディスパッチで Cell-Cell, Cell-BC, BC-Cell の組み合わせに対応
- 通気層（vented_air_space）の特殊処理を含む
- `Physics.jl`の純粋関数を呼び出す形式

---

### 2. flux/ventilation_flux.jl

**役割**: 換気による熱・水分流量の計算

**移行元**:
- flux_ventilation.jl: 換気流量計算モジュール群
- main.jl: `cal_network_flux_of_ventilation`
- multi_ventilation.jl: ネットワーク換気計算

**主要関数**:

```julia
module VentilationFlux

using ..Model: Opening, Room, BuildingNetwork, OpeningKind

export calculate_ventilation_flux!
export flux_ventilation_isothermal, flux_ventilation_nonisothermal

"""
等温条件での換気流量 [m³/s]
"""
function flux_ventilation_isothermal(opening::Opening,
                                     room_plus::Room,
                                     room_minus::Room)
end

"""
非等温条件での換気流量 [m³/s]
（温度差換気を考慮）
"""
function flux_ventilation_nonisothermal(opening::Opening,
                                        room_plus::Room,
                                        room_minus::Room)
end

"""
ネットワーク全体の換気流量計算
"""
function calculate_ventilation_flux!(network::BuildingNetwork)
    for room in network.rooms
        room.air.H_vent = 0.0
        room.air.J_vent = 0.0
    end

    for opening in network.openings
        calculate_single_opening_flux!(opening, network)
    end
end

end # module
```

**設計ポイント**:
- `OpeningKind`（gap, window, constant, fan）に応じた分岐
- 等温/非等温、一方向流/交差流のバリエーション
- Phase 5でより詳細なモジュール分割を検討

---

### 3. balance/cell_updater.jl

**役割**: セル（壁体要素）の状態更新

**移行元**:
- cell.jl: `cal_newtemp`, `cal_newmiu`, `cal_newphi`
- main.jl: `cal_new_value_ver_network`（壁部分）

**主要関数**:

```julia
module CellUpdater

using ..Model: Cell, Wall
using ..Physics: update_temp_cell, update_miu_cell

export update_cell!, update_wall_cells!

"""
単一セルの状態更新
Forward Euler法による陽解法
"""
function update_cell!(cell::Cell, dt::Float64)
    # 熱収支から新温度を計算
    Q_net = sum_flux(cell.Q_in, cell.Q_out)
    Jv_net = sum_flux(cell.Jv_in, cell.Jv_out)

    new_temp = update_temp_cell(
        crow = cell_crow(cell),
        temp = cell.temp,
        dq = Q_net,
        djv = Jv_net,
        dx = cell.dx,
        dt = dt
    )

    # 水分収支から新miuを計算
    Jl_net = sum_flux(cell.Jl_in, cell.Jl_out)
    new_miu = update_miu_cell(
        dphi = cell_dphi(cell),
        miu = cell.miu,
        djw = Jv_net + Jl_net,
        dx = cell.dx,
        dt = dt
    )

    cell.temp = new_temp
    cell.miu = new_miu
end

"""
壁体内の全セルを更新
"""
function update_wall_cells!(wall::Wall, dt::Float64)
    for cell in wall.cells
        update_cell!(cell, dt)
    end
end

end # module
```

---

### 4. balance/air_updater.jl

**役割**: 室空気の状態更新

**移行元**:
- air.jl: `cal_newtemp`, `cal_newRH`
- main.jl: `cal_new_value_ver_network`（室空気部分）

**主要関数**:

```julia
module AirUpdater

using ..Model: Air, Room
using ..Physics: update_ah_air

export update_air!, update_room_air!

"""
室空気の状態更新
"""
function update_air!(air::Air, dt::Float64)
    # 熱収支から新温度を計算
    H_total = air.H_wall + air.H_vent + air.H_internal
    new_temp = calculate_new_temp_air(air, H_total, dt)

    # 水分収支から新AHを計算
    J_total = air.J_wall + air.J_vent + air.J_internal
    new_ah = calculate_new_ah_air(air, J_total, dt)

    # 状態更新
    air.temp = new_temp
    air.rh = ah_to_rh(new_ah, new_temp, air.p_atm)
end

"""
室の空気を更新（Room経由）
"""
function update_room_air!(room::Room, dt::Float64)
    update_air!(room.air, dt)
end

end # module
```

---

### 5. control/stepper.jl

**役割**: 時間ステップの進行管理

**移行元**:
- main.jl: 時間ループ構造
- climate.jl: `time_elapses`

**主要関数**:

```julia
module Stepper

using ..Model: BuildingNetwork, Climate

export step!, reset_flux!

"""
1タイムステップの計算を実行
"""
function step!(network::BuildingNetwork, dt::Float64)
    # 1. 流量計算
    WallFlux.calculate_wall_flux!(network)
    VentilationFlux.calculate_ventilation_flux!(network)

    # 2. 状態更新
    for wall in network.walls
        CellUpdater.update_wall_cells!(wall, dt)
    end
    for room in network.rooms[2:end]  # 外気(id=1)以外
        AirUpdater.update_room_air!(room, dt)
    end

    # 3. 結露判定
    Condensation.check_condensation!(network)
end

"""
全要素の流量値をリセット
"""
function reset_flux!(network::BuildingNetwork)
    for wall in network.walls
        for cell in wall.cells
            cell.Q_in = cell.Q_out = 0.0
            cell.Jv_in = cell.Jv_out = 0.0
            cell.Jl_in = cell.Jl_out = 0.0
        end
    end
end

end # module
```

---

### 6. control/condensation.jl

**役割**: 結露判定と処理

**移行元**:
- main.jl: `cal_new_value_ver_network`内の結露処理
- transfer_in_media.jl: 結露判定ロジック

**主要関数**:

```julia
module Condensation

using ..Model: Cell, Wall, BCRobin

export check_condensation!, is_condensing

const MIU_SATURATION = -0.1  # 飽和時のmiu閾値

"""
結露判定
"""
function is_condensing(miu::Float64)::Bool
    return miu >= MIU_SATURATION
end

"""
壁体の結露チェックと処理
"""
function check_condensation!(wall::Wall)
    for (j, cell) in enumerate(wall.cells)
        if is_condensing(cell.miu)
            # 表面セルの場合は結露水を排出
            if j == 1 || j == length(wall.cells)
                handle_surface_condensation!(wall, j)
            else
                # 内部結露の警告
                handle_internal_condensation!(wall, j)
            end
            cell.miu = MIU_SATURATION
        end
    end
end

"""
表面結露の処理
"""
function handle_surface_condensation!(wall::Wall, cell_index::Int)
    cell = wall.cells[cell_index]
    bc = cell_index == 1 ? wall.bc_plus : wall.bc_minus

    # 結露水量を境界条件に記録
    condensate = cell.Jv_in + cell.Jv_out + cell.Jl_in + cell.Jl_out
    bc.jl_added += condensate
end

end # module
```

---

## 移行マッピング（サマリー）

| 移行元 | 移行先 | 内容 |
|--------|--------|------|
| transfer_in_media.jl: cal_q/jv/jl | flux/wall_flux.jl | 壁体流量（多重ディスパッチ） |
| flux_ventilation.jl | flux/ventilation_flux.jl | 換気流量計算 |
| cell.jl: cal_newtemp/miu | balance/cell_updater.jl | セル状態更新 |
| air.jl: cal_newtemp/RH | balance/air_updater.jl | 空気状態更新 |
| main.jl: 時間ループ | control/stepper.jl | ステップ制御 |
| main.jl: 結露処理 | control/condensation.jl | 結露判定 |

---

## 依存関係

```
Solver
├── uses Physics (純粋関数)
├── uses Model (型定義)
└── provides
    ├── WallFlux
    ├── VentilationFlux
    ├── CellUpdater
    ├── AirUpdater
    ├── Stepper
    └── Condensation
```

---

## 実装順序

```
Step 1: flux/wall_flux.jl
        - 最も複雑な多重ディスパッチ構造
        - Physics.jlとの連携確認

Step 2: balance/cell_updater.jl
        - cell_crow, cell_dphi の材料物性取得が必要
        - Materials モジュールとの連携（Phase 5で整理）

Step 3: balance/air_updater.jl
        - 比較的シンプル

Step 4: flux/ventilation_flux.jl
        - OpeningKindによる分岐
        - 等温/非等温のバリエーション

Step 5: control/condensation.jl
        - 結露判定・処理

Step 6: control/stepper.jl
        - 全モジュールの統合

Step 7: Solver.jl
        - エクスポート整理
```

---

## 課題・検討事項

### 1. 材料物性の取得方法

現状 `cell.jl` で `property_conversion.jl` を直接参照している:
```julia
crow(state::Cell) = C(state) * row(state) + wp.Cr * wp.row * phi(state)
lam(state::Cell)  = pc.get_lam(state, state.material_name)
```

**対応案**:
- Phase 5で `Materials` モジュールを整理
- Solver → Materials → Physics の依存関係とする

### 2. 多重ディスパッチの整理

現状の6パターン（Cell-Cell, BC-Cell, Cell-BC × 熱/水蒸気/液水）を:
- 統一インターフェースで整理
- 型パラメータによる汎用化を検討

### 3. 通気層の特殊処理

`vented_air_space` の処理が散在:
```julia
if material_name(target_model[j+1]) == "vented_air_space"
    q = 1.0 / Rthx(target_model[j+1]) * (temp(...) - temp(...))
```

**対応案**:
- 通気層専用の流量計算関数を作成
- または材料物性として吸収

### 4. ODE形式との統合

`transfer_in_media.jl`にはODE形式の更新関数も存在:
- `cal_newtemp_by_ODE`
- `cal_newmiu_by_ODE`

将来的にDifferentialEquations.jlとの連携を視野に入れる。

---

## 推定工数

| ファイル | 推定行数 | 複雑度 |
|----------|---------|--------|
| Solver.jl | ~50 | 低 |
| wall_flux.jl | ~150 | 高 |
| ventilation_flux.jl | ~100 | 中 |
| cell_updater.jl | ~80 | 中 |
| air_updater.jl | ~60 | 低 |
| stepper.jl | ~80 | 中 |
| condensation.jl | ~60 | 低 |
| **合計** | **~580** | - |

---

## 検証方法

1. **単体テスト**: 各関数の入出力を検証
2. **回帰テスト**: legacy-juliaの出力と比較
3. **ベンチマーク**: 計算速度の比較

---

## 参照ドキュメント

| ドキュメント | 内容 |
|------------|------|
| 計算フロー解説.md | 計算の流れ |
| モジュール解説.md | 既存モジュールの構造 |
| Phase 2 戦略 | Physics.jlの設計 |
| Phase 3 戦略 | Model.jlの設計 |
