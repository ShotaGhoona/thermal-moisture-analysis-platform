# 機械学習パイプライン - 換気量分類

## 概要

FFT解析で抽出した周波数特徴量を用いて、建物の換気量を分類するPyTorchパイプライン。

## ディレクトリ構成

```
machine-learning/
├── config.py          # 設定ファイル
├── data_loader.py     # データ読み込み・前処理
├── model.py           # PyTorchモデル定義
├── train.py           # 学習スクリプト (LOOCV)
├── evaluate.py        # 評価・可視化
├── README.md          # このファイル
└── output/            # 結果出力
    ├── results_mlp_*.json
    ├── results_linear_*.json
    └── *.png (可視化)
```

## 必要なライブラリ

```bash
pip install torch numpy pandas scikit-learn matplotlib seaborn
```

## 使い方

### 1. 学習実行

```bash
cd machine-learning
python train.py
```

**出力**:
- 各FoldのLOOCV結果
- 混同行列
- 結果JSON (`output/results_*.json`)

### 2. 評価・可視化

```bash
python evaluate.py
```

**出力**:
- 混同行列の画像
- 各Foldの正解/不正解の可視化
- 分類レポート (Precision/Recall/F1)

## データ

### 入力特徴量

`fft/output/1224/integrate-fft/` の12個のCSVファイル:
- `spectrum_room{1,2}_{temp,rh,ah}_{amplitude,phase}.csv`

各CSVは:
- 行: 周期 (0.1, 0.2, 0.5, 1.0, 2.0, 7.0, 14.0, 30.0, 90.0日)
- 列: シミュレーションケース

### 分類クラス

換気量の4クラス分類:
- `o01-base`: 基準換気
- `o02-low`: 低換気
- `o03-high`: 高換気
- `o04-none`: 無換気

### サンプル数

- 12サンプル (4換気条件 × 3気候)
- 小サンプルのため**Leave-One-Out Cross-Validation (LOOCV)** を使用

## モデル

### MLP (多層パーセプトロン)

```
入力 (108次元)
  ↓
Linear(108, 64) + BatchNorm + ReLU + Dropout
  ↓
Linear(64, 32) + BatchNorm + ReLU + Dropout
  ↓
Linear(32, 4) → 出力 (4クラス)
```

### 線形分類器 (ベースライン)

```
入力 (108次元) → Linear(108, 4) → 出力 (4クラス)
```

## 設定 (`config.py`)

```python
MODEL_CONFIG = {
    "hidden_sizes": [64, 32],  # 隠れ層サイズ
    "dropout": 0.3,
    "learning_rate": 0.001,
    "epochs": 100,
    "batch_size": 4,
}
```

## 今後の拡張

- [ ] 壁構造分類の追加
- [ ] 特徴量選択・重要度分析
- [ ] データ拡張 (ノイズ付加など)
- [ ] より多くのシミュレーションケースの追加
