#!/usr/bin/env python3
"""
換気量ごとの振幅比のばらつきを計算するスクリプト

壁構造別・換気量別の分散を計算し、棒グラフで可視化する
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

OPENINGS = ['o03', 'o05', 'o01', 'o02', 'o04']  # 換気量大→小の順
OPENING_NAMES = {
    'o01': '標準換気',
    'o02': '弱換気',
    'o03': '強換気',
    'o04': '無換気',
    'o05': '中程度換気',
}
OPENING_VALUES = {
    'o01': 0.010,
    'o02': 0.005,
    'o03': 0.020,
    'o04': 0.000,
    'o05': 0.015,
}
OPENING_LABELS = ['強換気\n(0.020)', '中程度\n(0.015)', '標準\n(0.010)', '弱換気\n(0.005)', '無換気\n(0.000)']

VARIABLES = ['ah', 'rh', 'temp']
VARIABLE_NAMES = {
    'ah': '絶対湿度',
    'rh': '相対湿度',
    'temp': '温度',
}


def calc_variance_by_wall_opening(variable='ah'):
    """
    壁構造別・換気量別の分散を計算

    Returns:
        dict: {wall: {opening: variance}}
    """
    csv_path = DATA_DIR / f"ratio_{variable}_amplitude.csv"
    df = pd.read_csv(csv_path, encoding='utf-8-sig')

    results = {}

    for wall in WALLS:
        results[wall] = {}
        for opening in OPENINGS:
            # この壁構造・換気量に該当する列を抽出（気候条件でグループ化）
            cols = [c for c in df.columns
                    if c != 'period_days'
                    and c.startswith(f'{wall}_')
                    and f'_{opening}_' in c]

            if not cols:
                results[wall][opening] = np.nan
                continue

            data = df[cols].values
            # 各周期での気候条件間の分散を計算し、平均
            with np.errstate(all='ignore'):
                var_per_period = np.nanvar(data, axis=1)
                mean_var = np.nanmean(var_per_period)
            results[wall][opening] = mean_var

    return results


def plot_variance_by_wall(variable='ah', save=True):
    """
    壁構造別の棒グラフを4枚組で作成
    """
    results = calc_variance_by_wall_opening(variable)

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes = axes.flatten()

    x = np.arange(len(OPENINGS))
    width = 0.6
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']

    for i, wall in enumerate(WALLS):
        ax = axes[i]
        variances = [results[wall][o] for o in OPENINGS]

        bars = ax.bar(x, variances, width, color=colors[i], alpha=0.8, edgecolor='black')
        ax.set_xlabel('換気量パターン', fontsize=11)
        ax.set_ylabel('周期内分散', fontsize=11)
        ax.set_title(f'{WALL_NAMES[wall]}', fontsize=13)
        ax.set_xticks(x)
        ax.set_xticklabels(OPENING_LABELS, fontsize=9)
        ax.grid(axis='y', alpha=0.3)

        # 値をバーの上に表示
        for bar, val in zip(bars, variances):
            if not np.isnan(val):
                ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.0003,
                        f'{val:.4f}', ha='center', va='bottom', fontsize=8)

    plt.suptitle(f'{VARIABLE_NAMES[variable]}振幅比の周期内分散（壁構造別）', fontsize=14, y=1.02)
    plt.tight_layout()

    if save:
        output_path = OUTPUT_DIR / f'variance_{variable}_by_wall_opening.png'
        fig.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
        print(f'保存: {output_path}')
        plt.close(fig)
    else:
        plt.show()

    return results


def print_table(variable='ah'):
    """
    結果をテーブル形式で出力
    """
    results = calc_variance_by_wall_opening(variable)

    print(f'\n=== {VARIABLE_NAMES[variable]}振幅比の周期内分散 ===\n')

    # ヘッダー
    header = '| 壁構造 |'
    for o in OPENINGS:
        header += f' {OPENING_NAMES[o]} |'
    print(header)

    separator = '|--------|'
    for _ in OPENINGS:
        separator += '----------|'
    print(separator)

    # データ行
    for wall in WALLS:
        row = f'| {WALL_NAMES[wall]} |'
        for o in OPENINGS:
            val = results[wall][o]
            if np.isnan(val):
                row += ' - |'
            else:
                row += f' {val:.4f} |'
        print(row)


def main():
    print("=" * 80)
    print("換気量と振幅比ばらつきの関係分析（壁構造別）")
    print("=" * 80)

    # AHのグラフと表を出力
    print('\n--- 絶対湿度 (AH) ---')
    plot_variance_by_wall('ah')
    print_table('ah')

    # 必要に応じてRH, TEMPも
    # print('\n--- 相対湿度 (RH) ---')
    # plot_variance_by_wall('rh')
    # print_table('rh')

    # print('\n--- 温度 (TEMP) ---')
    # plot_variance_by_wall('temp')
    # print_table('temp')


if __name__ == "__main__":
    main()
