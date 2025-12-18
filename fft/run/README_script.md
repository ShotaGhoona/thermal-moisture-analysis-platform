# FFT解析スクリプト使用方法

## 概要
`analyze_by_FFT.py` は熱解析データのFFT解析とハーモニック回帰を行うPythonスクリプトです。Jupyterノートブックと同等の機能を持ち、詳細なログ出力と自動化が可能です。

## 実行コマンド

### 基本的な使用方法
```bash
# Room1データの解析
python analyze_by_FFT.py input_data/0930_room_1.xlsx

# Room2データの解析  
python analyze_by_FFT.py input_data/0930_room_2.xlsx
```

### オプション付き実行
```bash
# 出力ディレクトリを指定
python analyze_by_FFT.py input_data/0930_room_1.xlsx --output-dir results

# 上位成分数を変更（デフォルト51）
python analyze_by_FFT.py input_data/0930_room_1.xlsx --top-n 100

# プロット保存をスキップ
python analyze_by_FFT.py input_data/0930_room_1.xlsx --no-plots

# ログレベルを変更
python analyze_by_FFT.py input_data/0930_room_1.xlsx --log-level DEBUG
```

### 完全なオプション例
```bash
python analyze_by_FFT.py input_data/0930_room_2.xlsx \
    --output-dir output_data/0930 \
    --top-n 75 \
    --log-level INFO
```

## コマンドラインオプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `input_file` | 入力Excelファイルパス（必須） | - |
| `--output-dir` | 出力ディレクトリ | `output_data` |
| `--top-n` | 解析する上位周波数成分数 | `51` |
| `--no-plots` | プロット保存をスキップ | False |
| `--log-level` | ログレベル (DEBUG/INFO/WARNING/ERROR) | `INFO` |

## 出力ファイル

### Excelファイル
1. **`harmonic_analysis_results_[ファイル名].xlsx`**
   - シート1: Fourier Spectrum（フーリエスペクトル）
   - シート2: Harmonic Components（各周波数成分の波形）
   - シート3: Harmonic Coefficients（回帰係数・振幅・位相）

2. **`harmonic_analysis_results_fft_[ファイル名].xlsx`**
   - シート1: Fourier Spectrum（フーリエスペクトル）
   - シート2: Waveforms（元波形と再構成波形）

### プロットファイル（PNG）
1. **`amplitude_spectrum_[ファイル名].png`**
   - 振幅スペクトル

2. **`comparison_[ファイル名].png`**
   - 元データ vs ハーモニック回帰
   - 元データ vs FFT再構成
   - 回帰残差

### ログファイル
- **`fft_analysis.log`**: 詳細な解析ログ

## 実行例とログ出力

```bash
$ python analyze_by_FFT.py input_data/0930_room_2.xlsx
```

