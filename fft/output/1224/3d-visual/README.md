# FFT 3D可視化結果 (1224)

## 概要
熱水分シミュレーション結果のFFT解析データを3D可視化したもの。
**換気量×地域**の関係を視覚的に把握するために作成。

## データパターン
- 壁材質: w01-base（固定）
- 換気量: o01-base / o02-low / o03-high / o04-none
- 地域: Kyoto / Okinawa / Sapporo

## 軸の意味
- **X軸**: 地域 (Kyoto / Okinawa / Sapporo)
- **Y軸**: 換気量 (Base / Low / High / None)
- **Z軸**: FFT振幅

## ファイル一覧

### 代表周期の比較 (`*_periods.png`)
1日/7日/30日/90日の4周期を2×2で並べたプロット。
各周期における換気量×地域の振幅分布を比較できる。

### 全周期の散布図 (`*_all.png`)
全周期のデータを1枚にプロット。換気量ごとに色分け。
周波数応答の全体像を把握するのに使用。

### 個別周期 (`*_period1.0.png`, `*_period90.0.png`)
- 1日周期: 日変動の応答特性
- 90日周期: 季節変動の応答特性

## 変数
- `room1_temp`: 室1の温度
- `room1_rh`: 室1の相対湿度
- `room2_temp`: 室2の温度
- `room2_rh`: 室2の相対湿度

## 生成コマンド
```bash
python fft/run/FFT-3d-visual.py fft/output/1224/integrate-fft
```

## 関連ファイル
- 入力データ: `fft/output/1224/integrate-fft/spectrum_*_amplitude.csv`
- スクリプト: `fft/run/FFT-3d-visual.py`
