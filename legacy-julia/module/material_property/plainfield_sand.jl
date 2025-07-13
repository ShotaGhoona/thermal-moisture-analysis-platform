module plainfield_sand

include("../function/vapour.jl")

# 空隙率
const psi = 0.37519

# 材料密度
const row = 307.0 #kg/m3

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
    if miu < 0.0 ; LM = log10( -miu )
        else; LM = -4.0; miu = 0.0
    end
    if LM > 5.990; phi = 0.0
        elseif LM > 0.50; phi = -0.018140 + 0.107130 / ( log10(-miu)-0.08470 )
        elseif LM > 0.0;  phi =  0.397790 + 0.040180 / ( log10(-miu)-0.754330)
        else;             phi =  0.30667e-1 * miu + 0.375190
    end
    return phi
end
get_phi( cell ) = get_phi( miu = cell.miu )

# 含水率の水分化学ポテンシャル微分
function get_dphi( ;miu::Float64, phi::Float64 );
    if miu < 0.0 ; LM = log10( -miu )
        else; LM = -4.0; miu = 0.0
    end
    if LM > 5.99; dphi = 0.0
        elseif LM > 0.5; dphi = -0.10713 / (( log10(-miu) - 0.0847   )^2.0 ) / miu / log(10.0)
        elseif LM > 0.0; dphi = -0.04018 / (( log10(-miu) - 0.754330 )^2.0 ) / miu / log(10.0)
        else; dphi = 0.30667e-1
    end
    return dphi
end
get_dphi( cell ) = get_dphi( miu = cell.miu, phi = get_phi( cell ) )
   
# dphi_version2
function get_dphi_v2( ;miu::Float64, phi::Float64 );
    if miu < 0.0 ; LM = log10( -miu )
        else; LM = -4.0; miu = 0.0
    end
    if LM > 5.99; dphi = 0.0
        elseif LM > 0.5; dphi = 0.10713 / (( log10(-miu) - 0.0847   )^2.0 ) / (miu^2.0) / (log(10.0)^2.0) * ( log(10.0)+2.0/( log10(-miu)-0.08470))
        elseif LM > 0.0; dphi = -0.04018 / (( log10(-miu) - 0.754330 )^2.0 ) / (miu^2.0) / (log(10.0)^2.0) * ( log(10.0)+2.0/( log10(-miu)-0.0754330))
        else; dphi = 0.0
    end
    return dphi
end

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi(; phi::Float64);
    # phi > 0.0 && phi < 0.369960; LM = 3662.970 / ( phi - 16.64990 ) + 225.9990; miu = -10.0 ^ LM
    #   elseif phi <= 0.43440;     LM = 0.1718110/ ( phi - 0.48150  ) + 2.54090;  miu = -10.0 ^ LM
    #   else;  miu = ( phi - 0.4400380 ) / 0.07211630
    # end
    miu = NaN
    return miu
end
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
# 湿気依存 LAMTGRとは？
function get_lam( ;phi::Float64 );
    if phi <=  0.0079; SLAMB =( 0.1e+1 )+( 0.22963e+3 ) * phi + ( -0.287037e+4 )*phi^2
        else; SLAMB =( 0.407536e+1 ) + ( 0.192233e+2 ) * phi + ( -0.404658e+2 )*phi^2 +(+0.452669e+2)*phi^3
    end
    SLAMB = SLAMB * 1.16279 * 100.0 * 3600.0 / 1000.0 / 1000.0
    #&&&&&&&&&&&&LAMTGRは暫定&&&&&&&&&&&&&&&
    LAMTGR = 0.0
    LAM   = SLAMB - ( 597.50 - 0.5590 * ( 293.160 - 273.160)) * 4.186050 * 1000.0 * LAMTGR
    return LAM
end
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
    if phi <= 0.020; DTVO = 0.0288360 * ( 1.0 - exp(-250.0*phi) )
        else; EV = -0.152711e+1 - 0.735882e0*phi - 0.293796e+1*phi^2.0; DTVO = 10.0^EV
    end
    DTG = DTVO * cal_DPvs(temp) / DPVSS
    LAMDTG = 1000.0 * DTG / 24.0 / 3600.0 / 10000.0
    return LAMDTG
end
get_ldtg( cell ) = get_ldtg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

function get_ldmg( ;temp::Float64, miu::Float64, phi::Float64 );    
    if phi <= 0.00470; DMVO = ( 0.137373e+4 ) * phi
        elseif phi <= 0.0350; EV = 0.110362e+1 - 0.495709e+2*phi -0.296899e+4 *phi^2.0 + 0.47685e+5 *phi^3.0; DMVO=10.0^EV
        else; EV = -0.669523 + -0.444095e+2 * phi; DMVO = 10.0^EV
    end
    DFG = DMVO * cal_Pvs(temp) / PSS
    LAMDMG = 1000.0 * DFG * get_dphi( miu = miu, phi = phi ) / 24.0 / 3600.0 / 10000.0
    return LAMDMG
end
get_ldmg( cell ) = get_ldmg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

end

mutable struct test_plainfield_sand
    temp::Float64
    miu::Float64
end

test_plainfield_sand_hygro = test_plainfield_sand( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

plainfield_sand.get_crow( test_plainfield_sand_hygro )

plainfield_sand.get_lam( test_plainfield_sand_hygro ) 

plainfield_sand.get_phi( miu = -0.00000001 )

plainfield_sand.get_phi( test_plainfield_sand_hygro )

plainfield_sand.get_miu_by_phi( phi = 0.01 )

plainfield_sand.get_miu_by_phi( phi = plainfield_sand.get_phi( test_plainfield_sand_hygro ) )

plainfield_sand.get_miu_by_phi( test_plainfield_sand_hygro )

plainfield_sand.get_ldml( test_plainfield_sand_hygro )

plainfield_sand.get_ldtg( test_plainfield_sand_hygro )

plainfield_sand.get_ldmg( test_plainfield_sand_hygro )




