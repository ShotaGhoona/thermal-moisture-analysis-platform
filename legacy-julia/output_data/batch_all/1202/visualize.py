"""
熱水分同時移動シミュレーション結果の可視化
1パターン用
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np
from pathlib import Path

# 日本語フォント設定
plt.rcParams['font.family'] = ['Hiragino Sans', 'Yu Gothic', 'Meiryo', 'sans-serif']
plt.rcParams['axes.unicode_minus'] = False

def load_all_rooms(case_dir: Path) -> pd.DataFrame:
    """result_all_rooms.csvを読み込む"""
    df = pd.read_csv(case_dir / "result_all_rooms.csv", header=[0, 1], index_col=0)
    df.index = pd.to_datetime(df.index, format="%Y/%m/%d %H:%M")
    df.columns = ['_'.join(col).strip() for col in df.columns.values]
    return df

def load_wall(case_dir: Path) -> pd.DataFrame:
    """result_wall1.csvを読み込む"""
    df = pd.read_csv(case_dir / "result_wall1.csv", header=[0, 1], index_col=0)
    df.index = pd.to_datetime(df.index, format="%Y/%m/%d %H:%M")
    df.columns = ['_'.join(col).strip() for col in df.columns.values]
    return df

def plot_annual_temperature(df: pd.DataFrame, output_dir: Path):
    """年間の室温推移（外気温との比較）"""
    fig, ax = plt.subplots(figsize=(14, 5))

    # room1の温度をプロット（室内）
    ax.plot(df.index, df['room1_temp'], label='室温 (room1)', linewidth=0.5, alpha=0.8)

    ax.set_xlabel('日付')
    ax.set_ylabel('温度 [°C]')
    ax.set_title('年間室温推移')
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%m月'))
    ax.xaxis.set_major_locator(mdates.MonthLocator())

    plt.tight_layout()
    plt.savefig(output_dir / "01_annual_temperature.png", dpi=150)
    plt.close()
    print("保存: 01_annual_temperature.png")

def plot_annual_humidity(df: pd.DataFrame, output_dir: Path):
    """年間の湿度推移"""
    fig, axes = plt.subplots(2, 1, figsize=(14, 8), sharex=True)

    # 相対湿度
    axes[0].plot(df.index, df['room1_rh'] * 100, linewidth=0.5, alpha=0.8)
    axes[0].set_ylabel('相対湿度 [%]')
    axes[0].set_title('年間相対湿度推移 (room1)')
    axes[0].grid(True, alpha=0.3)
    axes[0].set_ylim(0, 100)

    # 絶対湿度
    axes[1].plot(df.index, df['room1_ah'] * 1000, linewidth=0.5, alpha=0.8, color='green')
    axes[1].set_ylabel('絶対湿度 [g/kg]')
    axes[1].set_xlabel('日付')
    axes[1].set_title('年間絶対湿度推移 (room1)')
    axes[1].grid(True, alpha=0.3)

    axes[1].xaxis.set_major_formatter(mdates.DateFormatter('%m月'))
    axes[1].xaxis.set_major_locator(mdates.MonthLocator())

    plt.tight_layout()
    plt.savefig(output_dir / "02_annual_humidity.png", dpi=150)
    plt.close()
    print("保存: 02_annual_humidity.png")

def plot_weekly_detail(df: pd.DataFrame, output_dir: Path):
    """代表週の詳細（冬・夏）"""
    # 冬（1月中旬）と夏（8月中旬）
    winter_start = "2022-01-10"
    winter_end = "2022-01-17"
    summer_start = "2022-08-10"
    summer_end = "2022-08-17"

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # 冬の温度
    winter_df = df.loc[winter_start:winter_end]
    axes[0, 0].plot(winter_df.index, winter_df['room1_temp'], label='室温', linewidth=1)
    axes[0, 0].set_title('冬季代表週（1/10-1/17）温度')
    axes[0, 0].set_ylabel('温度 [°C]')
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)
    axes[0, 0].xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))

    # 冬の湿度
    axes[0, 1].plot(winter_df.index, winter_df['room1_rh'] * 100, label='相対湿度', linewidth=1, color='blue')
    axes[0, 1].set_title('冬季代表週（1/10-1/17）相対湿度')
    axes[0, 1].set_ylabel('相対湿度 [%]')
    axes[0, 1].set_ylim(0, 100)
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)
    axes[0, 1].xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))

    # 夏の温度
    summer_df = df.loc[summer_start:summer_end]
    axes[1, 0].plot(summer_df.index, summer_df['room1_temp'], label='室温', linewidth=1, color='red')
    axes[1, 0].set_title('夏季代表週（8/10-8/17）温度')
    axes[1, 0].set_ylabel('温度 [°C]')
    axes[1, 0].set_xlabel('日付')
    axes[1, 0].legend()
    axes[1, 0].grid(True, alpha=0.3)
    axes[1, 0].xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))

    # 夏の湿度
    axes[1, 1].plot(summer_df.index, summer_df['room1_rh'] * 100, label='相対湿度', linewidth=1, color='orange')
    axes[1, 1].set_title('夏季代表週（8/10-8/17）相対湿度')
    axes[1, 1].set_ylabel('相対湿度 [%]')
    axes[1, 1].set_xlabel('日付')
    axes[1, 1].set_ylim(0, 100)
    axes[1, 1].legend()
    axes[1, 1].grid(True, alpha=0.3)
    axes[1, 1].xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))

    plt.tight_layout()
    plt.savefig(output_dir / "03_weekly_detail.png", dpi=150)
    plt.close()
    print("保存: 03_weekly_detail.png")

def plot_wall_profile(df_wall: pd.DataFrame, output_dir: Path):
    """壁体内部の温度分布プロファイル"""
    # 温度カラムを抽出
    temp_cols = [col for col in df_wall.columns if col.endswith('_temp')]

    # 代表時刻を選択（冬の夜、冬の昼、夏の夜、夏の昼）
    times = [
        ("2022-01-15 03:00", "冬・夜間 (1/15 3:00)"),
        ("2022-01-15 15:00", "冬・日中 (1/15 15:00)"),
        ("2022-08-15 03:00", "夏・夜間 (8/15 3:00)"),
        ("2022-08-15 15:00", "夏・日中 (8/15 15:00)"),
    ]

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes = axes.flatten()

    for idx, (time_str, label) in enumerate(times):
        try:
            # 最も近い時刻のデータを取得
            target_time = pd.to_datetime(time_str)
            nearest_idx = df_wall.index.get_indexer([target_time], method='nearest')[0]
            row = df_wall.iloc[nearest_idx]

            temps = [row[col] for col in temp_cols]
            x_positions = range(len(temps))

            axes[idx].plot(x_positions, temps, 'o-', linewidth=2, markersize=4)
            axes[idx].set_title(label)
            axes[idx].set_xlabel('壁体層番号')
            axes[idx].set_ylabel('温度 [°C]')
            axes[idx].grid(True, alpha=0.3)

            # x軸ラベル
            labels = ['外気'] + [f'{i}' for i in range(1, len(temps)-1)] + ['室内']
            axes[idx].set_xticks(x_positions)
            axes[idx].set_xticklabels(labels, rotation=45, fontsize=8)
        except Exception as e:
            axes[idx].text(0.5, 0.5, f'データなし\n{e}', ha='center', va='center')

    plt.tight_layout()
    plt.savefig(output_dir / "04_wall_profile.png", dpi=150)
    plt.close()
    print("保存: 04_wall_profile.png")

def plot_statistics_summary(df: pd.DataFrame, output_dir: Path):
    """統計サマリー"""
    stats = {
        '最高室温 [°C]': df['room1_temp'].max(),
        '最低室温 [°C]': df['room1_temp'].min(),
        '平均室温 [°C]': df['room1_temp'].mean(),
        '室温変動幅 [°C]': df['room1_temp'].max() - df['room1_temp'].min(),
        '平均相対湿度 [%]': df['room1_rh'].mean() * 100,
        '平均絶対湿度 [g/kg]': df['room1_ah'].mean() * 1000,
    }

    fig, ax = plt.subplots(figsize=(10, 6))

    bars = ax.barh(list(stats.keys()), list(stats.values()), color='steelblue')
    ax.set_xlabel('値')
    ax.set_title('年間統計サマリー (room1)')

    # 値をバーの横に表示
    for bar, val in zip(bars, stats.values()):
        ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height()/2,
                f'{val:.2f}', va='center', fontsize=10)

    ax.set_xlim(0, max(stats.values()) * 1.2)
    ax.grid(True, alpha=0.3, axis='x')

    plt.tight_layout()
    plt.savefig(output_dir / "05_statistics_summary.png", dpi=150)
    plt.close()
    print("保存: 05_statistics_summary.png")

    # テキストでも出力
    print("\n=== 統計サマリー ===")
    for key, val in stats.items():
        print(f"  {key}: {val:.2f}")

def plot_monthly_boxplot(df: pd.DataFrame, output_dir: Path):
    """月別の室温箱ひげ図"""
    df_copy = df.copy()
    df_copy['month'] = df_copy.index.month

    fig, ax = plt.subplots(figsize=(12, 6))

    monthly_data = [df_copy[df_copy['month'] == m]['room1_temp'].values for m in range(1, 13)]

    bp = ax.boxplot(monthly_data, labels=[f'{m}月' for m in range(1, 13)], patch_artist=True)

    # 色付け
    colors = plt.cm.coolwarm(np.linspace(0, 1, 12))
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)

    ax.set_xlabel('月')
    ax.set_ylabel('室温 [°C]')
    ax.set_title('月別室温分布 (room1)')
    ax.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()
    plt.savefig(output_dir / "06_monthly_boxplot.png", dpi=150)
    plt.close()
    print("保存: 06_monthly_boxplot.png")


def main():
    # パスの設定
    case_dir = Path(__file__).parent / "w01-base_o01-base_kyoto"
    output_dir = case_dir / "figures"
    output_dir.mkdir(exist_ok=True)

    print(f"ケースディレクトリ: {case_dir}")
    print(f"出力ディレクトリ: {output_dir}")
    print()

    # データ読み込み
    print("データ読み込み中...")
    df_rooms = load_all_rooms(case_dir)
    df_wall = load_wall(case_dir)
    print(f"  result_all_rooms: {len(df_rooms)} 行")
    print(f"  result_wall1: {len(df_wall)} 行")
    print()

    # グラフ作成
    print("グラフ作成中...")
    plot_annual_temperature(df_rooms, output_dir)
    plot_annual_humidity(df_rooms, output_dir)
    plot_weekly_detail(df_rooms, output_dir)
    plot_wall_profile(df_wall, output_dir)
    plot_statistics_summary(df_rooms, output_dir)
    plot_monthly_boxplot(df_rooms, output_dir)

    print()
    print(f"完了！グラフは {output_dir} に保存されました。")


if __name__ == "__main__":
    main()
