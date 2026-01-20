#!/usr/bin/env python3
"""
FFT統合スクリプト - ビニング済みスペクトルを全パターン比較用CSVに統合

Usage:
    python FFT-integrate.py /path/to/output/1202
    python FFT-integrate.py /path/to/output/1202 --input-dir binned-fft --output-dir integrate-fft
"""

import sys
import logging
import argparse
from pathlib import Path
import numpy as np
import pandas as pd

# =============================================================================
# 設定: 統合対象のスペクトルファイル
# =============================================================================
SPECTRUM_FILES = [
    'spectrum_room1_temp',
    'spectrum_room1_rh',
    'spectrum_room1_ah',
    'spectrum_room2_temp',
    'spectrum_room2_rh',
    'spectrum_room2_ah',
]

# 振幅比・位相差を計算する変数ペア (室内, 外気, 出力名)
RATIO_PAIRS = [
    ('spectrum_room2_temp', 'spectrum_room1_temp', 'temp'),
    ('spectrum_room2_rh', 'spectrum_room1_rh', 'rh'),
    ('spectrum_room2_ah', 'spectrum_room1_ah', 'ah'),
]

# =============================================================================


def setup_logging(output_dir: Path):
    """ログ設定"""
    log_file = output_dir / 'fft_integrate.log'

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)


def integrate_spectrum(input_dir: Path, cases: list, spectrum_name: str, logger) -> tuple:
    """
    特定のスペクトルを全ケースから統合

    Args:
        input_dir: binned-fft ディレクトリ
        cases: ケースディレクトリのリスト
        spectrum_name: スペクトルファイル名（拡張子なし）

    Returns:
        (amplitude_df, phase_df): 振幅と位相の統合DataFrame
    """
    amplitude_data = {}
    phase_data = {}
    period_days = None

    for case_dir in cases:
        case_name = case_dir.name
        csv_path = case_dir / f'{spectrum_name}.csv'

        if not csv_path.exists():
            logger.warning(f"ファイルなし: {csv_path}")
            continue

        try:
            df = pd.read_csv(csv_path)

            # 周期を取得（最初のケースから）
            if period_days is None:
                period_days = df['Period (Day)'].values

            # 振幅と位相を取得
            amplitude_data[case_name] = df['Amplitude'].values
            phase_data[case_name] = df['Phase (radians)'].values

        except Exception as e:
            logger.error(f"読み込みエラー ({csv_path}): {e}")
            continue

    if period_days is None:
        return None, None

    # DataFrameに変換
    amplitude_df = pd.DataFrame(amplitude_data, index=period_days)
    amplitude_df.index.name = 'period_days'

    phase_df = pd.DataFrame(phase_data, index=period_days)
    phase_df.index.name = 'period_days'

    return amplitude_df, phase_df


def compute_ratio_and_diff(indoor_amp_df: pd.DataFrame, outdoor_amp_df: pd.DataFrame,
                           indoor_phase_df: pd.DataFrame, outdoor_phase_df: pd.DataFrame,
                           logger) -> tuple:
    """
    振幅比と位相差を計算

    Args:
        indoor_amp_df: 室内の振幅DataFrame
        outdoor_amp_df: 外気の振幅DataFrame
        indoor_phase_df: 室内の位相DataFrame
        outdoor_phase_df: 外気の位相DataFrame

    Returns:
        (ratio_df, diff_df): 振幅比と位相差のDataFrame
    """
    # 共通のカラム（ケース名）を取得
    common_cols = indoor_amp_df.columns.intersection(outdoor_amp_df.columns)

    if len(common_cols) == 0:
        logger.warning("共通のケースがありません")
        return None, None

    # 振幅比 = 室内 / 外気
    ratio_df = indoor_amp_df[common_cols] / outdoor_amp_df[common_cols]
    ratio_df.index.name = 'period_days'

    # 位相差 = 室内 - 外気（-π〜πの範囲に正規化）
    diff_df = indoor_phase_df[common_cols] - outdoor_phase_df[common_cols]
    # 位相差を-π〜πの範囲に正規化
    diff_df = np.arctan2(np.sin(diff_df), np.cos(diff_df))
    diff_df.index.name = 'period_days'

    return ratio_df, diff_df


