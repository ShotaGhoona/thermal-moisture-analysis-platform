#!/usr/bin/env python3
"""
温度振幅比の気候間分散を周期バンド別に比較するスクリプト

各周期バンドでの気候間分散を壁構造別に比較し、
短周期では気候による差が大きく、長周期では差が小さいことを定量的に示す。
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
from pathlib import Path

# 日本語フォント
matplotlib.rcParams['font.family'] = 'Hiragino Sans'
matplotlib.rcParams['axes.unicode_minus'] = False

# データディレクトリ
DATA_DIR = Path(__file__).parent.parent / "output" / "0126" / "integrate-fft"
OUTPUT_DIR = Path(__file__).parent.parent.parent / "docs" / "paper" / "source"

# 定義
WALLS = ['w01', 'w02', 'w04', 'w05']
WALL_NAMES = {
    'w01': 'RC単層',
    'w02': 'RC内断熱',
    'w04': 'RC内断熱+調湿',
    'w05': '土壁',
}

OPENINGS = ['o01', 'o02', 'o03', 'o04', 'o05']
CLIMATES = ['kyoto', 'okinawa', 'sapporo']


def calc_climate_variance_by_period(variable='temp'):
    """
    各周期バンド・壁構造別の気候間分散を計算

    Returns:
        tuple: (period_days, {wall: [variances]})
    """
    csv_path = DATA_DIR / f"ratio_{variable}_amplitude.csv"
    df = pd.read_csv(csv_path, encoding='utf-8-sig')

    # 365日（欠損が多い）を除外
    df = df[df['period_days'] < 365]

    period_days = df['period_days'].tolist()
    results = {}

    for wall in WALLS:
        results[wall] = []

        for _, row in df.iterrows():
            # この壁構造・周期での気候間分散を計算
            variances = []

            for opening in OPENINGS:
                # 3気候の値を取得
                values = []
                for climate in CLIMATES:
                    col = f'{wall}_{opening}_{climate}'
                    if col in df.columns:
                        val = row[col]
                        if not np.isnan(val):
                            values.append(val)

                if len(values) >= 2:
                    variances.append(np.var(values, ddof=0))

            # この周期での平均分散
            results[wall].append(np.mean(variances) if variances else np.nan)

    return period_days, results


def plot_climate_variance_by_period(save=True):
    """
    各周期バンドの気候間分散を壁構造別に棒グラフで表示
    """
    period_days, results = calc_climate_variance_by_period('temp')

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    axes = axes.flatten()

    # カラーマップ（短周期→長周期で赤→青）
    n_periods = len(period_days)
    colors = plt.cm.RdYlBu(np.linspace(0.1, 0.9, n_periods))

    x = np.arange(n_periods)
    x_labels = [f'{p}' for p in period_days]

    for i, wall in enumerate(WALLS):
        ax = axes[i]

        variances = results[wall]

        bars = ax.bar(x, variances, width=0.7, color=colors, alpha=0.8, edgecolor='black', linewidth=0.5)

        ax.set_ylabel('気候間分散', fontsize=11)
        ax.set_xlabel('周期 [日]', fontsize=11)
        ax.set_title(f'{WALL_NAMES[wall]}', fontsize=13)
        ax.set_xticks(x)
        ax.set_xticklabels(x_labels, fontsize=9, rotation=45, ha='right')
        ax.grid(axis='y', alpha=0.3)

        # Y軸を統一（比較しやすくするため）
        ax.set_ylim(0, 0.035)

    plt.suptitle('温度振幅比の気候間分散（周期バンド別）', fontsize=14, y=1.02)
    plt.tight_layout()

    if save:
        output_path = OUTPUT_DIR / 'variance_temp_by_period_band.png'
        fig.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
        print(f'保存: {output_path}')
        plt.close(fig)
    else:
        plt.show()

    return period_days, results


def print_table():
    """
    結果をテーブル形式で出力
    """
    period_days, results = calc_climate_variance_by_period('temp')

    print('\n=== 温度振幅比：周期バンド別の気候間分散 ===\n')

    # ヘッダー
    header = '| 壁構造 |'
    for p in period_days:
        header += f' {p}日 |'
    print(header)

    separator = '|--------|'
    for _ in period_days:
        separator += '--------|'
    print(separator)

    # データ行
    for wall in WALLS:
        row = f'| {WALL_NAMES[wall]} |'
        for val in results[wall]:
            if np.isnan(val):
                row += ' - |'
            else:
                row += f' {val:.4f} |'
        print(row)


def main():
    print("=" * 80)
    print("温度振幅比の気候間分散（周期バンド別比較）")
    print("=" * 80)

    period_days, results = plot_climate_variance_by_period()
    print_table()


if __name__ == "__main__":
    main()
