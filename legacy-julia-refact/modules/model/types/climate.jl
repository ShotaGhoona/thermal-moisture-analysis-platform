"""
    ClimateType

気象条件の型定義モジュール。
外気状態と日射等を管理する構造体を提供。

移行元: legacy-julia/module/climate.jl（struct部分のみ）
"""
module ClimateType

using Dates
using ..AirType: Air

export Climate, Location
export temp, rh

"""
    Location

地点情報。

# フィールド
- `name`: 地点名
- `latitude`: 緯度 [°]
- `longitude`: 経度 [°]
- `timezone_longitude`: 標準時経度 [°]
"""
struct Location
    name::String
    latitude::Float64   # 緯度 [°]
    longitude::Float64  # 経度 [°]
    timezone_longitude::Float64  # 標準時経度 [°]
end

# デフォルトコンストラクタ
Location() = Location("", 0.0, 0.0, 0.0)

"""
    Climate

気象条件。外気状態と日射等を管理。

# フィールド
- `datetime`: 日時
- `location`: 地点情報
- `air`: 外気状態（Air構造体）
- `precipitation`: 降水量 [mm/h]
- `wind_speed`: 風速 [m/s]
- `wind_direction`: 風向 [°]（北=0）
- `cloud_cover`: 雲量 [0-10]
- `atmospheric_transmittance`: 大気透過率 [-]
- `direct_normal_irradiance`: 法線面直達日射量 [W/m²]
- `diffuse_horizontal_irradiance`: 水平面天空日射量 [W/m²]
- `solar_altitude`: 太陽高度 [°]
- `solar_azimuth`: 太陽方位角 [°]
- `ground_reflectance`: 地表面反射率 [-]
"""
Base.@kwdef mutable struct Climate
    # 時刻
    datetime::DateTime = DateTime(2000, 1, 1)

    # 地点
    location::Location = Location()

    # 外気状態
    air::Air = Air(name="outdoor")

    # 気象要素
    precipitation::Float64 = 0.0  # 降水量 [mm/h]
    wind_speed::Float64 = 0.0     # 風速 [m/s]
    wind_direction::Float64 = 0.0 # 風向 [°]（北=0）
    cloud_cover::Int = 0          # 雲量 [0-10]

    # 日射
    atmospheric_transmittance::Float64 = 0.0  # 大気透過率 [-]
    direct_normal_irradiance::Float64 = 0.0   # 法線面直達日射量 [W/m²]
    diffuse_horizontal_irradiance::Float64 = 0.0 # 水平面天空日射量 [W/m²]
    solar_altitude::Float64 = 0.0  # 太陽高度 [°]
    solar_azimuth::Float64 = 0.0   # 太陽方位角 [°]

    # 地表面
    ground_reflectance::Float64 = 0.0  # 地表面反射率 [-]
end

#=============================================================================
  委譲アクセサ
=============================================================================#

"""外気温 [K]"""
temp(c::Climate) = c.air.temp

"""外気相対湿度 [-]"""
rh(c::Climate) = c.air.rh

"""外気圧 [Pa]"""
p_atm(c::Climate) = c.air.p_atm

end # module
