#!/usr/bin/env python3
"""
FFT解析結果の分析とレポート生成
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

def analyze_fft_results():
    """FFT解析結果を読み込んで分析"""
    
    # ファイルパス
    fft_file = "output_data/harmonic_analysis_results_fft_indoor_measurement_temp.xlsx"
    harmonic_file = "output_data/harmonic_analysis_results_indoor_measurement_temp.xlsx"
    
    print("=== FFT解析結果レポート ===\n")
    
    # FFT結果の読み込み
    print("1. FFT解析結果の読み込み")
    fft_spectrum = pd.read_excel(fft_file, sheet_name="Fourier Spectrum")
    fft_waveforms = pd.read_excel(fft_file, sheet_name="Waveforms")
    
    print(f"   - 周波数成分数: {len(fft_spectrum)}")
    print(f"   - データ点数: {len(fft_waveforms)}")
    print(f"   - 測定期間: {fft_waveforms['Time [day]'].max():.1f} 日")
    
    # ハーモニック回帰結果の読み込み
    print("\n2. ハーモニック回帰結果の読み込み")
    harmonic_spectrum = pd.read_excel(harmonic_file, sheet_name="Fourier Spectrum")
    harmonic_components = pd.read_excel(harmonic_file, sheet_name="Harmonic Components")
    harmonic_coeffs = pd.read_excel(harmonic_file, sheet_name="Harmonic Coefficients")
    
    print(f"   - 抽出された主要成分数: {len(harmonic_coeffs)}")
    
    # 主要周波数成分の分析
    print("\n3. 主要周波数成分の分析")
    
    # 振幅の大きい順にソート（DC成分を除く）
    non_dc_spectrum = fft_spectrum[fft_spectrum['Frequency (Hz)'] > 0].copy()
    top_components = non_dc_spectrum.nlargest(10, 'Amplitude')
    
    print("   上位10の周波数成分:")
    for i, (_, row) in enumerate(top_components.iterrows(), 1):
        freq = row['Frequency (Hz)']
        period_days = row['Period (Day)']
        amplitude = row['Amplitude']
        print(f"   {i:2d}. 周期: {period_days:6.1f}日, 振幅: {amplitude:8.4f}")
    
    # DC成分（平均値）の分析
    dc_component = fft_spectrum[fft_spectrum['Frequency (Hz)'] == 0]
    if not dc_component.empty:
        dc_amplitude = dc_component['Amplitude'].iloc[0]
        print(f"\n   DC成分（平均値）: {dc_amplitude:.2f}")
    
    # 周期範囲別の分析
    print("\n4. 周期範囲別の分析")
    
    def analyze_period_range(spectrum, min_days, max_days, label):
        mask = (spectrum['Period (Day)'] >= min_days) & (spectrum['Period (Day)'] <= max_days)
        range_data = spectrum[mask]
        if not range_data.empty:
            max_amp = range_data['Amplitude'].max()
            max_period = range_data.loc[range_data['Amplitude'].idxmax(), 'Period (Day)']
            count = len(range_data)
            total_power = (range_data['Amplitude'] ** 2).sum()
            print(f"   {label}: {count}成分, 最大振幅: {max_amp:.4f} (周期: {max_period:.1f}日), パワー: {total_power:.4f}")
        else:
            print(f"   {label}: 該当成分なし")
    
    analyze_period_range(non_dc_spectrum, 0, 1, "日内変動 (< 1日)")
    analyze_period_range(non_dc_spectrum, 1, 7, "週内変動 (1-7日)")
    analyze_period_range(non_dc_spectrum, 7, 30, "月内変動 (7-30日)")
    analyze_period_range(non_dc_spectrum, 30, 365, "季節変動 (30-365日)")
    analyze_period_range(non_dc_spectrum, 365, float('inf'), "年間変動 (> 365日)")
    
    # 再構成精度の評価
    print("\n5. 再構成精度の評価")
    original = fft_waveforms['Original'].values
    reconstructed = fft_waveforms['Reconstructed'].values
    
    mse = np.mean((original - reconstructed) ** 2)
    rmse = np.sqrt(mse)
    mae = np.mean(np.abs(original - reconstructed))
    r2 = np.corrcoef(original, reconstructed)[0, 1] ** 2
    
    print(f"   平均二乗誤差 (MSE): {mse:.6f}")
    print(f"   平均平方根誤差 (RMSE): {rmse:.6f}")
    print(f"   平均絶対誤差 (MAE): {mae:.6f}")
    print(f"   決定係数 (R²): {r2:.6f}")
    
    # 統計情報
    print("\n6. 測定データの統計情報")
    print(f"   平均値: {original.mean():.2f}")
    print(f"   標準偏差: {original.std():.2f}")
    print(f"   最小値: {original.min():.2f}")
    print(f"   最大値: {original.max():.2f}")
    print(f"   範囲: {original.max() - original.min():.2f}")
    
    return {
        'fft_spectrum': fft_spectrum,
        'fft_waveforms': fft_waveforms,
        'harmonic_coeffs': harmonic_coeffs,
        'top_components': top_components,
        'stats': {
            'mse': mse, 'rmse': rmse, 'mae': mae, 'r2': r2,
            'mean': original.mean(), 'std': original.std(),
            'min': original.min(), 'max': original.max()
        }
    }

if __name__ == "__main__":
    results = analyze_fft_results()