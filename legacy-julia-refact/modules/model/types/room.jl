"""
    RoomType

室の型定義モジュール。
室の空気状態と内部発熱・発湿を管理する構造体を提供。

移行元: legacy-julia/module/room.jl（struct部分のみ）
"""
module RoomType

using ..AirType: Air

export Room
export temp, rh, volume

"""
    Room

室。空気状態と内部発熱・発湿を管理。

# フィールド
- `id`: 室番号
- `name`: 名称
- `air`: 空気状態（Air構造体）
- `floor_height`: 床面高さ [m]
- `Q_internal`: 内部発熱 [W]
- `J_internal`: 内部発湿 [kg/s]
- `hvac_mode`: 空調モード (:off, :cooling, :heating, :auto)
"""
Base.@kwdef mutable struct Room
    # 識別
    id::Int = 0
    name::String = ""

    # 空気状態
    air::Air = Air()

    # 位置
    floor_height::Float64 = 0.0  # 床面高さ [m]

    # 内部負荷
    Q_internal::Float64 = 0.0  # 内部発熱 [W]
    J_internal::Float64 = 0.0  # 内部発湿 [kg/s]

    # 空調
    hvac_mode::Symbol = :off  # :off, :cooling, :heating, :auto
end

#=============================================================================
  委譲アクセサ
=============================================================================#

"""室温 [K]"""
temp(r::Room) = r.air.temp

"""室相対湿度 [-]"""
rh(r::Room) = r.air.rh

"""室容積 [m³]"""
volume(r::Room) = r.air.volume

"""床面圧力 [Pa]"""
p_floor(r::Room) = r.air.p_floor

end # module
