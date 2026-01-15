#!/usr/bin/env python3
"""
FFT結果の3D可視化スクリプト
参考: 散布図 + ワイヤーフレーム + 数値ラベル

Usage:
    python FFT-3d-visual.py ../output/0113/integrate-fft
"""

import sys
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# =============================================================================
# 設定
# =============================================================================

# 壁材質の定義
WALL_TYPES = ['w01-base', 'w02-inner', 'w03-outer', 'w04-hygro']
WALL_NAMES = {
    'w01-base': 'Base',
    'w02-inner': 'Inner',
    'w03-outer': 'Outer',
    'w04-hygro': 'Hygro',
}
WALL_INDICES = {w: i for i, w in enumerate(WALL_TYPES)}

# 換気量の定義
OPENING_TYPES = ['o01-base', 'o02-low', 'o03-high', 'o04-none', 'o05-storage']
OPENING_NAMES = {
    'o01-base': 'Base',
    'o02-low': 'Low',
    'o03-high': 'High',
    'o04-none': 'None',
    'o05-storage': 'Storage',
}
OPENING_INDICES = {o: i for i, o in enumerate(OPENING_TYPES)}

# 地域の定義
CLIMATE_TYPES = ['kyoto', 'okinawa', 'sapporo']
CLIMATE_NAMES = {
    'kyoto': 'Kyoto',
    'okinawa': 'Okinawa',
    'sapporo': 'Sapporo',
}
CLIMATE_INDICES = {c: i for i, c in enumerate(CLIMATE_TYPES)}

# プロット設定
FIGURE_DPI = 300
plt.rcParams['font.size'] = 12

# =============================================================================
# 関数
# =============================================================================

def load_amplitude_data(csv_path: Path) -> pd.DataFrame:
    """振幅CSVを読み込む"""
    df = pd.read_csv(csv_path, index_col=0, encoding='utf-8-sig')
    df = df.dropna(how='all')
    return df


def parse_case_name(case_name: str) -> tuple:
    """ケース名からwall, opening, climateを抽出"""
    parts = case_name.split('_')
    if len(parts) >= 3:
        return parts[0], parts[1], parts[2]
    return None, None, None


def detect_data_pattern(df: pd.DataFrame) -> str:
    """
    データパターンを検出
    Returns: 'wall_opening' or 'opening_climate'
    """
    walls = set()
    openings = set()
    climates = set()

    for col in df.columns:
        wall, opening, climate = parse_case_name(col)
        if wall:
            walls.add(wall)
        if opening:
            openings.add(opening)
        if climate:
            climates.add(climate)

    # 壁材質が複数 → wall_opening パターン
    if len(walls) > 1:
        return 'wall_opening'
    # 地域が複数 → opening_climate パターン
    elif len(climates) > 1:
        return 'opening_climate'
    else:
        return 'wall_opening'


def create_3d_matrix(df: pd.DataFrame) -> tuple:
    """
    データを壁材質×換気量の行列に変換（特定周期用）
    Returns: Z[wall_idx, opening_idx]
    """
    n_walls = len(WALL_TYPES)
    n_openings = len(OPENING_TYPES)

    # 各周期について行列を作成
    periods = df.index.values
    matrices = {}

    for period in periods:
        Z = np.full((n_walls, n_openings), np.nan)

        for col in df.columns:
            wall, opening, _ = parse_case_name(col)
            if wall in WALL_INDICES and opening in OPENING_INDICES:
                w_idx = WALL_INDICES[wall]
                o_idx = OPENING_INDICES[opening]
                Z[w_idx, o_idx] = df.loc[period, col]

        matrices[period] = Z

    return matrices, periods


