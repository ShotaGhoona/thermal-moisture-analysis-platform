#!/usr/bin/env python3
"""
Excelにグラフを追加するスクリプト
各シートに対数X軸・反転の散布図を追加

Usage:
    python FFT-excel-chart.py ../output/1224/integrate-fft/all_spectrums.xlsx
"""

import sys
import argparse
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.chart import ScatterChart, Reference, Series
from openpyxl.chart.series import SeriesLabel
from openpyxl.chart.shapes import GraphicalProperties
from openpyxl.drawing.line import LineProperties
from openpyxl.chart.axis import ChartLines

# visualize-scriptからインポート
sys.path.insert(0, str(Path(__file__).parent / 'visualize-script'))
from config import CLIMATE_NAMES, OPENING_NAMES

# 壁材質の表示名
WALL_NAMES = {
    'w01-base': '基準壁',
    'w01': 'RC単層',
    'w02-inner': '内断熱',
    'w02': 'RC内断熱',
    'w03-outer': '外断熱',
    'w03': 'RC外断熱',
    'w04-hygro': '調湿材',
    'w04': 'RC内断熱+調湿',
    'w05-mud': '土壁',
    'w05': '土壁',
}

# =============================================================================
# Excel グラフ設定
# =============================================================================

# グラフサイズ
CHART_WIDTH = 18
CHART_HEIGHT = 15

# グラフスタイル (1-48)
CHART_STYLE = 2

# 線の太さ (EMU単位, 12700 = 1pt)
LINE_WIDTH = 12700

# グリッド線の色 (RGB hex)
GRIDLINE_COLOR = "D3D3D3"  # ライトグレー

# 凡例の位置 ('b'=下, 'r'=右, 't'=上, 'l'=左)
LEGEND_POSITION = 'b'

# X軸設定
X_AXIS_LOG_BASE = 10
X_AXIS_MIN = 0.1
X_AXIS_MAX = 100
X_AXIS_TITLE = "周期 [日]"

# Y軸タイトル
Y_AXIS_TITLE_AMP = "振幅"
Y_AXIS_TITLE_PHASE = "位相 [rad]"
Y_AXIS_TITLE_RATIO = "振幅比 [-]"
Y_AXIS_TITLE_DIFF = "位相差 [rad]"

# グラフ配置位置（列）
CHART_COL_ALL = "AV"       # 全パターン
CHART_COL_CLIMATE = "BG"   # 気候別
CHART_COL_OPENING = "BR"   # 換気量別
CHART_COL_WALL = "CC"      # 壁材質別

# グラフ配置位置（行間隔）
CHART_ROW_SPACING = 30

# =============================================================================
# データ列の定義（動的生成用）
# =============================================================================

def parse_column_groups(ws):
    """
    列名からグループを動的に生成
    列名形式: w01_o01_kyoto または w01-base_o01-base_kyoto
    Returns: (wall_groups, opening_groups, climate_groups)
    """
    max_col = ws.max_column

    # 列名を解析
    columns_info = []
    for col in range(2, max_col + 1):
        name = ws.cell(row=1, column=col).value
        if name:
            parts = name.split('_')
            if len(parts) >= 3:
                wall = parts[0]      # w01 or w01-base
                opening = parts[1]   # o01 or o01-base
                climate = parts[2]   # kyoto
                columns_info.append({
                    'col': col,
                    'wall': wall,
                    'opening': opening,
                    'climate': climate,
                    'name': name
                })

    # 壁材質別グループ（同じ壁材質の列をまとめる → 換気量比較用）
    wall_groups = {}
    for info in columns_info:
        wall = info['wall']
        if wall not in wall_groups:
            wall_groups[wall] = []
        wall_groups[wall].append(info['col'])

    # 換気量別グループ（同じ換気量の列をまとめる → 壁材質比較用）
    opening_groups = {}
    for info in columns_info:
        opening = info['opening']
        if opening not in opening_groups:
            opening_groups[opening] = []
        opening_groups[opening].append(info['col'])

    # 気候別グループ（同じ気候の列をまとめる）
    climate_groups = {}
    for info in columns_info:
        climate = info['climate']
        if climate not in climate_groups:
            climate_groups[climate] = []
        climate_groups[climate].append(info['col'])

    return wall_groups, opening_groups, climate_groups

# =============================================================================
# 関数
# =============================================================================


