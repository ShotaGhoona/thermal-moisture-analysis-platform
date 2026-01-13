"""
学習スクリプト
Leave-One-Out Cross-Validation (LOOCV) による換気量分類
"""
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from sklearn.model_selection import LeaveOneOut, StratifiedKFold
from typing import Tuple, Dict, List
import json
from datetime import datetime
from pathlib import Path

from config import MODEL_CONFIG, NUM_CLASSES, RANDOM_SEED, ML_OUTPUT_DIR, VENTILATION_NAMES
from data_loader import load_all_features, normalize_features, VentilationDataset, print_data_summary
from model import VentilationClassifier, SimpleClassifier, print_model_summary


def set_seed(seed: int):
    """乱数シードを固定"""
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def train_one_epoch(
    model: nn.Module,
    train_loader: DataLoader,
    criterion: nn.Module,
    optimizer: optim.Optimizer,
    device: torch.device
) -> float:
    """1エポックの学習"""
    model.train()
    total_loss = 0.0

    for X_batch, y_batch in train_loader:
        X_batch, y_batch = X_batch.to(device), y_batch.to(device)

        optimizer.zero_grad()
        outputs = model(X_batch)
        loss = criterion(outputs, y_batch)
        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    return total_loss / len(train_loader)


def evaluate(
    model: nn.Module,
    data_loader: DataLoader,
    criterion: nn.Module,
    device: torch.device
) -> Tuple[float, float, List[int], List[int]]:
    """評価"""
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for X_batch, y_batch in data_loader:
            X_batch, y_batch = X_batch.to(device), y_batch.to(device)

            outputs = model(X_batch)
            loss = criterion(outputs, y_batch)
            total_loss += loss.item()

            _, predicted = torch.max(outputs, 1)
            total += y_batch.size(0)
            correct += (predicted == y_batch).sum().item()

            all_preds.extend(predicted.cpu().numpy())
            all_labels.extend(y_batch.cpu().numpy())

    accuracy = correct / total if total > 0 else 0
    avg_loss = total_loss / len(data_loader) if len(data_loader) > 0 else 0

    return avg_loss, accuracy, all_preds, all_labels


def train_loocv(
    X: np.ndarray,
    y: np.ndarray,
    case_names: List[str],
    model_type: str = "mlp"
) -> Dict:
    """Leave-One-Out Cross-Validationで学習・評価

    Args:
        X: 特徴量行列
        y: ラベル
        case_names: ケース名
        model_type: "mlp" or "linear"

    Returns:
        結果辞書
    """
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")

    # 正規化 (全データで計算)
    X_norm, norm_params = normalize_features(X, method="standard")

    # LOOCV
    loo = LeaveOneOut()
    predictions = []
    true_labels = []
    fold_results = []

    for fold_idx, (train_idx, test_idx) in enumerate(loo.split(X_norm)):
        test_case = case_names[test_idx[0]]
        print(f"\nFold {fold_idx + 1}/{len(X_norm)}: テストケース = {test_case}")

        # データ分割
        X_train, X_test = X_norm[train_idx], X_norm[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]

        # Dataset作成
        train_dataset = VentilationDataset(X_train, y_train)
        test_dataset = VentilationDataset(X_test, y_test)

        train_loader = DataLoader(train_dataset, batch_size=MODEL_CONFIG["batch_size"], shuffle=True)
        test_loader = DataLoader(test_dataset, batch_size=1)

        # モデル作成
        input_size = X_train.shape[1]
        if model_type == "mlp":
            model = VentilationClassifier(
                input_size=input_size,
                hidden_sizes=MODEL_CONFIG["hidden_sizes"],
                num_classes=NUM_CLASSES,
                dropout=MODEL_CONFIG["dropout"]
            )
        else:
            model = SimpleClassifier(input_size=input_size, num_classes=NUM_CLASSES)

        model = model.to(device)
        criterion = nn.CrossEntropyLoss()
        optimizer = optim.Adam(model.parameters(), lr=MODEL_CONFIG["learning_rate"])

        # 学習
        best_train_loss = float('inf')
        for epoch in range(MODEL_CONFIG["epochs"]):
            train_loss = train_one_epoch(model, train_loader, criterion, optimizer, device)
            if train_loss < best_train_loss:
                best_train_loss = train_loss

        # テスト
        _, _, preds, labels = evaluate(model, test_loader, criterion, device)

        pred = preds[0]
        true = labels[0]
        is_correct = pred == true

        predictions.append(pred)
        true_labels.append(true)

        result_str = "正解" if is_correct else "不正解"
        print(f"  予測: {VENTILATION_NAMES[pred]}, 正解: {VENTILATION_NAMES[true]} -> {result_str}")

        fold_results.append({
            "fold": fold_idx + 1,
            "test_case": test_case,
            "predicted": VENTILATION_NAMES[pred],
            "true": VENTILATION_NAMES[true],
            "correct": bool(is_correct)
        })

    # 全体の精度
    accuracy = np.mean(np.array(predictions) == np.array(true_labels))
    print(f"\n{'=' * 50}")
    print(f"LOOCV 精度: {accuracy * 100:.1f}% ({int(accuracy * len(y))}/{len(y)})")
    print(f"{'=' * 50}")

    # 混同行列
    confusion_matrix = np.zeros((NUM_CLASSES, NUM_CLASSES), dtype=int)
    for pred, true in zip(predictions, true_labels):
        confusion_matrix[true, pred] += 1

    print("\n混同行列:")
    print("予測 →", end="")
    for name in VENTILATION_NAMES:
        print(f"{name:>8}", end="")
    print()
    for i, name in enumerate(VENTILATION_NAMES):
        print(f"{name:>6} |", end="")
        for j in range(NUM_CLASSES):
            print(f"{confusion_matrix[i, j]:>8}", end="")
        print()

    return {
        "accuracy": float(accuracy),
        "confusion_matrix": confusion_matrix.tolist(),
        "fold_results": fold_results,
        "predictions": [int(p) for p in predictions],
        "true_labels": [int(t) for t in true_labels],
        "norm_params": {k: v.tolist() for k, v in norm_params.items()}
    }


def save_results(results: Dict, model_type: str):
    """結果を保存"""
    ML_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = ML_OUTPUT_DIR / f"results_{model_type}_{timestamp}.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n結果を保存: {output_path}")
    return output_path


def main():
    set_seed(RANDOM_SEED)

    print("=" * 50)
    print("換気量分類 - PyTorch LOOCV")
    print("=" * 50)

    # データ読み込み
    X, y, case_names = load_all_features()
    print_data_summary(X, y, case_names)

    # MLP で学習
    print("\n" + "=" * 50)
    print("MLP モデルで学習")
    print("=" * 50)
    results_mlp = train_loocv(X, y, case_names, model_type="mlp")
    save_results(results_mlp, "mlp")

    # 線形モデル (ベースライン)
    print("\n" + "=" * 50)
    print("線形モデル (ベースライン) で学習")
    print("=" * 50)
    results_linear = train_loocv(X, y, case_names, model_type="linear")
    save_results(results_linear, "linear")

    # 比較
    print("\n" + "=" * 50)
    print("結果比較")
    print("=" * 50)
    print(f"MLP精度:    {results_mlp['accuracy'] * 100:.1f}%")
    print(f"線形精度:   {results_linear['accuracy'] * 100:.1f}%")


if __name__ == "__main__":
    main()