def create_3d_matrix_climate(df: pd.DataFrame) -> tuple:
    """
    データを換気量×地域の行列に変換（特定周期用）
    Returns: Z[opening_idx, climate_idx]
    """
    openings_in_data = []
    climates_in_data = []

    for col in df.columns:
        _, opening, climate = parse_case_name(col)
        if opening and opening not in openings_in_data:
            openings_in_data.append(opening)
        if climate and climate not in climates_in_data:
            climates_in_data.append(climate)

    # ソート
    openings_in_data = [o for o in OPENING_TYPES if o in openings_in_data]
    climates_in_data = [c for c in CLIMATE_TYPES if c in climates_in_data]

    n_openings = len(openings_in_data)
    n_climates = len(climates_in_data)

    opening_idx_map = {o: i for i, o in enumerate(openings_in_data)}
    climate_idx_map = {c: i for i, c in enumerate(climates_in_data)}

    periods = df.index.values
    matrices = {}

    for period in periods:
        Z = np.full((n_openings, n_climates), np.nan)

        for col in df.columns:
            _, opening, climate = parse_case_name(col)
            if opening in opening_idx_map and climate in climate_idx_map:
                o_idx = opening_idx_map[opening]
                c_idx = climate_idx_map[climate]
                Z[o_idx, c_idx] = df.loc[period, col]

        matrices[period] = Z

    return matrices, periods, openings_in_data, climates_in_data