**出力例:**
```
2024-09-30 10:30:15,123 - INFO - 初期化完了: 入力=input_data/0930_room_2.xlsx, 出力=output_data/harmonic_analysis_results_0930_room_2.xlsx
2024-09-30 10:30:15,124 - INFO - FFT解析開始
2024-09-30 10:30:15,125 - INFO - データ読み込み開始: input_data/0930_room_2.xlsx
2024-09-30 10:30:15,456 - INFO - データ読み込み成功: shape=(18729, 1)
2024-09-30 10:30:15,457 - INFO - 温度データの選択とNaN除去開始
2024-09-30 10:30:15,478 - INFO - データ処理完了:
2024-09-30 10:30:15,478 - INFO -   - 元データ数: 18729
2024-09-30 10:30:15,478 - INFO -   - 有効データ数: 17568
2024-09-30 10:30:15,478 - INFO -   - NaN除去数: 1161
2024-09-30 10:30:15,478 - INFO -   - サンプリング間隔: 600.0秒
2024-09-30 10:30:15,478 - INFO -   - データ期間: 122.0日
2024-09-30 10:30:15,479 - INFO -   - データ統計: 平均=22.083, 標準偏差=5.709
2024-09-30 10:30:15,479 - INFO - FFT解析開始
2024-09-30 10:30:15,479 - INFO - 対象データ形状: (17568,)
2024-09-30 10:30:15,479 - INFO - フーリエ変換実行中...
2024-09-30 10:30:15,489 - INFO - FFT結果:
2024-09-30 10:30:15,489 - INFO -   - 周波数数: 8785
2024-09-30 10:30:15,489 - INFO -   - 最大振幅: 22.083338
2024-09-30 10:30:15,489 - INFO -   - 周波数範囲: 0.00e+00 - 8.33e-04 Hz
2024-09-30 10:30:15,489 - INFO - 逆フーリエ変換による再構成中...
2024-09-30 10:30:15,498 - INFO - 再構成誤差: 0.000000
2024-09-30 10:30:15,498 - INFO - FFT解析完了
2024-09-30 10:30:15,498 - INFO - 上位51成分の分析開始
2024-09-30 10:30:15,499 - INFO - 上位周波数成分:
2024-09-30 10:30:15,499 - INFO -   Rank 1: 周期=DC成分, 振幅=22.083338
2024-09-30 10:30:15,499 - INFO -   Rank 2: 周期=122.0日, 振幅=2.622549
2024-09-30 10:30:15,499 - INFO -   Rank 3: 周期=1.0日, 振幅=1.460377
2024-09-30 10:30:15,499 - INFO -   Rank 4: 周期=30.5日, 振幅=0.970388
2024-09-30 10:30:15,499 - INFO -   Rank 5: 周期=61.0日, 振幅=0.910456
2024-09-30 10:30:15,499 - INFO -   Rank 6: 周期=15.2日, 振幅=0.835446
2024-09-30 10:30:15,499 - INFO -   Rank 7: 周期=13.6日, 振幅=0.793260
2024-09-30 10:30:15,499 - INFO -   Rank 8: 周期=24.4日, 振幅=0.767708
2024-09-30 10:30:15,499 - INFO -   Rank 9: 周期=7.2日, 振幅=0.565814
2024-09-30 10:30:15,499 - INFO -   Rank 10: 周期=9.4日, 振幅=0.503331
2024-09-30 10:30:15,499 - INFO - 上位51成分の分析完了
2024-09-30 10:30:15,499 - INFO - ハーモニック回帰開始
2024-09-30 10:30:15,499 - INFO - 回帰設定: データ数=17568, 時間範囲=122.0日
2024-09-30 10:30:15,501 - INFO - 回帰対象周波数数: 51
2024-09-30 10:30:15,501 - INFO - デザイン行列作成中...
2024-09-30 10:30:15,545 - INFO - デザイン行列形状: (17568, 101)
2024-09-30 10:30:15,545 - INFO - 最小二乗法による回帰実行中...
2024-09-30 10:30:16,234 - INFO - 回帰結果:
2024-09-30 10:30:16,234 - INFO -   - R²: 0.999987
2024-09-30 10:30:16,234 - INFO -   - RMSE: 0.020635
2024-09-30 10:30:16,234 - INFO -   - 説明変数数: 101
2024-09-30 10:30:16,234 - INFO - ハーモニック回帰完了
2024-09-30 10:30:16,234 - INFO - 結果保存開始
2024-09-30 10:30:16,234 - INFO - Excel出力データ準備中...
2024-09-30 10:30:16,267 - INFO - Excel出力開始: output_data/harmonic_analysis_results_0930_room_2.xlsx
2024-09-30 10:30:17,123 - INFO - Excel出力開始: output_data/harmonic_analysis_results_fft_0930_room_2.xlsx
2024-09-30 10:30:17,456 - INFO - Excel出力完了
2024-09-30 10:30:17,456 - INFO - プロット保存開始
2024-09-30 10:30:18,789 - INFO - プロット保存完了
2024-09-30 10:30:18,789 - INFO - 結果保存完了
2024-09-30 10:30:18,789 - INFO - FFT解析完了
2024-09-30 10:30:18,789 - INFO - 出力ファイル: output_data/harmonic_analysis_results_0930_room_2.xlsx
2024-09-30 10:30:18,789 - INFO - FFT出力ファイル: output_data/harmonic_analysis_results_fft_0930_room_2.xlsx
```

## エラー対処

### よくあるエラー
1. **ファイルが見つからない**
   ```
   ERROR - 入力ファイルが見つかりません: input_data/missing_file.xlsx
   ```
   → ファイルパスを確認してください

2. **データ読み込みエラー**
   ```
   ERROR - データ読み込みエラー: Excel file format cannot be determined
   ```
   → ファイル形式を確認してください（.xlsxファイルが必要）

3. **メモリエラー**
   ```
   ERROR - メモリ不足
   ```
   → `--top-n` オプションで解析成分数を減らしてください

## バッチ処理例

複数ファイルを一括処理する場合:

```bash
#!/bin/bash
# batch_analysis.sh

for file in input_data/*.xlsx; do
    echo "Processing $file..."
    python analyze_by_FFT.py "$file" --output-dir "output_data/$(date +%m%d)"
done
```

## スクリプトの特徴

1. **詳細ログ**: 処理の各段階で詳細な情報を出力
2. **エラーハンドリング**: 適切なエラーメッセージと例外処理
3. **進捗表示**: データサイズ、処理時間、結果統計を表示
4. **自動化対応**: コマンドライン引数による柔軟な設定
5. **再現性**: 同じ入力に対して同じ結果を保証