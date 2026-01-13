"""
FFT特徴量データの読み込みとPyTorch Dataset作成
"""
import pandas as pd
import numpy as np
import torch
from torch.utils.data import Dataset
from typing import Tuple, List, Dict
from config import FEATURE_FILES, VENTILATION_LABELS, PERIOD_BINS


def extract_ventilation_label(case_name: str) -> int:
    """ケース名から換気量ラベルを抽出
    例: w01-base_o02-low_kyoto -> 1 (low)
    """
    for key, label in VENTILATION_LABELS.items():
        if key in case_name:
            return label
    raise ValueError(f"Unknown ventilation pattern in: {case_name}")


def extract_climate(case_name: str) -> str:
    """ケース名から気候を抽出"""
    if "kyoto" in case_name:
        return "kyoto"
    elif "okinawa" in case_name:
        return "okinawa"
    elif "sapporo" in case_name:
        return "sapporo"
    raise ValueError(f"Unknown climate in: {case_name}")


def load_all_features() -> Tuple[np.ndarray, np.ndarray, List[str]]:
    """全特徴量CSVを読み込み、特徴量行列とラベルを作成

    Returns:
        X: 特徴量行列 (n_samples, n_features)
        y: ラベル配列 (n_samples,)
        case_names: ケース名リスト
    """
    dfs = {}
    case_names = None

    # 各CSVを読み込み
    for name, path in FEATURE_FILES.items():
        df = pd.read_csv(path, index_col=0)
        # 365日周期は欠損が多いので除外
        df = df[df.index != 365.0]
        dfs[name] = df

        if case_names is None:
            case_names = list(df.columns)

    # 特徴量を結合 (各CSVの転置を横に並べる)
    features_list = []
    for name, df in dfs.items():
        # 転置して (n_samples, n_periods) の形に
        features_list.append(df.T.values)

    # 全特徴量を結合
    X = np.hstack(features_list)  # (n_samples, n_features)

    # ラベル作成
    y = np.array([extract_ventilation_label(name) for name in case_names])

    return X, y, case_names


def normalize_features(X: np.ndarray, method: str = "standard") -> Tuple[np.ndarray, Dict]:
    """特徴量の正規化

    Args:
        X: 特徴量行列
        method: "standard" (標準化) or "minmax" (最小最大正規化)

    Returns:
        X_normalized: 正規化済み特徴量
        params: 正規化パラメータ (逆変換用)
    """
    if method == "standard":
        mean = X.mean(axis=0)
        std = X.std(axis=0)
        std[std == 0] = 1  # ゼロ除算防止
        X_normalized = (X - mean) / std
        params = {"mean": mean, "std": std}
    elif method == "minmax":
        min_val = X.min(axis=0)
        max_val = X.max(axis=0)
        range_val = max_val - min_val
        range_val[range_val == 0] = 1
        X_normalized = (X - min_val) / range_val
        params = {"min": min_val, "max": max_val}
    else:
        raise ValueError(f"Unknown normalization method: {method}")

    return X_normalized, params


class VentilationDataset(Dataset):
    """換気量分類用PyTorch Dataset"""

    def __init__(self, X: np.ndarray, y: np.ndarray):
        self.X = torch.FloatTensor(X)
        self.y = torch.LongTensor(y)

    def __len__(self) -> int:
        return len(self.y)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        return self.X[idx], self.y[idx]


def get_feature_names() -> List[str]:
    """特徴量名のリストを生成"""
    feature_names = []
    for csv_name in FEATURE_FILES.keys():
        for period in PERIOD_BINS:
            feature_names.append(f"{csv_name}_period{period}d")
    return feature_names


def print_data_summary(X: np.ndarray, y: np.ndarray, case_names: List[str]):
    """データの概要を表示"""
    print("=" * 50)
    print("データ概要")
    print("=" * 50)
    print(f"サンプル数: {len(y)}")
    print(f"特徴量数: {X.shape[1]}")
    print(f"クラス分布:")
    for label, count in zip(*np.unique(y, return_counts=True)):
        vent_name = list(VENTILATION_LABELS.keys())[label]
        print(f"  {vent_name}: {count}サンプル")
    print(f"\nケース一覧:")
    for name, label in zip(case_names, y):
        print(f"  {name} -> class {label}")
    print("=" * 50)


if __name__ == "__main__":
    # テスト実行
    X, y, case_names = load_all_features()
    print_data_summary(X, y, case_names)

    X_norm, params = normalize_features(X, method="standard")
    print(f"\n正規化後の特徴量統計:")
    print(f"  平均: {X_norm.mean():.4f}")
    print(f"  標準偏差: {X_norm.std():.4f}")
