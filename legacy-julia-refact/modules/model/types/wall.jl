"""
    WallType

壁体の型定義モジュール。
複数のセルで構成される壁体の構造体を提供。

移行元: legacy-julia/module/wall.jl（struct部分のみ）
"""
module WallType

using ..CellType: Cell

export Wall
export thickness, n_cells

"""
    Wall

壁体。複数のセルで構成される。

# フィールド
- `id`: 壁番号
- `name`: 名称
- `room_id_plus`: プラス側室ID（熱流の正方向）
- `room_id_minus`: マイナス側室ID
- `orientation`: 壁の向き [°]
- `area`: 面積 [m²]
- `cells`: セル配列
"""
Base.@kwdef mutable struct Wall
    # 識別
    id::Int = 0
    name::String = ""

    # 接続情報
    room_id_plus::Int = 0   # プラス側室ID（旧IP）
    room_id_minus::Int = 0  # マイナス側室ID（旧IM）

    # 形状
    orientation::Float64 = 0.0  # 壁の向き [°]
    area::Float64 = 0.0         # 面積 [m²]

    # セル配列
    cells::Vector{Cell} = Cell[]
end

#=============================================================================
  アクセサ関数
=============================================================================#

"""壁体の総厚さ [m]"""
thickness(w::Wall) = sum(c.dx for c in w.cells; init=0.0)

"""セル数"""
n_cells(w::Wall) = length(w.cells)

"""最初のセル（プラス側境界）"""
first_cell(w::Wall) = w.cells[1]

"""最後のセル（マイナス側境界）"""
last_cell(w::Wall) = w.cells[end]

end # module
