#!/usr/bin/env python3
"""
論文用グラフ生成スクリプト

呪文形式でグラフを定義し、matplotlibで画像を生成する

Usage:
    python generate_plots.py
"""

import sys
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
import numpy as np

# =============================================================================
# 設定
# =============================================================================

# 日本語フォント
matplotlib.rcParams['font.family'] = 'Hiragino Sans'
matplotlib.rcParams['axes.unicode_minus'] = False

# データディレクトリ（相対パス）
# fft/run → parent = fft
DATA_DIR = Path(__file__).parent.parent / "output" / "0126" / "integrate-fft"

# 出力ディレクトリ
# fft/run → ../../docs/paper/source/ratio-ah
OUTPUT_DIR = Path(__file__).parent.parent.parent / "docs" / "paper" / "source" / "ratio-rh"

# 図のサイズ・DPI
FIGURE_SIZE = (10, 6)
FIGURE_DPI = 300

# =============================================================================
# 欲しいグラフを定義（呪文リスト）
# =============================================================================
# 形式: "{data_type}_{variable}[@filter1][@filter2]..."
#
# data_type:
#   room1, room2  → spectrum_room{n}_{var}_{amp/phase}.csv
#   ratio         → ratio_{var}_amplitude.csv
#   diff          → diff_{var}_phase.csv
#
# variable:
#   temp, rh, ah
#
# 種類（room1/room2のみ）:
#   _amp  → amplitude
#   _phase → phase
#   省略時は _amp
#
# filter:
#   @kyoto, @okinawa, @sapporo  → 気候
#   @w01, @w02, @w04, @w05      → 壁構造
#   @o01, @o02, @o03, @o04, @o05 → 換気量
#
# 例:
#   "room1_temp_amp@kyoto"      → 室1温度振幅、京都のみ
#   "ratio_temp@w01"            → 温度振幅比、w01のみ
#   "diff_ah@kyoto@w01"         → 絶対湿度位相差、京都かつw01
#
# 複数グラフを1枚にまとめる場合はリストで指定:
#   ["ratio_temp@kyoto@w01", "ratio_temp@kyoto@w02", ...]
#   ファイル名は最初の呪文に "_multi" を付けたものになる

