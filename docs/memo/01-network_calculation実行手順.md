# 01-network_calculation.ipynb 実行手順

## 概要
network_calculation.ipynbは建物全体の温湿度環境解析を行う高度なプログラムです。
室内・壁体・開口・外界気象の相互作用を統合的に計算します。

## 環境準備

### 1. Julia環境の設定

```bash
# ターミナルでJuliaを起動
julia
```

### 2. 必要パッケージのインストール

```julia
using Pkg
Pkg.add("CSV")
Pkg.add("DataFrames") 
Pkg.add("Plots")
Pkg.add("Dates")
Pkg.add("XLSX")
Pkg.add("StringEncodings")
```

## Cursor/VS Codeでの実行方法

### 1. 拡張機能のインストール
- 拡張機能タブを開く
- "Julia" で検索してインストール

### 2. Juliaカーネルの起動
- `Cmd+Shift+P` でコマンドパレットを開く
- "Julia: Start REPL" を実行
- 下部にJulia REPLが起動

### 3. Notebookの実行
1. `network_calculation.ipynb` を開く
2. 右上の "Select Kernel" をクリック
3. "Julia 1.11.5" を選択
4. 各セルの ▶︎ ボタンをクリック（または `Shift+Enter`）

## プログラムの構造

### 計算フロー
1. **モジュール読み込み** → 必要な計算機能を準備
2. **モデル構築** → 建物（室・壁・開口）＋気象データの結合
3. **流量計算** → 熱・水分の移動量を計算
4. **収支計算** → 新しい温湿度状態を算出
5. **時間更新** → 次の時刻へ進行
6. **結果保存** → CSVファイルに出力

### 主要な構成要素
- **rooms**: 室内空間（storage room, special storage room等）
- **walls**: 壁体構成（材料・厚さ・物性値）
- **openings**: 開口・隙間（換気量）
- **climate**: 外界気象（温度・湿度・日射）

## input_dataの構造と変更方法

### 1. room_condition.CSV
```csv
num,name,vol,temp,rh,Hight,Qs,Js,AC
2,storage room,646.2,10,56,0.01,0,0,OFF
3,special storage room,112.1,10,56,0.02,0,0,OFF
```

**変更例：室温の設定**
- `temp` 列の値を変更（例：10→20）
- 各室の初期温度を設定

### 2. wall_condition.CSV
```csv
num,IP,IM,Type,div_num,material_name,temp,rh,thickness,area,ION,dir_IP,dir_IM...
1,1,5,wall4,,,,,0.175,26.3,90,N,S...
2,1,2,wall1,,,,,0.22,41.6,90,N,S...
```

**変更例：壁体タイプの変更**
- `Type` 列を変更（例：wall1→wall_mud）
- 対応する `cell_data/` フォルダ内のファイルが必要

### 3. opening_condition.CSV
```csv
# 換気量・開口条件の設定
```

**変更例：換気量の調整**
- 換気回数や開口面積を変更

### 4. climate_data/climate_data_nagoya.csv
```csv
date,temp,rh,p_atm,Jp,Js,WS,WD,Qs,tau,cloudiness
2022/4/1 0:00,9.4,89,,1,,,,,1.00E-50,
2022/4/1 1:00,9.4,86,,0.5,,,,,1.00E-50,
```

**変更例：外気条件の変更**
- `temp` 列：外気温度（℃）
- `rh` 列：外気相対湿度（%）
- 他の気象データファイルに変更可能

## 実験提案

### A. 短時間テスト（推奨）
```julia
# セル25で計算期間を短縮
end_date = network_model.climate.date + Hour(24)  # 24時間だけ
```

### B. 室温変更実験
1. `room_condition.CSV` を開く
2. storage room の `temp` を 10→25 に変更
3. 計算実行して温度変化を観察

### C. 外気条件変更実験
1. `climate_data_nagoya.csv` の `temp` 列を +5℃
2. または `climate_data_okazaki.csv` に変更
3. 建物内環境への影響を確認

### D. 壁体材料変更実験
1. `wall_condition.CSV` の `Type` を変更
2. `cell_data/` フォルダ内の対応ファイルを確認
3. 材料特性の違いによる影響を観察

## 出力ファイル

### 計算結果の保存場所
```
output_data/
├── result_case0.2_all_rooms.csv      # 全室の温湿度
├── result_case0.2_wall1.csv          # 壁体1の内部状態
├── result_case0.2_wall2.csv          # 壁体2の内部状態
└── result_case0.2_room.csv           # 詳細解析結果
```

### 結果の確認方法
```julia
# 結果読み込みと可視化
using CSV, DataFrames, Plots
result = CSV.read("output_data/result_case0.2_all_rooms.csv", DataFrame)
plot(result.storage_room_temp, label="Storage Room Temperature")
```

## トラブルシューティング

### 1. カーネル選択の問題
**症状**: "Select Kernel" で Julia が選択できない
**対処**:
- Julia拡張機能の再インストール
- `Cmd+Shift+P` → "Julia: Restart REPL"

### 2. モジュール読み込みエラー
**症状**: `UndefVarError` や `LoadError`
**対処**:
- セルを順番に実行（飛ばし読み禁止）
- Julia REPL を再起動

### 3. ファイルが見つからないエラー
**症状**: `SystemError: opening file`
**対処**:
- 現在のディレクトリを確認: `pwd()`
- ファイルパスが正しいか確認

### 4. 計算エラー
**症状**: 温度や湿度が異常値
**対処**:
```julia
# エラー箇所の特定
println(network_model.climate.date)
for i = 1 : length(network_model.walls)
    for j = 1 : length(network_model.walls[i].cell)
        println("i = ",i, " j = ", j, " , ", rh(network_model.walls[i].cell[j]))
    end
end
```

### 5. メモリ不足
**症状**: 計算が非常に遅いまたは停止
**対処**:
- 計算期間を短縮
- `dt` (時間刻み) を大きくする

## 実行時のポイント

### セル実行の順序
1. **必ず上から順番に実行**
2. モジュール読み込みを最初に実行
3. エラーが出たら該当セルを再実行

### 計算時間の目安
- 24時間計算：約2-3分
- 1ヶ月計算：約30分-1時間
- 1年計算：数時間

### 推奨設定
```julia
# 初回実行時の推奨設定
dt = 1.0                                    # 時間刻み：1秒
end_date = network_model.climate.date + Hour(24)  # 24時間計算
```

## 期待される結果

### 物理的に正しい結果の例
- **室温**: 外気温度に応じて変化
- **壁体内温度**: 室内外の中間値
- **相対湿度**: 0-1の範囲内
- **時間変化**: 滑らかな変化曲線

### 異常な結果の例
- 温度が負の値や100℃超
- 相対湿度が1.0超または負の値
- 急激な不連続変化

## 応用展開

### 1. パラメータスタディ
- 複数の材料構成を比較
- 換気量の影響を定量評価
- 季節変化の長期解析

### 2. 最適化問題
- 最適な室温設定の探索
- エネルギー消費量の最小化
- 快適性と省エネの両立

### 3. 実測値との比較
- 実測データとの検証
- モデルの精度向上
- 新材料の性能予測

---

**作成日**: 2025-01-13  
**更新**: network_calculation.ipynb の実行方法と input_data 変更実験の手順