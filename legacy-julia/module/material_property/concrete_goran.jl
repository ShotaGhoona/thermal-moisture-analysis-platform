module concrete_goran

# 空隙率
const psi = 0.392 # おおよその値

# 材料密度
const row = 2200 #kg/m3

# 比熱
const C = 940.0 #J/kg

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
function get_phi( ;miu::Float64 )
    if miu > - 1.0e-3
        phi = 0.24120 * miu + 0.159720
    elseif log10( -miu ) < 3.7680
        phi = 0.16390 + 0.035180 / ( log10( -miu ) - 4.95930 )
    elseif log10( -miu ) < 5.2980
        phi = -3.0654540 + 2.2674670 * log10( -miu ) - 
        5.208352e-1 * log10( -miu ) ^ 2.0 + 3.833344e-2 * log10( -miu ) ^ 3.0
    elseif log10( -miu ) < 10.16940
        phi = -0.00980 + 0.063950 / ( log10( -miu ) - 3.64410 )
    else
        phi = 0.0
    end
    return phi
end

get_phi( cell ) = get_phi( miu = cell.miu )

# dphi/dmiu = dphi/drh * drh/dmiu
function get_dphi( ;temp::Float64, miu::Float64 )
    if   miu > -1.0e-3
        dphi = 0.24120
    elseif log10( -miu ) < 3.7680
        dphi = -0.035180 / ( log10( -miu ) - 4.95930 ) / 
            ( log10( -miu ) - 4.95930 ) / miu / log( 10.0 )
    elseif log10( -miu ) < 5.2980
        dphi = ( 2.2674670 - 1.04167040 * log10( -miu ) + 
            1.1500032e-1 * log10( -miu ) ^ 2.0) / miu / log( 10.0 )
    elseif log10( -miu ) < 10.16940
        dphi = -0.063950 / ( log10( -miu ) -3.64410 ) / 
            ( log10( -miu ) - 3.64410 ) / miu / log( 10.0 )
    else
        dphi = 0.0
    end
    return dphi
end
get_dphi( cell ) = get_dphi( temp = cell.temp, miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi( ;temp::Float64, phi::Float64 )
    PHI1 = 0.159470
    PHI0 = 0.13430
      
    if phi > PHI1
        miu = - 1.0e-3
    elseif PHI1 >= phi && phi >= PHI0
        miu = ( -1.0 ) * 10.0 ^ ( 4.95930 + 0.035180 / ( phi - 0.16390 ) )
    else
        miu = ( -1.0 ) * 10.0 ^ ( 3.7680 )
    end
    return miu
end
get_miu_by_phi( cell ) = get_miu_by_phi( temp = cell.temp, phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 1.3

# 湿気依存
get_lam( ;phi::Float64 ) = lam + 3.5 * phi
get_lam( cell ) = get_lam( phi = get_phi( cell ) )


# 水分移動
# 液水
# 水分化学ポテンシャル勾配に対する液相水分伝導率
function get_ldml( ;phi::Float64 )
    return exp( - 75.102120 + 350.0070 * phi )
end
get_ldml( cell ) = get_ldml( phi = get_phi( cell ) )

# 水蒸気
function cal_Pvs( temp )
    return exp( -5800.22060 / temp + 1.3914993 - 4.8640239E-2 * temp + 4.1764768E-5 * (temp ^ 2.0) - 1.4452093E-8 * (temp ^ 3.0) + 6.5459673 * log(temp) )
end
function cal_DPvs( temp )
    DP = 10.795740 * 273.160 / temp / temp - 5.0280 / temp / log(10.0) + 
    ( 1.50475E-4 ) * 8.2969 / 273.16 * log(10.0)* 
    ( 10.0 ^ ( -8.29690 * ( temp / 273.160 - 1.0 ) ) ) + 
    ( 0.42873E-3 ) * 4.769550 * 273.160 / temp / temp * log(10.0) * 
    ( 10.0 ^ ( 4.769550 * ( 1.0 - 273.160 / temp ) ) )
    return cal_Pvs(temp) * DP * log(10.0)
end
# 水分化学ポテンシャル勾配に対する気相水分伝導率
function get_ldmg( ;temp::Float64, miu::Float64, phi::Float64 ) 
    LDTG = get_ldtg( temp = temp, phi = phi  )
    dpvs = cal_DPvs( temp )
    pvs  = cal_Pvs( temp )
    return LDTG / ( Rv * temp * dpvs / pvs - miu / temp )
end
get_ldmg( cell ) = get_ldmg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

function get_ldtg( ;temp::Float64, phi::Float64 )
    DPVS  = cal_DPvs( temp )
    DPVSS = cal_DPvs( 293.16 )
    if   phi < 0.0000010
        LDTG  = 0.0
    elseif phi < 0.032964
        FTLDT = -9.87290 - 0.0101010 / phi
    elseif phi < 0.1278
        FTLDT = -10.489310 + 10.38831 * phi - 56.457320 * phi ^ 2.0 + 806.5875 * phi ^ 3.0
    else
        FTLDT = - 8063.50 * ( phi - 0.1300 ) ^ 2.0 - 8.3610
    end

    if phi < 0.00001
        LDTG=0.0
    else
        FTLDT  = FTLDT
        LDTG = 10.0 ^ FTLDT * DPVS / DPVSS
    end
    return LDTG
end
get_ldtg( cell ) = get_ldtg( ;temp = cell.temp, phi = get_phi(cell) )

end