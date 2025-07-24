# Plots.jl 使い方完全ガイド - Julia による科学データ可視化

## 目次
1. [Plots.jl とは](#plots-jl-とは)
2. [環境設定](#環境設定)
3. [基本的な使い方](#基本的な使い方)
4. [実用例：今回のプロジェクト](#実用例今回のプロジェクト)
5. [高度な機能](#高度な機能)
6. [トラブルシューティング](#トラブルシューティング)
7. [参考資料](#参考資料)

---

## Plots.jl とは

**Plots.jl** は Julia 言語の統一的なプロット API です。複数のバックエンド（GR、PlotlyJS、PyPlot など）を統一的な文法で使用できます。

### 特徴
- **統一的な API**: バックエンドを切り替えても同じコードで動作
- **高速**: Julia の高速性を活かした描画
- **インタラクティブ**: PlotlyJS バックエンドでズーム・パン可能
- **豊富な出力形式**: PNG、SVG、HTML、PDF など

---

## 環境設定

### 1. パッケージのインストール

```julia
using Pkg

# 基本パッケージ
Pkg.add(["Plots", "CSV", "DataFrames", "Dates"])

# バックエンド（お好みで）
Pkg.add("PlotlyJS")  # インタラクティブグラフ
Pkg.add("GR")        # 高速・軽量（デフォルト）
Pkg.add("PyPlot")    # Matplotlib ベース
```

### 2. パッケージの読み込み

```julia
using Plots, CSV, DataFrames, Dates

# バックエンドの選択
plotlyjs()  # インタラクティブ
# gr()      # 高速描画（デフォルト）
# pyplot()  # Matplotlib風
```

### 3. テーマの設定

```julia
theme(:bright)    # 明るいテーマ
theme(:dark)      # ダークテーマ  
theme(:wong)      # カラーブラインド対応
theme(:default)   # デフォルト
```

---

## 基本的な使い方

### 1. シンプルなプロット

```julia
# 基本的な線グラフ
x = 1:10
y = x.^2
plot(x, y)

# 複数系列
y1 = x.^2
y2 = x.^1.5
plot(x, [y1 y2], label=["x²" "x^1.5"])
```

### 2. データフレームからのプロット

```julia
# CSVデータの読み込み
df = CSV.read("data.csv", DataFrame)

# 時系列データ
dates = DateTime.(df.date, "yyyy/mm/dd HH:MM")
plot(dates, df.temperature, 
     title="温度変化", 
     xlabel="時間", 
     ylabel="温度 (℃)")
```

### 3. 複数のグラフを重ねる

```julia
# 最初のプロット
p = plot(x, y1, label="系列1")

# 追加のプロット
plot!(p, x, y2, label="系列2")  # ! で既存グラフに追加

# または一度に
plot(x, [y1 y2], label=["系列1" "系列2"])
```

### 4. グラフの保存

```julia
# 静的画像
savefig("graph.png")
savefig("graph.svg")
savefig("graph.pdf")

# インタラクティブ（PlotlyJS使用時）
savefig("graph.html")
```

---

## 実用例：今回のプロジェクト

### データ読み込みからグラフ作成まで

```julia
using Plots, CSV, DataFrames, Dates
plotlyjs()  # インタラクティブバックエンド

# データ読み込み
data = CSV.read("result_case0.2_all_rooms.csv", DataFrame, header=2)
dates = DateTime.(data[:,1], "yyyy/mm/dd HH:MM")

# 最初の1000ポイントを使用（データが大きい場合）
n = min(1000, size(data, 1))
dates_plot = dates[1:n]
data_plot = data[1:n, :]

# 温度比較グラフ
temperature_plot = plot(
    dates_plot, 
    [data_plot[:,2], data_plot[:,5], data_plot[:,8]], # 各室の温度列
    label=["外気" "物置内部" "地面"],
    title="物置小屋の温度変化",
    xlabel="時間",
    ylabel="温度 (℃)",
    linewidth=2,
    legend=:topright
)

# グラフの保存
savefig(temperature_plot, "temperature_comparison.png")
savefig(temperature_plot, "temperature_comparison.html")
```

### 2軸グラフ（温度と湿度）

```julia
# 温度を左軸
p1 = plot(dates_plot, data_plot[:,2], 
          label="温度", 
          color=:blue, 
          linewidth=2,
          ylabel="温度 (℃)")

# 湿度を右軸
plot!(twinx(), dates_plot, data_plot[:,3], 
      label="湿度", 
      color=:red, 
      linewidth=2, 
      ylabel="相対湿度 (-)",
      legend=:topright)
```

### 複数グラフのレイアウト

```julia
# 4つのサブプロット
p1 = plot(dates, temp1, title="温度1")
p2 = plot(dates, temp2, title="温度2") 
p3 = plot(dates, humid1, title="湿度1")
p4 = plot(dates, humid2, title="湿度2")

# 2x2 レイアウト
combined = plot(p1, p2, p3, p4, 
                layout=(2,2), 
                size=(1200,800))
```

---

## 高度な機能

### 1. カスタマイズ可能な属性

```julia
plot(x, y,
     # 線の設定
     linewidth=3,
     linestyle=:dash,    # :solid, :dash, :dot, :dashdot
     color=:red,
     
     # マーカー
     markershape=:circle, # :square, :diamond, :cross など
     markersize=5,
     markercolor=:blue,
     
     # ラベル・タイトル
     title="グラフタイトル",
     xlabel="X軸ラベル", 
     ylabel="Y軸ラベル",
     label="凡例ラベル",
     
     # 凡例
     legend=:topright,   # :topleft, :bottomright, :none など
     
     # サイズ
     size=(800, 600),
     
     # 軸の設定
     xlims=(0, 10),
     ylims=(-5, 5),
     xscale=:log10,     # 対数軸
     yscale=:log10)
```

### 2. アニメーション

```julia
# アニメーション作成
anim = @animate for i in 1:100
    plot(x, sin.(x .+ i/10), 
         title="時間 = $i", 
         ylims=(-1.5, 1.5))
end

# GIF として保存
gif(anim, "animation.gif", fps=10)
```

### 3. ヒートマップ

```julia
# 2次元データのヒートマップ
z = rand(10, 10)
heatmap(z, 
        title="ヒートマップ",
        xlabel="X", 
        ylabel="Y",
        color=:viridis)
```

### 4. 3Dプロット

```julia
# 3次元散布図
x, y, z = rand(100), rand(100), rand(100)
scatter(x, y, z, 
        title="3D散布図",
        xlabel="X", ylabel="Y", zlabel="Z")

# 3次元サーフェス
x = -5:0.5:5
y = -5:0.5:5
z = [sin(sqrt(xi^2 + yi^2)) for yi in y, xi in x]
surface(x, y, z, title="3Dサーフェス")
```

---

## エラーハンドリング

### よくあるエラーと対処法

```julia
# データ読み込みエラーの対処
try
    data = CSV.read("data.csv", DataFrame)
    plot(data.x, data.y)
catch e
    println("データ読み込みエラー: ", e)
    # デフォルトデータでプロット
    plot([1,2,3], [1,4,9], title="デフォルトデータ")
end

# 変数未定義エラーの対処
if @isdefined(plot_data)
    plot(plot_data)
else
    println("データが定義されていません")
end
```

---

## 実際のワークフロー例

### 科学データ分析の典型的な流れ

```julia
# 1. 環境設定
using Plots, CSV, DataFrames, Dates
plotlyjs()
theme(:bright)

# 2. データ読み込み
function load_simulation_data(filename)
    try
        data = CSV.read(filename, DataFrame, header=2)
        dates = DateTime.(data[:,1], "yyyy/mm/dd HH:MM")
        return data, dates
    catch e
        println("データ読み込みエラー: $filename - $e")
        return nothing, nothing
    end
end

# 3. プロット関数の定義
function plot_temperature_comparison(data, dates, title_str="温度比較")
    n = min(1000, length(dates))  # データ点数制限
    
    p = plot(dates[1:n], 
             [data[1:n,2], data[1:n,5], data[1:n,8]],
             label=["外気" "室内" "地面"],
             title=title_str,
             xlabel="時間",
             ylabel="温度 (℃)",
             linewidth=2,
             legend=:topright)
    
    return p
end

# 4. 実行とファイル保存
data, dates = load_simulation_data("result_data.csv")

if data !== nothing
    temp_plot = plot_temperature_comparison(data, dates)
    
    # 複数形式で保存
    savefig(temp_plot, "results/temperature.png")
    savefig(temp_plot, "results/temperature.html")
    
    display(temp_plot)  # Jupyter等で表示
end
```

---

## パフォーマンス最適化

### 大きなデータの処理

```julia
# データの間引き
function downsample_data(data, factor=10)
    return data[1:factor:end, :]
end

# 効率的なプロット
function efficient_plot(x, y, max_points=1000)
    if length(x) > max_points
        step = div(length(x), max_points)
        x = x[1:step:end]
        y = y[1:step:end]
    end
    
    return plot(x, y)
end
```

---

## トラブルシューティング

### よくある問題と解決法

#### 1. パッケージが見つからない
```julia
# 解決法: パッケージを追加
Pkg.add("PackageName")
```

#### 2. グラフが表示されない
```julia
# バックエンドを変更
gr()        # または
plotlyjs()  # または  
pyplot()
```

#### 3. メモリ不足
```julia
# データを間引く
data_small = data[1:10:end, :]  # 10個に1個取得

# または範囲を限定
data_range = data[1:1000, :]
```

#### 4. 日本語文字化け
```julia
# フォント設定（システム依存）
plot(x, y, 
     title="日本語タイトル",
     fontfamily="Hiragino Sans")  # macOS
     # fontfamily="MS Gothic"     # Windows
```

---

## 実用的なテンプレート

### 科学論文用のプロット

```julia
function scientific_plot(x, y; 
                        title="", xlabel="", ylabel="",
                        save_name="plot")
    
    p = plot(x, y,
             title=title,
             xlabel=xlabel, 
             ylabel=ylabel,
             linewidth=2,
             legend=:topright,
             size=(600, 400),
             dpi=300,                # 高解像度
             fontsize=12,
             gridwidth=1,
             gridcolor=:gray,
             framestyle=:box)        # 枠線
    
    # 高品質で保存
    savefig(p, "$save_name.png")
    savefig(p, "$save_name.pdf")    # ベクター形式
    
    return p
end
```

### レポート用の統合関数

```julia
function create_analysis_report(data_file, output_dir="plots")
    # ディレクトリ作成
    mkpath(output_dir)
    
    # データ読み込み
    data, dates = load_simulation_data(data_file)
    
    if data === nothing
        return false
    end
    
    # 複数のグラフを作成
    plots_list = []
    
    # 温度グラフ
    p1 = plot_temperature_comparison(data, dates)
    push!(plots_list, p1)
    savefig(p1, "$output_dir/temperature.png")
    
    # 湿度グラフ  
    p2 = plot_humidity_comparison(data, dates)
    push!(plots_list, p2)
    savefig(p2, "$output_dir/humidity.png")
    
    # サマリーグラフ
    summary = plot(p1, p2, layout=(2,1), size=(800,800))
    savefig(summary, "$output_dir/summary.png")
    
    println("レポート生成完了: $output_dir")
    return true
end
```

---

## まとめ

### Plots.jl を効果的に使うコツ

1. **バックエンド選択**: 用途に応じて使い分け
   - `gr()`: 高速・軽量、論文用
   - `plotlyjs()`: インタラクティブ、プレゼン用
   - `pyplot()`: Matplotlib風、細かい調整

2. **データ前処理**: 大きなデータは間引く

3. **関数化**: 繰り返し使うプロットは関数に

4. **エラーハンドリング**: try-catch で安全性確保

5. **保存形式**: PNG（一般）、PDF（論文）、HTML（共有）

### 次のステップ

- 公式ドキュメント: https://docs.juliaplots.org/
- ギャラリー: https://docs.juliaplots.org/stable/gallery/
- コミュニティ: Julia Discourse, GitHub Issues

Julia の Plots.jl により、科学データの可視化が効率的かつ美しく実現できます。このガイドを参考に、様々なデータ解析プロジェクトで活用してください！

---

*作成日: 2025-07-23*  
*対象: Julia 1.11.x, Plots.jl v1.40+*