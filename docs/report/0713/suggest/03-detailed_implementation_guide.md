# 小型物置最適パラメータ実装手順書

## 🎯 目標
小型物置の結露対策として、金属板(0.5mm) + グラスウール16K(50mm) + 石膏ボード(12.5mm)の3層壁構成で1D熱水分解析を実行する。

---

## 📋 実装手順（所要時間：約30分）

### ステップ1: CSVファイル作成（5分）

**1.1 フォルダ確認**
```bash
# 以下のフォルダが存在することを確認
input_data/wall_data/
```

**1.2 新規CSVファイル作成**
```
ファイル名: input_data/wall_data/storage_shed_optimal.csv
```

**1.3 CSVファイル内容**
以下を完全にコピー&ペーストして保存：
```csv
セル番号,セル幅,材料名,温度,相対湿度
i,dx,material_name,temp,rh
1,0.0005,metal_plate,10,70
2,0.0167,glass_wool_16K,10,70
3,0.0167,glass_wool_16K,10,70
4,0.0166,glass_wool_16K,10,70
5,0.00625,plasterboard,10,70
6,0.00625,plasterboard,10,70
```

**注意事項:**
- ヘッダー行（3行目）の`i,dx,material_name,temp,rh`は必須
- 数値は小数点も含めて正確に入力
- ファイル保存時の文字コードはUTF-8

---

### ステップ2: 1D_calculation.ipynb修正（15分）

**2.1 Jupyter Notebook起動**
```bash
# プロジェクトルートディレクトリで実行
jupyter notebook 1D_calculation.ipynb
```

**2.2 セル[4]実行（モジュール読込）**
```julia
# そのまま実行（変更なし）
using Dates
include("./module/cell.jl");
include("./module/air.jl");
include("./module/boundary_condition.jl");
include("./module/transfer_in_media.jl");
include("./module/climate.jl");
include("./logger.jl");
```

**2.3 セル[6]新規追加（壁データ読込関数）**
セル[6]と[7]の間に新しいセルを追加し、以下をコピー&ペースト：
```julia
# CSVファイル読込用モジュール
using CSV, DataFrames
include("./module/property_conversion.jl")

# 壁データ読込関数
function input_cell_data(file_name::String)
    file_directory = "./input_data/wall_data/"*string(file_name)*".csv"
    input_data = CSV.File(file_directory, header = 3) |> DataFrame
    cell = [Cell() for i = 1:length(input_data.i)]
    
    for i = 1:length(input_data.i)
        cell[i].i = [input_data.i[i], 1, 1]
        cell[i].dx = input_data.dx[i]
        cell[i].temp = input_data.temp[i] + 273.15
        cell[i].material_name = input_data.material_name[i]
        cell[i].rh = input_data.rh[i] / 100
        cell[i].miu = convertRH2Miu(temp = cell[i].temp, rh = cell[i].rh)
        
        # dx2設定
        if i == 1 || i == length(input_data.i)
            cell[i].dx2 = cell[i].dx
        else
            cell[i].dx2 = cell[i].dx / 2
        end
    end
    return cell
end
```

**2.4 セル[7]完全置換**
既存のセル[7]内容を以下で完全に置き換える：
```julia
# CSVファイルから壁構成を読込
wall = input_cell_data("storage_shed_optimal")
L = length(wall)

# 壁厚の確認表示
total_width = sum([cell.dx for cell in wall])
println("総壁厚: ", total_width*1000, "mm")
println("セル数: ", L, "個")
for i = 1:L
    println("Layer ", i, ": ", wall[i].material_name, " (", wall[i].dx*1000, "mm)")
end
```

**2.5 セル[8]削除またはコメントアウト**
セル[8]の内容を以下でコメントアウト：
```julia
# 手動設定は使用しないためコメントアウト
# for i = 1 : L
#     wall[i].i = [ i, 1, 1 ]
#     if i == 1 || i == L     wall[i].dx  = ( width / ( L - 1 ) / 2 )
#     else                    wall[i].dx = width / ( L - 1 ) end
#     ...
# end
```

**2.6 セル[10]修正（室内側境界条件）**
以下の行を修正：
```julia
air_in = BC_Robin()
air_in.air.name = "indoor"
air_in.air.temp = 10.0 + 273.15  # 物置内温度10℃
air_in.air.rh   = 0.7            # 物置内湿度70%RH ← 変更
air_in.alphac = 4.9
air_in.alphar = 4.4
air_in.alpha  = air_in.alphac + air_in.alphar
air_in.aldm   = aldm_by_alphac(air_in)
```

**2.7 セル[11]修正（外気側境界条件）**
以下の行を修正：
```julia
air_out = BC_Robin()
air_out.air.name = "outdoor"
air_out.air.temp = 20.0 + 273.15
air_out.air.rh   = 0.6
air_out.alphac = 18.6            # 外気側対流熱伝達率 ← 変更
air_out.alphar = 4.4
air_out.alpha  = air_out.alphac + air_out.alphar  # 23.0 W/m²K
air_out.aldm   = aldm_by_alphac(air_out)
```

**2.8 セル[27]修正（ロガー設定）**
ファイル名を変更：
```julia
logger_room = set_logger("result_storage_shed", 10.0, ["temp","rh","ah"], target_model)
```

---

### ステップ3: 計算実行（5分）

**3.1 セル順次実行**
以下の順序でセルを実行：
1. セル[4] → モジュール読込
2. セル[6] → CSV読込関数定義
3. セル[7] → 壁構成読込
4. セル[10] → 室内境界条件
5. セル[11] → 外気境界条件
6. セル[13] → モデル結合
7. セル[16] → 物理法則定義
8. セル[19] → 計算条件設定
9. セル[22] → 室内気象データ
10. セル[24] → 外気気象データ
11. セル[27] → ロガー設定
12. セル[29] → メイン計算実行

