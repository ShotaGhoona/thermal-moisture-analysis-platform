"""
    CellType

壁体セルの型定義モジュール。
壁体を構成する最小単位であるセルの構造体を提供。

移行元: legacy-julia/module/cell.jl（struct部分のみ）
"""
module CellType

export Cell
export volume, area_yz

"""
    Cell

壁体セル。壁体を構成する最小単位。

# フィールド
- `index`: 位置番号 (i, j, k)
- `dx`: x方向厚さ [m]
- `dy`: y方向幅 [m]
- `dz`: z方向高さ [m]
- `dx2`: 質点からセル境界までの距離 [m]
- `temp`: 温度 [K]
- `miu`: 水分化学ポテンシャル [J/kg]
- `material`: 材料名（Symbol）
- `Q_in`, `Q_out`: 流入/流出熱量 [W/m²]
- `Jw_in`, `Jw_out`: 流入/流出水分量 [kg/(m²·s)]
"""
Base.@kwdef mutable struct Cell
    # 位置
    index::NTuple{3, Int} = (1, 1, 1)

    # 寸法
    dx::Float64 = 0.0     # x方向厚さ [m]
    dy::Float64 = 1.0     # y方向幅 [m]
    dz::Float64 = 1.0     # z方向高さ [m]
    dx2::Float64 = 0.0    # 質点からセル境界までの距離 [m]

    # 状態量（独立変数）
    temp::Float64 = 293.15  # 温度 [K]
    miu::Float64  = 0.0     # 水分化学ポテンシャル [J/kg]

    # 材料
    material::Symbol = :unknown

    # 計算用中間値
    Q_in::Float64  = 0.0   # 流入熱量 [W/m²]
    Q_out::Float64 = 0.0   # 流出熱量 [W/m²]
    Jw_in::Float64 = 0.0   # 流入水分量 [kg/(m²·s)]
    Jw_out::Float64 = 0.0  # 流出水分量 [kg/(m²·s)]
end

#=============================================================================
  アクセサ関数
=============================================================================#

"""セルの体積 [m³]"""
volume(c::Cell) = c.dx * c.dy * c.dz

"""yz面の面積 [m²]（熱流方向に垂直な面）"""
area_yz(c::Cell) = c.dy * c.dz

"""xz面の面積 [m²]"""
area_xz(c::Cell) = c.dx * c.dz

"""xy面の面積 [m²]"""
area_xy(c::Cell) = c.dx * c.dy

"""流量中間値をリセット"""
function reset_flux!(c::Cell)
    c.Q_in = 0.0
    c.Q_out = 0.0
    c.Jw_in = 0.0
    c.Jw_out = 0.0
end

end # module
