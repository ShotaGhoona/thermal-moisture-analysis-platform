"""
機械学習パイプラインの設定ファイル
換気量分類タスク用
"""
from pathlib import Path

# パス設定
BASE_DIR = Path(__file__).parent.parent
FFT_OUTPUT_DIR = BASE_DIR / "fft" / "output" / "1224" / "integrate-fft"
ML_OUTPUT_DIR = Path(__file__).parent / "output"

# 特徴量ファイル
FEATURE_FILES = {
    "room1_temp_amplitude": FFT_OUTPUT_DIR / "spectrum_room1_temp_amplitude.csv",
    "room1_temp_phase": FFT_OUTPUT_DIR / "spectrum_room1_temp_phase.csv",
    "room1_rh_amplitude": FFT_OUTPUT_DIR / "spectrum_room1_rh_amplitude.csv",
    "room1_rh_phase": FFT_OUTPUT_DIR / "spectrum_room1_rh_phase.csv",
    "room1_ah_amplitude": FFT_OUTPUT_DIR / "spectrum_room1_ah_amplitude.csv",
    "room1_ah_phase": FFT_OUTPUT_DIR / "spectrum_room1_ah_phase.csv",
    "room2_temp_amplitude": FFT_OUTPUT_DIR / "spectrum_room2_temp_amplitude.csv",
    "room2_temp_phase": FFT_OUTPUT_DIR / "spectrum_room2_temp_phase.csv",
    "room2_rh_amplitude": FFT_OUTPUT_DIR / "spectrum_room2_rh_amplitude.csv",
    "room2_rh_phase": FFT_OUTPUT_DIR / "spectrum_room2_rh_phase.csv",
    "room2_ah_amplitude": FFT_OUTPUT_DIR / "spectrum_room2_ah_amplitude.csv",
    "room2_ah_phase": FFT_OUTPUT_DIR / "spectrum_room2_ah_phase.csv",
}

# 換気量ラベル (分類対象)
VENTILATION_LABELS = {
    "o01-base": 0,  # 基準換気
    "o02-low": 1,   # 低換気
    "o03-high": 2,  # 高換気
    "o04-none": 3,  # 無換気
}
VENTILATION_NAMES = ["base", "low", "high", "none"]
NUM_CLASSES = len(VENTILATION_LABELS)

# 周期バンド (日単位)
PERIOD_BINS = [0.1, 0.2, 0.5, 1.0, 2.0, 7.0, 14.0, 30.0, 90.0]

# モデル設定
MODEL_CONFIG = {
    "hidden_sizes": [64, 32],  # 隠れ層のサイズ
    "dropout": 0.3,
    "learning_rate": 0.001,
    "epochs": 100,
    "batch_size": 4,
}

# 乱数シード
RANDOM_SEED = 42
