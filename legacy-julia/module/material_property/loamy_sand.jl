module loamy_sand

include("../function/vapour.jl")

# 空隙率
const psi = 0.369960

# 小椋先生博士論文より砂質土壌の値を採用
# 石英砂：比重2660[kg/m3] 比熱753.49[J/kgK] 比容積0.6175[m3/m3] 小計12737645[J/m3K]
# 粘土　：比重1550[kg/m3] 比熱879.07[J/kgK] 比容積0.0325[m3/m3] 小計44283[J/m3K]
# ⇒　容積比熱 1281926 と算定
const crow = 1281926

# 比熱 ⇒　簡易的に平均値を用いる # 髙取修正部分
const C = (753.49 + 879.07) / 2.0 #J/kg

# 材料密度 # 髙取修正部分
const row = crow / C #kg/m3

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
get_crow( ;phi::Float64 ) = crow + croww * phi
get_crow( cell ) = get_crow( phi = get_phi( cell ) )

### 水分特性 ###

# 含水率
function get_phi( ;miu::Float64 )
    if miu < 0.0; LM = log10( -miu ); miu_cal = miu
        else;     LM = - 2.0;        miu_cal = 0.0
    end
    if LM > 5.9;          phi = 2.85651e-4
        elseif LM > 0.5;  phi = -0.2763160 + 2.670080  / ( LM + 3.763160 )
        elseif LM > 0.375;phi =  0.3954570 + 0.01406470/ ( LM - 0.809410 )
        else;             phi = 0.3954570  + 0.0136530 * miu_cal
    end
    return phi
end
get_phi( cell ) = get_phi( miu = cell.miu )

# 含水率の水分化学ポテンシャル微分
function get_dphi( ;miu::Float64, phi::Float64 );
    if miu < 0.0; LM = log10( -miu ); miu_cal = miu
        else;     LM  = - 2.0;        miu_cal = 0.0
    end   
    if LM > 5.9;          dphi = 1.5e-8
        elseif LM > 0.5;  dphi = -2.670080  / ( LM+3.763160) / ( LM+3.763160) / miu_cal / log(10.0)
        elseif LM > 0.375;dphi = -0.01406470/ ( LM-0.809410) / ( LM-0.809410) / miu_cal / log(10.0)
        else;             dphi = 0.013653
    end
    return dphi
end
get_dphi( cell ) = get_dphi( miu = cell.miu, phi = get_phi( cell ) )

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi(; phi::Float64);
    if phi > 0.0 && phi <= 0.369960; LM = 2.670080 / ( phi+0.2763160 ) - 3.763160; miu = -10.0 ^ LM
        elseif phi <= 0.43440;     LM = 0.01406470 / ( phi-0.3954570 ) + 0.809410; miu = -10.0 ^ LM
        else;  miu = ( phi - 0.3954570 ) / 0.0136530
    end    
    return phi
end
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.218581
# 湿気依存
get_lam( ;phi::Float64 ) = - 60.1639 * phi^ 4.0 + 60.3575 * phi ^3.0 - 26.6469 * phi ^2.0 + 8.57816 * phi + 0.218581
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 水分化学ポテンシャル勾配に対する液相水分伝導率
function get_ldml( ;temp::Float64, phi::Float64 );
    if phi < 0.20;        LDML = 10.0 ^ ( - 0.5662860/ ( phi + 0.0250 )    - 5.483220 )
        elseif phi < 0.3; LDML = 10.0 ^ ( - 1.70580  / ( phi - 0.5909110 ) - 12.35370 )
        elseif phi > 0.3; LDML = 10.0 ^ ( -2.279950  / ( phi - 0.007844260)+ 1.31390 )
    end
    F1 = 0.02340 * ( temp - 273.160 ) + 0.5320
    return LDML * F1
end
get_ldml( cell ) = get_ldml( temp = cell.temp, phi = get_phi(cell) )

# 気相水分伝導率
const STA   = 293.160
const PSS   = cal_Pvs( STA )
const DPVSS = cal_DPvs( STA )
const FP    = 0.0750
const miup  = get_miu_by_phi( phi = FP )
const EV    = ( -2.618670 / ( FP + 0.078660 ) - 0.4281460 )
const DMVO  = 10.0 ^ EV
# 水分化学ポテンシャル勾配に対する値

function cal_ldg( temp::Float64, miu::Float64, phi::Float64 )
    EV  = ( -0.5662860 / ( FP+0.0250 ) - 5.483220 )
    DMVO= 10.0^EV
    if miu > 0; miuh = 0.0
        else; miuh = miu
    end
    LAMDMG = ( 0.3950 - phi ) / (0.3950 - FP ) * DMVO * exp((miuh-miup) / Rv / STA )
    return LAMDMG
end

function get_ldtg( ;temp::Float64, miu::Float64, phi::Float64 );
    return cal_ldg(temp, miu, phi)  * ( DPVSS / PSS * Rv * STA - miu / STA ) * cal_DPvs(temp) / DPVSS
end
get_ldtg( cell ) = get_ldtg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

function get_ldmg( ;temp::Float64, miu::Float64, phi::Float64 );
    return cal_ldg(temp, miu, phi) * cal_Pvs(temp) / PSS
end
get_ldmg( cell ) = get_ldmg( temp = cell.temp, miu = cell.miu, phi = get_phi( cell ) )

end

mutable struct test_loamy_sand
    temp::Float64
    miu::Float64
end

test_loamy_sand_hygro = test_loamy_sand( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

loamy_sand.get_crow( test_loamy_sand_hygro )

loamy_sand.get_lam( test_loamy_sand_hygro ) 

loamy_sand.get_phi( test_loamy_sand_hygro )

loamy_sand.get_miu_by_phi( phi = loamy_sand.get_phi( test_loamy_sand_hygro ) )

loamy_sand.get_dphi( test_loamy_sand_hygro )

loamy_sand.get_miu_by_phi( test_loamy_sand_hygro )

loamy_sand.get_ldml( test_loamy_sand_hygro )

loamy_sand.get_ldtg( test_loamy_sand_hygro )

loamy_sand.get_ldmg( test_loamy_sand_hygro )


