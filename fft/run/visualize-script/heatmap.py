"""
ヒートマップ（パターン × 周期）
"""

import matplotlib.pyplot as plt
from pathlib import Path
from config import *
from data_loader import parse_case_name, load_integrate_data


def plot_heatmap(
    integrate_dir: Path,
    output_dir: Path,
    variable: str = 'room1_temp'
):
    """
    振幅のヒートマップ（行: パターン、列: 周期）
    """
    df = load_integrate_data(integrate_dir, variable, 'amplitude')

    # 転置して行がパターン、列が周期
    df_t = df.T

    # パターン名を短縮
    short_names = []
    for name in df_t.index:
        info = parse_case_name(name)
        wall_short = WALL_NAMES.get(info['wall'], info['wall'])
        opening_short = OPENING_NAMES.get(info['opening'], info['opening'])
        climate_short = CLIMATE_NAMES.get(info['climate'], info['climate'])
        short_names.append(f"{wall_short}/{opening_short}/{climate_short}")
    df_t.index = short_names

    # 周期を文字列に
    df_t.columns = [f"{p:.1f}日" for p in df_t.columns]

    fig, ax = plt.subplots(figsize=(12, max(6, len(df_t) * 0.4)), dpi=FIGURE_DPI)

    im = ax.imshow(df_t.values, aspect='auto', cmap='YlOrRd')

    ax.set_xticks(range(len(df_t.columns)))
    ax.set_xticklabels(df_t.columns, rotation=45, ha='right', fontsize=9)
    ax.set_yticks(range(len(df_t.index)))
    ax.set_yticklabels(df_t.index, fontsize=9)

    var_name = VARIABLE_NAMES.get(variable, variable)
    ax.set_title(f'振幅ヒートマップ - {var_name}', fontsize=14)
    ax.set_xlabel('周期', fontsize=12)
    ax.set_ylabel('パターン', fontsize=12)

    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('振幅', fontsize=10)

    plt.tight_layout()

    filename = f'ヒートマップ_{var_name}_振幅.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path
