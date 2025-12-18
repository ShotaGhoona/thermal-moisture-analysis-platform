#!/usr/bin/env python3
"""
FFTビニングスクリプト - 連続スペクトルを離散的な周期バンドに変換

Usage:
    python FFT-binning.py /path/to/output/1202
    python FFT-binning.py /path/to/output/1202 --input-dir raw-fft --output-dir binned-fft
"""

import sys
import logging
import argparse
from pathlib import Path
import numpy as np
import pandas as pd

# =============================================================================
# 設定: 周期バンドの境界値 [日]
# 必要に応じてここを変更してください
# =============================================================================
PERIOD_BINS = [0.1, 0.2, 0.5, 1, 2, 7, 14, 30, 90, 365]
# 各バンドは [PERIOD_BINS[i], PERIOD_BINS[i+1]) の範囲
# 例: 1日バンド = 周期1日以上2日未満の平均

# =============================================================================


def setup_logging(output_dir: Path):
    """ログ設定"""
    log_file = output_dir / 'fft_binning.log'

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)


def bin_spectrum(df: pd.DataFrame, period_bins: list) -> pd.DataFrame:
    """
    スペクトルをビニング（バンド分け）する

    Args:
        df: 元のスペクトルDataFrame (columns: Frequency (Hz), Period (Day), Amplitude, Phase (radians))
        period_bins: 周期バンドの境界値リスト

    Returns:
        ビニング後のDataFrame
    """
    periods = df['Period (Day)'].values
    amplitudes = df['Amplitude'].values
    phases = df['Phase (radians)'].values

    binned_data = []

    # 各バンドについて処理
    for i in range(len(period_bins)):
        lower = period_bins[i]

        # 上限を決定（最後のビンは無限大まで）
        if i < len(period_bins) - 1:
            upper = period_bins[i + 1]
        else:
            upper = np.inf

        # このバンドに属する周波数成分を抽出
        mask = (periods >= lower) & (periods < upper)

        if np.any(mask):
            # バンド内の平均を計算
            amp_mean = np.mean(amplitudes[mask])

            # 位相は円周平均（circular mean）を使用
            phase_values = phases[mask]
            phase_mean = np.arctan2(
                np.mean(np.sin(phase_values)),
                np.mean(np.cos(phase_values))
            )

            # 周波数は代表値（バンド下限の周期に対応）
            freq_representative = 1 / (lower * 86400) if lower > 0 else 0
        else:
            # データがない場合はNaN
            amp_mean = np.nan
            phase_mean = np.nan
            freq_representative = 1 / (lower * 86400) if lower > 0 else 0

        binned_data.append({
            'Frequency (Hz)': freq_representative,
            'Period (Day)': lower,
            'Amplitude': amp_mean,
            'Phase (radians)': phase_mean,
        })

    return pd.DataFrame(binned_data)


def process_case(case_dir: Path, output_case_dir: Path, period_bins: list, logger):
    """単一ケースの処理"""
    case_name = case_dir.name

    # spectrum_*.csv ファイルを探す
    spectrum_files = list(case_dir.glob('spectrum_*.csv'))

    if not spectrum_files:
        logger.warning(f"スペクトルファイルなし: {case_name}")
        return False

    output_case_dir.mkdir(parents=True, exist_ok=True)

    for spectrum_file in spectrum_files:
        try:
            # 読み込み
            df = pd.read_csv(spectrum_file)

            # ビニング
            binned_df = bin_spectrum(df, period_bins)

            # 保存
            output_file = output_case_dir / spectrum_file.name
            binned_df.to_csv(output_file, index=False, encoding='utf-8-sig')

        except Exception as e:
            logger.error(f"エラー ({spectrum_file.name}): {e}")
            return False

    return True


def main():
    parser = argparse.ArgumentParser(
        description='FFTビニングスクリプト - 連続スペクトルを離散的な周期バンドに変換',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
周期バンド境界値（デフォルト）:
    {PERIOD_BINS}

各バンドは [下限, 上限) の範囲の振幅平均を計算します。
例: 1日バンド = 周期1日以上2日未満の振幅平均

使用例:
    python FFT-binning.py ../output/1202
    python FFT-binning.py ../output/1202 --input-dir raw-fft --output-dir binned-fft
        """
    )

    parser.add_argument('base_dir', help='ベースディレクトリ (例: ../output/1202)')
    parser.add_argument('--input-dir', default='raw-fft', help='入力ディレクトリ名 (default: raw-fft)')
    parser.add_argument('--output-dir', default='binned-fft', help='出力ディレクトリ名 (default: binned-fft)')

    args = parser.parse_args()

    base_dir = Path(args.base_dir)
    input_dir = base_dir / args.input_dir
    output_dir = base_dir / args.output_dir

    # 入力ディレクトリ確認
    if not input_dir.exists():
        print(f"エラー: 入力ディレクトリが見つかりません: {input_dir}")
        return 1

    # 出力ディレクトリ作成
    output_dir.mkdir(parents=True, exist_ok=True)

    # ログ設定
    logger = setup_logging(output_dir)

    logger.info("=" * 60)
    logger.info("FFTビニング開始")
    logger.info(f"周期バンド: {PERIOD_BINS}")
    logger.info(f"入力: {input_dir}")
    logger.info(f"出力: {output_dir}")
    logger.info("=" * 60)

    # ケースディレクトリを検索
    cases = sorted([d for d in input_dir.iterdir() if d.is_dir() and d.name.startswith('w')])

    if not cases:
        logger.error("ケースディレクトリが見つかりません")
        return 1

    logger.info(f"検出ケース数: {len(cases)}")

    # 各ケースを処理
    success_count = 0
    for i, case_dir in enumerate(cases, 1):
        logger.info(f"進捗: {i}/{len(cases)} - {case_dir.name}")

        output_case_dir = output_dir / case_dir.name

        if process_case(case_dir, output_case_dir, PERIOD_BINS, logger):
            success_count += 1

    logger.info("=" * 60)
    logger.info("FFTビニング完了")
    logger.info(f"  成功: {success_count}/{len(cases)}")
    logger.info(f"  出力: {output_dir}")
    logger.info("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
