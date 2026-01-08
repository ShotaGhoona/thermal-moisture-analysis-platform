"""
PyTorch モデル定義
換気量分類用ニューラルネットワーク
"""
import torch
import torch.nn as nn
from typing import List


class VentilationClassifier(nn.Module):
    """換気量分類用の全結合ニューラルネットワーク"""

    def __init__(
        self,
        input_size: int,
        hidden_sizes: List[int],
        num_classes: int,
        dropout: float = 0.3
    ):
        """
        Args:
            input_size: 入力特徴量の次元数
            hidden_sizes: 隠れ層のサイズリスト
            num_classes: 分類クラス数
            dropout: ドロップアウト率
        """
        super().__init__()

        layers = []
        prev_size = input_size

        # 隠れ層を構築
        for hidden_size in hidden_sizes:
            layers.extend([
                nn.Linear(prev_size, hidden_size),
                nn.BatchNorm1d(hidden_size),
                nn.ReLU(),
                nn.Dropout(dropout),
            ])
            prev_size = hidden_size

        # 出力層
        layers.append(nn.Linear(prev_size, num_classes))

        self.network = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.network(x)


class SimpleClassifier(nn.Module):
    """シンプルな線形分類器 (ベースライン用)"""

    def __init__(self, input_size: int, num_classes: int):
        super().__init__()
        self.linear = nn.Linear(input_size, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.linear(x)


def count_parameters(model: nn.Module) -> int:
    """モデルのパラメータ数をカウント"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)


def print_model_summary(model: nn.Module, input_size: int):
    """モデル構造のサマリーを表示"""
    print("=" * 50)
    print("モデル構造")
    print("=" * 50)
    print(model)
    print(f"\n総パラメータ数: {count_parameters(model):,}")
    print("=" * 50)


if __name__ == "__main__":
    # テスト
    from config import MODEL_CONFIG, NUM_CLASSES

    # サンプル入力サイズ (12 CSVファイル × 9周期)
    input_size = 12 * 9

    model = VentilationClassifier(
        input_size=input_size,
        hidden_sizes=MODEL_CONFIG["hidden_sizes"],
        num_classes=NUM_CLASSES,
        dropout=MODEL_CONFIG["dropout"]
    )
    print_model_summary(model, input_size)

    # テスト推論
    x = torch.randn(4, input_size)
    out = model(x)
    print(f"\n入力形状: {x.shape}")
    print(f"出力形状: {out.shape}")
