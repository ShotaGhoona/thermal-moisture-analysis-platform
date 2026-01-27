#!/usr/bin/env python3
"""
グループ間分散 vs グループ内分散の比較スクリプト

グループ間分散: 換気量の違いによる振幅比の分散
グループ内分散: 同一換気量内での気候条件による振幅比の分散

「グループ間 > グループ内」であれば、気候が異なっていても換気量の識別が可能
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

VARIABLES = ['rh', 'ah', 'temp']
VARIABLE_NAMES = {
    'ah': '絶対湿度',
    'rh': '相対湿度',
    'temp': '温度',
}


def calc_between_within_variance(variable='rh'):
    """
    グループ間分散とグループ内分散を計算

    グループ間分散: 各換気量の平均振幅比の分散（換気量による差）
    グループ内分散: 各換気量内での気候間分散の平均（気候による差）

    Returns:
        dict: {wall: {'between': float, 'within': float}}
    """
    csv_path = DATA_DIR / f"ratio_{variable}_amplitude.csv"
    df = pd.read_csv(csv_path, encoding='utf-8-sig')
    n_periods = len(df)

    results = {}

    for wall in WALLS:
        between_vars = []  # 各周期でのグループ間分散
        within_vars = []   # 各周期でのグループ内分散

        for t in range(n_periods):
            # 各換気量の平均値（気候で平均）
            group_means = []
            # 各換気量内の分散（気候間）
            group_within_vars = []

            for opening in OPENINGS:
                # この壁・換気量・周期での3気候の値
                values = []
                for climate in CLIMATES:
                    col = f'{wall}_{opening}_{climate}'
                    if col in df.columns:
                        val = df.loc[t, col]
                        if not np.isnan(val):
                            values.append(val)

                if len(values) >= 2:
                    group_means.append(np.mean(values))
                    group_within_vars.append(np.var(values, ddof=0))

            if len(group_means) >= 2:
                # グループ間分散: 各換気量の平均値の分散
                between_vars.append(np.var(group_means, ddof=0))
                # グループ内分散: 各換気量内の気候間分散の平均
                within_vars.append(np.mean(group_within_vars))

        results[wall] = {
            'between': np.mean(between_vars),
            'within': np.mean(within_vars),
        }

    return results


def plot_between_within_variance(variable='rh', save=True):
    """
    グループ間分散 vs グループ内分散の棒グラフを作成
    """
    results = calc_between_within_variance(variable)

    fig, axes = plt.subplots(2, 2, figsize=(10, 8))
    axes = axes.flatten()

    colors = ['#1f77b4', '#ff7f0e']
    bar_labels = ['グループ間\n（換気量による差）', 'グループ内\n（気候による差）']

    for i, wall in enumerate(WALLS):
        ax = axes[i]
        between = results[wall]['between']
        within = results[wall]['within']

        x = np.arange(2)
        bars = ax.bar(x, [between, within], width=0.5, color=colors, alpha=0.8, edgecolor='black')

        ax.set_ylabel('分散', fontsize=11)
        ax.set_title(f'{WALL_NAMES[wall]}', fontsize=13)
        ax.set_xticks(x)
        ax.set_xticklabels(bar_labels, fontsize=10)
        ax.grid(axis='y', alpha=0.3)

        # 値をバーの上に表示
        for bar, val in zip(bars, [between, within]):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.002,
                    f'{val:.4f}', ha='center', va='bottom', fontsize=10)

        # 比率を表示
        if within > 0:
            ratio = between / within
            ax.text(0.95, 0.95, f'比率: {ratio:.1f}倍', transform=ax.transAxes,
                    ha='right', va='top', fontsize=11, fontweight='bold',
                    bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.suptitle(f'{VARIABLE_NAMES[variable]}振幅比：グループ間分散 vs グループ内分散', fontsize=14, y=1.02)
    plt.tight_layout()

    if save:
        output_path = OUTPUT_DIR / f'variance_{variable}_between_within.png'
        fig.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
        print(f'保存: {output_path}')
        plt.close(fig)
    else:
        plt.show()

    return results


def print_table(variable='rh'):
    """
    結果をテーブル形式で出力
    """
    results = calc_between_within_variance(variable)

    print(f'\n=== {VARIABLE_NAMES[variable]}振幅比：グループ間 vs グループ内分散 ===\n')
    print('| 壁構造 | グループ間 | グループ内 | 比率 |')
    print('|--------|------------|------------|------|')

    for wall in WALLS:
        b = results[wall]['between']
        w = results[wall]['within']
        ratio = b / w if w > 0 else float('inf')
        print(f"| {WALL_NAMES[wall]} | {b:.4f} | {w:.4f} | {ratio:.1f}倍 |")


def main():
    print("=" * 80)
    print("グループ間分散 vs グループ内分散の比較")
    print("=" * 80)

    # 相対湿度
    print('\n--- 相対湿度 (RH) ---')
    plot_between_within_variance('rh')
    print_table('rh')

    # 必要に応じて他の変数も
    # print('\n--- 絶対湿度 (AH) ---')
    # plot_between_within_variance('ah')
    # print_table('ah')

    # print('\n--- 温度 (TEMP) ---')
    # plot_between_within_variance('temp')
    # print_table('temp')


if __name__ == "__main__":
    main()
