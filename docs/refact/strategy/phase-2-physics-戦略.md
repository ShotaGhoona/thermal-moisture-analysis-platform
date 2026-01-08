# Phase 2: modules/physics/ 切り出し戦略

## 概要

Phase 2では、既存のlegacy-juliaコードから**純粋な物理法則**を抽出し、`modules/physics/`に切り出します。

### 目標

- 構造体（Cell, Air, BC_Robin等）に依存しない純粋な計算関数を抽出
- テスト可能な小さな関数群を作成
- 物理法則の再利用性を高める

---

## 分析結果

### 調査したファイル

| ファイル | サイズ | 内容 |
|---------|-------|------|
| `function/vapour.jl` | 85行 | 水蒸気圧・湿度変換 |
| `function/lewis_relation.jl` | 24行 | ルイス関係式 |
| `function/flux_and_balance_equation.jl` | 288行 | 流量計算・収支方程式 |
| `transfer_in_media.jl` | 853行 | 熱・水分移動の計算核 |
| `air.jl` | 116行 | 空気の状態管理 |
| `cell.jl` | 316行 | セルの状態管理 |
| `flux_ventilation.jl` | 317行 | 換気流量計算 |
| `boundary_condition.jl` | 178行 | 境界条件 |

### コードの分類

```
既存コードの構造:

┌─────────────────────────────────────────────────────────┐
│  純粋な物理法則（構造体に依存しない）                      │
│  ├── 飽和水蒸気圧計算（Magnus式）                        │
│  ├── 湿度変換関数群                                      │
│  ├── 熱伝導・熱伝達の基礎式                              │
│  ├── 水蒸気伝導・伝達の基礎式                            │
│  ├── 液水伝導の基礎式                                    │
│  ├── 収支方程式                                          │
│  └── 物理定数                                            │
├─────────────────────────────────────────────────────────┤
│  構造体に依存した計算（多重ディスパッチ）                   │
│  ├── cal_q(cell_mns::Cell, cell_pls::Cell)               │
│  ├── cal_jv(cell_mns::BC_Robin, cell_pls::Cell)          │
│  └── cal_newtemp(cell::Cell, ...)                        │
├─────────────────────────────────────────────────────────┤
│  境界条件の処理                                           │
│  ├── BC_Dirichlet（固定値境界）                          │
│  ├── BC_Neumann（流束指定境界）                          │
│  └── BC_Robin（対流境界）                                │
└─────────────────────────────────────────────────────────┘

Phase 2で抽出するのは最上層の「純粋な物理法則」のみ
```

---

## 作成するファイル一覧

### modules/physics/ ディレクトリ構造

```
modules/physics/
├── constants.jl          # 物理定数
├── psychrometrics.jl     # 湿り空気の物性
├── heat.jl               # 熱移動
├── vapor.jl              # 水蒸気移動
├── liquid.jl             # 液水移動
├── balance.jl            # 収支方程式
└── utils.jl              # 共通関数
```

---

## 各ファイルの詳細設計

### 1. constants.jl（物理定数）

**移行元**: 各ファイルに散在する定数

**内容**:
```julia
module PhysicsConstants

# 基本定数
const GRAVITY = 9.806650          # 重力加速度 [m/s²]
const R_UNIVERSAL = 8.314         # 理想気体定数 [J/(mol·K)]

# 水の物性
const M_WATER = 0.018             # 水のモル質量 [kg/mol]
const R_VAPOR = R_UNIVERSAL / M_WATER  # 水蒸気のガス定数 [J/(kg·K)]
const RHO_WATER = 1000.0          # 水の密度 [kg/m³]
const C_WATER = 4.18605e3         # 水の比熱 [J/(kg·K)]

# 空気の物性
const C_DRY_AIR = 1005.0          # 乾き空気の比熱 [J/(kg·K)]
const C_VAPOR = 1846.0            # 水蒸気の比熱 [J/(kg·K)]
const P_ATM = 101325.0            # 標準大気圧 [Pa]

# ルイス数
const LEWIS_NUMBER = 1.0

end
```

**行数**: 約25行

---

### 2. psychrometrics.jl（湿り空気の物性）

**移行元**: `function/vapour.jl`

