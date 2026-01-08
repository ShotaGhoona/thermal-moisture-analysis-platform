"""
評価・可視化スクリプト
混同行列、特徴量重要度などを可視化
"""
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import json
from typing import Dict, List

from config import ML_OUTPUT_DIR, VENTILATION_NAMES, NUM_CLASSES


# 日本語フォント設定
plt.rcParams['font.family'] = ['Hiragino Sans', 'Yu Gothic', 'Meirio', 'sans-serif']


def plot_confusion_matrix(
    confusion_matrix: np.ndarray,
    class_names: List[str],
    title: str = "混同行列",
    save_path: Path = None
):
    """混同行列を可視化"""
    fig, ax = plt.subplots(figsize=(8, 6))

    sns.heatmap(
        confusion_matrix,
        annot=True,
        fmt="d",
        cmap="Blues",
        xticklabels=class_names,
        yticklabels=class_names,
        ax=ax
    )

    ax.set_xlabel("予測ラベル")
    ax.set_ylabel("正解ラベル")
    ax.set_title(title)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"保存: {save_path}")

    plt.close()


def plot_fold_results(
    fold_results: List[Dict],
    title: str = "各Foldの結果",
    save_path: Path = None
):
    """各Foldの正解/不正解を可視化"""
    n_folds = len(fold_results)

    fig, ax = plt.subplots(figsize=(12, 4))

    colors = ['green' if r['correct'] else 'red' for r in fold_results]
    x = range(n_folds)

    bars = ax.bar(x, [1] * n_folds, color=colors, edgecolor='black')

    # ケース名をラベルに
    case_labels = [r['test_case'].replace('w01-base_', '').replace('_', '\n') for r in fold_results]
    ax.set_xticks(x)
    ax.set_xticklabels(case_labels, rotation=45, ha='right', fontsize=8)

    ax.set_ylabel("正解/不正解")
    ax.set_title(title)
    ax.set_yticks([])

    # 凡例
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='green', edgecolor='black', label='正解'),
        Patch(facecolor='red', edgecolor='black', label='不正解')
    ]
    ax.legend(handles=legend_elements, loc='upper right')

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"保存: {save_path}")

    plt.close()


def calculate_metrics(confusion_matrix: np.ndarray, class_names: List[str]) -> Dict:
    """各クラスの精度指標を計算"""
    metrics = {}

    for i, name in enumerate(class_names):
        tp = confusion_matrix[i, i]
        fp = confusion_matrix[:, i].sum() - tp
        fn = confusion_matrix[i, :].sum() - tp
        tn = confusion_matrix.sum() - tp - fp - fn

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

        metrics[name] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": int(confusion_matrix[i, :].sum())
        }

    return metrics


def print_classification_report(metrics: Dict):
    """分類レポートを表示"""
    print("\n分類レポート:")
    print("-" * 60)
    print(f"{'クラス':<12} {'Precision':>10} {'Recall':>10} {'F1':>10} {'Support':>10}")
    print("-" * 60)

    for name, m in metrics.items():
        print(f"{name:<12} {m['precision']:>10.2f} {m['recall']:>10.2f} {m['f1']:>10.2f} {m['support']:>10}")

    print("-" * 60)

    # マクロ平均
    macro_precision = np.mean([m['precision'] for m in metrics.values()])
    macro_recall = np.mean([m['recall'] for m in metrics.values()])
    macro_f1 = np.mean([m['f1'] for m in metrics.values()])
    total_support = sum(m['support'] for m in metrics.values())

    print(f"{'macro avg':<12} {macro_precision:>10.2f} {macro_recall:>10.2f} {macro_f1:>10.2f} {total_support:>10}")


def analyze_results(results_path: Path):
    """結果ファイルを分析"""
    with open(results_path, "r", encoding="utf-8") as f:
        results = json.load(f)

    confusion_matrix = np.array(results["confusion_matrix"])
    fold_results = results["fold_results"]
    accuracy = results["accuracy"]

    print("=" * 60)
    print(f"結果分析: {results_path.name}")
    print("=" * 60)
    print(f"全体精度: {accuracy * 100:.1f}%")

    # クラスごとの指標
    metrics = calculate_metrics(confusion_matrix, VENTILATION_NAMES)
    print_classification_report(metrics)

    # 可視化
    output_dir = results_path.parent
    stem = results_path.stem

    plot_confusion_matrix(
        confusion_matrix,
        VENTILATION_NAMES,
        title=f"混同行列 (精度: {accuracy * 100:.1f}%)",
        save_path=output_dir / f"{stem}_confusion_matrix.png"
    )

    plot_fold_results(
        fold_results,
        title=f"各Foldの結果 (精度: {accuracy * 100:.1f}%)",
        save_path=output_dir / f"{stem}_fold_results.png"
    )

    return metrics


def main():
    """最新の結果ファイルを分析"""
    # 最新の結果ファイルを探す
    result_files = sorted(ML_OUTPUT_DIR.glob("results_*.json"))

    if not result_files:
        print("結果ファイルが見つかりません。先にtrain.pyを実行してください。")
        return

    print(f"見つかった結果ファイル: {len(result_files)}件")

    for result_path in result_files[-2:]:  # 最新2件を分析
        analyze_results(result_path)
        print()


if __name__ == "__main__":
    main()
