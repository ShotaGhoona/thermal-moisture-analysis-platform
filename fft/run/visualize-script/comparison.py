"""
壁構造別・換気量別比較グラフ
"""

import matplotlib.pyplot as plt
from pathlib import Path
from config import *
from data_loader import parse_case_name, load_integrate_data


def plot_comparison_by_wall(
    integrate_dir: Path,
    output_dir: Path,
    variable: str = 'room1_temp',
    climate: str = 'kyoto',
    opening: str = 'o01-base'
):
    """
    壁構造別の周波数応答比較（換気・気候を固定）
    """
    df = load_integrate_data(integrate_dir, variable, 'amplitude')

    fig, ax = plt.subplots(figsize=FIGURE_SIZE_SINGLE, dpi=FIGURE_DPI)

    for case_name in df.columns:
        info = parse_case_name(case_name)

        # 指定した気候・換気のみ抽出
        if info['climate'] != climate or info['opening'] != opening:
            continue

        color = WALL_COLORS.get(info['wall'], 'gray')
        label = WALL_NAMES.get(info['wall'], info['wall'])

        periods = df.index.values
        values = df[case_name].values

        ax.plot(periods, values, marker='o', markersize=6, linewidth=2,
                label=label, color=color)

    ax.set_xscale('log')
    ax.set_xlabel('周期 [日]', fontsize=12)

    var_name = VARIABLE_NAMES.get(variable, variable)
    ax.set_ylabel(f'{var_name} 振幅', fontsize=12)

    climate_name = CLIMATE_NAMES.get(climate, climate)
    opening_name = OPENING_NAMES.get(opening, opening)
    ax.set_title(f'壁構造別比較 - {var_name} - {climate_name} / {opening_name}', fontsize=14)

    ax.grid(True, alpha=0.3)
    ax.legend(loc='upper left', fontsize=10)
    ax.invert_xaxis()

    plt.tight_layout()

    filename = f'壁構造別比較_{var_name}_{climate_name}_{opening_name}.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path


def plot_comparison_by_opening(
    integrate_dir: Path,
    output_dir: Path,
    variable: str = 'room1_rh',
    climate: str = 'kyoto',
    wall: str = 'w01-base'
):
    """
    換気量別の周波数応答比較（壁構造・気候を固定）
    """
    df = load_integrate_data(integrate_dir, variable, 'amplitude')

    fig, ax = plt.subplots(figsize=FIGURE_SIZE_SINGLE, dpi=FIGURE_DPI)

    for case_name in df.columns:
        info = parse_case_name(case_name)

        # 指定した気候・壁構造のみ抽出
        if info['climate'] != climate or info['wall'] != wall:
            continue

        color = OPENING_COLORS.get(info['opening'], 'gray')
        label = OPENING_NAMES.get(info['opening'], info['opening'])

        periods = df.index.values
        values = df[case_name].values

        ax.plot(periods, values, marker='o', markersize=6, linewidth=2,
                label=label, color=color)

    ax.set_xscale('log')
    ax.set_xlabel('周期 [日]', fontsize=12)

    var_name = VARIABLE_NAMES.get(variable, variable)
    ax.set_ylabel(f'{var_name} 振幅', fontsize=12)

    climate_name = CLIMATE_NAMES.get(climate, climate)
    wall_name = WALL_NAMES.get(wall, wall)
    ax.set_title(f'換気量別比較 - {var_name} - {climate_name} / {wall_name}', fontsize=14)

    ax.grid(True, alpha=0.3)
    ax.legend(loc='upper left', fontsize=10)
    ax.invert_xaxis()

    plt.tight_layout()

    filename = f'換気量別比較_{var_name}_{climate_name}_{wall_name}.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path
