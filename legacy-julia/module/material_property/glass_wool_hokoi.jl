module glass_wool_hokoi

# 空隙率
const psi = 0.99 # おおよその値

# 材料密度
const row = 16.0 #kg/m3

# 比熱
const C = 698.0 #J/kg

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
# 含水率
# 関数系　phi = a * ( b / ( rh + c ) + d ) [kg/kg]
# 相対湿度の閾値 rh_TH
a = 0.0006
b = 0.0015
c = 0.0179
N = 900

function get_phi( ;rh::Float64 )
    phi = a * rh + b + c * rh^N
    return phi
end

get_phi( cell ) = get_phi( rh = convertMiu2RH( temp = cell.temp, miu = cell.miu ) )

# 含水率の水分化学ポテンシャル微分
# dphi/dmiu = dphi/drh * drh/dmiu
drh_dmiu( temp::Float64, miu::Float64 ) = ( 1.0 / Rv / temp ) * exp( miu / Rv / temp )
function get_dphi( ;temp::Float64, miu::Float64, rh::Float64 )
    dphi_drh = a + c * N * rh^(N-1)
    return dphi_drh * drh_dmiu( temp, miu )
end
get_dphi( cell ) = get_dphi( temp = cell.temp, miu = cell.miu, rh = convertMiu2RH( temp = cell.temp, miu = cell.miu ) )

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi( ;temp::Float64, phi::Float64 )
    print("実装されていません")
    return miu
end
get_miu_by_phi( cell ) = get_miu_by_phi( temp = cell.temp, phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.045

# 湿気依存
get_lam( ;phi::Float64 ) = lam
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数
get_dw( ;phi::Float64 ) = 0.0
get_dw( cell ) = 0.0

# 透湿率（湿気伝導率）
# kg / kg DA
dah_dpv(pv::Float64) = 0.622 / ( 101325.0 - pv ) + 0.622 * pv / ( ( 101325.0 - pv )^2 )
dah_dpv() = dah_dpv(1700.0)
get_dp() = 2.52e-5 * dah_dpv() #絶乾時の透湿率[kg/m Pa s]
get_dp( cell ) = get_dp()

end