**3.2 実行中の確認ポイント**
```
セル[7]実行後の表示例:
総壁厚: 63.0mm
セル数: 6個
Layer 1: metal_plate (0.5mm)
Layer 2: glass_wool_16K (16.7mm)
Layer 3: glass_wool_16K (16.7mm)
Layer 4: glass_wool_16K (16.6mm)
Layer 5: plasterboard (6.25mm)
Layer 6: plasterboard (6.25mm)

セル[29]実行中の表示例:
2012/04/01 00:00 外気：温度3.7[℃] 湿度0.77[-]
2012/04/02 00:00 外気：温度6.7[℃] 湿度0.68[-]
...
```

**3.3 計算完了確認**
- 約7日間の計算で約5-10分程度
- エラーなく完了すると自動的に次のセルに進む
- `output_data/result_storage_shed.csv`ファイルが生成される

---

### ステップ4: 結果確認（5分）

**4.1 出力ファイル確認**
```bash
# 結果ファイルの存在確認
ls -la output_data/result_storage_shed.csv

# ファイルサイズ確認（約100KB程度が正常）
du -h output_data/result_storage_shed.csv
```

**4.2 結果データの簡単チェック**
```julia
# セル[30]に新規追加
using CSV, DataFrames
result = CSV.File("./output_data/result_storage_shed.csv") |> DataFrame

# データ概要表示
println("データ行数: ", nrow(result))
println("カラム数: ", ncol(result))
println("計算期間: ", result[1,1], " → ", result[end,1])

# 温度範囲チェック
temp_cols = [col for col in names(result) if contains(col, "temp")]
for col in temp_cols
    println(col, ": ", round(minimum(result[!,col])-273.15, digits=1), "℃ → ", 
                       round(maximum(result[!,col])-273.15, digits=1), "℃")
end
```

**4.3 期待される結果の例**
```
データ行数: 2017
カラム数: 25
計算期間: 2012-04-01T00:00:00 → 2012-04-08T00:00:00
air_in_temp: 9.8℃ → 10.2℃
cell_1_temp: 8.5℃ → 12.3℃  (金属板)
cell_2_temp: 8.8℃ → 11.8℃  (グラスウール外側)
cell_3_temp: 9.2℃ → 11.2℃  (グラスウール中央)
cell_4_temp: 9.5℃ → 10.8℃  (グラスウール内側)
cell_5_temp: 9.7℃ → 10.5℃  (石膏ボード外側)
cell_6_temp: 9.9℃ → 10.3℃  (石膏ボード内側)
air_out_temp: 3.7℃ → 17.1℃
```

---

## 🚨 トラブルシューティング

### エラー1: CSVファイル読込エラー
```
エラー: BoundsError: attempt to access 0-element Vector
解決: ヘッダー行の確認、ファイルパスの確認
```

### エラー2: 材料名エラー
```
エラー: UndefVarError: metal_plate not defined
解決: 材料名のスペルチェック（metal_plate, glass_wool_16K, plasterboard）
```

### エラー3: 数値エラー
```
エラー: MethodError: no method matching +(::String, ::Float64)
解決: CSVファイルの数値に文字が混入していないかチェック
```

### エラー4: 計算が進まない
```
症状: セル[29]で停止
解決: 気象データファイルの確認、dtの値を大きく（5.0等）に変更
```

---

## ✅ 成功判定基準

### 1. 定量的指標
- [ ] 計算が7日間正常完了（エラーなし）
- [ ] 結果ファイルが生成（約2000行のデータ）
- [ ] 内表面温度が外気温度より高い
- [ ] 室内側温度変動が外気変動より小さい

### 2. 物理的妥当性
- [ ] 温度分布：外気 < 金属板 < グラスウール < 石膏ボード < 室内
- [ ] 湿度分布：適切な勾配（急激な変化なし）
- [ ] 結露なし：全セルの温度 > 露点温度

### 3. 改善効果
- [ ] 内表面温度向上：断熱なしと比較して3-5℃向上
- [ ] 温度変動軽減：日較差が50%以下に軽減
- [ ] 湿度安定化：変動幅が30%以下に軽減

---

## 📊 次ステップ（オプション）

### データ分析例
```julia
# 結露リスク評価
using Plots
result = CSV.File("./output_data/result_storage_shed.csv") |> DataFrame

# 内表面温度と露点温度の比較
inner_temp = result.cell_6_temp .- 273.15  # 石膏ボード内側温度
indoor_rh = result.air_in_rh
dewpoint = [dewpoint_temp(result.air_in_temp[i], indoor_rh[i]) for i in 1:nrow(result)]

# グラフ化
plot(inner_temp, label="内表面温度", linewidth=2)
plot!(dewpoint, label="露点温度", linewidth=2, linestyle=:dash)
xlabel!("時間ステップ")
ylabel!("温度 [℃]")
title!("結露リスク評価：内表面温度 vs 露点温度")
```

### 比較検討
1. **断熱材厚さ変更**: 25mm, 75mm, 100mmでの比較
2. **材料変更**: 押出法ポリスチレン、ウレタンフォームとの比較
3. **境界条件変更**: より厳しい冬季条件での検証

---

## 🏆 完了報告

実装完了後、以下を確認してください：

✅ **基本動作確認**
- CSVファイル作成完了
- 1D_calculation.ipynb修正完了
- 計算実行完了
- 結果ファイル生成完了

✅ **結果妥当性確認**
- 温度分布が物理的に妥当
- 結露発生なし
- 期待される改善効果を確認

**これで小型物置の最適パラメータによる1D熱水分解析が完了です！**