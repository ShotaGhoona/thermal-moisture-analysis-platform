"""
    Condensation

結露判定・処理モジュール。
壁体表面および内部の結露判定と結露水処理を行う。

移行元:
- legacy-julia/run/main.jl: cal_new_value_ver_network内の結露処理
- legacy-julia/module/transfer_in_media.jl
"""
module Condensation

using ...Model: Cell, Wall, BuildingNetwork

export check_condensation!, is_condensing, CondensationResult

#=============================================================================
  定数
=============================================================================#

"""飽和時の水分化学ポテンシャル閾値 [J/kg]"""
const MIU_SATURATION = -0.1

#=============================================================================
  結露判定結果
=============================================================================#

"""結露判定結果"""
struct CondensationResult
    wall_id::Int
    cell_index::Int
    is_surface::Bool  # 表面結露か内部結露か
    condensate::Float64  # 結露水量 [kg/(m²·s)]
end

#=============================================================================
  結露判定
=============================================================================#

"""
    is_condensing(miu::Float64) -> Bool

水分化学ポテンシャルが飽和状態かを判定。

# Arguments
- `miu`: 水分化学ポテンシャル [J/kg]

# Returns
- true: 結露発生（miu >= MIU_SATURATION）
"""
function is_condensing(miu::Float64)::Bool
    return miu >= MIU_SATURATION
end

#=============================================================================
  ネットワーク全体の結露チェック
=============================================================================#

"""
    check_condensation!(network::BuildingNetwork) -> Vector{CondensationResult}

ネットワーク全体の結露をチェックし、必要に応じて処理する。

# Returns
- 結露発生箇所のリスト

# Note
- 各壁体のセルについて結露判定を実施
- 表面結露は結露水を排出
- 内部結露は警告を出力
"""
function check_condensation!(network::BuildingNetwork)::Vector{CondensationResult}
    results = CondensationResult[]

    for (i, wall) in enumerate(network.walls)
        wall_results = check_wall_condensation!(wall, i)
        append!(results, wall_results)
    end

    return results
end

"""
    check_wall_condensation!(wall::Wall, wall_id::Int) -> Vector{CondensationResult}

単一壁体の結露をチェックし、処理する。

# Arguments
- `wall`: チェック対象の壁体
- `wall_id`: 壁体ID（警告メッセージ用）

# Returns
- 結露発生箇所のリスト
"""
function check_wall_condensation!(wall::Wall, wall_id::Int)::Vector{CondensationResult}
    results = CondensationResult[]
    cells = wall.cells
    n = length(cells)

    for j in 1:n
        cell = cells[j]

        if is_condensing(cell.miu)
            is_surface = (j == 1 || j == n)

            if is_surface
                # 表面結露の処理
                result = handle_surface_condensation!(cell, wall_id, j)
                push!(results, result)
            else
                # 内部結露の処理
                result = handle_internal_condensation!(cell, wall_id, j)
                push!(results, result)
            end

            # 水分化学ポテンシャルを飽和値に設定
            cell.miu = MIU_SATURATION
        end
    end

    return results
end

#=============================================================================
  結露処理
=============================================================================#

"""
    handle_surface_condensation!(cell::Cell, wall_id::Int, cell_index::Int) -> CondensationResult

表面結露の処理。

# Note
- 結露水量を計算して記録
- 水分化学ポテンシャルを飽和値に戻す
- 結露水は境界条件の液水流束として処理（外部で実施）
"""
function handle_surface_condensation!(cell::Cell, wall_id::Int, cell_index::Int)
    # 結露水量を計算（流入 - 流出 の余剰分）
    condensate = cell.Jw_in - cell.Jw_out

    return CondensationResult(
        wall_id = wall_id,
        cell_index = cell_index,
        is_surface = true,
        condensate = condensate
    )
end

"""
    handle_internal_condensation!(cell::Cell, wall_id::Int, cell_index::Int) -> CondensationResult

内部結露の処理。

# Note
- 内部結露は警告を出力
- 厳密には結露水の蓄積・移動を考慮すべきだが、簡易的に飽和状態を維持
"""
function handle_internal_condensation!(cell::Cell, wall_id::Int, cell_index::Int)
    # 内部結露の警告（デバッグ用、本番では抑制可能）
    # @warn "内部結露発生: 壁体[$wall_id] セル[$cell_index]"

    # 結露水量
    condensate = cell.Jw_in - cell.Jw_out

    return CondensationResult(
        wall_id = wall_id,
        cell_index = cell_index,
        is_surface = false,
        condensate = condensate
    )
end

#=============================================================================
  結露水の集計
=============================================================================#

"""
    total_condensate(results::Vector{CondensationResult}) -> Float64

結露水量の合計を計算 [kg/(m²·s)]。
"""
function total_condensate(results::Vector{CondensationResult})::Float64
    return sum(r.condensate for r in results; init=0.0)
end

"""
    surface_condensation_count(results::Vector{CondensationResult}) -> Int

表面結露の発生箇所数をカウント。
"""
function surface_condensation_count(results::Vector{CondensationResult})::Int
    return count(r -> r.is_surface, results)
end

"""
    internal_condensation_count(results::Vector{CondensationResult}) -> Int

内部結露の発生箇所数をカウント。
"""
function internal_condensation_count(results::Vector{CondensationResult})::Int
    return count(r -> !r.is_surface, results)
end

end # module