PLOTS = [
    # RC内断熱（w02）のみ、全換気量×全気候を1枚に
    "ratio_rh@w02",

    # # ==========================================================================
    # # 2フィルター版: 換気量ごとに全壁構造をまとめたグラフ
    # # ==========================================================================
    # ["ratio_temp@o01@w01", "ratio_temp@o01@w02", "ratio_temp@o01@w04", "ratio_temp@o01@w05"],
    # ["ratio_temp@o02@w01", "ratio_temp@o02@w02", "ratio_temp@o02@w04", "ratio_temp@o02@w05"],
    # ["ratio_temp@o03@w01", "ratio_temp@o03@w02", "ratio_temp@o03@w04", "ratio_temp@o03@w05"],
    # ["ratio_temp@o04@w01", "ratio_temp@o04@w02", "ratio_temp@o04@w04", "ratio_temp@o04@w05"],
    # ["ratio_temp@o05@w01", "ratio_temp@o05@w02", "ratio_temp@o05@w04", "ratio_temp@o05@w05"],

    # # ==========================================================================
    # # 壁構造ごとに全換気量・全地域をまとめたグラフ（既存）
    # # ==========================================================================
    # ["ratio_temp@w01@o01", "ratio_temp@w01@o02", "ratio_temp@w01@o03", "ratio_temp@w01@o04", "ratio_temp@w01@o05"],
    # ["ratio_temp@w02@o01", "ratio_temp@w02@o02", "ratio_temp@w02@o03", "ratio_temp@w02@o04", "ratio_temp@w02@o05"],
    # ["ratio_temp@w04@o01", "ratio_temp@w04@o02", "ratio_temp@w04@o03", "ratio_temp@w04@o04", "ratio_temp@w04@o05"],
    # ["ratio_temp@w05@o01", "ratio_temp@w05@o02", "ratio_temp@w05@o03", "ratio_temp@w05@o04", "ratio_temp@w05@o05"],

    # # ==========================================================================
    # # Step 1: 位相差の全体像を把握
    # # ==========================================================================
    # "diff_temp",      # 全パターンの温度位相差
    # "diff_ah",        # 全パターンの絶対湿度位相差
    # "diff_rh",        # 全パターンの相対湿度位相差

    # # ==========================================================================
    # # Step 2: 条件を絞って詳細分析
    # # ==========================================================================
    # "diff_temp@o04",  # 無換気条件（壁体のみの効果）
    # "diff_temp@w05",  # 土壁のみ（換気量の影響）
    # "diff_ah@o04",    # 無換気・絶対湿度

    # # ==========================================================================
    # # Step 3: 未探索の振幅比パターン
    # # ==========================================================================
    # "ratio_ah@o04",   # 無換気・絶対湿度
    # "ratio_temp@w05", # 土壁のみ

    # # ==========================================================================
    # # Step 4: 地域比較（7.3節用）
    # # ==========================================================================
    # ["diff_temp@kyoto@o04", "diff_temp@okinawa@o04", "diff_temp@sapporo@o04"],
    # ["ratio_temp@kyoto@o04", "ratio_temp@okinawa@o04", "ratio_temp@sapporo@o04"],

    # # ==========================================================================
    # # Step 5: 追加探索
    # # ==========================================================================
    # # RC内断熱 vs RC内断熱+調湿 比較
    # ["ratio_temp@w02", "ratio_temp@w04"],
    # ["diff_temp@w02", "diff_temp@w04"],
    # # 相対湿度の位相差（調湿材効果）
    # ["diff_rh@w02@o04", "diff_rh@w04@o04", "diff_rh@w05@o04"],

    # # ==========================================================================
    # # Step 6: 地域比較（同一壁構造）
    # # ==========================================================================
    # ["ratio_temp@w02@kyoto", "ratio_temp@w02@sapporo"],
    # ["ratio_ah@w02@kyoto", "ratio_ah@w02@sapporo"],

    # # ==========================================================================
    # # Step 7: 換気量の影響（壁構造別）
    # # ==========================================================================
    # ["ratio_temp@w01@o01", "ratio_temp@w01@o02", "ratio_temp@w01@o03", "ratio_temp@w01@o04", "ratio_temp@w01@o05"],
    # ["ratio_temp@w02@o01", "ratio_temp@w02@o02", "ratio_temp@w02@o03", "ratio_temp@w02@o04", "ratio_temp@w02@o05"],
    # ["ratio_ah@w01@o01", "ratio_ah@w01@o02", "ratio_ah@w01@o03", "ratio_ah@w01@o04", "ratio_ah@w01@o05"],
    # ["ratio_ah@w02@o01", "ratio_ah@w02@o02", "ratio_ah@w02@o03", "ratio_ah@w02@o04", "ratio_ah@w02@o05"],

    # # RC単層の特徴（沖縄データあり）
    # "ratio_temp@w01",
    # "ratio_ah@w01",
    # "diff_temp@w01",

    # # 相対湿度振幅比
    # ["ratio_rh@w01", "ratio_rh@w02", "ratio_rh@w04", "ratio_rh@w05"],

    # # ==========================================================================
    # # 6章用: 地域別・壁構造別・換気量別グラフ
    # # ==========================================================================
    # # 外気温度振幅（地域別）
    # ["room1_temp_amp@kyoto", "room1_temp_amp@okinawa", "room1_temp_amp@sapporo"],

    # # 温度振幅比（京都）
    # ["ratio_temp@kyoto@w01", "ratio_temp@kyoto@w02", "ratio_temp@kyoto@w04", "ratio_temp@kyoto@w05"],
    # ["ratio_temp@kyoto@o01", "ratio_temp@kyoto@o02", "ratio_temp@kyoto@o03", "ratio_temp@kyoto@o04", "ratio_temp@kyoto@o05"],
    # # 温度振幅比（沖縄）
    # ["ratio_temp@okinawa@w01", "ratio_temp@okinawa@w02", "ratio_temp@okinawa@w04", "ratio_temp@okinawa@w05"],
    # ["ratio_temp@okinawa@o01", "ratio_temp@okinawa@o02", "ratio_temp@okinawa@o03", "ratio_temp@okinawa@o04", "ratio_temp@okinawa@o05"],
    # # 温度振幅比（札幌）
    # ["ratio_temp@sapporo@w01", "ratio_temp@sapporo@w02", "ratio_temp@sapporo@w04", "ratio_temp@sapporo@w05"],
    # ["ratio_temp@sapporo@o01", "ratio_temp@sapporo@o02", "ratio_temp@sapporo@o03", "ratio_temp@sapporo@o04", "ratio_temp@sapporo@o05"],

    # # 相対湿度振幅比（京都）
    # ["ratio_rh@kyoto@w01", "ratio_rh@kyoto@w02", "ratio_rh@kyoto@w04", "ratio_rh@kyoto@w05"],
    # ["ratio_rh@kyoto@o01", "ratio_rh@kyoto@o02", "ratio_rh@kyoto@o03", "ratio_rh@kyoto@o04", "ratio_rh@kyoto@o05"],
    # # 相対湿度振幅比（沖縄）
    # ["ratio_rh@okinawa@w01", "ratio_rh@okinawa@w02", "ratio_rh@okinawa@w04", "ratio_rh@okinawa@w05"],
    # ["ratio_rh@okinawa@o01", "ratio_rh@okinawa@o02", "ratio_rh@okinawa@o03", "ratio_rh@okinawa@o04", "ratio_rh@okinawa@o05"],
    # # 相対湿度振幅比（札幌）
    # ["ratio_rh@sapporo@w01", "ratio_rh@sapporo@w02", "ratio_rh@sapporo@w04", "ratio_rh@sapporo@w05"],
    # ["ratio_rh@sapporo@o01", "ratio_rh@sapporo@o02", "ratio_rh@sapporo@o03", "ratio_rh@sapporo@o04", "ratio_rh@sapporo@o05"],

    # # 絶対湿度振幅比（京都）
    # ["ratio_ah@kyoto@w01", "ratio_ah@kyoto@w02", "ratio_ah@kyoto@w04", "ratio_ah@kyoto@w05"],
    # ["ratio_ah@kyoto@o01", "ratio_ah@kyoto@o02", "ratio_ah@kyoto@o03", "ratio_ah@kyoto@o04", "ratio_ah@kyoto@o05"],
    # # 絶対湿度振幅比（沖縄）
    # ["ratio_ah@okinawa@w01", "ratio_ah@okinawa@w02", "ratio_ah@okinawa@w04", "ratio_ah@okinawa@w05"],
    # ["ratio_ah@okinawa@o01", "ratio_ah@okinawa@o02", "ratio_ah@okinawa@o03", "ratio_ah@okinawa@o04", "ratio_ah@okinawa@o05"],
    # # 絶対湿度振幅比（札幌）
    # ["ratio_ah@sapporo@w01", "ratio_ah@sapporo@w02", "ratio_ah@sapporo@w04", "ratio_ah@sapporo@w05"],
    # ["ratio_ah@sapporo@o01", "ratio_ah@sapporo@o02", "ratio_ah@sapporo@o03", "ratio_ah@sapporo@o04", "ratio_ah@sapporo@o05"],

    # # ==========================================================================
    # # 7章用: 無換気条件
    # # ==========================================================================
    # "ratio_rh@o04",   # 相対湿度振幅比（無換気条件）
    # "ratio_temp@o04", # 温度振幅比（無換気条件）
]

