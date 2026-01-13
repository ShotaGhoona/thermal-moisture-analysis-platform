# FFT解析パイプライン

## 概要

このディレクトリには、熱水分同時移動シミュレーションの出力データに対してFFT（高速フーリエ変換）解析を行い、建物性能の逆推定に使用する周波数特徴量を抽出するためのスクリプト群が含まれています。

## 目的

**最終目標**: 室内温湿度の時系列データから、建物性能（壁構造・換気量など）を逆推定する

**本パイプラインの役割**:
1. シミュレーション出力（温湿度時系列）をFFT解析し、周波数スペクトルを取得
2. 連続スペクトルを離散的な周期バンドにビニング（平均化）
3. 全パターンを統合し、比較・考察しやすいCSV/Excelを生成

## 理論的背景

建物の温湿度応答には、建物固有の性能が周波数特性として現れる：

- **日周期（1日）**: 壁体の蓄熱性能、断熱性能の影響
- **週〜月周期**: 換気量、気密性の影響
- **年周期**: 断熱性能、熱容量の影響
- **湿度の周波数応答**: 吸放湿性能、換気量の影響

これらの周波数成分の振幅・位相を特徴量として抽出し、機械学習モデルの入力とすることで、建物性能の逆推定を行う。

## パイプライン構成

```
┌─────────────────────────────────────────────────────────────┐
│  Julia シミュレーション                                       │
│  legacy-julia/output_data/batch_all/1202/                   │
│  └── w*_o*_*/result_all_rooms.csv (温湿度時系列)             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. FFT-all.py  (生FFT解析)                                  │
│  入力: result_all_rooms.csv                                  │
│  出力: raw-fft/ (各ケース×スペクトルCSV)                     │
│        - spectrum_room1_temp.csv (数千行)                    │
│        - spectrum_room1_rh.csv                               │
│        - spectrum_room2_temp.csv                             │
│        - spectrum_room2_rh.csv                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. FFT-binning.py  (周波数ビニング)                         │
│  入力: raw-fft/                                              │
│  出力: binned-fft/ (各ケース×ビニング済みCSV)                │
│        - spectrum_room1_temp.csv (10行程度)                  │
│                                                              │
│  手法: 連続スペクトルを離散的な周期バンドに分割し、           │
│        各バンド内の振幅を平均化                              │
│  参考: 鉾井らの周波数応答解析手法                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. FFT-integrate.py  (統合CSV作成)                          │
│  入力: binned-fft/                                           │
│  出力: integrate-fft/                                        │
│        - spectrum_*_amplitude.csv (行:周期, 列:パターン)     │
│        - spectrum_*_phase.csv                                │
│        - all_spectrums.xlsx (8シート統合)                    │
│                                                              │
│  用途: Excel でグラフ作成・パターン間比較・考察              │
└─────────────────────────────────────────────────────────────┘
```

## 出力ディレクトリ構造

```
fft/output/1202/
├── raw-fft/                          # 生スペクトル
│   ├── w01-base_o01-base_kyoto/
│   │   ├── spectrum_room1_temp.csv   # 周波数, 周期, 振幅, 位相 (数千行)
│   │   ├── spectrum_room1_rh.csv
│   │   ├── spectrum_room2_temp.csv
│   │   ├── spectrum_room2_rh.csv
│   │   ├── features.csv              # 抽出した特徴量
│   │   └── amplitude_spectrum.png    # スペクトル図
│   ├── w01-base_o02-low_kyoto/
│   └── ...
│
├── binned-fft/                       # ビニング済み
│   ├── w01-base_o01-base_kyoto/
│   │   ├── spectrum_room1_temp.csv   # 10行程度に集約
│   │   └── ...
│   └── ...
│
└── integrate-fft/                    # 統合CSV
    ├── spectrum_room1_temp_amplitude.csv  # 行:周期, 列:全パターン
    ├── spectrum_room1_temp_phase.csv
    ├── spectrum_room1_rh_amplitude.csv
    ├── spectrum_room1_rh_phase.csv
    ├── spectrum_room2_temp_amplitude.csv
    ├── spectrum_room2_temp_phase.csv
    ├── spectrum_room2_rh_amplitude.csv
    ├── spectrum_room2_rh_phase.csv
    └── all_spectrums.xlsx                 # 上記8ファイルを1Excelに統合
```

## 使用方法

### 前提条件

```bash
# Python環境（anaconda推奨）
pip install numpy pandas matplotlib scipy openpyxl
```

### 実行手順

