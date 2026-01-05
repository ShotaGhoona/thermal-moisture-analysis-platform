$env:Path += ";C:\Program Files\Git\cmd"
これをうったらぎっとがつかえるようになる

$env:Path += ";C:\Program Files\Git\cmd"
$env:Path += ";C:\Users\ogura-labo\AppData\Local\Programs\Julia-1.11.2\bin"
cd legacy-julia
julia legacy-julia/run/main-all-git-o01.jl
julia legacy-julia/run/main-all-git-o02.jl
julia legacy-julia/run/main-all-git-o03.jl
julia legacy-julia/run/main-all-git-o04.jl
julia legacy-julia/run/main-all-git-o05.jl

🚨 エラー発生

⏰ 発生時刻: 2026-01-05 15:06:16

📝 エラーメッセージ:
SystemError: opening file "./output_data/output_data/batch_all/0105/w02-inner_o02-low_okinawa/result_all_rooms.csv": No such file or directory

📋 スタックトレース:
SystemError: opening file "./output_data/output_data/batch_all/0105/w02-inner_o02-low_okinawa/result_all_rooms.csv": No such file or directory
Stacktrace:
  [1] systemerror(p::String, errno::Int32; extrainfo::Nothing)
    @ Base .\error.jl:176
  [2] systemerror
    @ .\error.jl:175 [inlined]
  [3] open(fname::String; lock::Bool, read::Nothing, write::Nothing, create::Nothing, truncate::Bool, append::Nothing)
    @ Base .\iostream.jl:295
  [4] open
    @ .\iostream.jl:277 [inlined]
  [5] open(fname::String, mode::String; lock::Bool)
    @ Base .\iostream.jl:358
  [6] open
    @ .\iostream.jl:357 [inlined]
  [7] set_logger(file_name::String, logging_interval::Float64, data_type::Vector{String}, logging_data::Vector{Room})
    @ Main C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\logger.jl:14
  [8] run_single_simulation(wall::@NamedTuple{id::String, file::String, name::String}, opening::@NamedTuple{id::String, file::String, name::String}, climate::@NamedTuple{id::String, file::String, name::String, lon::Float64, phi::Float64}, output_dir::String, case_idx::Int64, total::Int64)
    @ Main C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-o02.jl:511
  [9] main()
    @ Main C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-o02.jl:895
 [10] top-level scope
    @ C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-o02.jl:1013
 [11] include(mod::Module, _path::String)
    @ Base .\Base.jl:557
 [12] exec_options(opts::Base.JLOptions)
    @ Base .\client.jl:323
 [13] _start()
    @ Base .\client.jl:531