# =============================================================================
# 表示名マッピング
# =============================================================================

WALL_NAMES = {
    'w01': 'RC単層',
    'w02': 'RC内断熱',
    'w04': 'RC内断熱+調湿',
    'w05': '土壁',
}

OPENING_NAMES = {
    'o01': '標準換気',
    'o02': '弱換気',
    'o03': '強換気',
    'o04': '無換気',
    'o05': '中程度換気',
}

CLIMATE_NAMES = {
    'kyoto': '京都',
    'okinawa': '沖縄',
    'sapporo': '札幌',
}

VARIABLE_NAMES = {
    'temp': '温度',
    'rh': '相対湿度',
    'ah': '絶対湿度',
}

DATA_TYPE_NAMES = {
    'room1': '室内',
    'room2': '室2',
    'ratio': '振幅比',
    'diff': '位相差',
}

# カラーパレット
COLORS = [
    '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
    '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf',
    '#aec7e8', '#ffbb78', '#98df8a', '#ff9896', '#c5b0d5',
]

# =============================================================================
# ヘルパー関数
# =============================================================================

def parse_spell(spell: str) -> dict:
    """
    呪文をパースして辞書に変換

    Returns:
        {
            'data_type': 'room1' | 'room2' | 'ratio' | 'diff',
            'variable': 'temp' | 'rh' | 'ah',
            'kind': 'amp' | 'phase',
            'filters': {'climate': [...], 'wall': [...], 'opening': [...]},
            'raw': 元の呪文文字列
        }
    """
    parts = spell.split('@')
    main_part = parts[0]
    filter_parts = parts[1:] if len(parts) > 1 else []

    # メイン部分を解析
    tokens = main_part.split('_')

    data_type = tokens[0]  # room1, room2, ratio, diff
    variable = tokens[1]   # temp, rh, ah

    # 種類（amp/phase）
    if len(tokens) >= 3:
        kind = tokens[2]
    else:
        # ratioはデフォルトでamp、diffはphase
        if data_type == 'ratio':
            kind = 'amp'
        elif data_type == 'diff':
            kind = 'phase'
        else:
            kind = 'amp'

    # フィルタを分類
    filters = {'climate': [], 'wall': [], 'opening': []}
    for f in filter_parts:
        if f in ['kyoto', 'okinawa', 'sapporo']:
            filters['climate'].append(f)
        elif f.startswith('w'):
            filters['wall'].append(f)
        elif f.startswith('o'):
            filters['opening'].append(f)

    return {
        'data_type': data_type,
        'variable': variable,
        'kind': kind,
        'filters': filters,
        'raw': spell,
    }


