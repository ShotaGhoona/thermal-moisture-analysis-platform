"""
    Stepper

時間ステップ制御モジュール。
シミュレーションの1タイムステップ分の計算を統合管理。

移行元:
- legacy-julia/run/main.jl: 時間ループ内の処理
"""
module Stepper

using ...Model: BuildingNetwork, Room, Wall
using ..WallFlux: calculate_wall_flux!
using ..VentilationFlux: calculate_ventilation_flux!
using ..CellUpdater: update_wall_cells!, update_vented_air_space!
using ..AirUpdater: update_room_air!
using ..Condensation: check_condensation!, CondensationResult

export step!, reset_all_flux!

#=============================================================================
  1タイムステップの計算
=============================================================================#

"""
    step!(network::BuildingNetwork, dt::Float64) -> Vector{CondensationResult}

1タイムステップ分の計算を実行する。

# Arguments
- `network`: ビルディングネットワーク
- `dt`: タイムステップ [hour]

# Returns
- 結露発生箇所のリスト

# 計算フロー
1. 流量計算
   - 壁体を通じた熱・水分流量
   - 換気による熱・水分流量
2. 状態更新
   - 壁体セルの温度・水分状態
   - 室空気の温度・湿度
3. 結露判定
   - 表面/内部結露のチェックと処理
"""
function step!(network::BuildingNetwork, dt::Float64)::Vector{CondensationResult}
    # === 1. 流量計算 ===
    calculate_wall_flux!(network)
    calculate_ventilation_flux!(network)

    # === 2. 状態更新 ===
    # 壁体セルの更新
    for wall in network.walls
        update_wall_cells!(wall, dt)
    end

    # 通気層の処理
    for wall in network.walls
        update_vented_air_space!(wall)
    end

    # 室空気の更新（外気を除く）
    for i in 2:length(network.rooms)
        update_room_air!(network.rooms[i], dt)
    end

    # === 3. 結露判定 ===
    results = check_condensation!(network)

    return results
end

"""
    step_with_climate_update!(network::BuildingNetwork, dt::Float64, update_climate!::Function)

気象データ更新を含む1タイムステップ分の計算。

# Arguments
- `network`: ビルディングネットワーク
- `dt`: タイムステップ [hour]
- `update_climate!`: 気象データ更新関数
"""
function step_with_climate_update!(network::BuildingNetwork, dt::Float64, update_climate!::Function)
    # 気象データの更新
    update_climate!(network.climate, dt)

    # 通常のステップ計算
    return step!(network, dt)
end

#=============================================================================
  フラックスリセット
=============================================================================#

"""
    reset_all_flux!(network::BuildingNetwork)

ネットワーク内の全要素のフラックス中間値をリセット。

# Note
ステップ計算の前に呼び出すことで、前ステップの値をクリア
"""
function reset_all_flux!(network::BuildingNetwork)
    # 壁体セルのフラックスリセット
    for wall in network.walls
        for cell in wall.cells
            cell.Q_in = 0.0
            cell.Q_out = 0.0
            cell.Jw_in = 0.0
            cell.Jw_out = 0.0
        end
    end

    # 室空気の収支値リセット
    for room in network.rooms
        room.air.H_wall = 0.0
        room.air.H_vent = 0.0
        room.air.H_internal = 0.0
        room.air.J_wall = 0.0
        room.air.J_vent = 0.0
        room.air.J_internal = 0.0
    end
end

#=============================================================================
  複数ステップ実行
=============================================================================#

"""
    run_steps!(network::BuildingNetwork, dt::Float64, n_steps::Int;
               on_step::Function = (i, results) -> nothing)

複数ステップを連続実行する。

# Arguments
- `network`: ビルディングネットワーク
- `dt`: タイムステップ [hour]
- `n_steps`: ステップ数
- `on_step`: 各ステップ後に呼び出されるコールバック関数

# Example
```julia
run_steps!(network, 0.1, 8760) do step, results
    if step % 240 == 0
        println("Step \$step completed")
    end
end
```
"""
function run_steps!(network::BuildingNetwork, dt::Float64, n_steps::Int;
                    on_step::Function = (i, results) -> nothing)
    for i in 1:n_steps
        results = step!(network, dt)
        on_step(i, results)
    end
end

#=============================================================================
  CFL条件チェック（オプション）
=============================================================================#

"""
    check_cfl_condition(network::BuildingNetwork, dt::Float64) -> Bool

CFL条件（安定性条件）をチェックする。

# Returns
- true: 安定条件を満たす
- false: 不安定の可能性あり

# Note
陽解法のため、タイムステップが大きすぎると不安定になる。
一般的に dt < dx² / (2 * α) が必要（αは熱拡散率）
"""
function check_cfl_condition(network::BuildingNetwork, dt::Float64)::Bool
    dt_sec = dt * 3600.0
    min_dx = Inf

    # 最小セル厚さを探索
    for wall in network.walls
        for cell in wall.cells
            if cell.dx > 0.0 && cell.dx < min_dx
                min_dx = cell.dx
            end
        end
    end

    if isinf(min_dx)
        return true
    end

    # 熱拡散率の代表値（コンクリート相当）
    alpha = 1.6 / (2.0e6)  # λ / (ρc)

    # CFL条件
    dt_max = min_dx^2 / (2.0 * alpha)

    return dt_sec <= dt_max
end

"""
    estimate_stable_dt(network::BuildingNetwork) -> Float64

安定なタイムステップを推定する [hour]。
"""
function estimate_stable_dt(network::BuildingNetwork)::Float64
    min_dx = Inf

    for wall in network.walls
        for cell in wall.cells
            if cell.dx > 0.0 && cell.dx < min_dx
                min_dx = cell.dx
            end
        end
    end

    if isinf(min_dx)
        return 1.0  # デフォルト値
    end

    # 熱拡散率の代表値
    alpha = 1.6 / (2.0e6)

    # 安全係数0.5を適用
    dt_sec = 0.5 * min_dx^2 / (2.0 * alpha)

    # 秒 → 時間
    return dt_sec / 3600.0
end

end # module
