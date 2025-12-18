#!/usr/bin/env python3
"""
FFT可視化メインスクリプト

Usage:
    python FFT-plot.py ../output/1202
    python FFT-plot.py ../output/1202 --output-dir figure-fft
"""

import sys
import logging
import argparse
from pathlib import Path

# visualize-scriptからインポート
sys.path.insert(0, str(Path(__file__).parent / 'visualize-script'))
from frequency_response import plot_frequency_response_all
from comparison import plot_comparison_by_wall, plot_comparison_by_opening
from four_panel import plot_four_panel_comparison
from heatmap import plot_heatmap
from bar_chart import plot_bar_by_period
from data_loader import get_available_cases
from config import WALL_NAMES, OPENING_NAMES, CLIMATE_NAMES

# =============================================================================
# 出力フォルダ構造
# =============================================================================
OUTPUT_SUBDIRS = {
    'frequency_response': 'frequency_response',
    'wall_comparison': 'wall_comparison',
    'opening_comparison': 'opening_comparison',
    'four_panel': 'four_panel',
    'heatmap': 'heatmap',
    'bar_chart': 'bar_chart',
}


def setup_logging(output_dir: Path):
    """ログ設定"""
    log_file = output_dir / 'visualize.log'

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)


def create_output_dirs(output_dir: Path) -> dict:
    """出力サブディレクトリを作成"""
    dirs = {}
    for key, name in OUTPUT_SUBDIRS.items():
        subdir = output_dir / name
        subdir.mkdir(parents=True, exist_ok=True)
        dirs[key] = subdir
    return dirs


