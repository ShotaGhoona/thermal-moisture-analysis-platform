module bentheimer_sandstone

# 空隙率
const psi = 0.23

# 材料密度
const row = 1479.25

# 比熱
const C = 750.0

include("./liquid_water.jl")

# 熱容量
get_crow( ;phi::Float64 ) = C * row + water_property.crow * phi
get_crow( cell ) = get_crow( phi=get_phi( cell ) )

# van-Genuchten用情報
include("./van_genuchten.jl")

BeSand_vG = van_Genuchten.vG_parameter( 
    10.0/98.0,
    2.0,
    1.0 - ( 1.0 / 2.0 ),
    0.5
)

### 水分特性 ###
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
const lam = 1.2
get_lam( cell ) = lam

# 飽和時の透水係数
const Ksat = 2.0e-7

# 絶乾湿の透湿率
const Dp = 2.0E-10

# 透水係数
get_dw( ;miu::Float64 ) = Ksat * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu )
get_dw( cell ) = get_dw( ;miu = cell.miu )

# 透湿率（湿気伝導率）
get_dp( ;phi::Float64 ) = Dp * ( 1.0 - ( phi / psi ) * 0.9 )
get_dp( cell ) = get_dp( phi = get_phi( cell ) )

end

mutable struct test_bentheimer
    temp::Float64
    miu::Float64
    rh::Float64
    pv::Float64
    phi::Float64
end

test_ben_hygro = test_bentheimer( 293.15, -100.0, 0.7, 1000.0, 0.1 )

bentheimer_sandstone.get_crow( test_ben_hygro )

bentheimer_sandstone.get_phi( test_ben_hygro )

bentheimer_sandstone.get_dphi( test_ben_hygro )

bentheimer_sandstone.get_miu_by_phi( test_ben_hygro )

bentheimer_sandstone.get_dw( test_ben_hygro )

bentheimer_sandstone.get_dp( test_ben_hygro )


