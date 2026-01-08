"""
6パネル比較グラフ（温度・相対湿度・絶対湿度 × room1・room2）
"""

import matplotlib.pyplot as plt
from pathlib import Path
from config import *
from data_loader import parse_case_name, load_integrate_data


def plot_four_panel_comparison(
    integrate_dir: Path,
    output_dir: Path,
    group_by: str = 'wall',  # 'wall', 'opening', 'climate'
    filter_dict: dict = None  # 例: {'climate': 'kyoto', 'opening': 'o01-base'}
):
    """
    6パネル比較グラフ（室1温度、室1相対湿度、室1絶対湿度、室2温度、室2相対湿度、室2絶対湿度）
    """
    variables = ['room1_temp', 'room1_rh', 'room1_ah', 'room2_temp', 'room2_rh', 'room2_ah']

    fig, axes = plt.subplots(2, 3, figsize=(18, 10), dpi=FIGURE_DPI)
    axes = axes.flatten()

    if group_by == 'wall':
        colors = WALL_COLORS
        names = WALL_NAMES
        group_key = 'wall'
    elif group_by == 'opening':
        colors = OPENING_COLORS
        names = OPENING_NAMES
        group_key = 'opening'
    else:
        colors = CLIMATE_COLORS
        names = CLIMATE_NAMES
        group_key = 'climate'

    filter_dict = filter_dict or {}

    for idx, variable in enumerate(variables):
        ax = axes[idx]
        df = load_integrate_data(integrate_dir, variable, 'amplitude')

        plotted_groups = set()

        for case_name in df.columns:
            info = parse_case_name(case_name)

            # フィルタ適用
            skip = False
            for key, value in filter_dict.items():
                if info.get(key) != value:
                    skip = True
                    break
            if skip:
                continue

            group_value = info[group_key]
            color = colors.get(group_value, 'gray')
            label = names.get(group_value, group_value) if group_value not in plotted_groups else None
            plotted_groups.add(group_value)

            periods = df.index.values
            values = df[case_name].values

            ax.plot(periods, values, marker='o', markersize=4, linewidth=1.5,
                    label=label, color=color, alpha=0.8)

        ax.set_xscale('log')
        ax.set_xlabel('周期 [日]', fontsize=10)

        var_name = VARIABLE_NAMES.get(variable, variable)
        ax.set_ylabel(f'{var_name} 振幅', fontsize=10)
        ax.set_title(f'{var_name}', fontsize=12)
        ax.grid(True, alpha=0.3)
        ax.legend(loc='upper left', fontsize=8)
        ax.invert_xaxis()

    # 全体タイトル
    filter_str = ', '.join([f"{k}={v}" for k, v in filter_dict.items()]) if filter_dict else '全条件'
    group_name = {'wall': '壁構造', 'opening': '換気量', 'climate': '気候'}[group_by]
    fig.suptitle(f'6パネル周波数応答比較 - {group_name}別 ({filter_str})', fontsize=14)

    plt.tight_layout()

    filename = f'6パネル比較_{group_name}別_{filter_str.replace(", ", "_").replace("=", "")}.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path
