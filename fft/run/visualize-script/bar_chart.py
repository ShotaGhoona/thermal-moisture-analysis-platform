"""
周期別棒グラフ（特定周期での全パターン比較）
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from config import *
from data_loader import parse_case_name, load_integrate_data


def plot_bar_by_period(
    integrate_dir: Path,
    output_dir: Path,
    variable: str = 'room1_temp',
    target_period: float = 1.0  # 日周期
):
    """
    特定周期での振幅を棒グラフで比較
    """
    df = load_integrate_data(integrate_dir, variable, 'amplitude')

    # 最も近い周期を探す
    periods = df.index.values
    closest_idx = np.argmin(np.abs(periods - target_period))
    actual_period = periods[closest_idx]

    values = df.iloc[closest_idx]

    # パターン名を短縮してソート
    data = []
    for case_name, value in values.items():
        info = parse_case_name(case_name)
        data.append({
            'case': case_name,
            'wall': info['wall'],
            'opening': info['opening'],
            'climate': info['climate'],
            'value': value,
            'wall_name': WALL_NAMES.get(info['wall'], info['wall']),
            'opening_name': OPENING_NAMES.get(info['opening'], info['opening']),
        })

    data_df = pd.DataFrame(data)
    data_df = data_df.sort_values(['wall', 'opening'])

    fig, ax = plt.subplots(figsize=(max(10, len(data_df) * 0.5), 6), dpi=FIGURE_DPI)

    colors = [WALL_COLORS.get(w, 'gray') for w in data_df['wall']]
    bars = ax.bar(range(len(data_df)), data_df['value'], color=colors, alpha=0.8)

    ax.set_xticks(range(len(data_df)))
    labels = [f"{row['wall_name']}\n{row['opening_name']}" for _, row in data_df.iterrows()]
    ax.set_xticklabels(labels, rotation=45, ha='right', fontsize=8)

    var_name = VARIABLE_NAMES.get(variable, variable)
    ax.set_ylabel(f'{var_name} 振幅', fontsize=12)
    ax.set_title(f'周期{actual_period:.1f}日での振幅比較 - {var_name}', fontsize=14)
    ax.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()

    filename = f'棒グラフ_{var_name}_周期{actual_period:.1f}日.png'
    output_path = output_dir / filename
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()

    return output_path
