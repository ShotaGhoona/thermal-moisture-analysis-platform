#!/usr/bin/env python3
"""
FFT解析スクリプト - 熱解析データの周波数解析とハーモニック回帰
"""

import sys
import logging
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import statsmodels.api as sm
from scipy.fft import rfft, rfftfreq, irfft

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('fft_analysis.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class FFTAnalyzer:
    """FFT解析とハーモニック回帰を行うクラス"""
    
    def __init__(self, input_file, output_dir="output_data"):
        """
        初期化
        
        Args:
            input_file (str): 入力ファイルパス
            output_dir (str): 出力ディレクトリ
        """
        self.input_file = Path(input_file)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # 出力ファイル名を生成
        base_name = self.input_file.stem
        self.output_file = self.output_dir / f"harmonic_analysis_results_{base_name}.xlsx"
        self.output_file_fft = self.output_dir / f"harmonic_analysis_results_fft_{base_name}.xlsx"
        
        logger.info(f"初期化完了: 入力={self.input_file}, 出力={self.output_file}")
    
    def load_data(self):
        """データの読み込み"""
        logger.info(f"データ読み込み開始: {self.input_file}")
        
        try:
            # Excelファイルの読み込み
            df = pd.read_excel(self.input_file, header=[1,1], index_col=0)
            logger.info(f"データ読み込み成功: shape={df.shape}")
            
            # 分析するデータの選択（NaN除去）
            logger.info("温度データの選択とNaN除去開始")
            temp_series = df['temp'].dropna()
            self.target_data = temp_series.values
            self.valid_index = temp_series.index
            
            # サンプリング間隔の計算
            td = pd.Timedelta(self.valid_index[1] - self.valid_index[0])
            self.sampling_rate = td.total_seconds()
            
            logger.info(f"データ処理完了:")
            logger.info(f"  - 元データ数: {len(df)}")
            logger.info(f"  - 有効データ数: {len(self.target_data)}")
            logger.info(f"  - NaN除去数: {len(df) - len(self.target_data)}")
            logger.info(f"  - サンプリング間隔: {self.sampling_rate}秒")
            logger.info(f"  - データ期間: {len(self.target_data) * self.sampling_rate / 86400:.1f}日")
            logger.info(f"  - データ統計: 平均={np.mean(self.target_data):.3f}, 標準偏差={np.std(self.target_data):.3f}")
            
            return True
            
        except Exception as e:
            logger.error(f"データ読み込みエラー: {e}")
            return False
    
    def perform_fft(self):
        """FFT解析の実行"""
        logger.info("FFT解析開始")
        
        # データの1次元化
        self.target_array = self.target_data.flatten()
        logger.info(f"対象データ形状: {self.target_array.shape}")
        
        # FFT実行
        logger.info("フーリエ変換実行中...")
        self.fft_result = rfft(self.target_array)
        self.freqs = rfftfreq(len(self.target_data), d=self.sampling_rate)
        
        # 振幅と位相の計算
        self.amplitudes = np.abs(self.fft_result) / len(self.target_data)
        self.phases = np.angle(self.fft_result)
        
        logger.info(f"FFT結果:")
        logger.info(f"  - 周波数数: {len(self.freqs)}")
        logger.info(f"  - 最大振幅: {np.max(self.amplitudes):.6f}")
        logger.info(f"  - 周波数範囲: {self.freqs[0]:.2e} - {self.freqs[-1]:.2e} Hz")
        
        # 逆FFTによる再構成
        logger.info("逆フーリエ変換による再構成中...")
        self.reconstructed = irfft(self.fft_result)
        
        # 再構成精度の確認
        reconstruction_error = np.mean(np.abs(self.target_array - self.reconstructed[:len(self.target_array)]))
        logger.info(f"再構成誤差: {reconstruction_error:.6f}")
        
        logger.info("FFT解析完了")
    
    def analyze_top_frequencies(self, top_n=51):
        """振幅上位成分の分析"""
        logger.info(f"上位{top_n}成分の分析開始")
        
        # 振幅の大きい順にソート
        indices = np.argsort(self.amplitudes)[-top_n:][::-1]
        self.top_amplitudes = self.amplitudes[indices]
        self.top_frequencies = self.freqs[indices]
        
        logger.info("上位周波数成分:")
        for i, (freq, amp) in enumerate(zip(self.top_frequencies[:10], self.top_amplitudes[:10]), 1):
            if freq == 0:
                period_str = "DC成分"
            else:
                period_days = 1 / freq / 86400
                period_str = f"{period_days:.1f}日"
            logger.info(f"  Rank {i}: 周期={period_str}, 振幅={amp:.6f}")
        
        logger.info(f"上位{top_n}成分の分析完了")
    
    def perform_harmonic_regression(self):
        """ハーモニック回帰の実行"""
        logger.info("ハーモニック回帰開始")
        
        # 時間軸の設定
        dt = self.sampling_rate
        N = len(self.target_data)
        t = np.arange(N) * dt
        
        logger.info(f"回帰設定: データ数={N}, 時間範囲={t[-1]/86400:.1f}日")
        
        # 周波数辞書の作成（0除算を回避）
        self.frequencies = {}
        for freq in self.top_frequencies:
            if freq == 0:
                label = "DC"
            else:
                period_days = 1 / freq / 86400
                label = f"{period_days:.2f}_Day"
            self.frequencies[label] = freq
        
        logger.info(f"回帰対象周波数数: {len(self.frequencies)}")
        
        # デザイン行列の作成
        logger.info("デザイン行列作成中...")
        X_dict = {"Intercept": np.ones(N)}
        
        for label, freq in self.frequencies.items():
            if freq != 0:  # DC成分以外
                X_dict[f"cos_{label}"] = np.cos(2 * np.pi * freq * t)
                X_dict[f"sin_{label}"] = np.sin(2 * np.pi * freq * t)
        
        X = pd.DataFrame(X_dict)
        logger.info(f"デザイン行列形状: {X.shape}")
        
        # 回帰モデルの学習
        logger.info("最小二乗法による回帰実行中...")
        self.model = sm.OLS(self.target_data.flatten(), X).fit()
        
        # 再構成
        self.y_fit_total = self.model.predict(X)
        
        # 回帰結果の評価
        r2 = self.model.rsquared
        rmse = np.sqrt(np.mean((self.target_data.flatten() - self.y_fit_total)**2))
        
        logger.info(f"回帰結果:")
        logger.info(f"  - R²: {r2:.6f}")
        logger.info(f"  - RMSE: {rmse:.6f}")
        logger.info(f"  - 説明変数数: {len(X.columns)}")
        
        # 各成分の保存
        self.t = t
        self.X = X
        
        logger.info("ハーモニック回帰完了")
    
    def save_results(self, save_plots=True):
        """結果の保存"""
        logger.info("結果保存開始")
        
        try:
            # Excel出力用データの準備
            logger.info("Excel出力データ準備中...")
            
            # 時間軸
            t_days = self.t / 86400
            
            # 周波数スペクトル
            periods = np.where(self.freqs != 0, 1 / self.freqs / 86400, np.nan)
            fourier_df = pd.DataFrame({
                "Frequency (Hz)": self.freqs,
                "Period (Day)": periods,
                "Amplitude": self.amplitudes,
                "Phase (radians)": self.phases
            })
            
            # 波形データ
            min_len = min(len(self.t), len(self.target_array), len(self.reconstructed))
            waveform_df = pd.DataFrame({
                "Time [s]": self.t[:min_len],
                "Time [day]": t_days[:min_len],
                "Original": self.target_array[:min_len],
                "Reconstructed": self.reconstructed[:min_len]
            })
            
            # 各周波数成分の波形
            component_df = pd.DataFrame({
                "Time [s]": self.t, 
                "Original Data": self.target_data.flatten()
            })
            
            # 回帰係数
            coeffs = []
            for label, freq in self.frequencies.items():
                if freq == 0:  # DC成分
                    cos_coeff = self.model.params["Intercept"]
                    sin_coeff = 0
                    amplitude = abs(cos_coeff)
                    phase = 0 if cos_coeff >= 0 else np.pi
                    component_df[f"{label}_component"] = np.full_like(self.t, cos_coeff)
                else:
                    cos_coeff = self.model.params[f"cos_{label}"]
                    sin_coeff = self.model.params[f"sin_{label}"]
                    amplitude = np.sqrt(cos_coeff**2 + sin_coeff**2)
                    phase = np.arctan2(sin_coeff, cos_coeff)
                    
                    cos_wave = cos_coeff * np.cos(2 * np.pi * freq * self.t)
                    sin_wave = sin_coeff * np.sin(2 * np.pi * freq * self.t)
                    component_df[f"{label}_component"] = cos_wave + sin_wave
                
                coeffs.append({
                    "Component": label,
                    "Frequency (Hz)": freq,
                    "Period (Day)": 1/freq/86400 if freq != 0 else np.inf,
                    "cos_coeff": cos_coeff,
                    "sin_coeff": sin_coeff,
                    "Amplitude": amplitude,
                    "Phase (radians)": phase
                })
            
            coeff_df = pd.DataFrame(coeffs)
            
            # Excel出力
            logger.info(f"Excel出力開始: {self.output_file}")
            with pd.ExcelWriter(self.output_file, engine="openpyxl") as writer:
                fourier_df.to_excel(writer, index=False, sheet_name="Fourier Spectrum")
                component_df.to_excel(writer, index=False, sheet_name="Harmonic Components")
                coeff_df.to_excel(writer, index=False, sheet_name="Harmonic Coefficients")
            
            logger.info(f"Excel出力開始: {self.output_file_fft}")
            with pd.ExcelWriter(self.output_file_fft, engine="openpyxl") as writer:
                fourier_df.to_excel(writer, index=False, sheet_name="Fourier Spectrum")
                waveform_df.to_excel(writer, index=False, sheet_name="Waveforms")
            
            logger.info("Excel出力完了")
            
            # プロット保存
            if save_plots:
                self._save_plots()
            
            logger.info("結果保存完了")
            return True
            
        except Exception as e:
            logger.error(f"結果保存エラー: {e}")
            return False
    
    def _save_plots(self):
        """プロットの保存"""
        logger.info("プロット保存開始")
        
        try:
            # 振幅スペクトル
            plt.figure(figsize=(12, 8))
            plt.plot(self.freqs, self.amplitudes, label="Amplitude Spectrum")
            plt.title("Amplitude Spectrum from Fourier Transform")
            plt.xlabel("Frequency (Hz)")
            plt.ylabel("Amplitude")
            plt.grid(True)
            plt.legend()
            plt.savefig(self.output_dir / f"amplitude_spectrum_{self.input_file.stem}.png", dpi=300, bbox_inches='tight')
            plt.close()
            
            # 元データと再構成の比較
            plt.figure(figsize=(16, 10))
            
            # 全体比較
            plt.subplot(3, 1, 1)
            plt.plot(self.target_data.flatten(), label="Original Data", alpha=0.6)
            plt.plot(self.y_fit_total, label="Harmonic Regression", linestyle="--")
            plt.title("Original vs Harmonic Regression")
            plt.legend()
            plt.grid(True)
            
            # FFT再構成比較
            plt.subplot(3, 1, 2)
            plt.plot(self.target_data.flatten(), label="Original Data", alpha=0.6)
            plt.plot(self.reconstructed[:len(self.target_data)], label="Reconstructed by iFFT", linestyle="--")
            plt.title("Original vs Reconstructed Signal (iFFT)")
            plt.legend()
            plt.grid(True)
            
            # 残差
            plt.subplot(3, 1, 3)
            residuals = self.target_data.flatten() - self.y_fit_total
            plt.plot(residuals, label="Residuals", alpha=0.7)
            plt.title("Regression Residuals")
            plt.legend()
            plt.grid(True)
            
            plt.tight_layout()
            plt.savefig(self.output_dir / f"comparison_{self.input_file.stem}.png", dpi=300, bbox_inches='tight')
            plt.close()
            
            logger.info("プロット保存完了")
            
        except Exception as e:
            logger.error(f"プロット保存エラー: {e}")
    
    def run_analysis(self, top_n=51, save_plots=True):
        """完全な解析の実行"""
        logger.info("FFT解析開始")
        
        # データ読み込み
        if not self.load_data():
            logger.error("データ読み込み失敗")
            return False
        
        # FFT解析
        self.perform_fft()
        
        # 上位成分分析
        self.analyze_top_frequencies(top_n)
        
        # ハーモニック回帰
        self.perform_harmonic_regression()
        
        # 結果保存
        if not self.save_results(save_plots):
            logger.error("結果保存失敗")
            return False
        
        logger.info("FFT解析完了")
        logger.info(f"出力ファイル: {self.output_file}")
        logger.info(f"FFT出力ファイル: {self.output_file_fft}")
        
        return True

def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(description='FFT解析とハーモニック回帰')
    parser.add_argument('input_file', help='入力Excelファイルパス')
    parser.add_argument('--output-dir', default='output_data', help='出力ディレクトリ (default: output_data)')
    parser.add_argument('--top-n', type=int, default=51, help='解析する上位成分数 (default: 51)')
    parser.add_argument('--no-plots', action='store_true', help='プロット保存をスキップ')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], 
                        default='INFO', help='ログレベル (default: INFO)')
    
    args = parser.parse_args()
    
    # ログレベル設定
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    # 入力ファイル確認
    input_path = Path(args.input_file)
    if not input_path.exists():
        logger.error(f"入力ファイルが見つかりません: {input_path}")
        return 1
    
    # 解析実行
    analyzer = FFTAnalyzer(args.input_file, args.output_dir)
    success = analyzer.run_analysis(args.top_n, not args.no_plots)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())