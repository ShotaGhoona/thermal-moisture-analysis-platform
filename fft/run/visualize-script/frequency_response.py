"""
周波数応答グラフ（全パターン比較）
"""

import matplotlib.pyplot as plt
from pathlib import Path
from config import *
from data_loader import parse_case_name, load_integrate_data


def plot_frequency_response_all(
    integrate_dir: Path,
    output_dir: Path,
    variable: str = 'room1_temp',
    value_type: str = 'amplitude'
):
    """
    全パターンの周波数応答を1つのグラフに描画

    Args:
        integrate_dir: integrate-fft ディレクトリ
        output_dir: 出力ディレクトリ
        variable: 変数名
        value_type: 'amplitude' or 'phase'
    """
    df = load_integrate_data(integrate_dir, variable, value_type)

    fig, ax = plt.subplots(figsize=FIGURE_SIZE_SINGLE, dpi=FIGURE_DPI)

    for case_name in df.columns:
        info = parse_case_name(case_name)
        color = WALL_COLORS.get(info['wall'], 'gray')
        label = f"{WALL_NAMES.get(info['wall'], info['wall'])} / {OPENING_NAMES.get(info['opening'], info['opening'])}"

        periods = df.index.values
        values = df[case_name].values

        ax.plot(periods, values, marker='o', markersize=4, label=label, color=color, alpha=0.7)

    ax.set_xscale('log')
    ax.set_xlabel('周期 [日]', fontsize=12)

    var_name = VARIABLE_NAMES.get(variable, variable)
    if value_type == 'amplitude':
        ax.set_ylabel(f'{var_name} 振幅', fontsize=12)
        title = f'周波数応答解析 - {var_name}振幅 - 全パターン比較'
    else:
        ax.set_ylabel(f'{var_name} 位相 [rad]', fontsize=12)
        title = f'周波数応答解析 - {var_name}位相 - 全パターン比較'

    ax.set_title(title, fontsize=14)
    ax.grid(True, alpha=0.3)
    ax.legend(bbox_to_anchor=(1.02, 1), loc='upper left', fontsize=8)
    ax.invert_xaxis()  # 長周期を左に

    plt.tight_layout()

    filename = f'周波数応答_{var_name}_{value_type}_全パターン比較.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path