**内容**:
```julia
module Psychrometrics

using ..PhysicsConstants: R_VAPOR, P_ATM

export cal_Pvs, cal_DPvs
export convertRH2Pv, convertPv2RH
export convertRH2Miu, convertMiu2RH
export convertPv2AH, convertAH2Pv
export convertRH2AH, convertAH2RH
export convertPv2Miu, convertMiu2Pv
export cal_DPvDT, cal_DPvDMiu
export cal_drh_dmiu, cal_dah_dpv, cal_dah_drh

# 飽和水蒸気圧 [Pa]
function cal_Pvs(temp::Float64)
    return exp(-5800.22060 / temp + 1.3914993 -
               4.8640239e-2 * temp +
               4.1764768e-5 * temp^2 -
               1.4452093e-8 * temp^3 +
               6.5459673 * log(temp))
end

# 飽和水蒸気圧の温度微分 [Pa/K]
function cal_DPvs(temp::Float64)
    DP = 10.795740 * 273.160 / temp^2 -
         5.0280 / temp / log(10.0) +
         1.50475e-4 * 8.2969 / 273.16 * log(10.0) *
         10.0^(-8.29690 * (temp / 273.160 - 1.0)) +
         0.42873e-3 * 4.769550 * 273.160 / temp^2 * log(10.0) *
         10.0^(4.769550 * (1.0 - 273.160 / temp))
    return cal_Pvs(temp) * DP * log(10.0)
end

# 変換関数群
convertRH2Pv(temp::Float64, rh::Float64) = rh * cal_Pvs(temp)
convertPv2RH(temp::Float64, pv::Float64) = pv / cal_Pvs(temp)
convertRH2Miu(temp::Float64, rh::Float64) = R_VAPOR * temp * log(rh)
convertMiu2RH(temp::Float64, miu::Float64) = exp(miu / R_VAPOR / temp)

function convertPv2Miu(temp::Float64, pv::Float64)
    rh = convertPv2RH(temp, pv)
    return convertRH2Miu(temp, rh)
end

function convertMiu2Pv(temp::Float64, miu::Float64)
    rh = convertMiu2RH(temp, miu)
    return convertRH2Pv(temp, rh)
end

convertPv2AH(pv::Float64, patm::Float64=P_ATM) = 0.622 * pv / (patm - pv)
convertAH2Pv(ah::Float64, patm::Float64=P_ATM) = ah * patm / (0.622 + ah)
convertRH2AH(temp::Float64, rh::Float64, patm::Float64=P_ATM) =
    convertPv2AH(convertRH2Pv(temp, rh), patm)
convertAH2RH(temp::Float64, ah::Float64, patm::Float64=P_ATM) =
    convertPv2RH(temp, convertAH2Pv(ah, patm))

# 微分係数
function cal_DPvDT(temp::Float64, miu::Float64)
    pvs = cal_Pvs(temp)
    dpvs = cal_DPvs(temp)
    rh = exp(miu / R_VAPOR / temp)
    return dpvs * rh - pvs * miu / R_VAPOR / temp^2 * rh
end

function cal_DPvDMiu(temp::Float64, miu::Float64)
    pvs = cal_Pvs(temp)
    return pvs / R_VAPOR / temp * exp(miu / R_VAPOR / temp)
end

cal_drh_dmiu(temp::Float64, miu::Float64) =
    (1.0 / R_VAPOR / temp) * exp(miu / R_VAPOR / temp)

cal_dah_dpv(pv::Float64, patm::Float64=P_ATM) =
    0.622 * patm / (patm - pv)^2

function cal_dah_drh(temp::Float64, rh::Float64, patm::Float64=P_ATM)
    pvs = cal_Pvs(temp)
    return 0.622 * pvs * patm / (patm - pvs * rh)^2
end

end
```

**行数**: 約85行

---

### 3. heat.jl（熱移動）

**移行元**: `transfer_in_media.jl`, `function/flux_and_balance_equation.jl`

