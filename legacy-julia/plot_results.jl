# 物置小屋シミュレーション結果の可視化
# 2025/07/23

using Plots, CSV, DataFrames, Dates

# プロットの設定
plotlyjs() # インタラクティブなplotlyjs backend使用
theme(:bright) # 明るいテーマ

println("データを読み込み中...")

# 1. 全室の温湿度データ読み込み
data_rooms = CSV.read("./output_data/result_case0.2_all_rooms.csv", DataFrame, header=2)
dates = DateTime.(data_rooms[:,1], "yyyy/mm/dd HH:MM")

# データの前処理（最初の100データポイントを使用、18ヶ月分は重すぎるため）
n_points = min(1000, size(data_rooms, 1)) # 最大1000ポイント
dates_plot = dates[1:n_points]
data_plot = data_rooms[1:n_points, :]

println("グラフを作成中...")

# 2. 温度変化のグラフ
p1 = plot(dates_plot, 
          [data_plot[:,2], data_plot[:,5], data_plot[:,8]], # room1, room2, room3の温度
          label=["外気(outdoor)" "物置内部(storage)" "地面(ground)"],
          title="物置小屋の温度変化",
          xlabel="時間",
          ylabel="温度 (℃)",
          linewidth=2,
          legend=:topright)

# 3. 湿度変化のグラフ  
p2 = plot(dates_plot,
          [data_plot[:,3], data_plot[:,6], data_plot[:,9]], # room1, room2, room3の湿度
          label=["外気(outdoor)" "物置内部(storage)" "地面(ground)"],
          title="物置小屋の湿度変化", 
          xlabel="時間",
          ylabel="相対湿度 (-)",
          linewidth=2,
          legend=:topright)

# 4. 絶対湿度変化のグラフ
p3 = plot(dates_plot,
          [data_plot[:,4], data_plot[:,7], data_plot[:,10]], # room1, room2, room3の絶対湿度
          label=["外気(outdoor)" "物置内部(storage)" "地面(ground)"],
          title="物置小屋の絶対湿度変化",
          xlabel="時間", 
          ylabel="絶対湿度 (kg/kg)",
          linewidth=2,
          legend=:topright)

# 5. 温湿度の複合グラフ（2軸）
p4 = plot(dates_plot, data_plot[:,2], 
          label="外気温度", 
          color=:blue, 
          linewidth=2,
          ylabel="温度 (℃)",
          title="外気の温度・湿度変化")
plot!(twinx(), dates_plot, data_plot[:,3], 
      label="外気湿度", 
      color=:red, 
      linewidth=2, 
      ylabel="相対湿度 (-)",
      legend=:topright)

# 6. 物置内部の温湿度変化
p5 = plot(dates_plot, data_plot[:,5], 
          label="物置温度", 
          color=:green, 
          linewidth=2,
          ylabel="温度 (℃)",
          title="物置内部の温度・湿度変化")
plot!(twinx(), dates_plot, data_plot[:,6], 
      label="物置湿度", 
      color=:orange, 
      linewidth=2,
      ylabel="相対湿度 (-)",
      legend=:topright)

println("壁体データを読み込み中...")

# 7. 壁体内温度分布（Wall1: 外壁）
try
    data_wall1 = CSV.read("./output_data/result_case0.2_wall1.csv", DataFrame, header=2)
    dates_wall = DateTime.(data_wall1[1:n_points,1], "yyyy/mm/dd HH:MM")
    
    p6 = plot(dates_wall,
              [data_wall1[1:n_points,2], data_wall1[1:n_points,6], data_wall1[1:n_points,10]], # climate, wall, storage
              label=["外気側" "壁体内部" "室内側"],
              title="外壁(金属板)内の温度分布",
              xlabel="時間",
              ylabel="温度 (℃)",
              linewidth=2,
              legend=:topright)
    
    # 8. 床の温度分布（Wall2: コンクリート床）
    data_wall2 = CSV.read("./output_data/result_case0.2_wall2.csv", DataFrame, header=2)
    
    p7 = plot(dates_wall,
              [data_wall2[1:n_points,2], data_wall2[1:n_points,6], data_wall2[1:n_points,10]], # storage, wall, ground
              label=["物置側" "床内部" "地面側"],
              title="床(コンクリート)内の温度分布",
              xlabel="時間", 
              ylabel="温度 (℃)",
              linewidth=2,
              legend=:topright)
              
    # 9. 全体のサマリーグラフ（2x2レイアウト）
    p8 = plot(p1, p2, p6, p7, layout=(2,2), size=(1200,800))
    plot!(plot_title="物置小屋シミュレーション結果サマリー")
    
    println("壁体グラフを作成しました")
catch e
    println("壁体データの読み込みでエラー: ", e)
    p6 = plot(title="壁体データ読み込みエラー")
    p7 = plot(title="壁体データ読み込みエラー")
    p8 = plot(p1, p2, layout=(1,2), size=(1200,400))
end

println("グラフを保存中...")

# グラフの保存
savefig(p1, "./output_data/plots/temperature_comparison.png")
savefig(p2, "./output_data/plots/humidity_comparison.png") 
savefig(p3, "./output_data/plots/absolute_humidity_comparison.png")
savefig(p4, "./output_data/plots/outdoor_temp_humidity.png")
savefig(p5, "./output_data/plots/storage_temp_humidity.png")

try
    savefig(p6, "./output_data/plots/wall1_temperature_distribution.png")
    savefig(p7, "./output_data/plots/wall2_temperature_distribution.png")
    savefig(p8, "./output_data/plots/summary_analysis.png")
catch e
    println("一部のグラフ保存でエラー: ", e)
end

# HTML形式でインタラクティブグラフも保存
savefig(p1, "./output_data/plots/temperature_comparison.html")
savefig(p2, "./output_data/plots/humidity_comparison.html")

println("完了！以下のファイルが生成されました:")
println("- temperature_comparison.png/html : 温度比較グラフ")
println("- humidity_comparison.png/html : 湿度比較グラフ") 
println("- absolute_humidity_comparison.png : 絶対湿度比較グラフ")
println("- outdoor_temp_humidity.png : 外気の温湿度変化")
println("- storage_temp_humidity.png : 物置内の温湿度変化")
println("- wall1_temperature_distribution.png : 外壁内温度分布")
println("- wall2_temperature_distribution.png : 床内温度分布")
println("- summary_analysis.png : サマリー分析")

# 最後に主要なグラフを表示
display(p1)
display(p2)
try
    display(p8)
catch e
    println("サマリーグラフの表示でエラー: ", e)
end

println("\n=== 分析完了 ===")
println("グラフファイルは ./output_data/plots/ フォルダに保存されました")