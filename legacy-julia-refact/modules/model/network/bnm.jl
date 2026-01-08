"""
    NetworkModel

ビルディングネットワークモデルの型定義モジュール。
室・壁・開口・気象のネットワーク構造を提供。

移行元: legacy-julia/module/building_network_model.jl
"""
module NetworkModel

using ..RoomType: Room
using ..WallType: Wall
using ..OpeningType: Opening
using ..ClimateType: Climate

export BuildingNetwork
export n_rooms, n_walls, n_openings

"""
    BuildingNetwork

ビルディングネットワークモデル。
室・壁・開口・気象のネットワーク構造を保持。

# フィールド
- `rooms`: 室の配列
- `walls`: 壁体の配列
- `openings`: 開口部の配列
- `climate`: 気象条件
- `wall_incidence`: 壁インシデンス行列（室×壁）
- `opening_incidence`: 開口インシデンス行列（室×開口）
"""
struct BuildingNetwork
    # 構成要素
    rooms::Vector{Room}
    walls::Vector{Wall}
    openings::Vector{Opening}
    climate::Climate

    # インシデンス行列
    wall_incidence::Matrix{Int}     # 室×壁
    opening_incidence::Matrix{Int}  # 室×開口
end

"""
    BuildingNetwork(rooms, walls, openings, climate)

BuildingNetworkを構築。インシデンス行列を自動生成。
"""
function BuildingNetwork(rooms::Vector{Room}, walls::Vector{Wall},
                         openings::Vector{Opening}, climate::Climate)
    nr = length(rooms)
    nw = length(walls)
    no = length(openings)

    # 壁のインシデンス行列を構築
    # +1: プラス側に接続, -1: マイナス側に接続
    wall_inc = zeros(Int, nr, nw)
    for (j, w) in enumerate(walls)
        if 1 <= w.room_id_plus <= nr
            wall_inc[w.room_id_plus, j] = 1
        end
        if 1 <= w.room_id_minus <= nr
            wall_inc[w.room_id_minus, j] = -1
        end
    end

    # 開口のインシデンス行列を構築
    opening_inc = zeros(Int, nr, no)
    for (j, o) in enumerate(openings)
        if 1 <= o.room_id_plus <= nr
            opening_inc[o.room_id_plus, j] = 1
        end
        if 1 <= o.room_id_minus <= nr
            opening_inc[o.room_id_minus, j] = -1
        end
    end

    return BuildingNetwork(rooms, walls, openings, climate,
                          wall_inc, opening_inc)
end

#=============================================================================
  アクセサ関数
=============================================================================#

"""室数"""
n_rooms(bn::BuildingNetwork) = length(bn.rooms)

"""壁数"""
n_walls(bn::BuildingNetwork) = length(bn.walls)

"""開口数"""
n_openings(bn::BuildingNetwork) = length(bn.openings)

"""室を取得"""
get_room(bn::BuildingNetwork, id::Int) = bn.rooms[id]

"""壁を取得"""
get_wall(bn::BuildingNetwork, id::Int) = bn.walls[id]

"""開口を取得"""
get_opening(bn::BuildingNetwork, id::Int) = bn.openings[id]

"""室iに接続している壁のインデックスを取得"""
function walls_connected_to(bn::BuildingNetwork, room_id::Int)
    indices = Int[]
    for j in 1:n_walls(bn)
        if bn.wall_incidence[room_id, j] != 0
            push!(indices, j)
        end
    end
    return indices
end

"""室iに接続している開口のインデックスを取得"""
function openings_connected_to(bn::BuildingNetwork, room_id::Int)
    indices = Int[]
    for j in 1:n_openings(bn)
        if bn.opening_incidence[room_id, j] != 0
            push!(indices, j)
        end
    end
    return indices
end

end # module