def get_csv_path(parsed: dict) -> Path:
    """パース結果からCSVファイルパスを取得"""
    data_type = parsed['data_type']
    variable = parsed['variable']
    kind = parsed['kind']

    if data_type in ['room1', 'room2']:
        kind_str = 'amplitude' if kind == 'amp' else 'phase'
        filename = f"spectrum_{data_type}_{variable}_{kind_str}.csv"
    elif data_type == 'ratio':
        filename = f"ratio_{variable}_amplitude.csv"
    elif data_type == 'diff':
        filename = f"diff_{variable}_phase.csv"
    else:
        raise ValueError(f"Unknown data_type: {data_type}")

    return DATA_DIR / filename


def filter_columns(df: pd.DataFrame, filters: dict) -> list:
    """フィルタ条件に合う列名を取得"""
    columns = [c for c in df.columns if c != 'period_days']

    filtered = []
    for col in columns:
        parts = col.split('_')
        if len(parts) < 3:
            continue

        wall = parts[0]
        opening = parts[1]
        climate = parts[2]

        # フィルタ適用
        if filters['climate'] and climate not in filters['climate']:
            continue
        if filters['wall'] and wall not in filters['wall']:
            continue
        if filters['opening'] and opening not in filters['opening']:
            continue

        filtered.append(col)

    return filtered


def make_legend_label(col: str) -> str:
    """列名から凡例ラベルを生成"""
    parts = col.split('_')
    if len(parts) < 3:
        return col

    wall = WALL_NAMES.get(parts[0], parts[0])
    opening = OPENING_NAMES.get(parts[1], parts[1])
    climate = CLIMATE_NAMES.get(parts[2], parts[2])

    return f"{wall} / {opening} / {climate}"


