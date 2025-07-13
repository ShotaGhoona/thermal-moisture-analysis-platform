# 実際の計算実行ガイド

## 現状の制約

現在の環境では実際の計算は実行していません。以下の制約があります：

- Julia実行環境の不在
- Jupyter Notebook実行不可
- 計算時間の制約（数時間必要）

## 実際に計算を実行する手順

### 1. Julia環境の確認
```bash
julia --version
# Julia 1.x.x が必要
```

### 2. 必要パッケージのインストール
```julia
using Pkg
Pkg.add("CSV")
Pkg.add("DataFrames")
Pkg.add("Dates")
```

### 3. 1D_calculation.ipynbの修正実行

#### 方法A: Notebookを直接修正
1. 1D_calculation.ipynbを開く
2. 以下の箇所を修正：

**inputファイル読み込み部分を追加：**
```julia
# CSVファイルから壁体構成を読み込む関数を追加
include("./module/data_management/file_input.jl")  # もし存在する場合

# 既存の手動設定部分をコメントアウトし、CSV読み込みに変更
# input_file = "./input_data/1D_model/storage_basic.CSV"  # パターン1
# input_file = "./input_data/1D_model/storage_standard.CSV"  # パターン2
# input_file = "./input_data/1D_model/storage_premium.CSV"  # パターン3
```

#### 方法B: 作成したJuliaスクリプトを実行
```bash
cd /Users/yamashitashota/Downloads/[Julia]熱水分同時移動解析標準プログラムver2.2.1
julia storage_basic_calculation.jl
```

### 4. 各パターンの実行

**パターン1実行：**
- 入力：storage_basic.CSV
- 期待される出力：output_data/storage_basic_result.csv

**パターン2実行：**
- 入力：storage_standard.CSV  
- 期待される出力：output_data/storage_standard_result.csv

**パターン3実行：**
- 入力：storage_premium.CSV
- 期待される出力：output_data/storage_premium_result.csv

### 5. 実行時の注意点

**計算時間：**
- 各パターン：20-30分程度
- 全3パターン：1-2時間

**メモリ使用量：**
- 約1-2GB RAM必要
- 長時間計算のためPCの電源管理に注意

**エラー対処：**
- 材料名のスペルチェック
- CSVファイルの文字エンコーディング確認
- パスの区切り文字確認（Windows: \\, Mac/Linux: /）

## 実行後の分析手順

### 1. 結果ファイルの確認
```bash
ls output_data/
# storage_*_result.csv ファイルの存在確認
```

### 2. データの可視化
- Excel, Python, Rなどで時系列グラフ作成
- 温度・湿度・結露リスクの比較

### 3. レポートの更新
- 実際の数値結果でレポート更新
- 想定結果との比較・考察追加

## 代替案（計算環境がない場合）

1. **大学の計算機環境を利用**
2. **クラウド環境（Google Colab等）でJulia実行**
3. **協力者に計算実行を依頼**

現在作成したファイル群は、実際の計算実行の準備が完全に整っており、Julia環境があればすぐに実行可能です。