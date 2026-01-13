"""
データ読み込み・パース関数
"""

import pandas as pd
from pathlib import Path


def parse_case_name(case_name: str) -> dict:
    """ケース名をパースして壁構造・換気・気候を抽出"""
    parts = case_name.split('_')
    return {
        'wall': parts[0] if len(parts) > 0 else '',
        'opening': parts[1] if len(parts) > 1 else '',
        'climate': parts[2] if len(parts) > 2 else '',
    }


def load_integrate_data(integrate_dir: Path, variable: str, value_type: str = 'amplitude') -> pd.DataFrame:
    """
    統合CSVを読み込む

    Args:
        integrate_dir: integrate-fft ディレクトリ
        variable: 'room1_temp', 'room1_rh', 'room2_temp', 'room2_rh'
        value_type: 'amplitude' or 'phase'

    Returns:
        DataFrame (index: period_days, columns: case_names)
    """
    csv_path = integrate_dir / f'spectrum_{variable}_{value_type}.csv'
    if not csv_path.exists():
        raise FileNotFoundError(f"ファイルが見つかりません: {csv_path}")

    df = pd.read_csv(csv_path, index_col=0)
    return df


def get_available_cases(integrate_dir: Path) -> tuple:
    """
    利用可能なケース情報を取得

    Returns:
        (cases, climates, openings, walls): 各種セット
    """
    df = pd.read_csv(integrate_dir / 'spectrum_room1_temp_amplitude.csv', index_col=0)
    cases = df.columns.tolist()

    climates = set()
    openings = set()
    walls = set()

    for case in cases:
        parts = case.split('_')
        if len(parts) >= 3:
            walls.add(parts[0])
            openings.add(parts[1])
            climates.add(parts[2])

    return cases, climates, openings, walls