**内容**:
```julia
module HeatTransfer

using ..PhysicsConstants: C_WATER

export latent_heat
export cal_heat_conduction, cal_heat_conduction_diff
export cal_heat_transfer, cal_heat_transfer_diff

# 潜熱 [J/kg]
latent_heat(temp::Float64) = (597.5 - 0.559 * (temp - 273.15)) * C_WATER

# 熱伝導
# 基礎式: q = -λ * ∂T/∂x [W/m²]
cal_heat_conduction(lam::Float64, dtemp::Float64, dx::Float64) =
    -lam * dtemp / dx

# 差分方程式（質点間の熱伝導）
function cal_heat_conduction_diff(;
    lam_mns::Float64, lam_pls::Float64,
    temp_mns::Float64, temp_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    # 抵抗値の平均化
    lam = (dx2_mns + dx2_pls) / (dx2_mns / lam_mns + dx2_pls / lam_pls)
    return cal_heat_conduction(lam, temp_pls - temp_mns, dx2_mns + dx2_pls)
end

# 熱伝達
# 基礎式: q = -α * ΔT [W/m²]
cal_heat_transfer(alpha::Float64, dtemp::Float64) = -alpha * dtemp

cal_heat_transfer_diff(alpha::Float64, temp_mns::Float64, temp_pls::Float64) =
    cal_heat_transfer(alpha, temp_pls - temp_mns)

end
```

**行数**: 約45行

---

### 4. vapor.jl（水蒸気移動）

**移行元**: `transfer_in_media.jl`, `function/flux_and_balance_equation.jl`

**内容**:
```julia
module VaporTransfer

export cal_vapour_permeance_pressure, cal_vapour_permeance_pressure_diff
export cal_vapour_permeance_potential, cal_vapour_permeance_potential_diff
export cal_vapour_transfer_pressure, cal_vapour_transfer_pressure_diff
export cal_vapour_transfer_potential, cal_vapour_transfer_potential_diff

# 水蒸気伝導（圧力差駆動）
# 基礎式: jv = -δp * ∂pv/∂x [kg/(m²·s)]
cal_vapour_permeance_pressure(dp::Float64, dpv::Float64, dx::Float64) =
    -dp * dpv / dx

function cal_vapour_permeance_pressure_diff(;
    dp_mns::Float64, dp_pls::Float64,
    pv_mns::Float64, pv_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    dp = (dx2_mns + dx2_pls) / (dx2_mns / dp_mns + dx2_pls / dp_pls)
    return cal_vapour_permeance_pressure(dp, pv_pls - pv_mns, dx2_mns + dx2_pls)
end

# 水蒸気伝導（水分化学ポテンシャル駆動）
# 基礎式: jv = -(λ'μg * ∂μ/∂x + λ'Tg * ∂T/∂x) [kg/(m²·s)]
cal_vapour_permeance_potential(ldmg::Float64, ldtg::Float64,
    dmiu::Float64, dtemp::Float64, dx::Float64) =
    -(ldmg * dmiu / dx + ldtg * dtemp / dx)

function cal_vapour_permeance_potential_diff(;
    ldmg_mns::Float64, ldmg_pls::Float64,
    ldtg_mns::Float64, ldtg_pls::Float64,
    miu_mns::Float64, miu_pls::Float64,
    temp_mns::Float64, temp_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64)

    ldmg = (dx2_mns + dx2_pls) / (dx2_mns / ldmg_mns + dx2_pls / ldmg_pls)
    ldtg = (dx2_mns + dx2_pls) / (dx2_mns / ldtg_mns + dx2_pls / ldtg_pls)
    return cal_vapour_permeance_potential(
        ldmg, ldtg,
        miu_pls - miu_mns, temp_pls - temp_mns,
        dx2_mns + dx2_pls)
end

# 水蒸気伝達（圧力差駆動）
# 基礎式: jv = -α'dm * Δpv [kg/(m²·s)]
cal_vapour_transfer_pressure(aldm::Float64, dpv::Float64) = -aldm * dpv

cal_vapour_transfer_pressure_diff(aldm::Float64, pv_mns::Float64, pv_pls::Float64) =
    cal_vapour_transfer_pressure(aldm, pv_pls - pv_mns)

# 水蒸気伝達（ポテンシャル駆動）
cal_vapour_transfer_potential(aldmg::Float64, aldtg::Float64,
    dmiu::Float64, dtemp::Float64) =
    -aldmg * dmiu - aldtg * dtemp

cal_vapour_transfer_potential_diff(aldmg::Float64, aldtg::Float64,
    miu_mns::Float64, miu_pls::Float64,
    temp_mns::Float64, temp_pls::Float64) =
    cal_vapour_transfer_potential(aldmg, aldtg, miu_pls - miu_mns, temp_pls - temp_mns)

end
```