def plot_3d_for_period(df: pd.DataFrame, output_dir: Path, var_name: str, target_period: float):
    """特定周期の3Dプロット（壁材質×換気量×振幅）"""

    matrices, periods = create_3d_matrix(df)

    if target_period not in matrices:
        print(f"  周期 {target_period} がデータにありません")
        return

    Z = matrices[target_period]

    # X: 換気量インデックス, Y: 壁材質インデックス
    x = np.arange(len(OPENING_TYPES))
    y = np.arange(len(WALL_TYPES))
    Xg, Yg = np.meshgrid(x, y)

    fig = plt.figure(figsize=(10, 8), dpi=FIGURE_DPI)
    ax = fig.add_subplot(111, projection='3d')

    # 散布図（点）
    ax.scatter(
        Xg, Yg, Z,
        color='black',
        s=80,
        depthshade=True,
        label='Data points'
    )

    # ワイヤーフレーム
    ax.plot_wireframe(
        Xg, Yg, Z,
        color='gray',
        linewidth=1.2
    )

    # 数値ラベル
    for i in range(len(WALL_TYPES)):
        for j in range(len(OPENING_TYPES)):
            if not np.isnan(Z[i, j]):
                ax.text(
                    Xg[i, j],
                    Yg[i, j],
                    Z[i, j] + Z.max() * 0.03,
                    f"{Z[i, j]:.3g}",
                    ha='center',
                    va='bottom',
                    fontsize=9
                )

    # 軸ラベル
    ax.set_xlabel('Ventilation', labelpad=12)
    ax.set_ylabel('Wall type', labelpad=12)
    ax.text2D(-0.08, 0.5, "Amplitude", transform=ax.transAxes,
              rotation=90, va='center', ha='center', fontsize=12)

    # X軸（換気量）ラベル
    ax.set_xticks(x)
    ax.set_xticklabels([OPENING_NAMES[o] for o in OPENING_TYPES], fontsize=10)

    # Y軸（壁材質）ラベル
    ax.set_yticks(y)
    ax.set_yticklabels([WALL_NAMES[w] for w in WALL_TYPES], fontsize=10)

    # Z軸範囲
    z_min = np.nanmin(Z)
    z_max = np.nanmax(Z)
    ax.set_zlim(z_min * 0.9, z_max * 1.1)

    ax.set_title(f'{var_name} - Period: {target_period} days', fontsize=14, fontweight='bold')
    ax.view_init(elev=25, azim=225)

    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_period{target_period}.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def plot_3d_all_periods(df: pd.DataFrame, output_dir: Path, var_name: str):
    """全周期を1枚にまとめた3Dプロット"""

    matrices, periods = create_3d_matrix(df)

    # 周期を数値に変換
    period_values = np.array([float(p) for p in periods])

    n_walls = len(WALL_TYPES)
    n_openings = len(OPENING_TYPES)

    fig = plt.figure(figsize=(12, 9), dpi=FIGURE_DPI)
    ax = fig.add_subplot(111, projection='3d')

    # X: 換気量, Y: 周期(log), Z: 振幅
    # 各壁材質ごとに色を変えてプロット
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']

    for w_idx, wall_type in enumerate(WALL_TYPES):
        x_data = []
        y_data = []
        z_data = []

        for o_idx, opening_type in enumerate(OPENING_TYPES):
            for period in periods:
                Z = matrices[period]
                if not np.isnan(Z[w_idx, o_idx]):
                    x_data.append(o_idx)
                    y_data.append(np.log10(float(period)))
                    z_data.append(Z[w_idx, o_idx])

        # 散布図
        ax.scatter(
            x_data, y_data, z_data,
            color=colors[w_idx],
            s=50,
            label=WALL_NAMES[wall_type],
            alpha=0.8
        )

    # 軸ラベル
    ax.set_xlabel('Ventilation', labelpad=12)
    ax.set_ylabel('log10(Period [days])', labelpad=12)
    ax.text2D(-0.08, 0.5, "Amplitude", transform=ax.transAxes,
              rotation=90, va='center', ha='center', fontsize=12)

    # X軸（換気量）ラベル
    ax.set_xticks(range(n_openings))
    ax.set_xticklabels([OPENING_NAMES[o] for o in OPENING_TYPES], fontsize=10)

    ax.legend(loc='upper left', fontsize=10)
    ax.set_title(f'{var_name} - All Periods', fontsize=14, fontweight='bold')
    ax.view_init(elev=20, azim=225)

    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_all.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def plot_3d_heatmap_style(df: pd.DataFrame, output_dir: Path, var_name: str):
    """
    壁材質×換気量の行列を周期ごとにサーフェスで表示
    X: 換気量, Y: 壁材質, Z: 振幅
    """
    matrices, periods = create_3d_matrix(df)

    # 代表的な周期を選択
    target_periods = [1.0, 7.0, 30.0, 90.0]

    fig = plt.figure(figsize=(14, 12), dpi=FIGURE_DPI)

    for idx, target_period in enumerate(target_periods):
        if target_period not in matrices:
            continue

        Z = matrices[target_period]

        ax = fig.add_subplot(2, 2, idx + 1, projection='3d')

        x = np.arange(len(OPENING_TYPES))
        y = np.arange(len(WALL_TYPES))
        Xg, Yg = np.meshgrid(x, y)

        # 散布図
        ax.scatter(
            Xg, Yg, Z,
            color='black',
            s=60,
            depthshade=True
        )

        # ワイヤーフレーム
        ax.plot_wireframe(
            Xg, Yg, Z,
            color='gray',
            linewidth=1.0
        )

        # 数値ラベル
        for i in range(len(WALL_TYPES)):
            for j in range(len(OPENING_TYPES)):
                if not np.isnan(Z[i, j]):
                    ax.text(
                        Xg[i, j],
                        Yg[i, j],
                        Z[i, j] + np.nanmax(Z) * 0.05,
                        f"{Z[i, j]:.2g}",
                        ha='center',
                        va='bottom',
                        fontsize=8
                    )

        # 軸設定
        ax.set_xlabel('Ventilation', labelpad=10)
        ax.set_ylabel('Wall type', labelpad=10)

        ax.set_xticks(x)
        ax.set_xticklabels([OPENING_NAMES[o] for o in OPENING_TYPES], fontsize=8, rotation=20)
        ax.set_yticks(y)
        ax.set_yticklabels([WALL_NAMES[w] for w in WALL_TYPES], fontsize=8)

        ax.set_title(f'Period: {target_period} days', fontsize=12, fontweight='bold')
        ax.view_init(elev=25, azim=225)

    fig.suptitle(f'{var_name}', fontsize=14, fontweight='bold')
    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_periods.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def plot_3d_climate_periods(df: pd.DataFrame, output_dir: Path, var_name: str):
    """
    換気量×地域パターン用の3Dプロット
    """
    matrices, periods, openings, climates = create_3d_matrix_climate(df)

    target_periods = [1.0, 7.0, 30.0, 90.0]
    target_periods = [p for p in target_periods if p in matrices]

    if not target_periods:
        print(f"  対象周期がありません")
        return

    fig = plt.figure(figsize=(14, 12), dpi=FIGURE_DPI)

    for idx, target_period in enumerate(target_periods):
        Z = matrices[target_period]

        ax = fig.add_subplot(2, 2, idx + 1, projection='3d')

        x = np.arange(len(climates))
        y = np.arange(len(openings))
        Xg, Yg = np.meshgrid(x, y)

        # 散布図
        ax.scatter(
            Xg, Yg, Z,
            color='black',
            s=60,
            depthshade=True
        )

        # ワイヤーフレーム
        ax.plot_wireframe(
            Xg, Yg, Z,
            color='gray',
            linewidth=1.0
        )

        # 数値ラベル
        for i in range(len(openings)):
            for j in range(len(climates)):
                if not np.isnan(Z[i, j]):
                    ax.text(
                        Xg[i, j],
                        Yg[i, j],
                        Z[i, j] + np.nanmax(Z) * 0.05,
                        f"{Z[i, j]:.2g}",
                        ha='center',
                        va='bottom',
                        fontsize=8
                    )

        # 軸設定
        ax.set_xlabel('Climate', labelpad=10)
        ax.set_ylabel('Ventilation', labelpad=10)

        ax.set_xticks(x)
        ax.set_xticklabels([CLIMATE_NAMES.get(c, c) for c in climates], fontsize=9)
        ax.set_yticks(y)
        ax.set_yticklabels([OPENING_NAMES.get(o, o) for o in openings], fontsize=9)

        ax.set_title(f'Period: {target_period} days', fontsize=12, fontweight='bold')
        ax.view_init(elev=25, azim=225)

    fig.suptitle(f'{var_name}', fontsize=14, fontweight='bold')
    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_periods.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def plot_3d_climate_single(df: pd.DataFrame, output_dir: Path, var_name: str, target_period: float):
    """
    換気量×地域パターン用の単一周期3Dプロット
    """
    matrices, periods, openings, climates = create_3d_matrix_climate(df)

    if target_period not in matrices:
        print(f"  周期 {target_period} がデータにありません")
        return

    Z = matrices[target_period]

    fig = plt.figure(figsize=(10, 8), dpi=FIGURE_DPI)
    ax = fig.add_subplot(111, projection='3d')

    x = np.arange(len(climates))
    y = np.arange(len(openings))
    Xg, Yg = np.meshgrid(x, y)

    # 散布図
    ax.scatter(
        Xg, Yg, Z,
        color='black',
        s=80,
        depthshade=True
    )

    # ワイヤーフレーム
    ax.plot_wireframe(
        Xg, Yg, Z,
        color='gray',
        linewidth=1.2
    )

    # 数値ラベル
    for i in range(len(openings)):
        for j in range(len(climates)):
            if not np.isnan(Z[i, j]):
                ax.text(
                    Xg[i, j],
                    Yg[i, j],
                    Z[i, j] + np.nanmax(Z) * 0.03,
                    f"{Z[i, j]:.3g}",
                    ha='center',
                    va='bottom',
                    fontsize=9
                )

    # 軸設定
    ax.set_xlabel('Climate', labelpad=12)
    ax.set_ylabel('Ventilation', labelpad=12)
    ax.text2D(-0.08, 0.5, "Amplitude", transform=ax.transAxes,
              rotation=90, va='center', ha='center', fontsize=12)

    ax.set_xticks(x)
    ax.set_xticklabels([CLIMATE_NAMES.get(c, c) for c in climates], fontsize=10)
    ax.set_yticks(y)
    ax.set_yticklabels([OPENING_NAMES.get(o, o) for o in openings], fontsize=10)

    ax.set_title(f'{var_name} - Period: {target_period} days', fontsize=14, fontweight='bold')
    ax.view_init(elev=25, azim=225)

    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_period{target_period}.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def plot_3d_climate_all(df: pd.DataFrame, output_dir: Path, var_name: str):
    """
    換気量×地域パターン用の全周期散布図
    """
    matrices, periods, openings, climates = create_3d_matrix_climate(df)

    fig = plt.figure(figsize=(12, 9), dpi=FIGURE_DPI)
    ax = fig.add_subplot(111, projection='3d')

    colors = plt.cm.tab10(np.linspace(0, 1, len(openings)))

    for o_idx, opening in enumerate(openings):
        x_data = []
        y_data = []
        z_data = []

        for c_idx, climate in enumerate(climates):
            for period in periods:
                Z = matrices[period]
                if not np.isnan(Z[o_idx, c_idx]):
                    x_data.append(c_idx)
                    y_data.append(np.log10(float(period)))
                    z_data.append(Z[o_idx, c_idx])

        ax.scatter(
            x_data, y_data, z_data,
            color=colors[o_idx],
            s=50,
            label=OPENING_NAMES.get(opening, opening),
            alpha=0.8
        )

    ax.set_xlabel('Climate', labelpad=12)
    ax.set_ylabel('log10(Period [days])', labelpad=12)
    ax.text2D(-0.08, 0.5, "Amplitude", transform=ax.transAxes,
              rotation=90, va='center', ha='center', fontsize=12)

    ax.set_xticks(range(len(climates)))
    ax.set_xticklabels([CLIMATE_NAMES.get(c, c) for c in climates], fontsize=10)

    ax.legend(loc='upper left', fontsize=10)
    ax.set_title(f'{var_name} - All Periods', fontsize=14, fontweight='bold')
    ax.view_init(elev=20, azim=225)

    plt.tight_layout()

    output_path = output_dir / f'3d_{var_name}_all.png'
    plt.savefig(output_path, dpi=FIGURE_DPI, bbox_inches='tight')
    plt.close()
    print(f"  保存: {output_path.name}")


