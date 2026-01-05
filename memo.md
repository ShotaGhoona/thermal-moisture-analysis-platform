$env:Path += ";C:\Program Files\Git\cmd"
これをうったらぎっとがつかえるようになる

$env:Path += ";C:\Program Files\Git\cmd"
$env:Path += ";C:\Users\ogura-labo\AppData\Local\Programs\Julia-1.11.2\bin"
cd legacy-julia
julia run/main-all-git-o01.jl
julia run/main-all-git-o02.jl
julia run/main-all-git-o03.jl
julia run/main-all-git-o04.jl
julia run/main-all-git-o05.jl


ERROR: LoadError: SystemError: opening file "./output_data/output_data/batch_test/0105_1456/w01-base_o01-base_kyoto/result_all_rooms.csv": No such file or directory
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
 [8] main()
   @ Main C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-test.jl:271
 [9] top-level scope
   @ C:\Users\ogura-labo\OneDrive - Kyoto University\デスクト ップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-test.jl:328
in expression starting at C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトップ\yamashita2025\thermal-moisture-analysis-platform\legacy-julia\run\main-all-git-test.jl:328
PS C:\Users\ogura-labo\OneDrive - Kyoto University\デスクトッ プ\yamashita2025\thermal-moisture-analysis-platform>