**行数**: 約65行

---

### 5. liquid.jl（液水移動）

**移行元**: `transfer_in_media.jl`, `function/flux_and_balance_equation.jl`

**内容**:
```julia
module LiquidTransfer

using ..PhysicsConstants: GRAVITY

export cal_liquid_conduction_potential, cal_liquid_conduction_potential_diff

# 液水伝導
# 基礎式: jl = -λ'μl * (∂μ/∂x - nx * g) [kg/(m²·s)]
# nx: 鉛直方向の方向余弦（上向きが正）
cal_liquid_conduction_potential(ldml::Float64, dmiu::Float64,
    dx::Float64, nx::Float64=0.0) =
    -ldml * (dmiu / dx - nx * GRAVITY)

function cal_liquid_conduction_potential_diff(;
    ldml_mns::Float64, ldml_pls::Float64,
    miu_mns::Float64, miu_pls::Float64,
    dx2_mns::Float64, dx2_pls::Float64,
    nx::Float64=0.0)

    ldml = (dx2_mns + dx2_pls) / (dx2_mns / ldml_mns + dx2_pls / ldml_pls)
    return cal_liquid_conduction_potential(
        ldml, miu_pls - miu_mns, dx2_mns + dx2_pls, nx)
end

end
```

**行数**: 約30行

---

### 6. balance.jl（収支方程式）

**移行元**: `function/flux_and_balance_equation.jl`, `cell.jl`, `air.jl`

**内容**:
```julia
module BalanceEquation

using ..PhysicsConstants: RHO_WATER, C_WATER, C_DRY_AIR, C_VAPOR
using ..HeatTransfer: latent_heat

export cal_newtemp_cell, cal_newmiu_cell, cal_newphi_cell
export cal_newtemp_air, cal_newah_air

# 壁体セルの温度更新
# 熱収支: ρc * ∂T/∂t = -∂q/∂x + r * ∂jv/∂x
function cal_newtemp_cell(;
    crow::Float64,      # 熱容量 [J/(m³·K)]
    temp::Float64,      # 現在温度 [K]
    dq::Float64,        # 熱流量の収支 [W/m²]
    W::Float64,         # 水蒸気蒸発量 [kg/(m²·s)]（相変化用）
    dx::Float64,        # セル厚さ [m]
    dt::Float64)        # タイムステップ [s]

    r = latent_heat(temp)
    return temp + (dq - r * W) / dx * (dt / crow)
end

# 壁体セルの水分化学ポテンシャル更新
# 水分収支: ∂w/∂t = -∂jv/∂x - ∂jl/∂x
function cal_newmiu_cell(;
    dphi::Float64,      # ∂φ/∂μ [kg/m³ / (J/kg)]
    miu::Float64,       # 現在の水分化学ポテンシャル [J/kg]
    djw::Float64,       # 水分流量の収支 [kg/(m²·s)]
    dx::Float64,        # セル厚さ [m]
    dt::Float64)        # タイムステップ [s]

    return miu + djw / dx / dphi * (dt / RHO_WATER)
end

# 壁体セルの含水率更新（含水率ベースの計算用）
function cal_newphi_cell(;
    phi::Float64,       # 現在の含水率 [kg/m³]
    djw::Float64,       # 水分流量の収支 [kg/(m²·s)]
    dx::Float64,        # セル厚さ [m]
    dt::Float64)        # タイムステップ [s]

    return phi + djw / dx * (dt / RHO_WATER)
end

# 室空気の温度更新
# 熱収支: ρca*V * ∂T/∂t = Hw + Hv + Hi
function cal_newtemp_air(;
    temp::Float64,      # 現在温度 [K]
    ah::Float64,        # 絶対湿度 [kg/kg]
    vol::Float64,       # 室容積 [m³]
    Hw::Float64,        # 壁からの熱流量 [W]
    Hv::Float64,        # 換気による熱流量 [W]
    Hi::Float64,        # 内部発熱 [W]
    dt::Float64)        # タイムステップ [s]

    ca = C_DRY_AIR + C_VAPOR * ah  # 湿り空気の比熱
    rho = 353.25 / temp             # 空気密度（ボイル・シャルルの法則）
    return temp + (Hw + Hv + Hi) / (ca * rho * vol / dt)
end

# 室空気の絶対湿度更新
# 水分収支: ρ*V * ∂ah/∂t = Jw + Jv + Ji
function cal_newah_air(;
    temp::Float64,      # 現在温度 [K]
    ah::Float64,        # 現在の絶対湿度 [kg/kg]
    vol::Float64,       # 室容積 [m³]
    Jw::Float64,        # 壁からの水分流量 [kg/s]
    Jv::Float64,        # 換気による水分流量 [kg/s]
    Ji::Float64,        # 内部発湿 [kg/s]
    dt::Float64)        # タイムステップ [s]

    rho = 353.25 / temp
    return ah + (Jw + Jv + Ji) / (rho * vol / dt)
end

end
```