```bash
cd fft/run

# 1. 生FFT解析（シミュレーション出力 → raw-fft）
python FFT-all.py ../../legacy-julia/output_data/batch_all/1202

# 2. ビニング（raw-fft → binned-fft）
python FFT-binning.py ../output/1202

# 3. 統合（binned-fft → integrate-fft）
python FFT-integrate.py ../output/1202
```

### 一括実行

```bash
# 全ステップを連続実行
python FFT-all.py ../../legacy-julia/output_data/batch_all/1202 && \
python FFT-binning.py ../output/1202 && \
python FFT-integrate.py ../output/1202
```

## 各スクリプトの詳細

### 1. FFT-all.py

**役割**: シミュレーション出力に対してFFT解析を実行

**入力**: `result_all_rooms.csv`（2行ヘッダーのCSV）
```csv
,room1,room1,room1,room2,room2,room2,
,temp,rh,ah,temp,rh,ah,
2022/01/01 00:00,3.9,0.72,0.00359,25.0,0.5,0.00988,
```

**出力**:
- `spectrum_*.csv`: 周波数スペクトル（Frequency, Period, Amplitude, Phase）
- `features.csv`: 主要周期の特徴量
- `amplitude_spectrum.png`: スペクトル可視化

**オプション**:
```bash
python FFT-all.py <batch_dir> [--output-dir DIR] [--top-n N] [--parallel P]

--output-dir    出力先（デフォルト: fft/output/{batch_name}/raw-fft）
--top-n         抽出する上位周波数成分数（デフォルト: 20）
--parallel      並列プロセス数（デフォルト: 1）
```

### 2. FFT-binning.py

**役割**: 連続スペクトルを離散的な周期バンドに変換

**手法**:
- 周期バンド境界を定義（デフォルト: 0.1, 0.2, 0.5, 1, 2, 7, 14, 30, 90, 365日）
- 各バンド内の振幅を平均化
- 位相は円周平均（circular mean）を使用

**設定変更**: スクリプト冒頭の `PERIOD_BINS` を編集
```python
PERIOD_BINS = [0.1, 0.2, 0.5, 1, 2, 7, 14, 30, 90, 365]
```

**オプション**:
```bash
python FFT-binning.py <base_dir> [--input-dir DIR] [--output-dir DIR]

--input-dir     入力ディレクトリ名（デフォルト: raw-fft）
--output-dir    出力ディレクトリ名（デフォルト: binned-fft）
```

### 3. FFT-integrate.py

**役割**: 全パターンのビニング結果を統合し、比較用CSVを作成

**出力形式**:
```csv
period_days, w01-base_o01-base_kyoto, w01-base_o02-low_kyoto, ...
0.1, 0.0015, 0.0016, ...
1.0, 0.0448, 0.0450, ...  ← 日周期の振幅比較
```

**用途**:
- Excelでグラフ作成（行を選択→挿入→グラフ）
- パターン間の周波数応答比較
- 壁構造・換気量による応答差の考察

**オプション**:
```bash
python FFT-integrate.py <base_dir> [--input-dir DIR] [--output-dir DIR]

--input-dir     入力ディレクトリ名（デフォルト: binned-fft）
--output-dir    出力ディレクトリ名（デフォルト: integrate-fft）
```

## 出力データの活用

### 1. Excelでの可視化

`all_spectrums.xlsx` を開き：
1. シートを選択（例: `room1 temp amp`）
2. データ範囲を選択
3. 挿入 → グラフ → 折れ線グラフ
4. パターン間の振幅差を視覚的に比較

### 2. 機械学習への入力

`raw-fft/*/features.csv` または統合CSVを使用：
```python
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

# 特徴量読み込み
df = pd.read_csv('integrate-fft/spectrum_room1_temp_amplitude.csv', index_col=0)

# 転置して1行1パターンに
X = df.T
y = [name.split('_')[0] for name in X.index]  # 壁構造ラベル

# 分類モデル学習
clf = RandomForestClassifier()
clf.fit(X, y)
```

### 3. 考察のポイント

- **日周期の振幅差**: 蓄熱性能・断熱性能の違いを反映
- **位相の遅れ**: 熱容量の大きさを反映
- **湿度の周波数応答**: 吸放湿性能・換気量の影響
- **壁構造による差**: RC単層 vs 断熱 vs 土壁 の応答差
- **換気量による差**: 特に湿度応答に顕著

## 参考文献

- 鉾井修一 他: 吸放湿を有する室の湿度応答に関する研究（周波数応答解析手法）
