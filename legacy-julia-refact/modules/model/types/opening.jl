"""
    OpeningType

開口部の型定義モジュール。
換気経路を表現する構造体を提供。

移行元: legacy-julia/module/opening.jl（struct部分のみ）
"""
module OpeningType

export Opening, OpeningKind
export height

"""
    OpeningKind

開口のタイプを表すenum。

- `gap`: 隙間（常時開放）
- `window`: 開口（開閉可能な窓）
- `constant`: 換気量固定（機械換気等）
- `fan`: 換気ファン
"""
@enum OpeningKind begin
    gap       # 隙間
    window    # 開口
    constant  # 換気量固定
    fan       # 換気ファン
end

"""
    Opening

開口部。換気経路を表現。

# フィールド
- `id`: 開口番号
- `kind`: 開口タイプ（OpeningKind）
- `room_id_plus`: プラス側室ID
- `room_id_minus`: マイナス側室ID
- `width`: 開口幅 [m]
- `height_top`: 上端高さ [m]
- `height_bottom`: 下端高さ [m]
- `area`: 開口面積 [m²]
- `flow_coefficient`: 流量係数 α
- `gap_characteristic`: 隙間特性値 M
- `Q_plus`, `Q_minus`: 固定流量 [m³/s]
- `wind_pressure_plus`, `wind_pressure_minus`: 風圧係数 [-]
- `delta_p`: 圧力差 [Pa]（計算値）
- `mass_flow`: 質量流量 [kg/s]（計算値）
"""
Base.@kwdef mutable struct Opening
    # 識別
    id::Int = 0
    kind::OpeningKind = gap

    # 接続
    room_id_plus::Int = 0
    room_id_minus::Int = 0

    # 形状
    width::Float64 = 0.0          # 開口幅 [m]
    height_top::Float64 = 0.0     # 上端高さ [m]
    height_bottom::Float64 = 0.0  # 下端高さ [m]
    area::Float64 = 0.0           # 開口面積 [m²]

    # 流量特性
    flow_coefficient::Float64 = 0.0   # 流量係数 α
    gap_characteristic::Float64 = 0.0 # 隙間特性値 M

    # 固定流量（constant/fanタイプ用）
    Q_plus::Float64 = 0.0   # プラス方向流量 [m³/s]
    Q_minus::Float64 = 0.0  # マイナス方向流量 [m³/s]

    # 風圧係数
    wind_pressure_plus::Float64 = 0.0
    wind_pressure_minus::Float64 = 0.0

    # 計算値
    delta_p::Float64 = 0.0    # 圧力差 [Pa]
    mass_flow::Float64 = 0.0  # 質量流量 [kg/s]
end

#=============================================================================
  アクセサ関数
=============================================================================#

"""開口高さ [m]"""
height(o::Opening) = o.height_top - o.height_bottom

"""中心高さ [m]"""
center_height(o::Opening) = (o.height_top + o.height_bottom) / 2.0

end # module
