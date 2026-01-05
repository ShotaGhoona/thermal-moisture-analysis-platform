"""
    PhysicsConstants

物理定数モジュール。
熱・水分移動計算で使用する基本定数を定義。
"""
module PhysicsConstants

# 基本定数
const GRAVITY = 9.806650          # 重力加速度 [m/s²]
const R_UNIVERSAL = 8.314         # 理想気体定数 [J/(mol·K)]

# 水の物性
const M_WATER = 0.018             # 水のモル質量 [kg/mol]
const R_VAPOR = R_UNIVERSAL / M_WATER  # 水蒸気のガス定数 [J/(kg·K)] ≈ 461.9
const RHO_WATER = 1000.0          # 水の密度 [kg/m³]
const C_WATER = 4.18605e3         # 水の比熱 [J/(kg·K)]

# 空気の物性
const C_DRY_AIR = 1005.0          # 乾き空気の定圧比熱 [J/(kg·K)]
const C_VAPOR = 1846.0            # 水蒸気の定圧比熱 [J/(kg·K)]
const P_ATM = 101325.0            # 標準大気圧 [Pa]

# 無次元数
const LEWIS_NUMBER = 1.0          # ルイス数 [-]

end # module
