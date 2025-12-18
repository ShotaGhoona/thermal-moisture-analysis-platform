"""
可視化設定ファイル
"""

import matplotlib.pyplot as plt
import matplotlib

# =============================================================================
# 日本語フォント設定
# =============================================================================
matplotlib.rcParams['font.family'] = 'Hiragino Sans'  # macOS
# matplotlib.rcParams['font.family'] = 'Yu Gothic'    # Windows
matplotlib.rcParams['axes.unicode_minus'] = False

# =============================================================================
# グラフスタイル設定
# =============================================================================
FIGURE_DPI = 150
FIGURE_SIZE_SINGLE = (10, 6)
FIGURE_SIZE_DOUBLE = (14, 6)
FIGURE_SIZE_QUAD = (14, 10)

# カラーパレット（壁構造別）
WALL_COLORS = {
    'w01-base': '#1f77b4',    # 青: RC単体
    'w02-inner': '#ff7f0e',   # オレンジ: RC内断熱
    'w03-outer': '#2ca02c',   # 緑: RC外断熱
    'w04-hygro': '#d62728',   # 赤: RC内断熱+調湿
    'w05-mud': '#9467bd',     # 紫: 土壁
}

# カラーパレット（換気量別）
OPENING_COLORS = {
    'o01-base': '#1f77b4',    # 青: 基準換気
    'o02-low': '#ff7f0e',     # オレンジ: 低換気
    'o03-high': '#2ca02c',    # 緑: 高換気
    'o04-none': '#d62728',    # 赤: 無換気
    'o05-storage': '#9467bd', # 紫: 蔵換気
}

# カラーパレット（気候別）
CLIMATE_COLORS = {
    'kyoto': '#1f77b4',       # 青: 京都
    'okinawa': '#ff7f0e',     # オレンジ: 沖縄
    'sapporo': '#2ca02c',     # 緑: 札幌
}

# 壁構造の日本語名
WALL_NAMES = {
    'w01-base': 'RC単体',
    'w02-inner': 'RC内断熱',
    'w03-outer': 'RC外断熱',
    'w04-hygro': 'RC内断熱+調湿',
    'w05-mud': '土壁',
}

# 換気量の日本語名
OPENING_NAMES = {
    'o01-base': '基準換気',
    'o02-low': '低換気',
    'o03-high': '高換気',
    'o04-none': '無換気',
    'o05-storage': '蔵換気',
}

# 気候の日本語名
CLIMATE_NAMES = {
    'kyoto': '京都',
    'okinawa': '沖縄',
    'sapporo': '札幌',
}

# 変数の日本語名
VARIABLE_NAMES = {
    'room1_temp': '室1温度',
    'room2_temp': '室2温度',
    'room1_rh': '室1相対湿度',
    'room2_rh': '室2相対湿度',
}
