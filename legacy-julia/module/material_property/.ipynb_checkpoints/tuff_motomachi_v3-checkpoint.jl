module tuff_motomachi_v3

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

#重力加速度
const g = 9.806650

### 水分特性 ###
# van-Genuchten用情報
include("./van_genuchten.jl")
include("./Boltzmann_transformation.jl")

BeSand_vG = van_Genuchten.vG_parameter( 
    0.03, #α
    1.6, #n
    1.0 - ( 1.0 / 1.6 ), #m
    #0.5
    #30.0
    35.0
    #35.0
)

# Boltzmann変換用変数
Bvalue_a = 0.43053007
Bvalue_b = 19389.63902
Bvalue_c =-8.119220102

# 含水率
get_phi( ;miu::Float64 ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = miu, phimax = psi )
get_phi( cell ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = cell.miu, phimax = psi )

# 含水率の水分化学ポテンシャル微分
get_dphi( ;miu::Float64 ) = van_Genuchten.get_dphi( vG = BeSand_vG, miu = miu, phimax = psi )
get_dphi( cell ) = get_dphi( miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = van_Genuchten.get_miu(vG = BeSand_vG, phimax = psi, phi = phi  )
get_miu_by_phi( cell ) = get_miu_by_phi( phi = cell.phi )

### 移動特性 ###
# 熱伝導率
const lam = 0.35 # 適当な値だったはず（2020/11/19コメント）
# 湿気依存
get_lam( ;phi::Float64 ) = lam + 1.7227 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 飽和時の透水係数
#const Ksat = 2.7e-7
const Ksat = 4.8e-7
#const Ksat = 4.8e-7 * 1.2


# 透水係数
#get_dw( ;miu::Float64 ) = Ksat * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu ) + 
#( cal_Dw_by_Boltzmann( a = Bvalue_a, b = Bvalue_b, c = Bvalue_c, phi_init = 0.0, phi = get_phi( miu = miu )) / 4.1e-9) ^ 0.5 * 4.1e-9 * 0.045
# 0.5, 0.1の一致が良い
#get_dw( ;miu::Float64 ) = ( cal_Dw_by_Boltzmann( a = Bvalue_a, b = Bvalue_b, c = Bvalue_c, phi_init = 0.0, phi = get_phi( miu = miu )) / 4.1e-9) ^ 0.5 * 4.1e-9 * 0.045

#1.5e-10
#get_dw( cell ) = get_dw( ;miu = cell.miu )


## 透水係数（変換後）
#get_dw( ;miu::Float64 ) = Ksat / g * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu ) / get_dphi( miu = miu ) * 1000.0  
#+ 1.00e-9
#( cal_Dw_by_Boltzmann( a = Bvalue_a, b = Bvalue_b, c = Bvalue_c, phi_init = 0.0, phi = get_phi( miu = miu )) / 4.1e-9) ^ 0.5 * 4.1e-9 * 0.045
# 0.5, 0.1の一致が良い


##########################################
## 透水係数（変換後）
get_dw( ;miu::Float64 ) = Ksat * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu ) 
#+ 1.00e-9

get_dw( cell ) = get_dw( ;miu = cell.miu )


#get_dw( ;miu::Float64, rowsw::Float64 ) = Ksat  / g / rowsw * van_Genuchten.get_kl( vG = BeSand_vG, miu = miu ) 
#+ 1.00e-9

#get_dw( cell ) = get_dw( ;miu = cell.miu, rowsw = rowsw(cell) )

###########################################


#水分化学ポテンシャル勾配に対する液相水分伝導率
#get_ldml( ;miu::Float64 ) = get_dw( miu = miu ) * roww / g 

#get_ldml( cell ) = get_ldml( ;miu = cell.miu )

#ボルツマン変換
#get_dw( ;phi::Float64 ) = cal_Dw_by_Boltzmann( a = Bvalue_a, b = Bvalue_b, c = Bvalue_c, phi_init = 0.0, phi = phi)
#get_dw( cell ) = get_dw( ;phi = get_phi( cell ) )


# 透湿率（湿気伝導率）
function get_dp( ;temp::Float64, phi::Float64 );
    dp = 1.2e-10 #絶乾時の透湿率[kg/m Pa s]
    return dp * ( ( psi + 0.001 - phi ) / psi )
end
get_dp( cell ) = get_dp( temp = cell.temp, phi = get_phi( cell ) )

end

mutable struct test_tuff_motomachi_v3
    temp::Float64
    miu::Float64
end



test_tuffm_hygro_v3 = test_tuff_motomachi_v3( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7) )

tuff_motomachi_v3.get_crow( test_tuffm_hygro_v3 )

tuff_motomachi_v3.get_lam( test_tuffm_hygro_v3 ) 

tuff_motomachi_v3.get_phi( test_tuffm_hygro_v3 )

tuff_motomachi_v3.get_miu_by_phi( phi = tuff_motomachi_v3.get_phi( test_tuffm_hygro_v3 ) )

tuff_motomachi_v3.get_dphi( test_tuffm_hygro_v3 )

tuff_motomachi_v3.get_dw( test_tuffm_hygro_v3 )

tuff_motomachi_v3.get_dp( test_tuffm_hygro_v3 )

1.968e-7 * ( ( 20.0 * 273.15 )^0.81 ) / 101325.0 / tuff_motomachi_v3.get_dp( test_tuffm_hygro_v3 )




