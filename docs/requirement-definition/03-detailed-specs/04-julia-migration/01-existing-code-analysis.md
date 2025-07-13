# 既存Juliaコード詳細分析

## 分析概要

既存の熱水分同時移動解析標準プログラムを詳細に分析し、Web化に向けた移植戦略を策定する。

## ファイル構造分析

### コア計算モジュール（優先度：高）

#### `module/transfer_in_media.jl`
**役割**: 熱・水分移動計算の核となる部分
**重要度**: ★★★★★
**移植優先度**: 1
```julia
# 主要関数
- cal_q(cell1, cell2)           # 熱流計算
- cal_jv(cell1, cell2)          # 水蒸気流計算  
- cal_jl(cell1, cell2, gravity) # 液水流計算
- cal_newtemp(cell, heat_balance, moisture_latent, dt)  # 新温度計算
- cal_newmiu(cell, vapor_balance, liquid_balance, dt)   # 新水分計算
```
**Web化への適合性**: 
- ✅ 純粋な数値計算関数で副作用なし
- ✅ 入力・出力が明確
- ✅ 状態変更なし（関数型）
- 🔄 Cell構造体への依存（要ラッパー化）

#### `module/cell.jl`  
**役割**: 計算セルの基本構造体定義
**重要度**: ★★★★★
**移植優先度**: 1
```julia
mutable struct Cell
    i::Array{Int, 1}           # 位置インデックス
    xyz::Array{Float64,1}      # 座標
    dx, dy, dz::Float64        # セル寸法
    temp::Float64              # 温度[K]
    miu::Float64               # 水分化学ポテンシャル[J/kg]
    material_name::String      # 材料名
    # その他物性値フィールド多数
end
```
**Web化への適合性**:
- ✅ データ構造が明確
- ✅ アクセサ関数で抽象化可能
- 🔄 mutableな設計（Webでは不変オブジェクト推奨）
- 🔄 材料名による動的な物性値取得

#### `module/boundary_condition.jl`
**役割**: 境界条件の定義と処理
**重要度**: ★★★★☆
**移植優先度**: 2
```julia
mutable struct BC_Robin
    name::String
    air::Air              # 空気状態
    cell::Cell           # セル情報
    alpha::Float64       # 総合熱伝達率
    aldm::Float64        # 湿気伝達率
    # 境界条件パラメータ
end
```
**Web化への適合性**:
- ✅ 明確な境界条件パターン
- ✅ 第1種・第2種・第3種すべて対応
- 🔄 Air・Cell構造体への依存
- ✅ 計算ロジックはシンプル

### 材料物性モジュール（優先度：高）

#### `module/material_property/`ディレクトリ
**役割**: 各種建築材料の物性値定義
**重要度**: ★★★★☆
**移植優先度**: 2

**分析結果**:
```julia
# 典型的な材料定義パターン（mud_wall.jl例）
function psi(cell::Cell)    # 空隙率
    return 0.082
end

function row(cell::Cell)    # 密度[kg/m³]
    return 1650.0
end

function C(cell::Cell)      # 比熱[J/(kg·K)]
    return 900.0
end

function lam(cell::Cell)    # 熱伝導率[W/(m·K)]
    return 0.23
end

function phi(cell::Cell)    # 含水率[kg/kg]
    rh = convertMiu2RH(temp=cell.temp, miu=cell.miu)
    if rh < 0.85
        return 0.002 + 0.03 * rh
    else
        return 0.032 + 0.15 * (rh - 0.85)
    end
end
```

**移植戦略**:
- 🔄 **データベース化**: 関数 → JSON/辞書形式
- 🔄 **条件分岐の処理**: if-else → 数式エンジンまたはルックアップテーブル
- ✅ **物性値の体系化**: カテゴリ別整理が容易

### 補助モジュール（優先度：中）

#### `module/air.jl`
**役割**: 空気状態の管理
**重要度**: ★★★☆☆
**移植優先度**: 3
```julia
mutable struct Air
    name::String
    temp::Float64      # 温度[K]
    rh::Float64        # 相対湿度[-]
    ah::Float64        # 絶対湿度[kg/kg]
    pv::Float64        # 水蒸気圧[Pa]
    # その他空気状態パラメータ
end
```
**Web化への適合性**:
- ✅ 単純なデータ構造
- ✅ 計算関数が独立している
- 🔄 Cell構造体との循環依存

#### `module/climate.jl`
**役割**: 外界気象データの管理  
**重要度**: ★★☆☆☆
**移植優先度**: 4
```julia
mutable struct Climate
    date::DateTime
    air::Air
    location::Dict     # 位置情報
    # 気象データの時間補間機能
end
```
**Web化への適合性**:
- ✅ データ駆動で理解しやすい
- ✅ 時間補間ロジックが明確
- 🔄 ファイル読み込み依存（Web化時はJSON API化）

### 計算制御ファイル（優先度：低）

#### `1D_calculation.ipynb`
**役割**: 1次元計算のメイン実行制御
**重要度**: ★★★☆☆
**移植優先度**: 5
```julia
# 主要な処理フロー
1. モジュール読み込み
2. モデル構築（Cell配列作成）
3. 境界条件設定
4. 時間ループ
   - 流量計算: cal_q, cal_jv, cal_jl
   - 収支計算: cal_newtemp, cal_newmiu
   - 値更新
   - 時間進行
5. 結果出力
```
**Web化への適合性**:
- ✅ フロー制御が明確
- ✅ バッチ処理のパターン化が容易
- 🔄 Jupyter依存（Julia script化必要）
- ✅ 進捗報告の挿入ポイントが明確

