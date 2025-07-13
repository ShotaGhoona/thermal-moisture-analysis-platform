module extruded_polystyrene

# 空隙率
const psi = 0.392

# 材料密度
const row = 25 #kg/m3 25~55程度

# 比熱
const C = 1470.0 #J/kg 鉱物性の建材の標準的な値

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
get_phi( ;rh::Float64 ) = rh * 0.0018
get_phi( cell ) = get_phi( rh = convertMiu2RH( temp = cell.temp, miu = cell.miu ) )

# 含水率の水分化学ポテンシャル微分
# dphi/dmiu = dphi/drh * drh/dmiu
get_dphi( ;temp::Float64, miu::Float64 ) = 0.0018 * ( 1.0 / Rv / temp ) * exp( miu / Rv / temp )
get_dphi( cell ) = get_dphi( temp = cell.temp, miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;temp::Float64, phi::Float64 ) = Rv * temp * log( phi / 0.0018 )
get_miu_by_phi( cell ) = get_miu_by_phi( temp = cell.temp, phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.03

# 湿気依存
get_lam( ;phi::Float64 ) = lam # + 1.6e-4 * phi + 5.8e-5 * phi^2.0
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数
get_dw( ;phi::Float64 ) = 0.0
get_dw( cell ) = 0.0

# 透湿率（湿気伝導率）
get_dp( ;phi::Float64 ) = 1.2e-12 #絶乾時の透湿率[kg/m Pa s]
get_dp( cell ) = 1.2e-12

end