def make_title(parsed: dict) -> str:
    """グラフタイトルを生成"""
    data_type_name = DATA_TYPE_NAMES.get(parsed['data_type'], parsed['data_type'])
    var_name = VARIABLE_NAMES.get(parsed['variable'], parsed['variable'])

    if parsed['data_type'] in ['room1', 'room2']:
        kind_name = '振幅' if parsed['kind'] == 'amp' else '位相'
        title = f"{data_type_name}{var_name} {kind_name}"
    else:
        title = f"{var_name}{data_type_name}"

    # フィルタ情報を追加
    filter_strs = []
    for f in parsed['filters']['climate']:
        filter_strs.append(CLIMATE_NAMES.get(f, f))
    for f in parsed['filters']['wall']:
        filter_strs.append(WALL_NAMES.get(f, f))
    for f in parsed['filters']['opening']:
        filter_strs.append(OPENING_NAMES.get(f, f))

    if filter_strs:
        title += f" ({', '.join(filter_strs)})"

    return title


def make_ylabel(parsed: dict) -> str:
    """Y軸ラベルを生成"""
    if parsed['data_type'] == 'ratio':
        return '振幅比 [-]'
    elif parsed['data_type'] == 'diff':
        return '位相差 [rad]'
    elif parsed['kind'] == 'phase':
        return '位相 [rad]'
    else:
        var = parsed['variable']
        if var == 'temp':
            return '振幅 [°C]'
        elif var == 'rh':
            return '振幅 [%]'
        elif var == 'ah':
            return '振幅 [kg/kg]'
    return '値'


def make_filename(spell: str) -> str:
    """呪文からファイル名を生成"""
    return spell.replace('@', '_') + '.png'


def get_common_prefix(spells: list) -> str:
    """複数の呪文から共通接頭辞を取得"""
    if not spells:
        return ""
    if len(spells) == 1:
        return spells[0]

    # 最短の呪文の長さを取得
    min_len = min(len(s) for s in spells)

    # 文字ごとに比較して共通接頭辞を取得
    prefix = ""
    for i in range(min_len):
        char = spells[0][i]
        if all(s[i] == char for s in spells):
            prefix += char
        else:
            break

    return prefix


def make_multi_filename(spells: list) -> str:
    """複数の呪文から共通部分を抽出してファイル名を生成"""
    prefix = get_common_prefix(spells)

    # 末尾の数字を除去（w01, w02... → w）
    # 末尾が数字で終わっている場合、数字部分を削除
    while prefix and prefix[-1].isdigit():
        prefix = prefix[:-1]

    # 末尾の区切り文字も整理
    prefix = prefix.rstrip('@_-')

    if not prefix:
        prefix = spells[0]  # フォールバック

    return prefix.replace('@', '_') + '_multi.png'


# =============================================================================
# グラフ生成
# =============================================================================

def plot_single_ax(ax, spell: str) -> bool:
    """単一のaxにグラフを描画"""
    parsed = parse_spell(spell)
    csv_path = get_csv_path(parsed)

    if not csv_path.exists():
        print(f"  警告: ファイルが見つかりません: {csv_path}")
        return False

    df = pd.read_csv(csv_path, encoding='utf-8-sig')
    columns = filter_columns(df, parsed['filters'])

    if not columns:
        print(f"  警告: フィルタ条件に合う列がありません: {spell}")
        return False

    x = df['period_days'].values

    for i, col in enumerate(columns):
        y = df[col].values
        color = COLORS[i % len(COLORS)]
        label = make_legend_label(col)
        ax.plot(x, y, marker='o', markersize=3, color=color, label=label, linewidth=1.2)

    ax.set_xscale('log')
    ax.set_xlabel('周期 [日]', fontsize=10)
    ax.set_ylabel(make_ylabel(parsed), fontsize=10)
    ax.set_title(make_title(parsed), fontsize=11)
    ax.set_xlim(0.1, 400)

    if parsed['data_type'] == 'ratio':
        ax.set_ylim(0, 1.5)
    elif parsed['data_type'] == 'diff':
        ax.set_ylim(-3.5, 3.5)

    ax.grid(True, alpha=0.3)

    if len(columns) <= 6:
        ax.legend(loc='best', fontsize=7)
    else:
        ax.legend(loc='upper left', bbox_to_anchor=(1.02, 1), fontsize=6)

    return True


