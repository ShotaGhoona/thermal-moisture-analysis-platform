using CSV
using DataFrames
#include("vapour.jl")
include("./room.jl")
include("./wall.jl")
include("./opening.jl")
include("./climate.jl")

Base.@kwdef mutable struct BNM
    rooms::Array{Room, 1}       = [] # 室内空間
    walls::Array{Wall, 1}       = [] # 壁体構成
    openings::Array{Opening, 1} = [] # 開口
    climate::Climate            = [] # 外界気象    
    IC_walls::Array{Int}         = [] # インシデンス行列
    IC_openings::Array{Int}      = [] # インシデンス行列
end

function create_BNM_model(;file_name_rooms::String, file_name_walls::String, file_name_openings::String, file_name_climate::String, 
    header_room::Int = 3, header_wall::Int = 3, header_opening::Int = 3, header_climate::Int = 3)
    # ファイルの読み込み
    climate  = input_climate_data(file_name_climate, header_climate)
    rooms    = input_room_data(file_name_rooms, header_room)
    walls    = input_wall_data(file_name_walls, header_wall)
    openings = input_opening_data(file_name_openings, header_opening)
    
    # roomデータの1番目をclimateのair情報とリンクさせる。（換気回路網計算では床面圧力が必要なため、roomを入力値とする必要あり。）
    rooms[1].air = climate.air
    
    # wallデータ内のair情報をroom情報のairとリンクさせる。
    for i = 1 : length(walls)
        try 
            walls[i].BC_IP.air = rooms[walls[i].IP].air
        catch
            println(" 壁番号 = ", i, ", IP = ", walls[i].IP )
            println("は第一種あるいは第二種境界条件です。" )
        end
        try 
            walls[i].BC_IM.air = rooms[walls[i].IM].air
        catch
            println(" 壁番号 = ", i, ", IM = ", walls[i].IM )
            println("は第一種あるいは第二種境界条件です。" )
        end
    end

    # openingデータ内の上流側・下流側の情報をroomあるいはclimateとリンクさせる。
    for i = 1 : length(openings)
        openings[i].room_IP = rooms[openings[i].IP]
        openings[i].room_IM = rooms[openings[i].IM]
    end
    
    # インシデンス行列の作成
    IC_walls = zeros( length(rooms), length(walls) )
    for i = 1 : length(walls)
        # 第一,二種境界条件を除く
        if walls[i].IP ≠ 0 && walls[i].IP ≠ -1
            IC_walls[ walls[i].IP, i] = +1.0
        end
        if walls[i].IM ≠ 0 && walls[i].IM ≠ -1
            IC_walls[ walls[i].IM, i] = -1.0
        end
    end

    IC_openings = zeros( length(rooms), length(openings) )
    for i = 1 : length(openings)
        IC_openings[ openings[i].IP, i] = +1.0
        IC_openings[ openings[i].IM, i] = -1.0
    end

    # Building Network Modelの構築
    network = BNM( rooms = rooms, walls = walls, openings = openings, climate = climate, IC_walls = IC_walls, IC_openings = IC_openings )

    return network
end