## 依存関係分析

### コア依存関係
```
transfer_in_media.jl
├── cell.jl
├── material_property/*.jl
└── function/
    ├── vapour.jl
    ├── property_conversion.jl
    └── lewis_relation.jl
```

### 循環依存の問題
```
cell.jl ←→ material_property/*.jl
  ↕
air.jl ←→ boundary_condition.jl
```

**解決策**: インターフェース分離、依存性注入パターン

## Web化移植戦略

### Phase 1: コア計算エンジン移植（2週間）

#### 1.1 Cell構造体のWeb対応化
```julia
# 既存 (mutable, 状態変更あり)
mutable struct Cell
    temp::Float64
    material_name::String
    # ... 他フィールド
end

# Web版 (immutable, 純粋関数型)
struct CellState
    position::Position
    thermal_state::ThermalState  
    material_properties::MaterialProperties
end

# アクセサ関数化
function get_temperature(cell::CellState)::Float64
function get_material_property(cell::CellState, property::Symbol)::Float64
```

#### 1.2 材料物性のデータベース化
```julia
# 既存 (関数ベース)
function phi(cell::Cell)
    # 複雑な条件分岐...
end

# Web版 (データ+計算エンジン)
struct MaterialDatabase
    materials::Dict{String, MaterialDefinition}
end

function calculate_moisture_content(
    material_def::MaterialDefinition,
    temperature::Float64,
    chemical_potential::Float64
)::Float64
```

#### 1.3 計算エンジンのステートレス化
```julia
# 既存 (Cell配列の直接変更)
for i = 1:length(wall)
    wall[i].temp = ntemp[i]
    wall[i].miu = nmiu[i]
end

# Web版 (純粋関数、新しい状態を返す)
function update_thermal_state(
    current_state::Vector{CellState},
    heat_fluxes::Vector{Float64},
    moisture_fluxes::Vector{Float64},
    dt::Float64
)::Vector{CellState}
```

### Phase 2: API ラッパー実装（1週間）

#### 2.1 JSON インターフェース
```julia
# JSON入力を受け取り、Julia構造体に変換
function parse_simulation_request(json_str::String)::SimulationConfig

# Julia計算結果をJSON出力に変換
function format_simulation_results(results::SimulationResults)::String
```

#### 2.2 進捗報告機能
```julia
# プログレスコールバック
function run_simulation_with_progress(
    config::SimulationConfig,
    progress_callback::Function
)::SimulationResults

# WebSocket経由での進捗通知
progress_callback = (percentage, current_time, estimated_remaining) -> begin
    # WebSocket送信処理
end
```

#### 2.3 エラーハンドリング
```julia
# 計算エラーの構造化
struct CalculationError
    error_type::Symbol      # :convergence_error, :material_error, etc.
    message::String
    context::Dict{String, Any}
    suggestions::Vector{String}
end

# エラーの捕捉とJSON形式での返却
function safe_run_simulation(config::SimulationConfig)::Result{SimulationResults, CalculationError}
```

### Phase 3: 最適化・検証（3日）

#### 3.1 性能最適化
- **メモリプール**: Cell構造体の再利用
- **計算並列化**: マルチスレッド対応（当面は不要）
- **中間結果キャッシュ**: 材料物性値の事前計算

#### 3.2 精度検証
```julia
# 既存計算との比較テスト
function validate_against_legacy(
    test_cases::Vector{TestCase}
)::ValidationReport

struct ValidationReport
    test_name::String
    max_temperature_error::Float64
    max_humidity_error::Float64
    computation_time_ratio::Float64
    memory_usage_ratio::Float64
end
```

## 移植時の重要な設計決定

### 1. 状態管理方針
- **既存**: mutable struct + 直接変更
- **Web版**: immutable struct + 純粋関数
- **利点**: 並行実行安全、テスト容易、デバッグ簡単

### 2. 材料物性の扱い
- **既存**: 関数による動的計算
- **Web版**: 事前計算済みルックアップテーブル + 補間
- **利点**: 高速化、データベース化、管理容易

### 3. エラーハンドリング
- **既存**: 例外による異常終了
- **Web版**: Result型によるエラー表現
- **利点**: エラー情報の構造化、復旧可能性

### 4. 時間管理
- **既存**: グローバル時刻変数
- **Web版**: 時刻を引数として渡す関数型
- **利点**: 副作用なし、テスト容易

## 移植リスク評価

### 高リスク項目
1. **材料物性関数の複雑性**: 条件分岐が多い関数の移植
2. **数値計算精度**: 浮動小数点演算の微細な差異
3. **収束判定**: 反復計算の収束条件の再現

### 中リスク項目
1. **メモリ使用量**: 不変オブジェクトによるメモリ増加
2. **計算速度**: 関数呼び出しオーバーヘッド
3. **初期化処理**: 複雑な初期条件設定

### 低リスク項目
1. **基本データ構造**: 数値・文字列・配列の扱い
2. **ファイル入出力**: JSON APIでの代替
3. **可視化**: Web側での再実装

## 移植完了の判定基準

### 必須条件
- [ ] 既存計算結果との数値一致（誤差 < 1e-10）
- [ ] 全40種類材料の物性値計算の再現
- [ ] 計算時間が既存の3倍以内
- [ ] メモリ使用量が既存の5倍以内

### 推奨条件
- [ ] 進捗報告機能の実装
- [ ] 構造化エラーメッセージ
- [ ] 中間結果の出力機能
- [ ] 計算条件の検証機能

この分析に基づき、既存Juliaコードの価値を最大限活用しながら、Web環境に適した設計への移植を実現します。