**行数**: 約85行

---

### 7. utils.jl（共通関数）

**移行元**: `transfer_in_media.jl`, `function/lewis_relation.jl`

**内容**:
```julia
module PhysicsUtils

using ..PhysicsConstants: LEWIS_NUMBER, C_DRY_AIR, R_VAPOR

export sum_resistance, cal_mean_average, cal_transmittance
export cal_aldm_by_lewis

# 抵抗値の調和平均（直列抵抗の合成）
function sum_resistance(;
    val_mns::Float64, val_pls::Float64,
    len_mns::Float64, len_pls::Float64)

    return (len_mns + len_pls) / (len_mns / val_mns + len_pls / val_pls)
end

# 加重平均
function cal_mean_average(;
    val_mns::Float64, val_pls::Float64,
    len_mns::Float64, len_pls::Float64)

    return (val_mns * len_mns + val_pls * len_pls) / (len_mns + len_pls)
end

# 貫流係数（熱伝達＋熱伝導）
function cal_transmittance(;
    alpha::Float64,     # 伝達率
    lam::Float64,       # 伝導率
    dx2::Float64)       # 質点から表面までの距離

    return 1.0 / (1.0 / alpha + dx2 / (2.0 * lam))
end

# ルイス関係式による物質伝達率計算
# α'dm = α / (Le * cp * ρ * Rv * T)
function cal_aldm_by_lewis(;
    alpha::Float64,     # 対流熱伝達率 [W/(m²·K)]
    temp::Float64,      # 温度 [K]
    rho::Float64=1.293) # 空気密度 [kg/m³]

    return alpha / (LEWIS_NUMBER * C_DRY_AIR * rho * R_VAPOR * temp)
end

end
```

**行数**: 約50行

---

## ファイル間の依存関係

```
constants.jl
    ↓
┌───┴───┬───────────┬───────────┐
↓       ↓           ↓           ↓
psychrometrics.jl  heat.jl    vapor.jl   liquid.jl
        ↓           ↓           ↓
        └─────┬─────┴───────────┘
              ↓
         balance.jl
              ↓
         utils.jl（他から独立、または依存先）
```

**依存ルール**:
1. `constants.jl` は何にも依存しない
2. 各物理モジュールは `constants.jl` のみに依存
3. `balance.jl` は `heat.jl` の `latent_heat` を使用
4. `utils.jl` は `constants.jl` に依存

---

## 移行マッピング