def main():
    parser = argparse.ArgumentParser(
        description='FFT可視化スクリプト - 周波数応答グラフを生成',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
出力グラフ（フォルダ分け）:
    frequency_response/   : 全パターンの周波数応答
    wall_comparison/      : 壁構造別の比較
    opening_comparison/   : 換気量別の比較
    four_panel/           : 温度・湿度の4パネル比較
    heatmap/              : 振幅のヒートマップ
    bar_chart/            : 特定周期での棒グラフ

使用例:
    python FFT-plot.py ../output/1202
    python FFT-plot.py ../output/1202 --input-dir integrate-fft --output-dir figure-fft
        """
    )

    parser.add_argument('base_dir', help='ベースディレクトリ (例: ../output/1202)')
    parser.add_argument('--input-dir', default='integrate-fft', help='入力ディレクトリ名 (default: integrate-fft)')
    parser.add_argument('--output-dir', default='figure-fft', help='出力ディレクトリ名 (default: figure-fft)')

    args = parser.parse_args()

    base_dir = Path(args.base_dir)
    integrate_dir = base_dir / args.input_dir
    output_dir = base_dir / args.output_dir

    # 入力ディレクトリ確認
    if not integrate_dir.exists():
        print(f"エラー: 入力ディレクトリが見つかりません: {integrate_dir}")
        return 1

    # 出力ディレクトリ作成
    output_dir.mkdir(parents=True, exist_ok=True)
    output_dirs = create_output_dirs(output_dir)

    # ログ設定
    logger = setup_logging(output_dir)

    logger.info("=" * 60)
    logger.info("FFT可視化開始")
    logger.info(f"入力: {integrate_dir}")
    logger.info(f"出力: {output_dir}")
    logger.info("=" * 60)

    generated_files = []

    # 利用可能なケース情報を取得
    try:
        cases, climates, openings, walls = get_available_cases(integrate_dir)
        logger.info(f"検出: {len(cases)}パターン, {len(climates)}気候, {len(openings)}換気, {len(walls)}壁構造")
    except Exception as e:
        logger.error(f"ケース情報取得エラー: {e}")
        return 1

    # =========================================================================
    # 1. 周波数応答グラフ（全パターン比較）
    # =========================================================================
    logger.info("1. 周波数応答グラフ（全パターン比較）")
    for variable in ['room1_temp', 'room1_rh', 'room2_temp', 'room2_rh']:
        for value_type in ['amplitude', 'phase']:
            try:
                path = plot_frequency_response_all(
                    integrate_dir, output_dirs['frequency_response'], variable, value_type
                )
                logger.info(f"   → {path.name}")
                generated_files.append(path)
            except Exception as e:
                logger.warning(f"   スキップ ({variable}, {value_type}): {e}")

    # =========================================================================
    # 2. 壁構造別比較グラフ
    # =========================================================================
    logger.info("2. 壁構造別比較グラフ")
    for climate in climates:
        for opening in openings:
            for variable in ['room1_temp', 'room1_rh']:
                try:
                    path = plot_comparison_by_wall(
                        integrate_dir, output_dirs['wall_comparison'], variable, climate, opening
                    )
                    logger.info(f"   → {path.name}")
                    generated_files.append(path)
                except Exception as e:
                    logger.warning(f"   スキップ: {e}")

    # =========================================================================
    # 3. 換気量別比較グラフ
    # =========================================================================
    logger.info("3. 換気量別比較グラフ")
    for climate in climates:
        for wall in walls:
            for variable in ['room1_temp', 'room1_rh']:
                try:
                    path = plot_comparison_by_opening(
                        integrate_dir, output_dirs['opening_comparison'], variable, climate, wall
                    )
                    logger.info(f"   → {path.name}")
                    generated_files.append(path)
                except Exception as e:
                    logger.warning(f"   スキップ: {e}")

    # =========================================================================
    # 4. 4パネル比較グラフ
    # =========================================================================
    logger.info("4. 4パネル比較グラフ")
    try:
        # 壁構造別（全気候・全換気）
        path = plot_four_panel_comparison(
            integrate_dir, output_dirs['four_panel'], group_by='wall'
        )
        logger.info(f"   → {path.name}")
        generated_files.append(path)

        # 換気量別（全気候・全壁構造）
        path = plot_four_panel_comparison(
            integrate_dir, output_dirs['four_panel'], group_by='opening'
        )
        logger.info(f"   → {path.name}")
        generated_files.append(path)

        # 気候別固定で壁構造比較
        for climate in climates:
            path = plot_four_panel_comparison(
                integrate_dir, output_dirs['four_panel'],
                group_by='wall',
                filter_dict={'climate': climate}
            )
            logger.info(f"   → {path.name}")
            generated_files.append(path)
    except Exception as e:
        logger.warning(f"   4パネル比較をスキップ: {e}")

    # =========================================================================
    # 5. ヒートマップ
    # =========================================================================
    logger.info("5. ヒートマップ")
    for variable in ['room1_temp', 'room1_rh', 'room2_temp', 'room2_rh']:
        try:
            path = plot_heatmap(integrate_dir, output_dirs['heatmap'], variable)
            logger.info(f"   → {path.name}")
            generated_files.append(path)
        except Exception as e:
            logger.warning(f"   スキップ ({variable}): {e}")

    # =========================================================================
    # 6. 周期別棒グラフ
    # =========================================================================
    logger.info("6. 周期別棒グラフ")
    target_periods = [1.0, 7.0, 30.0]  # 日周期、週周期、月周期
    for variable in ['room1_temp', 'room1_rh']:
        for period in target_periods:
            try:
                path = plot_bar_by_period(
                    integrate_dir, output_dirs['bar_chart'], variable, period
                )
                logger.info(f"   → {path.name}")
                generated_files.append(path)
            except Exception as e:
                logger.warning(f"   スキップ ({variable}, {period}日): {e}")

    # =========================================================================
    # 完了
    # =========================================================================
    logger.info("=" * 60)
    logger.info("FFT可視化完了")
    logger.info(f"  生成ファイル数: {len(generated_files)}")
    logger.info(f"  出力先: {output_dir}")
    for subdir_name in OUTPUT_SUBDIRS.values():
        subdir = output_dir / subdir_name
        count = len(list(subdir.glob('*.png')))
        logger.info(f"    {subdir_name}/: {count}ファイル")
    logger.info("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
