"""
    WallFlux

壁体を通じた熱・水分流量計算モジュール。
Cell間およびCell-境界条件間の熱・水蒸気・液水流束を計算。

移行元:
- legacy-julia/module/transfer_in_media.jl
- legacy-julia/run/main.jl: cal_network_flux_of_wall
"""
module WallFlux

using ...Model: Cell, Wall, Room, BCRobin, BuildingNetwork
using ...Model: reset_balance!, add_H_wall!, add_J_wall!, area_yz, reset_flux!
using ...Model: alpha_total
using ...Physics: HeatTransfer, VaporTransfer, LiquidTransfer
using ...Physics: Psychrometrics

export flux_heat, flux_vapor, flux_liquid
export calculate_wall_flux!

#=============================================================================
  材料物性取得（暫定版）
  TODO: Phase 5でMaterialsモジュールに移行
=============================================================================#

"""材料の熱伝導率を取得 [W/(m·K)]（暫定版）"""
function get_lambda(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 暫定的に固定値を返す
    # 実際にはMaterialsモジュールから取得
    materials = Dict(
        :concrete => 1.6,
        :mortar => 1.5,
        :insulation => 0.04,
        :gypsum => 0.22,
        :wood => 0.12,
        :plywood => 0.16,
        :unknown => 1.0
    )
    return get(materials, material, 1.0)
end

"""水蒸気伝導率λ'μg [kg/(m·s·J/kg)]（暫定版）"""
function get_ldmg(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 暫定値：一般的なコンクリート相当
    return 1.0e-12
end

"""温度勾配に対する水蒸気伝導率λ'Tg [kg/(m·s·K)]（暫定版）"""
function get_ldtg(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 温度勾配駆動は無視（ポテンシャル駆動のみ）
    return 0.0
end

"""液水伝導率λ'μl [kg/(m·s·J/kg)]（暫定版）"""
function get_ldml(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 暫定値：一般的なコンクリート相当
    return 1.0e-14
end

"""湿気伝達率α'dm [kg/(m²·s·Pa)]（暫定版）"""
function get_aldm(alpha_conv::Float64, temp::Float64)::Float64
    # ルイス関係式から算出
    R_vapor = 461.5
    return alpha_conv / (1005.0 * R_vapor * temp)
end

"""水分化学ポテンシャル勾配に対する湿気伝達率（暫定版）"""
function get_aldmg(alpha_moisture::Float64, temp::Float64, miu::Float64)::Float64
    # 線形化係数
    pvs = Psychrometrics.cal_Pvs(temp)
    dpvdmiu = Psychrometrics.cal_DPvDMiu(temp, miu)
    return alpha_moisture * dpvdmiu
end

#=============================================================================
  Cell-Cell間の流束計算
=============================================================================#

"""
    flux_heat(cell_mns::Cell, cell_pls::Cell) -> Float64

Cell間の熱流束を計算 [W/m²]。

# Arguments
- `cell_mns`: マイナス側セル
- `cell_pls`: プラス側セル

# Returns
- 熱流束 [W/m²]（正: mns → pls 方向）
"""
function flux_heat(cell_mns::Cell, cell_pls::Cell)
    lam_mns = get_lambda(cell_mns.material, cell_mns.temp, cell_mns.miu)
    lam_pls = get_lambda(cell_pls.material, cell_pls.temp, cell_pls.miu)

    dx2_mns = cell_mns.dx - cell_mns.dx2  # マイナス側セルのプラス境界までの距離
    dx2_pls = cell_pls.dx2                 # プラス側セルのマイナス境界までの距離

    return HeatTransfer.heat_conduction_diff(
        lam_mns = lam_mns, lam_pls = lam_pls,
        temp_mns = cell_mns.temp, temp_pls = cell_pls.temp,
        dx2_mns = dx2_mns, dx2_pls = dx2_pls
    )
end

"""
    flux_vapor(cell_mns::Cell, cell_pls::Cell) -> Float64

Cell間の水蒸気流束を計算 [kg/(m²·s)]。

# Arguments
- `cell_mns`: マイナス側セル
- `cell_pls`: プラス側セル

# Returns
- 水蒸気流束 [kg/(m²·s)]（正: mns → pls 方向）
"""
function flux_vapor(cell_mns::Cell, cell_pls::Cell)
    ldmg_mns = get_ldmg(cell_mns.material, cell_mns.temp, cell_mns.miu)
    ldmg_pls = get_ldmg(cell_pls.material, cell_pls.temp, cell_pls.miu)
    ldtg_mns = get_ldtg(cell_mns.material, cell_mns.temp, cell_mns.miu)
    ldtg_pls = get_ldtg(cell_pls.material, cell_pls.temp, cell_pls.miu)

    dx2_mns = cell_mns.dx - cell_mns.dx2
    dx2_pls = cell_pls.dx2

    return VaporTransfer.vapor_permeance_potential_diff(
        ldmg_mns = ldmg_mns, ldmg_pls = ldmg_pls,
        ldtg_mns = ldtg_mns, ldtg_pls = ldtg_pls,
        miu_mns = cell_mns.miu, miu_pls = cell_pls.miu,
        temp_mns = cell_mns.temp, temp_pls = cell_pls.temp,
        dx2_mns = dx2_mns, dx2_pls = dx2_pls
    )
end

"""
    flux_liquid(cell_mns::Cell, cell_pls::Cell; nx::Float64=0.0) -> Float64

Cell間の液水流束を計算 [kg/(m²·s)]。

# Arguments
- `cell_mns`: マイナス側セル
- `cell_pls`: プラス側セル
- `nx`: 鉛直方向余弦（上向きが正）

# Returns
- 液水流束 [kg/(m²·s)]（正: mns → pls 方向）
"""
function flux_liquid(cell_mns::Cell, cell_pls::Cell; nx::Float64=0.0)
    ldml_mns = get_ldml(cell_mns.material, cell_mns.temp, cell_mns.miu)
    ldml_pls = get_ldml(cell_pls.material, cell_pls.temp, cell_pls.miu)

    dx2_mns = cell_mns.dx - cell_mns.dx2
    dx2_pls = cell_pls.dx2

    return LiquidTransfer.liquid_conduction_potential_diff(
        ldml_mns = ldml_mns, ldml_pls = ldml_pls,
        miu_mns = cell_mns.miu, miu_pls = cell_pls.miu,
        dx2_mns = dx2_mns, dx2_pls = dx2_pls,
        nx = nx
    )
end

#=============================================================================
  BCRobin-Cell間の流束計算
=============================================================================#

"""
    flux_heat(bc::BCRobin, cell::Cell) -> Float64

境界条件（空気側）からセルへの熱流束 [W/m²]。

# Note
正の値はbc→cell方向（空気から壁への熱流入）
"""
function flux_heat(bc::BCRobin, cell::Cell)
    # 対流熱伝達
    alpha = alpha_total(bc)
    q_conv = HeatTransfer.heat_transfer_diff(alpha, bc.air_temp, cell.temp)

    # 日射等の追加熱流束
    q_added = bc.q_added

    return q_conv + q_added
end

"""
    flux_vapor(bc::BCRobin, cell::Cell) -> Float64

境界条件（空気側）からセルへの水蒸気流束 [kg/(m²·s)]。
"""
function flux_vapor(bc::BCRobin, cell::Cell)
    # 空気側の水蒸気分圧
    pv_air = Psychrometrics.cal_Pv(bc.air_temp, bc.air_rh)

    # セル側の水蒸気分圧
    pv_cell = Psychrometrics.cal_Pv_from_miu(cell.temp, cell.miu)

    # 湿気伝達
    jv_conv = VaporTransfer.vapor_transfer_pressure_diff(
        bc.alpha_moisture, pv_air, pv_cell
    )

    # 追加水蒸気流束
    jv_added = bc.jv_added

    return jv_conv + jv_added
end

"""
    flux_liquid(bc::BCRobin, cell::Cell) -> Float64

境界条件からセルへの液水流束 [kg/(m²·s)]。
"""
function flux_liquid(bc::BCRobin, cell::Cell)
    # 追加液水流束（降雨等）のみ
    return bc.jl_added
end

#=============================================================================
  Cell-BCRobin間の流束計算（逆方向）
=============================================================================#

"""
    flux_heat(cell::Cell, bc::BCRobin) -> Float64

セルから境界条件（空気側）への熱流束 [W/m²]。
"""
function flux_heat(cell::Cell, bc::BCRobin)
    return -flux_heat(bc, cell)
end

"""
    flux_vapor(cell::Cell, bc::BCRobin) -> Float64

セルから境界条件への水蒸気流束 [kg/(m²·s)]。
"""
function flux_vapor(cell::Cell, bc::BCRobin)
    return -flux_vapor(bc, cell)
end

"""
    flux_liquid(cell::Cell, bc::BCRobin) -> Float64

セルから境界条件への液水流束 [kg/(m²·s)]。
"""
function flux_liquid(cell::Cell, bc::BCRobin)
    return -flux_liquid(bc, cell)
end

#=============================================================================
  ネットワーク全体の壁体流量計算
=============================================================================#

"""
    calculate_wall_flux!(network::BuildingNetwork)

ネットワーク全体の壁体を通じた熱・水分流量を計算。
各セルおよび室空気の収支値を更新する。

# Note
- 室の収支値（H_wall, J_wall）を初期化してから計算
- 各壁のセルについて隣接セル間の流量を計算
- 境界セルについては境界条件からの流量を計算
"""
function calculate_wall_flux!(network::BuildingNetwork)
    # 室の壁体からの収支値を初期化
    for room in network.rooms
        room.air.H_wall = 0.0
        room.air.J_wall = 0.0
    end

    # 各セルの流量中間値をリセット
    for wall in network.walls
        for cell in wall.cells
            reset_flux!(cell)
        end
    end

    # 壁ごとに流量計算
    for wall in network.walls
        calculate_single_wall_flux!(wall, network)
    end
end

"""
    calculate_single_wall_flux!(wall::Wall, network::BuildingNetwork)

単一壁体の流量を計算。

# Note
壁の構成: [BC_plus] → [Cell_1] → [Cell_2] → ... → [Cell_n] → [BC_minus]
- プラス側（room_id_plus）から熱・水分が流入する方向を正とする
- 壁の向きから鉛直方向余弦を算出（液水流量計算用）
"""
function calculate_single_wall_flux!(wall::Wall, network::BuildingNetwork)
    cells = wall.cells
    n = length(cells)

    if n == 0
        return
    end

    # 壁の傾斜から鉛直方向余弦を算出
    # orientation: 壁の向き [°]、90°=垂直壁、0°=水平面（上向き）
    nx = sin(wall.orientation * π / 180.0)

    # プラス側室の取得（外気の場合はclimate.airを使用）
    room_plus = get_room_or_climate(network, wall.room_id_plus)
    room_minus = get_room_or_climate(network, wall.room_id_minus)

    # プラス側境界条件（BC → Cell[1]）
    bc_plus = create_bc_from_room(room_plus)
    q_in = flux_heat(bc_plus, cells[1])
    jv_in = flux_vapor(bc_plus, cells[1])
    jl_in = flux_liquid(bc_plus, cells[1])

    # 面積
    A = wall.area > 0 ? wall.area : area_yz(cells[1])

    # Cell[1]への流入
    cells[1].Q_in += q_in
    cells[1].Jw_in += jv_in + jl_in

    # プラス側室への熱・水分流出
    add_H_wall!(room_plus.air, -q_in * A)
    add_J_wall!(room_plus.air, -jv_in * A)

    # セル間の流量計算
    for j in 1:(n-1)
        q = flux_heat(cells[j], cells[j+1])
        jv = flux_vapor(cells[j], cells[j+1])
        jl = flux_liquid(cells[j], cells[j+1]; nx = nx)

        # 流出側（Cell[j]）
        cells[j].Q_out += q
        cells[j].Jw_out += jv + jl

        # 流入側（Cell[j+1]）
        cells[j+1].Q_in += q
        cells[j+1].Jw_in += jv + jl
    end

    # マイナス側境界条件（Cell[n] → BC）
    bc_minus = create_bc_from_room(room_minus)
    q_out = flux_heat(cells[n], bc_minus)
    jv_out = flux_vapor(cells[n], bc_minus)
    jl_out = flux_liquid(cells[n], bc_minus)

    # Cell[n]からの流出
    cells[n].Q_out += q_out
    cells[n].Jw_out += jv_out + jl_out

    # マイナス側室への熱・水分流入
    add_H_wall!(room_minus.air, q_out * A)
    add_J_wall!(room_minus.air, jv_out * A)
end

#=============================================================================
  ヘルパー関数
=============================================================================#

"""室またはclimateを取得"""
function get_room_or_climate(network::BuildingNetwork, room_id::Int)
    if room_id == 0 || room_id > length(network.rooms)
        # 外気として扱う（IDが0または範囲外の場合）
        # 暫定的にrooms[1]を外気とみなす
        return network.rooms[1]
    else
        return network.rooms[room_id]
    end
end

"""室からBCRobinを作成（暫定版）"""
function create_bc_from_room(room::Room)
    return BCRobin(
        air_temp = room.air.temp,
        air_rh = room.air.rh,
        alpha_conv = 9.0,       # 室内側標準値
        alpha_rad = 4.4,        # 室内側標準値
        alpha_moisture = 3.2e-8 # 標準値
    )
end

end # module
