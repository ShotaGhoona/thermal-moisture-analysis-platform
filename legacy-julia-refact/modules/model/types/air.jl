"""
    AirType

室空気の型定義モジュール。
室内空気の温湿度・圧力等の状態を表す構造体を提供。

移行元: legacy-julia/module/air.jl（struct部分のみ）
"""
module AirType

export Air
export reset_balance!, add_H_wall!, add_J_wall!

"""
    Air

室空気。温湿度・圧力等の状態を保持。

# フィールド
- `name`: 名称
- `volume`: 体積 [m³]
- `temp`: 温度 [K]
- `rh`: 相対湿度 [-]
- `p_atm`: 大気圧 [Pa]
- `p_floor`: 床面圧力 [Pa]
- `H_wall`, `H_vent`, `H_internal`: 熱流量の蓄積値 [W]
- `J_wall`, `J_vent`, `J_internal`: 水分流量の蓄積値 [kg/s]
"""
Base.@kwdef mutable struct Air
    # 識別
    name::String = ""

    # 容積
    volume::Float64 = 0.0   # 体積 [m³]

    # 状態量（独立変数）
    temp::Float64 = 293.15  # 温度 [K]
    rh::Float64   = 0.5     # 相対湿度 [-]
    p_atm::Float64 = 101325.0 # 大気圧 [Pa]

    # 圧力（換気計算用）
    p_floor::Float64 = 0.0  # 床面圧力 [Pa]

    # 熱収支の蓄積値
    H_wall::Float64 = 0.0     # 壁体からの熱流量 [W]
    H_vent::Float64 = 0.0     # 換気による熱流量 [W]
    H_internal::Float64 = 0.0 # 内部発熱 [W]

    # 水分収支の蓄積値
    J_wall::Float64 = 0.0     # 壁体からの水分流量 [kg/s]
    J_vent::Float64 = 0.0     # 換気による水分流量 [kg/s]
    J_internal::Float64 = 0.0 # 内部発湿 [kg/s]
end

#=============================================================================
  収支値操作関数
=============================================================================#

"""収支値をリセット"""
function reset_balance!(air::Air)
    air.H_wall = 0.0
    air.H_vent = 0.0
    air.H_internal = 0.0
    air.J_wall = 0.0
    air.J_vent = 0.0
    air.J_internal = 0.0
end

"""壁体からの熱流量を加算"""
function add_H_wall!(air::Air, H::Float64)
    air.H_wall += H
end

"""換気による熱流量を加算"""
function add_H_vent!(air::Air, H::Float64)
    air.H_vent += H
end

"""壁体からの水分流量を加算"""
function add_J_wall!(air::Air, J::Float64)
    air.J_wall += J
end

"""換気による水分流量を加算"""
function add_J_vent!(air::Air, J::Float64)
    air.J_vent += J
end

"""総熱流量 [W]"""
total_H(air::Air) = air.H_wall + air.H_vent + air.H_internal

"""総水分流量 [kg/s]"""
total_J(air::Air) = air.J_wall + air.J_vent + air.J_internal

end # module
