module mud_wall

include("../function/vapour.jl")

# 空隙率
const psi = 0.082

# 材料密度
const row = 1650.0 #kg/m3 

# 比熱
const C = 900.0 #J/kg 鉱物性の建材の標準的な値

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
convertMiu2RH( temp::Float64, miu::Float64 ) = convertMiu2RH( temp=temp, miu=miu )

# 熱容量
get_crow( ;phi::Float64 ) = C * row + croww * phi
get_crow( cell ) = get_crow( phi = get_phi( cell ) )

### 水分特性 ###

# 含水率
function get_phi( ;temp::Float64, miu::Float64 )
#-------------( RH)---------------
    RH = convertMiu2RH( temp, miu )
#-------------( PSI)---------------    
    if RH<0.4885 
        phi = -0.00596/(RH+0.325) + 0.0184
    else
        phi = -0.00304/(RH-1.07) + 0.00579
    end
#    RHO_2W = 1000.0
#    RHO_MW = 1650.0
#    return phi * RHO_2W / RHO_MW #容積含水率
    return phi * row / roww #2021/01/20高取修正
end
get_phi( cell ) = get_phi( temp = cell.temp, miu = cell.miu )

# 含水率の水分化学ポテンシャル微分
function get_dphi( ;temp::Float64, miu::Float64 )
    DRH_DMU = 1 / Rv/ temp* exp( miu/Rv/temp )
    RH = convertMiu2RH( temp, miu )
    if RH<0.4885
        DPHI_DRH = 0.00596 / ( (RH+0.325)^2.0 )
    else
        DPHI_DRH = 0.00304 / ( (RH-1.07 )^2.0 )
    end
    return DPHI_DRH * DRH_DMU
end
get_dphi( cell ) = get_dphi( temp = cell.temp, miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = 0.0
get_miu_by_phi( cell ) = get_miu_by_phi( phi = get_phi( cell ) )

### 移動特性 ###
# 熱伝導率
const lam = 0.23
# 湿気依存
get_lam( ;phi::Float64 ) = lam
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数
function get_dw( ;phi::Float64 );
    return 0.0
end
get_dw( cell ) = get_dw( phi = get_phi(cell) )

# 気相水分伝導率
const Patm = 101325.0 #[Pa]
const LAMDX = 2.25e-6

function cal_dp( temp::Float64, miu::Float64 )
    Pv = cal_Pvs(temp)^exp( miu/Rv/temp )
    return LAMDX * ( 0.622*Patm ) / ( ( Patm - Pv )^2 )
end

# 水分化学ポテンシャル勾配に対する値
function get_ldtg( ;temp::Float64, miu::Float64 );
    DPV_DT = cal_DPvs(temp) * exp( miu/Rv/temp ) + cal_Pvs(temp) * ( - miu/Rv/(temp)^2 ) * exp( miu/Rv/temp )
    return cal_dp(temp, miu) * DPV_DT
end
get_ldtg( cell ) = get_ldtg( temp = cell.temp, miu = cell.miu )

function get_ldmg( ;temp::Float64, miu::Float64 );
    return cal_dp(temp, miu) * cal_Pvs(temp) / Rv / temp * exp( miu/Rv/temp )
end
get_ldmg( cell ) = get_ldmg( temp = cell.temp, miu = cell.miu )

end

mutable struct test_mud_wall
    temp::Float64
    miu::Float64
end

mud_wall_hygro = test_mud_wall( 293.15, 8.314 / 0.018 * 293.15 * log( 0.7 ) )

mud_wall.get_crow( mud_wall_hygro )

mud_wall.get_lam( mud_wall_hygro ) 

mud_wall.get_phi( mud_wall_hygro )

mud_wall.get_phi( temp = mud_wall_hygro.temp, miu = -0.00000001 )

mud_wall.get_miu_by_phi( phi = mud_wall.get_phi( mud_wall_hygro ) )

mud_wall.get_dphi( mud_wall_hygro )

mud_wall.get_miu_by_phi( mud_wall_hygro )

mud_wall.get_dw( mud_wall_hygro )

mud_wall.get_ldmg( mud_wall_hygro )

mud_wall.get_ldtg( mud_wall_hygro )


