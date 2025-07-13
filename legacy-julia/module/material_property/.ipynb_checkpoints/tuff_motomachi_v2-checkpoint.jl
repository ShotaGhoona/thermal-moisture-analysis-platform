module tuff_motomachi_v2

# 空隙率
const psi = 0.3

# 材料密度
const row = 1479.25 #kg/m3 

# 比熱
const C = 750.0 #J/kg 鉱物性の建材の標準的な値

# 水の密度
const roww = 1000.0 #kg/m3
#理想気体定数
const R = 8.314 # J/(mol K)
# 水のモル質量
const Mw = 0.018 # kg/mol
# 水蒸気のガス定数
Rv = R / Mw # J/(kg K)
# 水の熱容量
const croww = 1000.0 * 4.18605e+3

# 熱容量
get_crow( ;phi::Float64 ) = C * row + croww * phi
get_crow( cell ) = get_crow( phi = get_phi( cell ) )

### 水分特性 ###
# van-Genuchten用情報
include("./van_genuchten.jl")

BeSand_vG = van_Genuchten.vG_parameter( 
    3.5/98.0,
    1.31,
    1.0 - ( 1.0 / 1.31 ),
    # 0.5
    6.0
)
# 含水率
get_phi( ;miu::Float64 ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = miu, phimax = psi )
get_phi( cell ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = cell.miu, phimax = psi )

# 含水率の水分化学ポテンシャル微分
get_dphi( ;miu::Float64 ) = van_Genuchten.get_dphi( vG = BeSand_vG, miu = miu, phimax = psi )
get_dphi( cell ) = get_dphi( miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = van_Genuchten.get_miu(vG = BeSand_vG, phi = phi, phimax = psi )
get_miu_by_phi( cell ) = get_miu_by_phi( phi = cell.phi )

### 移動特性 ###
# 熱伝導率
const lam = 0.35 # 適当な値だったはず（2020/11/19コメント）
# 湿気依存
get_lam( ;phi::Float64 ) = lam + 1.7227 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 飽和時の透水係数
const Ksat = 3.0e-7

# 透水係数
get_dw( ;miu::Float64 ) = Ksat * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu )
get_dw( cell ) = get_dw( ;miu = cell.miu )

# 透湿率（湿気伝導率）
function get_dp( ;temp::Float64, phi::Float64 );
    dp = 1.2e-10 #絶乾時の透湿率[kg/m Pa s]
    return dp * ( ( psi + 0.001 - phi ) / psi )
end
get_dp( cell ) = get_dp( temp = cell.temp, phi = get_phi( cell ) )

end

mutable struct test_tuff_motomachi_v2
    temp::Float64
    miu::Float64
end

test_tuffm_hygro_v2 = test_tuff_motomachi_v2( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

tuff_motomachi_v2.get_crow( test_tuffm_hygro_v2 )

tuff_motomachi_v2.get_lam( test_tuffm_hygro_v2 ) 

tuff_motomachi_v2.get_phi( test_tuffm_hygro_v2 )

tuff_motomachi_v2.get_miu_by_phi( phi = tuff_motomachi_v2.get_phi( test_tuffm_hygro_v2 ) )

tuff_motomachi_v2.get_dphi( test_tuffm_hygro_v2 )

tuff_motomachi_v2.get_dw( test_tuffm_hygro_v2 )

tuff_motomachi_v2.get_dp( test_tuffm_hygro_v2 )

1.968e-7 * ( ( 20.0 * 273.15 )^0.81 ) / 101325.0 / tuff_motomachi_v2.get_dp( test_tuffm_hygro_v2 )