def generate_multi_plot(spells: list) -> Path:
    """複数の呪文を1枚のpngにまとめて生成"""
    n = len(spells)

    # レイアウト決定（2列）
    ncols = 2
    nrows = (n + 1) // 2

    fig, axes = plt.subplots(nrows, ncols, figsize=(12, 4 * nrows), dpi=FIGURE_DPI)
    axes = axes.flatten() if n > 1 else [axes]

    for i, spell in enumerate(spells):
        print(f"  サブプロット {i+1}/{n}: {spell}")
        plot_single_ax(axes[i], spell)

    # 余ったaxを非表示
    for j in range(n, len(axes)):
        axes[j].set_visible(False)

    plt.tight_layout()

    # ファイル名は共通部分から生成
    filename = make_multi_filename(spells)
    output_path = OUTPUT_DIR / filename

    fig.savefig(output_path, bbox_inches='tight', facecolor='white')
    plt.close(fig)

    return output_path


def generate_plot(spell: str) -> Path:
    """呪文からグラフを生成"""
    parsed = parse_spell(spell)
    csv_path = get_csv_path(parsed)

    if not csv_path.exists():
        print(f"  警告: ファイルが見つかりません: {csv_path}")
        return None

    # データ読み込み
    df = pd.read_csv(csv_path, encoding='utf-8-sig')

    # フィルタ適用
    columns = filter_columns(df, parsed['filters'])

    if not columns:
        print(f"  警告: フィルタ条件に合う列がありません: {spell}")
        return None

    # グラフ作成
    fig, ax = plt.subplots(figsize=FIGURE_SIZE, dpi=FIGURE_DPI)

    x = df['period_days'].values

    for i, col in enumerate(columns):
        y = df[col].values
        color = COLORS[i % len(COLORS)]
        label = make_legend_label(col)
        ax.plot(x, y, marker='o', markersize=4, color=color, label=label, linewidth=1.5)

    # 軸設定
    ax.set_xscale('log')
    ax.set_xlabel('周期 [日]', fontsize=12)
    ax.set_ylabel(make_ylabel(parsed), fontsize=12)
    ax.set_title(make_title(parsed), fontsize=14)

    # X軸範囲
    ax.set_xlim(0.1, 400)

    # Y軸範囲（データタイプに応じて）
    if parsed['data_type'] == 'ratio':
        ax.set_ylim(0, 1.5)
    elif parsed['data_type'] == 'diff':
        ax.set_ylim(-3.5, 3.5)

    # グリッド
    ax.grid(True, alpha=0.3)

    # 凡例
    if len(columns) <= 10:
        ax.legend(loc='best', fontsize=8)
    else:
        ax.legend(loc='upper left', bbox_to_anchor=(1.02, 1), fontsize=7)
        fig.subplots_adjust(right=0.75)

    # 保存
    output_path = OUTPUT_DIR / make_filename(spell)
    fig.savefig(output_path, bbox_inches='tight', facecolor='white')
    plt.close(fig)

    return output_path


# =============================================================================
# メイン
# =============================================================================

def main():
    print(f"データディレクトリ: {DATA_DIR}")
    print(f"出力ディレクトリ: {OUTPUT_DIR}")
    print(f"生成するグラフ数: {len(PLOTS)}")
    print()

    for item in PLOTS:
        if isinstance(item, list):
            # 複数グラフを1枚にまとめる
            print(f"生成中 (複数): {len(item)}個のグラフ")
            output_path = generate_multi_plot(item)
            if output_path:
                print(f"  -> {output_path.name}")
        else:
            # 単一グラフ
            print(f"生成中: {item}")
            output_path = generate_plot(item)
            if output_path:
                print(f"  -> {output_path.name}")

    print()
    print("完了")


if __name__ == "__main__":
    main()
