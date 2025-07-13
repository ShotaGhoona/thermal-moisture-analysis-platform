850.0 * 2146

module benchmark_EN15026

# 空隙率
const psi = 0.146

# 材料密度
const row = 2146.0 #kg/m3 

# 比熱
const C = 850.0 #J/kg 鉱物性の建材の標準的な値

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
# Kelvin式
psuc( ;temp::Float64, rh::Float64 ) = - Rv * temp * roww * log(rh)
psuc( cell ) = psuc( temp = cell.temp, rh = convertMiu2RH( temp = cell.temp, miu = cell.miu ))

# 含水率
get_phi( ;psuc::Float64 ) = 146.0 / 1000.0 / ( ( 1.0 + (8.0e-8 * psuc)^1.6 )^0.375 )
get_phi( cell ) = get_phi( psuc = psuc( cell ) )

# 含水率の水分化学ポテンシャル微分
get_dphi( ;psuc::Float64, phi::Float64 ) = 1.0 / ( psuc * ( 0.625 / ( 1.0 - ( 146.0 / 1000.0 / phi )^( - 1.0 / 0.375 ) ) ) * ( 1.0 / ( 0.375 * phi * 1000.0 ) ) )
get_dphi( cell ) = get_dphi( psuc = psuc(cell), phi = get_phi( cell ) )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = - ( ( ( 146.0 / ( 1000.0*phi ) )^( 1.0/0.375 ) - 1.0 )^( 1.0/1.6 ) ) / 8.0e-8 / roww
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )


### 移動特性 ###
# 熱伝導率
const lam = 1.5
# 湿気依存
get_lam( ;phi::Float64 ) = lam + 15.8 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数 EN 15026では毛管圧勾配になっている。
function get_K_pc( ;phi::Float64 );
    phi_con = phi * roww - 73.0
    return exp( -39.2619 + 0.0704*phi_con - 1.7420e-4*phi_con^2.0 - 2.7953e-6*phi_con^3.0 - 1.1566e-7*phi_con^4.0 + 2.5969e-9*phi_con^5.0 )
end
get_ldml( cell ) = get_K_pc( phi = get_phi( cell ) ) * 1000.0

# 透湿率（湿気伝導率） ⇒　EN15026の式が間違っている　⇒　WUFIの式が正しい模様
get_dp( ;temp::Float64, phi::Float64 ) = ( Mw / (R*temp) ) * ( 26.1e-6 / 200.0 ) * ( 1.0 - phi/0.146 ) / ( 0.503 * (1.0 - phi/0.146 )^2.0 + 0.497 )
#get_dp( ;temp::Float64, phi::Float64 ) = ( Mw / (Rv*temp) ) * ( 26.1e-6 / 200.0 ) * ( 1.0 - phi/0.146 ) / ( 0.503 * (1.0 - phi/0.146 )^2.0 + 0.497 )
get_dp( cell ) = get_dp( temp = cell.temp, phi = get_phi( cell ) )

end

mutable struct test_benchmark_EN15026
    temp::Float64
    miu::Float64
end

test_ben_hygro = test_benchmark_EN15026( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

benchmark_EN15026.get_crow( test_ben_hygro )

benchmark_EN15026.get_lam( test_ben_hygro ) 

benchmark_EN15026.get_phi( test_ben_hygro )

benchmark_EN15026.get_miu_by_phi( phi = benchmark_EN15026.get_phi( test_ben_hygro ) )

benchmark_EN15026.get_dphi( test_ben_hygro )

benchmark_EN15026.get_miu_by_phi( test_ben_hygro )

benchmark_EN15026.get_ldml( test_ben_hygro )

benchmark_EN15026.get_dp( test_ben_hygro )

1.968e-7 * ( ( 20.0 * 273.15 )^0.81 ) / 101325.0 / benchmark_EN15026.get_dp( test_ben_hygro )






