module tuff_motomachi

# 空隙率
const psi = 0.392

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

# miu ⇒　rh の変換係数
function convertMiu2RH( ;temp::Float64, miu::Float64 );
    return exp( miu / Rv / temp )
end

# 熱容量
get_crow( ;phi::Float64 ) = C * row + croww * phi
get_crow( cell ) = get_crow( phi = get_phi( cell ) )

### 水分特性 ###
const A_gomp = 0.001
const B_gomp = 0.4
# ゴンペルツ(Gompertz)曲線
cal_phi_by_Gompertz_curve( A, B, miu ) = psi - psi * ( A ^ ( B ^ ( log10( -miu ) ) ) )
cal_dphi_by_Gompertz_curve( A, B, miu, phi ) = phi * ( ( log( B ) ) / ( -miu * ( log( 10.0 ) ) ) * ( B ^ ( log10( -miu ) ) ) * ( log(A) ) )
cal_miu_by_phi_Gompertz_curve( A, B, phi ) = -10.0 ^ ( ( log( log( ( psi - phi ) / psi ) / log(A) ) ) / log(B) )

# 含水率
get_phi( ;miu::Float64 ) = cal_phi_by_Gompertz_curve( A_gomp, B_gomp, miu )
get_phi( cell ) = get_phi( miu = cell.miu )

# 含水率の水分化学ポテンシャル微分
get_dphi( ;miu::Float64, phi::Float64 ) = cal_dphi_by_Gompertz_curve( A_gomp, B_gomp, miu, phi )
get_dphi( cell ) = get_dphi( miu = cell.miu, phi = get_phi( cell ) )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = - cal_miu_by_phi_Gompertz_curve( A_gomp, B_gomp, phi )
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.35 # 適当な値だったはず（2020/11/19コメント）
# 湿気依存
get_lam( ;phi::Float64 ) = lam + 1.7227 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数
function get_dw( ;phi::Float64 );
    ksat = 1.1e-7 #[m/s]
    n = 15.0
    return ksat * ( phi / psi ) ^ n
end
get_dw( cell ) = get_dw( phi = get_phi(cell) )

# 透湿率（湿気伝導率）
function get_dp( ;temp::Float64, phi::Float64 );
    dp = 1.2e-10 #絶乾時の透湿率[kg/m Pa s]
    return dp * ( ( psi + 0.001 - phi ) / psi )
end
get_dp( cell ) = get_dp( temp = cell.temp, phi = get_phi( cell ) )

end

mutable struct test_tuff_motomachi
    temp::Float64
    miu::Float64
end

test_tuffm_hygro = test_tuff_motomachi( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

tuff_motomachi.get_crow( test_tuffm_hygro )

tuff_motomachi.get_lam( test_tuffm_hygro ) 

tuff_motomachi.get_phi( test_tuffm_hygro )

tuff_motomachi.get_miu_by_phi( phi = tuff_motomachi.get_phi( test_tuffm_hygro ) )

tuff_motomachi.get_dphi( test_tuffm_hygro )

tuff_motomachi.get_miu_by_phi( test_tuffm_hygro )

tuff_motomachi.get_dw( test_tuffm_hygro )

tuff_motomachi.get_dp( test_tuffm_hygro )

1.968e-7 * ( ( 20.0 * 273.15 )^0.81 ) / 101325.0 / tuff_motomachi.get_dp( test_tuffm_hygro )