def main():
    parser = argparse.ArgumentParser(
        description='FFT統合スクリプト - ビニング済みスペクトルを全パターン比較用CSVに統合',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
出力ファイル:
    spectrum_room1_temp_amplitude.csv  - Room1温度の振幅比較
    spectrum_room1_temp_phase.csv      - Room1温度の位相比較
    spectrum_room1_rh_amplitude.csv    - Room1湿度の振幅比較
    spectrum_room1_rh_phase.csv        - Room1湿度の位相比較
    （room2も同様）

使用例:
    python FFT-integrate.py ../output/1202
    python FFT-integrate.py ../output/1202 --input-dir binned-fft --output-dir integrate-fft
        """
    )

    parser.add_argument('base_dir', help='ベースディレクトリ (例: ../output/1202)')
    parser.add_argument('--input-dir', default='binned-fft', help='入力ディレクトリ名 (default: binned-fft)')
    parser.add_argument('--output-dir', default='integrate-fft', help='出力ディレクトリ名 (default: integrate-fft)')

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
    logger.info("FFT統合開始")
    logger.info(f"入力: {input_dir}")
    logger.info(f"出力: {output_dir}")
    logger.info("=" * 60)

    # ケースディレクトリを検索
    cases = sorted([d for d in input_dir.iterdir() if d.is_dir() and d.name.startswith('w')])

    if not cases:
        logger.error("ケースディレクトリが見つかりません")
        return 1

    logger.info(f"検出ケース数: {len(cases)}")

    # 各スペクトルファイルを統合
    all_dataframes = {}  # Excel出力用に保存

    for spectrum_name in SPECTRUM_FILES:
        logger.info(f"統合中: {spectrum_name}")

        amplitude_df, phase_df = integrate_spectrum(input_dir, cases, spectrum_name, logger)

        if amplitude_df is None:
            logger.warning(f"データなし: {spectrum_name}")
            continue

        # CSV出力
        amplitude_path = output_dir / f'{spectrum_name}_amplitude.csv'
        phase_path = output_dir / f'{spectrum_name}_phase.csv'

        amplitude_df.to_csv(amplitude_path, encoding='utf-8-sig')
        phase_df.to_csv(phase_path, encoding='utf-8-sig')

        logger.info(f"  → {amplitude_path.name} ({len(amplitude_df.columns)}パターン)")
        logger.info(f"  → {phase_path.name} ({len(phase_df.columns)}パターン)")

        # Excel用に保存
        all_dataframes[f'{spectrum_name}_amp'] = amplitude_df
        all_dataframes[f'{spectrum_name}_phase'] = phase_df

    # =================================================================
    # 振幅比・位相差の計算（室内/外気）
    # =================================================================
    logger.info("-" * 60)
    logger.info("振幅比・位相差の計算")

    for indoor_name, outdoor_name, var_name in RATIO_PAIRS:
        logger.info(f"計算中: {var_name} (室内/外気)")

        # 室内と外気のデータを取得
        indoor_amp_key = f'{indoor_name}_amp'
        outdoor_amp_key = f'{outdoor_name}_amp'
        indoor_phase_key = f'{indoor_name}_phase'
        outdoor_phase_key = f'{outdoor_name}_phase'

        if indoor_amp_key not in all_dataframes or outdoor_amp_key not in all_dataframes:
            logger.warning(f"  データ不足: {var_name}")
            continue

        indoor_amp_df = all_dataframes[indoor_amp_key]
        outdoor_amp_df = all_dataframes[outdoor_amp_key]
        indoor_phase_df = all_dataframes[indoor_phase_key]
        outdoor_phase_df = all_dataframes[outdoor_phase_key]

        # 振幅比・位相差を計算
        ratio_df, diff_df = compute_ratio_and_diff(
            indoor_amp_df, outdoor_amp_df,
            indoor_phase_df, outdoor_phase_df,
            logger
        )

        if ratio_df is None:
            continue

        # CSV出力
        ratio_path = output_dir / f'ratio_{var_name}_amplitude.csv'
        diff_path = output_dir / f'diff_{var_name}_phase.csv'

        ratio_df.to_csv(ratio_path, encoding='utf-8-sig')
        diff_df.to_csv(diff_path, encoding='utf-8-sig')

        logger.info(f"  → {ratio_path.name} ({len(ratio_df.columns)}パターン)")
        logger.info(f"  → {diff_path.name} ({len(diff_df.columns)}パターン)")

        # Excel用に保存
        all_dataframes[f'ratio_{var_name}_amp'] = ratio_df
        all_dataframes[f'diff_{var_name}_phase'] = diff_df

    # =================================================================
    # Excel出力（全シートを1ファイルに）
    # =================================================================
    if all_dataframes:
        excel_path = output_dir / 'all_spectrums.xlsx'
        with pd.ExcelWriter(excel_path, engine='openpyxl') as writer:
            for sheet_name, df in all_dataframes.items():
                # シート名は31文字制限があるので短縮
                short_name = sheet_name.replace('spectrum_', '').replace('_', ' ')
                df.to_excel(writer, sheet_name=short_name[:31])
        logger.info(f"Excel出力: {excel_path.name} ({len(all_dataframes)}シート)")

    logger.info("=" * 60)
    logger.info("FFT統合完了")
    logger.info(f"出力: {output_dir}")
    logger.info("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