def main():
    parser = argparse.ArgumentParser(
        description='FFT結果の3D可視化スクリプト'
    )
    parser.add_argument('input_dir', help='integrate-fftディレクトリ')
    parser.add_argument('--output-dir', '-o', help='出力ディレクトリ（省略時は入力と同じ）')

    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    # デフォルト出力先: 同階層の3d-visual
    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = input_dir.parent / '3d-visual'

    if not input_dir.exists():
        print(f"エラー: ディレクトリが見つかりません: {input_dir}")
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("FFT 3D可視化")
    print(f"入力: {input_dir}")
    print(f"出力: {output_dir}")
    print("=" * 60)

    # 処理対象
    targets = [
        ('spectrum_room1_temp_amplitude.csv', 'room1_temp'),
        ('spectrum_room1_rh_amplitude.csv', 'room1_rh'),
        ('spectrum_room1_ah_amplitude.csv', 'room1_ah'),
        ('spectrum_room2_temp_amplitude.csv', 'room2_temp'),
        ('spectrum_room2_rh_amplitude.csv', 'room2_rh'),
        ('spectrum_room2_ah_amplitude.csv', 'room2_ah'),
    ]

    for csv_name, var_name in targets:
        csv_path = input_dir / csv_name
        if not csv_path.exists():
            print(f"スキップ: {csv_name}")
            continue

        print(f"\n処理中: {var_name}")

        df = load_amplitude_data(csv_path)

        # データパターンを検出
        pattern = detect_data_pattern(df)
        print(f"  パターン: {pattern}")

        if pattern == 'opening_climate':
            # 換気量×地域パターン
            plot_3d_climate_periods(df, output_dir, var_name)
            plot_3d_climate_all(df, output_dir, var_name)
            for period in [1.0, 90.0]:
                plot_3d_climate_single(df, output_dir, var_name, period)
        else:
            # 壁材質×換気量パターン
            plot_3d_heatmap_style(df, output_dir, var_name)
            plot_3d_all_periods(df, output_dir, var_name)
            for period in [1.0, 90.0]:
                plot_3d_for_period(df, output_dir, var_name, period)

    print("\n" + "=" * 60)
    print("完了")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