def create_chart(ws, sheet_name: str, columns: list, title_suffix: str, max_row: int):
    """グラフを作成するヘルパー関数"""
    chart = ScatterChart()
    chart.title = f"{sheet_name} {title_suffix}"
    chart.style = CHART_STYLE
    chart.width = CHART_WIDTH
    chart.height = CHART_HEIGHT

    x_values = Reference(ws, min_col=1, min_row=2, max_row=max_row)

    for col in columns:
        y_values = Reference(ws, min_col=col, min_row=2, max_row=max_row)
        series = Series(y_values, x_values, title_from_data=False)
        title_str = ws.cell(row=1, column=col).value
        series.title = SeriesLabel(v=title_str)
        series.smooth = False
        series.graphicalProperties.line.width = LINE_WIDTH
        chart.series.append(series)

    # グラフの枠線を消す
    chart.graphical_properties = GraphicalProperties()
    chart.graphical_properties.line = LineProperties(noFill=True)
    chart.rounded_corners = False

    # X軸の設定
    chart.x_axis.title = X_AXIS_TITLE
    chart.x_axis.scaling.logBase = X_AXIS_LOG_BASE
    chart.x_axis.scaling.orientation = "minMax"
    chart.x_axis.scaling.min = X_AXIS_MIN
    chart.x_axis.scaling.max = X_AXIS_MAX
    chart.x_axis.delete = False

    # Y軸の設定（シート名に応じてタイトルを変更）
    if "ratio" in sheet_name:
        chart.y_axis.title = Y_AXIS_TITLE_RATIO
        # 振幅比は0〜2の範囲を想定
        chart.y_axis.scaling.min = 0
        chart.y_axis.scaling.max = 2
    elif "diff" in sheet_name:
        chart.y_axis.title = Y_AXIS_TITLE_DIFF
        # 位相差は-π〜πの範囲
        chart.y_axis.scaling.min = -3.5
        chart.y_axis.scaling.max = 3.5
    elif "amp" in sheet_name:
        chart.y_axis.title = Y_AXIS_TITLE_AMP
    else:
        chart.y_axis.title = Y_AXIS_TITLE_PHASE
    chart.y_axis.delete = False

    # グリッド線を薄いグレーに
    gray_line = LineProperties(solidFill=GRIDLINE_COLOR)
    chart.x_axis.majorGridlines = ChartLines()
    chart.x_axis.majorGridlines.spPr = GraphicalProperties(ln=gray_line)
    chart.y_axis.majorGridlines = ChartLines()
    chart.y_axis.majorGridlines.spPr = GraphicalProperties(ln=gray_line)

    # 凡例の位置
    chart.legend.position = LEGEND_POSITION
    chart.legend.overlay = False

    return chart


def add_chart_to_sheet(ws, sheet_name: str, simple: bool = False):
    """シートにグラフを追加"""

    # データ範囲を取得（空データの行を除外）
    max_row = ws.max_row
    max_col = ws.max_column

    # 最終行が空かチェックして除外
    if ws.cell(row=max_row, column=2).value is None:
        max_row -= 1

    # === 1列目: 全パターン ===
    all_cols = list(range(2, max_col + 1))
    chart_all = create_chart(ws, sheet_name, all_cols, "(全パターン)", max_row)
    ws.add_chart(chart_all, f"{CHART_COL_ALL}2")

    # simpleモードの場合は全体グラフのみ
    if simple:
        return True

    # 列名からグループを動的に生成
    wall_groups, opening_groups, climate_groups = parse_column_groups(ws)

    # === 2列目: 気候別グラフ ===
    if len(climate_groups) > 0:
        for i, (climate_key, cols) in enumerate(sorted(climate_groups.items())):
            if len(cols) < 1:
                continue
            climate_name = CLIMATE_NAMES.get(climate_key, climate_key)
            row = 2 + i * CHART_ROW_SPACING
            chart = create_chart(ws, sheet_name, cols, f"({climate_name})", max_row)
            ws.add_chart(chart, f"{CHART_COL_CLIMATE}{row}")

    # === 3列目: 換気量別グラフ ===
    if len(opening_groups) > 0:
        for i, (opening_key, cols) in enumerate(sorted(opening_groups.items())):
            if len(cols) < 1:
                continue
            opening_name = OPENING_NAMES.get(opening_key, opening_key)
            row = 2 + i * CHART_ROW_SPACING
            chart = create_chart(ws, sheet_name, cols, f"({opening_name})", max_row)
            ws.add_chart(chart, f"{CHART_COL_OPENING}{row}")

    # === 4列目: 壁材質別グラフ ===
    if len(wall_groups) > 0:
        for i, (wall_key, cols) in enumerate(sorted(wall_groups.items())):
            if len(cols) < 1:
                continue
            wall_name = WALL_NAMES.get(wall_key, wall_key)
            row = 2 + i * CHART_ROW_SPACING
            chart = create_chart(ws, sheet_name, cols, f"({wall_name})", max_row)
            ws.add_chart(chart, f"{CHART_COL_WALL}{row}")

    return True


def main():
    parser = argparse.ArgumentParser(
        description='Excelにグラフを追加するスクリプト'
    )
    parser.add_argument('excel_path', help='対象のExcelファイル')
    parser.add_argument('--output', '-o', help='出力ファイル名（省略時は_chart付きで保存）')
    parser.add_argument('--simple', '-s', action='store_true', help='全体グラフのみ生成（壁材質別・換気量別グラフをスキップ）')

    args = parser.parse_args()

    excel_path = Path(args.excel_path)
    if not excel_path.exists():
        print(f"エラー: ファイルが見つかりません: {excel_path}")
        return 1

    # 出力先
    if args.output:
        output_path = Path(args.output)
    else:
        output_path = excel_path.parent / f"{excel_path.stem}_chart{excel_path.suffix}"

    print(f"読み込み: {excel_path}")
    wb = load_workbook(excel_path)

    print(f"シート数: {len(wb.sheetnames)}")

    for sheet_name in wb.sheetnames:
        print(f"  処理中: {sheet_name}")
        ws = wb[sheet_name]
        add_chart_to_sheet(ws, sheet_name, simple=args.simple)

    # 保存
    wb.save(output_path)
    print(f"保存完了: {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