| 移行元ファイル | 移行元関数 | 移行先ファイル |
|--------------|----------|--------------|
| `function/vapour.jl` | `cal_Pvs`, `cal_DPvs` | `psychrometrics.jl` |
| `function/vapour.jl` | `convertRH2Pv`, etc. | `psychrometrics.jl` |
| `function/vapour.jl` | `cal_DPvDT`, `cal_DPvDMiu` | `psychrometrics.jl` |
| `function/vapour.jl` | `cal_drh_dmiu`, `cal_dah_dpv` | `psychrometrics.jl` |
| `transfer_in_media.jl` | `cal_heat_conduction` | `heat.jl` |
| `transfer_in_media.jl` | `cal_heat_transfer` | `heat.jl` |
| `transfer_in_media.jl` | `cal_vapour_permeance_*` | `vapor.jl` |
| `transfer_in_media.jl` | `cal_vapour_transfer_*` | `vapor.jl` |
| `transfer_in_media.jl` | `cal_liquid_conduction_*` | `liquid.jl` |
| `transfer_in_media.jl` | `sum_resistance` | `utils.jl` |
| `transfer_in_media.jl` | `cal_mean_average` | `utils.jl` |
| `cell.jl` | `cal_newtemp` (基礎式) | `balance.jl` |
| `cell.jl` | `cal_newmiu` (基礎式) | `balance.jl` |
| `cell.jl` | `cal_newphi` (基礎式) | `balance.jl` |
| `air.jl` | `cal_energy_balance` | `balance.jl` |
| `air.jl` | `cal_moisture_balance` | `balance.jl` |
| `function/lewis_relation.jl` | `cal_aldm` | `utils.jl` |
| `flux_and_balance_equation.jl` | `latent_heat` | `heat.jl` |

---

## 行数見積もり

| ファイル | 推定行数 |
|---------|--------|
| constants.jl | 25 |
| psychrometrics.jl | 85 |
| heat.jl | 45 |
| vapor.jl | 65 |
| liquid.jl | 30 |
| balance.jl | 85 |
| utils.jl | 50 |
| **合計** | **約385行** |

※ 元の関連コード約1,500行から純粋な物理法則のみを抽出

---

## テスト方針

各モジュールに対して単体テストを作成:

```julia
# tests/physics/test_psychrometrics.jl
@testset "Psychrometrics" begin
    # 飽和水蒸気圧の検証（0℃ = 273.15K）
    @test isapprox(cal_Pvs(273.15), 611.2, rtol=0.01)

    # 変換の往復テスト
    temp = 293.15  # 20℃
    rh = 0.6
    miu = convertRH2Miu(temp, rh)
    @test isapprox(convertMiu2RH(temp, miu), rh, rtol=1e-10)
end
```

---

## 移行手順

```
Step 2.1: constants.jl を作成
├── 物理定数を集約
└── エクスポートを確認

Step 2.2: psychrometrics.jl を作成
├── vapour.jl から関数を移行
├── 定数参照を PhysicsConstants に変更
└── テストを作成

Step 2.3: heat.jl を作成
├── 熱伝導・熱伝達の基礎式を移行
├── 潜熱計算を移行
└── テストを作成

Step 2.4: vapor.jl を作成
├── 水蒸気伝導・伝達の基礎式を移行
└── テストを作成

Step 2.5: liquid.jl を作成
├── 液水伝導の基礎式を移行
└── テストを作成

Step 2.6: balance.jl を作成
├── 収支方程式を移行
├── heat.jl の latent_heat を参照
└── テストを作成

Step 2.7: utils.jl を作成
├── 共通関数を移行
├── ルイス関係式を移行
└── テストを作成

Step 2.8: 統合テスト
├── 全モジュールの結合テスト
└── 既存コードとの比較検証
```

---

## 注意事項

### 1. 構造体に依存しないこと

Phase 2では、Cell, Air, BC_Robin などの構造体に依存しない純粋な計算関数のみを抽出します。

**良い例**:
```julia
cal_heat_conduction(lam::Float64, dtemp::Float64, dx::Float64)
```

**悪い例**:
```julia
cal_q(cell_mns::Cell, cell_pls::Cell)  # 構造体に依存
```

### 2. 多重ディスパッチはPhase 4で

構造体を引数にとる関数（多重ディスパッチ）は、Phase 4の`modules/solver/`で実装します。

### 3. 定数の一元管理

各ファイルに散在している定数（Rv, grav, roww等）を`constants.jl`に集約し、一貫した命名規則を適用します。

---

## 完了条件

- [ ] 7つのファイルが作成されている
- [ ] 全ての関数がエクスポートされている
- [ ] 構造体に依存していない
- [ ] 単体テストが通過する
- [ ] 既存コードとの数値比較が一致する

---

作成日: 2024年12月26日
