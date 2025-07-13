module ALC

# 空隙率
const psi = 0.7861

# 材料密度
const row = 493.7 #kg/m3

# 比熱
const C = 1089.4 #J/kg

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
function get_phi( ;rh::Float64 )
    if rh >= 0.0 && rh <= 0.9855
        phi = ( - 4.77353e-3 ) / ( rh - 1.05623e0 ) - 4.51942e-3
    elseif rh > 0.9855 && rh <= 1.0
        phi = ( - 2.21026e-4 ) / ( rh - 1.00068e0 ) + 4.84126e-2
    end    
    return phi
end

get_phi( cell ) = get_phi( rh = convertMiu2RH( temp = cell.temp, miu = cell.miu ) )

# dphi/dmiu = dphi/drh * drh/dmiu
function get_dphi( ;temp::Float64, miu::Float64 )
    rh = convertMiu2RH( temp = temp, miu = miu )
    if rh >= 0.0 && rh <= 0.9855
        DWCI = ( 4.77353e-3 ) / ( rh - 1.05623e0 ) ^ 2.0
    elseif rh > 0.9855 && rh <= 1.0
        DWCI = ( 2.21026e-4 ) / ( rh - 1.00068e0 ) ^ 2.0
    end
    dphi = DWCI * exp( miu / Rv / temp ) / Rv / temp
    return dphi
end
get_dphi( cell ) = get_dphi( temp = cell.temp, miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi( ;temp::Float64, phi::Float64 )
    if phi >= 0.0 && phi <= 0.062496303711919124
        rh = ( - 4.77353e-3 ) / ( phi + 4.51942e-3 ) + 1.05623e0 
    elseif phi > 0.062496303711919124 && phi <= psi
        rh = ( - 2.21026e-4 ) / ( phi - 4.84126e-2 ) + 1.00068e0
    end    
    miu = Rv * temp * log(rh)
    return miu
end
get_miu_by_phi( cell ) = get_miu_by_phi( temp = cell.temp, phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.1258

# 湿気依存
get_lam( ;phi::Float64 ) = lam + 0.8085 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 水分移動
# 透湿率
get_dp( ;phi::Float64 ) = 1.82e-11 * ( psi - phi ) / psi
get_dp( cell ) = get_dp( phi = get_phi( cell ) )

# 水分化学ポテンシャル勾配に対する液相水分伝導率
function cal_Pvs( temp )
    return exp( -5800.22060 / temp + 1.3914993 - 4.8640239E-2 * temp + 4.1764768E-5 * (temp ^ 2.0) - 1.4452093E-8 * (temp ^ 3.0) + 6.5459673 * log(temp) )
end
cal_dpdmiu( temp::Float64, miu::Float64 ) = cal_Pvs( temp ) * exp( miu / Rv / temp ) / Rv / temp

function get_ldml( ;temp::Float64, miu::Float64 )
    rh  = convertMiu2RH( temp = temp, miu = miu )
    phi = get_phi( rh = rh )
    if phi <= 0.21
        ZLDM = 30.67390805e0 * phi ^ 2.0 -12.88304138e0 * phi  - 5.028260409e0
    elseif phi > 0.21 && phi <= 0.29
        ZLDM = - 9351.44099e0 * phi ^ 3.0 + 6803.17332e0 * phi ^2 - 1620.137151e0 * phi  + 120.4315736e0
    elseif phi > 0.29 && phi < 0.32
        ZLDM = 561.0864594e0 * phi ^ 2.0 - 359.095334e0 * phi + 51.61665726e0
    else
        ZLDM = 10.e0 * ( phi - 0.32e0 ) ^ 2 - 5.838596176e0
    end

    if rh >= 0.0 && rh <= 0.9855
        DWCI = ( 4.77353e-3 ) / ( rh - 1.05623e0 ) ^ 2.0
    elseif rh > 0.9855 && rh <= 1.0
        DWCI = ( 2.21026e-4 ) / ( rh - 1.00068e0 ) ^ 2.0
    end

    ldm  = rh / Rv / temp * DWCI * 10.0 ^ ZLDM
    ldmg = get_dp( phi = phi ) * cal_dpdmiu( temp, miu )
    ldml = if ldm > ldmg; ldm - ldmg; else; 0.0 end

    return ldml
end
get_ldml( cell ) = get_ldml( temp = cell.temp, miu = cell.miu )

end