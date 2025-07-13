# 小型物置1D解析：関連コードファイル構造

## メインプログラム（実行エントリポイント）

```
📁 /
├── 1D_calculation.ipynb           # 🎯 メイン実行ファイル
│                                 #    - 1次元熱水分移動計算の統合プログラム
│                                 #    - inputファイル読み込み→計算→結果出力
│                                 #    - 今回の3パターン実験で直接実行
```

## 入力データファイル（実験パラメータ設定）

```
📁 input_data/
├── 1D_model/
│   ├── WG_benchmark_stage0.CSV    # 🔧 ベースとなる入力ファイル
│   │                             #    - 標準的な壁体構成例
│   │                             #    - 3パターン用に複製・編集予定
│   │
│   ├── storage_basic.CSV          # 📝 作成予定：パターン1用入力
│   │                             #    - 金属外壁+薄断熱材（25mm）+内装なし
│   │
│   ├── storage_standard.CSV       # 📝 作成予定：パターン2用入力  
│   │                             #    - 金属外壁+標準断熱材（50mm）+石膏ボード
│   │
│   └── storage_premium.CSV        # 📝 作成予定：パターン3用入力
│                                 #    - 金属外壁+厚断熱材（100mm）+防湿シート+石膏ボード
│
└── climate_data/
    └── climate_data_nagoya.csv    # 🌡️ 名古屋気象データ
                                  #    - 外気温・湿度・日射量の年間データ
                                  #    - 境界条件として使用
```

## コアモジュール（計算エンジン）

```
📁 module/
├── transfer_in_media.jl           # ⚙️ 熱水分移動計算の中核
│                                 #    - Fourier法則（熱伝導）
│                                 #    - Fick法則（水分移動）
│                                 #    - 微分方程式の数値解法
│
├── cell.jl                       # 🧱 計算セル（要素）の定義
│                                 #    - 各材料層の温度・湿度状態管理
│                                 #    - 物性値と状態変数の統合
│
├── boundary_condition.jl         # 🌊 境界条件の定義・処理
│                                 #    - Robin境界（対流熱伝達）
│                                 #    - Neumann境界（熱流束指定）
│                                 #    - Dirichlet境界（温度指定）
│
└── climate.jl                    # 🌤️ 気象データ処理
                                  #    - CSV気象データの読み込み
                                  #    - 時間補間・データ取得
```

## 材料物性データベース（各パターンで使用）

```
📁 module/material_property/
├── metal_plate.jl                # 🔩 金属サイディング物性
│                                 #    - 全パターン共通の外壁材
│                                 #    - 熱伝導率、密度、比熱等
│
├── glass_wool_16K.jl             # 🧽 グラスウール断熱材物性
│                                 #    - 全パターンで使用（厚さ違い）
│                                 #    - 湿気依存特性含む
│
├── plasterboard.jl               # 📄 石膏ボード物性
│                                 #    - パターン2,3で内装材として使用
│                                 #    - 調湿性能あり
│
├── moisture_proof_sheet.jl       # 🛡️ 防湿シート物性
│                                 #    - パターン3のみで使用
│                                 #    - 水蒸気透過抵抗大
│
└── property_conversion.jl        # 🔄 物性値変換ユーティリティ
                                  #    - 材料名→物性値の変換
                                  #    - 温湿度依存特性の処理
```

## 支援モジュール（計算サポート）

```
📁 module/
├── air.jl                        # 💨 空気物性・湿り空気計算
│                                 #    - 相対湿度⇔絶対湿度変換
│                                 #    - 露点温度計算
│
└── function/
    ├── vapour.jl                 # 💧 水蒸気圧計算
    │                             #    - 飽和水蒸気圧
    │                             #    - 相対湿度関連計算
    │
    └── flux_and_balance_equation.jl # ⚖️ 流束・収支方程式
                                  #    - 熱・水分流束計算
                                  #    - 材料境界での連続条件
```

## 出力・可視化関連

```
📁 /
├── logger.jl                     # 📊 結果出力・ログ管理
│                                 #    - CSV形式での結果保存
│                                 #    - 温度・湿度・流束データ
│
└── output_data/                  # 📈 計算結果保存フォルダ
    ├── storage_basic_result.csv   # 📝 作成予定：パターン1結果
    ├── storage_standard_result.csv # 📝 作成予定：パターン2結果
    └── storage_premium_result.csv  # 📝 作成予定：パターン3結果
```

## 実験実行フロー

```
🔄 実行ステップ：

1. 📝 inputファイル作成
   WG_benchmark_stage0.CSV → 3パターンCSV作成

2. 🎯 メイン実行
   1D_calculation.ipynb → 各パターンでnotebook実行

3. 📊 結果確認
   output_data/ → CSVファイルで結果確認

4. 📈 分析・グラフ化
   結果データ → Excel/Python等で可視化
```

## ファイル依存関係

```
依存関係図：
1D_calculation.ipynb
├── input_data/1D_model/*.CSV      (入力データ)
├── input_data/climate_data/*.csv   (気象データ)
├── module/transfer_in_media.jl     (計算エンジン)
├── module/cell.jl                  (セル定義)
├── module/boundary_condition.jl    (境界条件)
├── module/climate.jl               (気象処理)
├── module/material_property/*.jl   (材料物性)
├── module/air.jl                   (空気物性)
├── module/function/*.jl            (計算関数)
└── logger.jl                       (結果出力)
```

## 重要ポイント

### ✅ 直接編集するファイル
- **inputファイル**：3パターンのCSV作成・編集
- **1D_calculation.ipynb**：必要に応じて計算条件調整

### 🔒 変更不要のファイル
- **moduleファイル群**：既存の物性値・計算ロジック使用
- **気象データ**：名古屋データをそのまま使用

### 📋 実験で重要な関係
```
パラメータ変更 → inputファイル
材料特性     → material_propertyフォルダ
計算実行     → 1D_calculation.ipynb  
結果確認     → output_dataフォルダ
```

この構造により、コアプログラムを変更せずに、inputファイルの編集のみで3パターンの実験が実現できます。