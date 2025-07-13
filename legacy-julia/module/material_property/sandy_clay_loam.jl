module sandy_clay_loam

include("../function/vapour.jl")

# 空隙率
const psi = 0.440038

# 材料密度
const row = 269.0 #kg/m3

# 比熱 ⇒　簡易的に平均値を用いる
const C = 4.18605e+3 #暫定的に水の比熱を用いている

# 水の密度
const roww = 1000.0 #kg/m3
#理想気体定数
const R = 8.314 # J/(mol K)
# 水のモル質量
const Mw = 0.018 # kg/mol
# 水蒸気のガス定数
#Rv = R / Mw # J/(kg K)
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
    if miu < 0.0; LM = log10( -miu ); miu_cal = miu
        else;     LM = - 2.0;        miu_cal = 0.0
    end
    if LM > 1.0;            phi = 16.64990 + 3662.970  / ( LM - 225.9990 )
        elseif LM > -1.110; phi = 0.48150  + 0.1718110 / ( LM - 2.54090 )
        else;               phi = 0.4400380 + 0.07211630 * miu_cal
    end
    if phi <= 0.0; phi = 0.0 end
    return phi
end
get_phi( cell ) = get_phi( miu = cell.miu )

# 含水率の水分化学ポテンシャル微分
function get_dphi( ;miu::Float64, phi::Float64 );
    if miu < 0.0; LM = log10( -miu ); miu_cal = miu
        else;     LM  = - 2.0;        miu_cal = 0.0
    end   
    if LM > 1.0;             dphi = - 3662.970 / ( LM - 225.9990 ) / ( LM - 225.9990 ) / miu_cal / log( 10.0 )
        elseif LM > -1.110;  dphi = - 0.1718110 / ( LM - 2.54090 ) / ( LM - 2.54090 ) / miu_cal / log( 10.0 )
        else;                dphi = 0.07211630
    end
    return dphi
end
get_dphi( cell ) = get_dphi( miu = cell.miu, phi = get_phi( cell ) )

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi(; phi::Float64);
    if phi > 0.0 && phi < 0.369960; LM = 3662.970 / ( phi - 16.64990 ) + 225.9990; miu = -10.0 ^ LM
        elseif phi <= 0.43440;     LM = 0.1718110/ ( phi - 0.48150  ) + 2.54090;  miu = -10.0 ^ LM
        else;  miu = ( phi - 0.4400380 ) / 0.07211630
    end
    return phi
end
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.5884120
# 湿気依存
get_lam( ;phi::Float64 ) = - 46.1440 * phi^ 4.0 + 57.86150 * phi ^3.0 - 28.80760 * phi ^2.0 + 7.75485 * phi + 0.5884120
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 水分化学ポテンシャル勾配に対する液相水分伝導率
function get_ldml( ;temp::Float64, phi::Float64 );
    if phi < 0.30;         LDML = 10.0 ^ ( - 2.618670   / ( phi + 0.078660  ) - 0.4281460 )
        elseif phi < 0.34; LDML = 10.0 ^ ( - 0.04473370 / ( phi - 0.3615380 ) - 8.066920  )
        elseif phi > 0.34; LDML = 10.0 ^ ( - 0.06593130 / ( phi - 0.3080650 ) - 3.925480  )
    end
    return LDML * ( 0.02340 * ( temp - 273.160 ) + 0.5320 ) 
end
get_ldml( cell ) = get_ldml( temp = cell.temp, phi = get_phi(cell) )

# 気相水分伝導率
const STA   = 293.160
const PSS   = cal_Pvs( STA )
const DPVSS = cal_DPvs( STA )
const FP    = 0.180
const miup  = get_miu_by_phi( phi = FP )
const EV    = ( -2.618670 / ( FP + 0.078660 ) - 0.4281460 )
const DMVO  = 10.0 ^ EV
# 水分化学ポテンシャル勾配に対する値
function get_ldtg( ;temp::Float64, miu::Float64, phi::Float64 );
    if miu > 0; miuh = 0.0
        else; miuh = miu
    end
    LDMG = ( 0.44010 - phi ) / ( 0.440 - FP ) * DMVO * exp( ( miuh - miup ) / Rv / STA )
    LDTG2 = LDMG  * ( DPVSS / PSS * Rv * STA - miu / STA )
    LDTG  = LDTG2 * cal_DPvs(temp) / DPVSS
    return LDTG
end
get_ldtg( cell ) = get_ldtg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

function get_ldmg( ;temp::Float64, miu::Float64, phi::Float64 );
    if miu > 0; miuh = 0.0
        else; miuh = miu
    end
    LDMG = ( 0.44010 - phi ) / ( 0.440 - FP ) * DMVO * exp( ( miuh - miup ) / Rv / STA )
    LDMG  = LDMG  * cal_Pvs(temp) / PSS
    return LDMG
end
get_ldmg( cell ) = get_ldmg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

end



