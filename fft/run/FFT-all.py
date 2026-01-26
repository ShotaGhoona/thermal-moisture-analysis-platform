#!/usr/bin/env python3
"""
FFT一括解析スクリプト - 熱解析シミュレーション全パターンのFFT解析

Usage:
    python FFT-all.py /path/to/batch_all/1202
    python FFT-all.py /path/to/batch_all/1202 --output-dir fft_results
    python FFT-all.py /path/to/batch_all/1202 --top-n 30 --parallel 4
"""

import sys
import logging
import argparse
from pathlib import Path
from datetime import datetime
from concurrent.futures import ProcessPoolExecutor, as_completed
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.fft import rfft, rfftfreq
import warnings

warnings.filterwarnings('ignore')

# ログ設定
def setup_logging(output_dir: Path, log_level: str = 'INFO'):
    """ログ設定"""
    log_file = output_dir / 'fft_batch_analysis.log'

    logging.basicConfig(
        level=getattr(logging, log_level),
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)


class FFTBatchAnalyzer:
    """シミュレーション出力の一括FFT解析クラス"""

    # 解析対象の周期（日単位）
    TARGET_PERIODS = {
        'annual': 365.0,      # 年周期
        'semi_annual': 182.5, # 半年周期
        'monthly': 30.0,      # 月周期
        'weekly': 7.0,        # 週周期
        'daily': 1.0,         # 日周期
        'semi_daily': 0.5,    # 半日周期
    }

    def __init__(self, batch_dir: str, output_dir: str = None, top_n: int = 20):
        """
        初期化

        Args:
            batch_dir: シミュレーション出力のバッチディレクトリ
            output_dir: FFT解析結果の出力先
            top_n: 抽出する上位周波数成分数
        """
        self.batch_dir = Path(batch_dir)
        self.top_n = top_n

        # 出力ディレクトリの設定
        if output_dir:
            self.output_dir = Path(output_dir)
        else:
            # デフォルト: fft/output/{batch_name}/raw-fft
            batch_name = self.batch_dir.name
            self.output_dir = Path(__file__).parent.parent / 'output' / batch_name / 'raw-fft'

        self.output_dir.mkdir(parents=True, exist_ok=True)

        # ログ設定
        self.logger = setup_logging(self.output_dir)
        self.logger.info(f"FFT一括解析初期化: batch_dir={self.batch_dir}")
        self.logger.info(f"出力先: {self.output_dir}")

        # 結果格納用
        self.all_features = []
        self.case_results = {}

    def find_case_directories(self) -> list:
        """解析対象のケースディレクトリを検索

        対応する構造:
        1. 従来形式: batch_dir/w01-base_o01-base_kyoto/result_all_rooms.csv
        2. data/julia形式: batch_dir/{climate}/{wall}/{opening}/result_all_rooms.csv
        3. 単一ディレクトリ: batch_dir/result_all_rooms.csv
        """
        cases = []

        # 単一ディレクトリの場合（直接CSVがある）
        if (self.batch_dir / 'result_all_rooms.csv').exists():
            cases.append(self.batch_dir)
            self.logger.info(f"単一ディレクトリモード: {self.batch_dir.name}")
            return cases

        # 従来形式: w*で始まるディレクトリ
        for d in sorted(self.batch_dir.iterdir()):
            if d.is_dir() and d.name.startswith('w'):
                csv_file = d / 'result_all_rooms.csv'
                if csv_file.exists():
                    cases.append(d)

        # 従来形式で見つかった場合
        if cases:
            self.logger.info(f"従来形式で検出: {len(cases)}ケース")
            return cases

        # data/julia形式: {climate}/{wall}/{opening} 構造を探索
        for climate_dir in sorted(self.batch_dir.iterdir()):
            if not climate_dir.is_dir():
                continue
            for wall_dir in sorted(climate_dir.iterdir()):
                if not wall_dir.is_dir():
                    continue
                for opening_dir in sorted(wall_dir.iterdir()):
                    if not opening_dir.is_dir():
                        continue
                    csv_file = opening_dir / 'result_all_rooms.csv'
                    if csv_file.exists():
                        cases.append(opening_dir)

        if cases:
            self.logger.info(f"data/julia形式で検出: {len(cases)}ケース")
        else:
            self.logger.warning("解析対象のケースが見つかりません")

        return cases

    def load_simulation_data(self, case_dir: Path) -> dict:
        """
        シミュレーション出力CSVの読み込み

        Returns:
            dict: {'room1': {'temp': array, 'rh': array, 'ah': array}, 'room2': {...}, 'sampling_rate': float}
        """
        csv_path = case_dir / 'result_all_rooms.csv'

        # 2行ヘッダーのCSV読み込み
        df = pd.read_csv(csv_path, header=[0, 1], index_col=0, encoding='utf-8')

        # インデックスをdatetimeに変換
        df.index = pd.to_datetime(df.index)

        # サンプリング間隔の計算（秒）
        td = df.index[1] - df.index[0]
        sampling_rate = td.total_seconds()

        # データ抽出
        data = {
            'room1': {
                'temp': df[('room1', 'temp')].dropna().values,
                'rh': df[('room1', 'rh')].dropna().values,
                'ah': df[('room1', 'ah')].dropna().values,
            },
            'room2': {
                'temp': df[('room2', 'temp')].dropna().values,
                'rh': df[('room2', 'rh')].dropna().values,
                'ah': df[('room2', 'ah')].dropna().values,
            },
            'sampling_rate': sampling_rate,
            'datetime_index': df.index,
        }

        return data

    def perform_fft(self, signal: np.ndarray, sampling_rate: float) -> dict:
        """
        FFT解析の実行

        Returns:
            dict: {'freqs': array, 'amplitudes': array, 'phases': array}
        """
        # FFT実行
        fft_result = rfft(signal)
        freqs = rfftfreq(len(signal), d=sampling_rate)

        # 振幅と位相
        amplitudes = np.abs(fft_result) / len(signal)
        phases = np.angle(fft_result)

        return {
            'freqs': freqs,
            'amplitudes': amplitudes,
            'phases': phases,
            'fft_result': fft_result,
        }

    def extract_features(self, fft_result: dict, sampling_rate: float, signal: np.ndarray) -> dict:
        """
        機械学習用の特徴量抽出

        Returns:
            dict: 各周期の振幅・位相を含む特徴量辞書
        """
        freqs = fft_result['freqs']
        amplitudes = fft_result['amplitudes']
        phases = fft_result['phases']

        features = {}

        # DC成分（平均値）
        features['dc_amplitude'] = amplitudes[0]

        # 各ターゲット周期の特徴量
        for period_name, period_days in self.TARGET_PERIODS.items():
            target_freq = 1 / (period_days * 86400)  # Hz

            # 最も近い周波数のインデックスを探す
            if target_freq < freqs[-1]:  # 周波数範囲内の場合
                idx = np.argmin(np.abs(freqs - target_freq))
                features[f'{period_name}_amplitude'] = amplitudes[idx]
                features[f'{period_name}_phase'] = phases[idx]
            else:
                features[f'{period_name}_amplitude'] = np.nan
                features[f'{period_name}_phase'] = np.nan

        # 上位N成分の振幅（DC成分除く）
        top_indices = np.argsort(amplitudes[1:])[-self.top_n:][::-1] + 1
        for i, idx in enumerate(top_indices):
            period_days = 1 / freqs[idx] / 86400 if freqs[idx] > 0 else np.inf
            features[f'top{i+1}_amplitude'] = amplitudes[idx]
            features[f'top{i+1}_period_days'] = period_days
            features[f'top{i+1}_phase'] = phases[idx]

        # 統計的特徴量
        features['signal_mean'] = np.mean(signal)
        features['signal_std'] = np.std(signal)
        features['signal_max'] = np.max(signal)
        features['signal_min'] = np.min(signal)

        return features

    def _extract_case_info(self, case_dir: Path) -> tuple:
        """ケースディレクトリからケース名とパラメータを抽出

        対応形式:
        1. 従来形式: w01-base_o01-base_kyoto
        2. data/julia形式: kyoto/w01/o01 -> w01_o01_kyoto
        """
        dir_name = case_dir.name

        # 従来形式: w*で始まる場合
        if dir_name.startswith('w'):
            parts = dir_name.split('_')
            wall_type = parts[0] if len(parts) > 0 else ''
            opening_type = parts[1] if len(parts) > 1 else ''
            climate = parts[2] if len(parts) > 2 else ''
            return dir_name, wall_type, opening_type, climate

        # data/julia形式: opening/wall/climate の構造
        # case_dir: .../data/julia/{climate}/{wall}/{opening}
        opening = case_dir.name  # o01
        wall = case_dir.parent.name  # w01
        climate = case_dir.parent.parent.name  # kyoto

        case_name = f"{wall}_{opening}_{climate}"
        return case_name, wall, opening, climate

    def analyze_single_case(self, case_dir: Path) -> dict:
        """単一ケースの解析"""
        case_name, wall_type, opening_type, climate = self._extract_case_info(case_dir)
        self.logger.info(f"解析開始: {case_name}")

        try:
            # データ読み込み
            data = self.load_simulation_data(case_dir)
            sampling_rate = data['sampling_rate']

            result = {
                'case_name': case_name,
                'status': 'success',
                'sampling_rate': sampling_rate,
                'data_points': len(data['room1']['temp']),
            }

            result['wall_type'] = wall_type
            result['opening_type'] = opening_type
            result['climate'] = climate

            # 各室・各変数のFFT解析
            fft_results = {}
            all_features = {'case_name': case_name}
            all_features['wall_type'] = result['wall_type']
            all_features['opening_type'] = result['opening_type']
            all_features['climate'] = result['climate']

            for room in ['room1', 'room2']:
                for var in ['temp', 'rh', 'ah']:
                    signal = data[room][var]
                    key = f'{room}_{var}'

                    # FFT解析
                    fft_res = self.perform_fft(signal, sampling_rate)
                    fft_results[key] = fft_res

                    # 特徴量抽出
                    features = self.extract_features(fft_res, sampling_rate, signal)

                    # プレフィックス付きで追加
                    for feat_name, feat_val in features.items():
                        all_features[f'{key}_{feat_name}'] = feat_val

            result['features'] = all_features
            result['fft_results'] = fft_results

            self.logger.info(f"解析完了: {case_name}")
            return result

        except Exception as e:
            self.logger.error(f"解析エラー ({case_name}): {e}")
            return {
                'case_name': case_name,
                'status': 'error',
                'error_message': str(e),
            }

    def save_case_results(self, case_dir: Path, result: dict):
        """単一ケースの結果保存"""
        if result['status'] != 'success':
            return

        case_name = result['case_name']
        case_output_dir = self.output_dir / case_name
        case_output_dir.mkdir(exist_ok=True)

        fft_results = result['fft_results']

        # CSV出力: 各室・変数のスペクトル
        for key, fft_res in fft_results.items():
            freqs = fft_res['freqs']
            periods = np.where(freqs > 0, 1 / freqs / 86400, np.inf)

            df = pd.DataFrame({
                'Frequency (Hz)': freqs,
                'Period (Day)': periods,
                'Amplitude': fft_res['amplitudes'],
                'Phase (radians)': fft_res['phases'],
            })
            csv_path = case_output_dir / f'spectrum_{key}.csv'
            df.to_csv(csv_path, index=False, encoding='utf-8-sig')

        # 特徴量サマリー
        features_df = pd.DataFrame([result['features']])
        features_csv_path = case_output_dir / 'features.csv'
        features_df.to_csv(features_csv_path, index=False, encoding='utf-8-sig')

        # プロット保存
        self._save_plots(case_output_dir, fft_results, case_name)

    def _save_plots(self, output_dir: Path, fft_results: dict, case_name: str):
        """プロットの保存"""
        fig, axes = plt.subplots(2, 3, figsize=(18, 10))
        fig.suptitle(f'FFT Analysis: {case_name}', fontsize=14)

        plot_configs = [
            ('room1_temp', 'Room1 Temperature', axes[0, 0]),
            ('room1_rh', 'Room1 Relative Humidity', axes[0, 1]),
            ('room1_ah', 'Room1 Absolute Humidity', axes[0, 2]),
            ('room2_temp', 'Room2 Temperature', axes[1, 0]),
            ('room2_rh', 'Room2 Relative Humidity', axes[1, 1]),
            ('room2_ah', 'Room2 Absolute Humidity', axes[1, 2]),
        ]

        for key, title, ax in plot_configs:
            if key in fft_results:
                fft_res = fft_results[key]
                freqs = fft_res['freqs']
                amplitudes = fft_res['amplitudes']

                # 周期（日）に変換して表示（DC成分除く）
                mask = freqs > 0
                periods = 1 / freqs[mask] / 86400
                amps = amplitudes[mask]

                # 表示範囲を制限（0.1日〜400日）
                display_mask = (periods >= 0.1) & (periods <= 400)

                ax.loglog(periods[display_mask], amps[display_mask], linewidth=0.5)
                ax.set_xlabel('Period (Days)')
                ax.set_ylabel('Amplitude')
                ax.set_title(title)
                ax.grid(True, alpha=0.3)
                ax.invert_xaxis()  # 長周期を左に

                # 主要周期にマーカー
                for period_name, period_days in self.TARGET_PERIODS.items():
                    ax.axvline(period_days, color='red', alpha=0.3, linestyle='--')

        plt.tight_layout()
        plt.savefig(output_dir / 'amplitude_spectrum.png', dpi=150, bbox_inches='tight')
        plt.close()

    def run_batch_analysis(self, parallel: int = 1):
        """バッチ解析の実行"""
        self.logger.info("=" * 60)
        self.logger.info("FFT一括解析開始")
        self.logger.info("=" * 60)

        # ケースディレクトリの検索
        cases = self.find_case_directories()

        if not cases:
            self.logger.error("解析対象のケースが見つかりません")
            return False

        # 解析実行
        results = []

        if parallel > 1:
            self.logger.info(f"並列処理: {parallel}プロセス")
            with ProcessPoolExecutor(max_workers=parallel) as executor:
                futures = {executor.submit(self.analyze_single_case, case): case for case in cases}
                for future in as_completed(futures):
                    result = future.result()
                    results.append(result)
                    if result['status'] == 'success':
                        self.save_case_results(futures[future], result)
        else:
            for i, case in enumerate(cases, 1):
                self.logger.info(f"進捗: {i}/{len(cases)}")
                result = self.analyze_single_case(case)
                results.append(result)
                if result['status'] == 'success':
                    self.save_case_results(case, result)

        # サマリー出力
        self._save_summary(results)

        # 結果レポート
        success_count = sum(1 for r in results if r['status'] == 'success')
        error_count = len(results) - success_count

        self.logger.info("=" * 60)
        self.logger.info("FFT一括解析完了")
        self.logger.info(f"  成功: {success_count}/{len(results)}")
        self.logger.info(f"  失敗: {error_count}/{len(results)}")
        self.logger.info(f"  出力先: {self.output_dir}")
        self.logger.info("=" * 60)

        return True

    def _save_summary(self, results: list):
        """処理結果のサマリー出力"""

        # 進捗ファイル
        progress_path = self.output_dir / '_progress.txt'
        with open(progress_path, 'w', encoding='utf-8') as f:
            f.write(f"FFT一括解析完了\n")
            f.write(f"解析日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"入力: {self.batch_dir}\n")
            f.write(f"出力: {self.output_dir}\n")
            f.write(f"ケース数: {len(results)}\n")
            f.write(f"成功: {sum(1 for r in results if r['status'] == 'success')}\n")
            f.write(f"\n各ケース:\n")
            for r in results:
                status = "✓" if r['status'] == 'success' else "✗"
                f.write(f"  {status} {r['case_name']}\n")


def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(
        description='FFT一括解析スクリプト - 熱解析シミュレーション全パターンのFFT解析',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
    python FFT-all.py /path/to/batch_all/1202
    python FFT-all.py /path/to/batch_all/1202 --output-dir fft_results
    python FFT-all.py /path/to/batch_all/1202 --top-n 30 --parallel 4
        """
    )

    parser.add_argument('batch_dir', help='シミュレーション出力のバッチディレクトリ')
    parser.add_argument('--output-dir', '-o', help='出力ディレクトリ（デフォルト: fft/output_data/{batch_name}_{timestamp}）')
    parser.add_argument('--top-n', type=int, default=20, help='抽出する上位周波数成分数（デフォルト: 20）')
    parser.add_argument('--parallel', '-p', type=int, default=1, help='並列プロセス数（デフォルト: 1）')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                        default='INFO', help='ログレベル（デフォルト: INFO）')

    args = parser.parse_args()

    # 入力ディレクトリ確認
    batch_path = Path(args.batch_dir)
    if not batch_path.exists():
        print(f"エラー: バッチディレクトリが見つかりません: {batch_path}")
        return 1

    # 解析実行
    analyzer = FFTBatchAnalyzer(
        batch_dir=args.batch_dir,
        output_dir=args.output_dir,
        top_n=args.top_n,
    )

    success = analyzer.run_batch_analysis(parallel=args.parallel)

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
