"""
    CellUpdater

壁体セルの状態更新モジュール。
熱・水分収支から温度・水分化学ポテンシャルを更新。

移行元:
- legacy-julia/module/cell.jl: cal_newtemp, cal_newmiu
- legacy-julia/run/main.jl: cal_new_value_ver_network（壁部分）
"""
module CellUpdater

using ...Model: Cell, Wall
using ...Physics: BalanceEquation

export update_cell!, update_wall_cells!
export cell_crow, cell_dphi

#=============================================================================
  材料物性取得（暫定版）
  TODO: Phase 5でMaterialsモジュールに移行
=============================================================================#

# 水の物性定数
const RHO_WATER = 1000.0   # 水の密度 [kg/m³]
const C_WATER = 4186.05    # 水の比熱 [J/(kg·K)]

"""材料の容積比熱を取得 [J/(m³·K)]（暫定版）"""
function get_crow_dry(material::Symbol)::Float64
    # 乾燥時の容積比熱 = 密度 × 比熱
    materials = Dict(
        :concrete => 2.0e6,    # 2000 kg/m³ × 1000 J/(kg·K)
        :mortar => 1.6e6,
        :insulation => 0.03e6, # 30 kg/m³ × 1000 J/(kg·K)
        :gypsum => 1.0e6,
        :wood => 0.5e6,
        :plywood => 0.6e6,
        :unknown => 1.5e6
    )
    return get(materials, material, 1.5e6)
end

"""材料の含水率容量を取得 ∂φ/∂μ [kg/m³ / (J/kg)]（暫定版）"""
function get_dphi(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 暫定値：一般的な多孔質材料
    # 実際には材料の吸着等温線から算出
    return 1.0e-5
end

"""材料の気孔率を取得 [-]（暫定版）"""
function get_porosity(material::Symbol)::Float64
    materials = Dict(
        :concrete => 0.15,
        :mortar => 0.20,
        :insulation => 0.95,
        :gypsum => 0.40,
        :wood => 0.50,
        :plywood => 0.45,
        :unknown => 0.20
    )
    return get(materials, material, 0.20)
end

"""材料の含水率を取得 [kg/m³]（暫定版）"""
function get_phi(material::Symbol, temp::Float64, miu::Float64)::Float64
    # 暫定的に気孔率の10%程度の含水率を仮定
    porosity = get_porosity(material)
    return porosity * RHO_WATER * 0.1
end

#=============================================================================
  セル物性の計算
=============================================================================#

"""
    cell_crow(cell::Cell) -> Float64

セルの実効容積比熱を計算 [J/(m³·K)]。

# Note
crow = ρc_dry + ρ_w * c_w * φ
水分の寄与を考慮した有効熱容量
"""
function cell_crow(cell::Cell)::Float64
    crow_dry = get_crow_dry(cell.material)
    phi = get_phi(cell.material, cell.temp, cell.miu)
    return crow_dry + C_WATER * phi
end

"""
    cell_dphi(cell::Cell) -> Float64

セルの含水率容量 ∂φ/∂μ [kg/m³ / (J/kg)]。

# Note
吸着等温線の傾きに相当
"""
function cell_dphi(cell::Cell)::Float64
    return get_dphi(cell.material, cell.temp, cell.miu)
end

#=============================================================================
  セル状態の更新
=============================================================================#

"""
    update_cell!(cell::Cell, dt::Float64)

単一セルの温度・水分状態を更新する。

# Arguments
- `cell`: 更新対象のセル
- `dt`: タイムステップ [hour]

# Note
- Forward Euler法（陽解法）による時間積分
- 流量中間値（Q_in, Q_out, Jw_in, Jw_out）から収支を計算
- dtはhour単位、内部でsecに変換
"""
function update_cell!(cell::Cell, dt::Float64)
    # hour → sec
    dt_sec = dt * 3600.0

    # 熱収支
    dq = cell.Q_out - cell.Q_in  # 流出 - 流入

    # 水分収支（水蒸気 + 液水）
    djw = cell.Jw_out - cell.Jw_in  # 流出 - 流入

    # 水蒸気蒸発量（暫定：水分流の一定割合）
    W = -djw / cell.dx * 0.1  # 暫定値

    # 有効熱容量
    crow = cell_crow(cell)

    # 温度更新
    new_temp = BalanceEquation.update_temp_cell(
        crow = crow,
        temp = cell.temp,
        dq = dq,
        W = W,
        dx = cell.dx,
        dt = dt_sec
    )

    # 含水率容量
    dphi = cell_dphi(cell)

    # 水分化学ポテンシャル更新
    new_miu = BalanceEquation.update_miu_cell(
        dphi = dphi,
        miu = cell.miu,
        djw = djw,
        dx = cell.dx,
        dt = dt_sec
    )

    # 状態を更新
    cell.temp = new_temp
    cell.miu = new_miu
end

"""
    update_wall_cells!(wall::Wall, dt::Float64)

壁体内の全セルを更新する。

# Arguments
- `wall`: 更新対象の壁体
- `dt`: タイムステップ [hour]

# Note
通気層などの特殊材料は別処理が必要（未実装）
"""
function update_wall_cells!(wall::Wall, dt::Float64)
    for cell in wall.cells
        # 通気層のチェック（暫定：materialが:vented_air_spaceの場合スキップ）
        if cell.material == :vented_air_space
            # 通気層は隣接セルの平均値を設定
            # TODO: 適切な処理を実装
            continue
        end

        update_cell!(cell, dt)
    end
end

#=============================================================================
  通気層の処理（暫定版）
=============================================================================#

"""
    update_vented_air_space!(wall::Wall)

通気層セルの状態を隣接セルから設定する（暫定版）。

# Note
通気層は熱・水分の蓄積がないため、隣接セルの平均値を使用
"""
function update_vented_air_space!(wall::Wall)
    cells = wall.cells
    n = length(cells)

    for j in 1:n
        if cells[j].material == :vented_air_space
            # 隣接セルが存在する場合は平均値
            if j > 1 && j < n
                cells[j].temp = (cells[j-1].temp + cells[j+1].temp) / 2.0
                cells[j].miu = (cells[j-1].miu + cells[j+1].miu) / 2.0
            end
        end
    end
end

end # module
