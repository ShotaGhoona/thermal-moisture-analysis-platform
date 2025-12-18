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

    # Excel出力（全シートを1ファイルに）
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
