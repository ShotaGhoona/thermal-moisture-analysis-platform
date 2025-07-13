include("cell.jl")
include("air.jl")
include("boundary_condition.jl")
#include("wall.jl")

# 抵抗値の平均化
function sum_resistance( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    #if val_mns <= 0 or val_pls <= 0:
    #    lam = 0.0 
    #else:
    return (len_mns + len_pls) / ( len_mns / val_mns + len_pls / val_pls )
end

# 加重平均による平均化
function cal_mean_average( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    return ( val_mns * len_mns + val_pls * len_pls ) / ( len_mns + len_pls )
end

# （境界面）貫流値として足し合わせる場合
function cal_transmittance( ;alpha::Float64, lam::Float64, dx2::Float64 )
    return ( 1.0 ) / ( 1.0 / alpha + dx / ( 2.0 * lam ) )
end

# $$$$$$ 熱 $$$$$$
# 熱伝導：基礎式
cal_heat_conduction( ;lam::Float64, dtemp::Float64, dx2::Float64 ) = - lam * dtemp / dx2

# 差分方程式（質点の位置に注意）
function cal_heat_conduction_diff( ;lam_mns::Float64, lam_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64, dx2_pls::Float64 )
    lam = sum_resistance( val_mns = lam_mns, val_pls = lam_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_heat_conduction( lam = lam, dtemp = temp_pls - temp_mns, dx2 = dx2_mns + dx2_pls )
end

# 加重平均による計算方法
function cal_heat_conduction_diff_meanAve( ;lam_mns::Float64, lam_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64, dx2_pls::Float64 )
    lam = cal_mean_average( val_mns = lam_mns, val_pls = lam_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_heat_conduction( lam = lam, dtemp = temp_pls - temp_mns, dx2 = dx2_mns + dx2_pls )
end

function cal_q( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_q(;cell_mns, cell_pls ) = cal_q( cell_mns, cell_pls )

# x軸方向
function cal_qx( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_qx(;cell_mns, cell_pls ) = cal_qx( cell_mns, cell_pls )
# y軸方向
function cal_qy( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dy(cell_mns) - dy2(cell_mns), dx2_pls = dy2(cell_pls) )
end
cal_qy(;cell_mns, cell_pls ) = cal_qy( cell_mns, cell_pls )
# x軸方向
function cal_qz( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dz(cell_mns) - dz2(cell_mns), dx2_pls = dz2(cell_pls) )
end
cal_qy(;cell_mns, cell_pls ) = cal_qy( cell_mns, cell_pls )

function cal_q_meanAve( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff_meanAve( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_q_meanAve(; cell_mns, cell_pls ) = cal_q_meanAve(cell_mns, cell_pls)

######################
# 熱伝達：基礎式
cal_heat_transfer( ;alpha::Float64, dtemp::Float64 ) = - alpha *  dtemp

#cal_heat_transfer( ;alpha::Float64, temp_mns::Float64, temp_pls::Float64 ) = cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
cal_heat_transfer_diff( ;alpha::Float64, temp_mns::Float64, temp_pls::Float64 ) = cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_heat_transfer_plswall( ;alpha_mns::Float64, lam_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_pls::Float64 );
    alpha = cal_transmittance( alpha = alpha_mns, lam = lam_pls, dx2 = dx2_pls )
    return cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_heat_transfer_mnswall( ;alpha_pls::Float64, lam_mns::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64 );
    alpha = cal_transmittance( alpha = alpha_pls, lam = lam_mns, dx2 = dx2_mns )
    return cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
end

# Cell-BC_Robin間
# mns側が空気
function cal_q( cell_mns::BC_Robin, cell_pls::Cell )
    return cal_heat_transfer_diff( 
        alpha    = alpha(cell_mns), 
        temp_mns = temp(cell_mns.air), 
        temp_pls = temp(cell_pls) ) + cell_mns.q_added
end
cal_qx( cell_mns::BC_Robin, cell_pls::Cell ) = cal_q( cell_mns, cell_pls )
cal_qy( cell_mns::BC_Robin, cell_pls::Cell ) = cal_q( cell_mns, cell_pls )
cal_qz( cell_mns::BC_Robin, cell_pls::Cell ) = cal_q( cell_mns, cell_pls )

# pls側が空気
function cal_q( cell_mns::Cell, cell_pls::BC_Robin )
    return cal_heat_transfer_diff( 
        alpha    = alpha(cell_pls), 
        temp_mns = temp(cell_mns), 
        temp_pls = temp(cell_pls.air) ) - cell_pls.q_added
end
cal_qx( cell_mns::Cell, cell_pls::BC_Robin ) = cal_q( cell_mns, cell_pls )
cal_qy( cell_mns::Cell, cell_pls::BC_Robin ) = cal_q( cell_mns, cell_pls )
cal_qz( cell_mns::Cell, cell_pls::BC_Robin ) = cal_q( cell_mns, cell_pls )

# Cell-第一種境界条件間
cal_q(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_q( cell_mns, cell_pls.cell )
cal_q(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_q( cell_mns.cell, cell_pls )
# Cell-第二種境界条件間
cal_q(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.q
cal_q(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.q
# BC_Robin-BC_Robin間
cal_q(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_q(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
# BC_Robin-第二種境界条件間
cal_q(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_q(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0

# 3次元用
# Cell-第一種境界条件間
cal_qx(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_q( cell_mns, cell_pls.cell )
cal_qx(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_q( cell_mns.cell, cell_pls )
cal_qy(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_q( cell_mns, cell_pls.cell )
cal_qy(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_q( cell_mns.cell, cell_pls )
cal_qz(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_q( cell_mns, cell_pls.cell )
cal_qz(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_q( cell_mns.cell, cell_pls )
# Cell-第二種境界条件間
cal_qx(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.q
cal_qx(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.q
cal_qy(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.q
cal_qy(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.q
cal_qz(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.q
cal_qz(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.q
# BC_Robin-BC_Robin間
cal_qx(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
cal_qy(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
cal_qz(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_qx(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
cal_qy(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
cal_qz(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
# BC_Robin-第二種境界条件間
cal_qx(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_qx(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0
cal_qy(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_qy(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0
cal_qz(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_qz(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0

##############################################
# $$$$$$ 湿気（水蒸気） $$$$$$
# 湿気伝導（圧力差流れ）：基礎式
cal_vapour_permeance_pressure( ;dp::Float64, dpv::Float64, dx2::Float64 ) = - dp * dpv / dx2

# 差分方程式
function cal_vapour_permeance_pressure_diff( ;dp_mns::Float64, dp_pls::Float64, pv_mns::Float64, pv_pls::Float64, dx2_mns::Float64, dx2_pls::Float64 )
    dp = sum_resistance( val_mns = dp_mns, val_pls = dp_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_pressure( dp = dp, dpv = pv_pls - pv_mns, dx2 = dx2_mns + dx2_pls )
end

# 湿気伝導（水分化学ポテンシャル流れ）
cal_vapour_permeance_potential( ;ldmg::Float64, ldtg::Float64, dmiu::Float64, dtemp::Float64, dx2::Float64 ) = - ( ldmg * dmiu / dx2 + ldtg * dtemp / dx2 )

# 差分方程式
function cal_vapour_permeance_potential_diff( ;ldmg_mns::Float64, ldmg_pls::Float64, ldtg_mns::Float64, ldtg_pls::Float64, miu_mns::Float64, miu_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64, dx2_pls::Float64 )
    ldmg = sum_resistance( val_mns = ldmg_mns, val_pls = ldmg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    ldtg = sum_resistance( val_mns = ldtg_mns, val_pls = ldtg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_potential( ldmg = ldmg, ldtg = ldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns, dx2 = dx2 = dx2_mns + dx2_pls )
end

# 加重平均による計算方法
function cal_vapour_permeance_potential_diff_meanAve( ;ldmg_mns::Float64, ldmg_pls::Float64, ldtg_mns::Float64, ldtg_pls::Float64, miu_mns::Float64, miu_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64, dx2_pls::Float64 )
    ldmg = cal_mean_average( val_mns = ldmg_mns, val_pls = ldmg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    ldtg = cal_mean_average( val_mns = ldtg_mns, val_pls = ldtg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_potential( ldmg = ldmg, ldtg = ldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns, dx2 = dx2 = dx2_mns + dx2_pls )
end

function cal_jv( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff(
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_jv(; cell_mns, cell_pls ) = cal_jv(cell_mns, cell_pls)

# Cell-Cell間
# x軸方向
function cal_jvx( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff(
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_jvx(; cell_mns, cell_pls ) = cal_jvx(cell_mns, cell_pls)
# y軸方向
function cal_jvy( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff(
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dy(cell_mns) - dy2(cell_mns), dx2_pls = dy2(cell_pls) )
end
cal_jvy(; cell_mns, cell_pls ) = cal_jvy(cell_mns, cell_pls)
# x軸方向
function cal_jvz( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff(
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dz(cell_mns) - dz2(cell_mns), dx2_pls = dz2(cell_pls) )
end
cal_jvz(; cell_mns, cell_pls ) = cal_jvz(cell_mns, cell_pls)

function cal_jv_meanAve( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff_meanAve( 
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_jv_meanAve(; cell_mns, cell_pls ) = cal_jv_meanAve( cell_mns, cell_pls)

######################
# 湿気伝達（圧力差流れ）
cal_vapour_transfer_pressure( ;aldm::Float64, dpv::Float64 ) = - aldm * dpv

function cal_vapour_transfer_pressure_diff( ;aldm::Float64, pv_mns::Float64, pv_pls::Float64 );
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_vapour_transfer_pressure_plswall( ;aldm_mns::Float64, dp_pls::Float64, pv_mns::Float64, pv_pls::Float64, dx2_pls::Float64 );
    aldm = cal_transmittance( alpha = aldm_mns, lam = dp_pls, dx2 = dx2_pls )
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_vapour_transfer_pressure_mnswall( ;aldm_pls::Float64, dp_mns::Float64, pv_mns::Float64, pv_pls::Float64, dx2_mns::Float64 );
    aldm = cal_transmittance( alpha = aldm_pls, lam = dp_mns, dx2 = dx2_mns )
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

# Cell-BC_Robin間
# mns側が空気
function cal_jv( cell_mns::BC_Robin, cell_pls::Cell )
    cal_vapour_transfer_pressure_diff( aldm = aldm(cell_mns), 
        pv_mns = pv(cell_mns.air), pv_pls = pv(cell_pls) ) + cell_mns.jv_added
end
cal_jvx( cell_mns::BC_Robin, cell_pls::Cell ) = cal_jv( cell_mns, cell_pls )
cal_jvy( cell_mns::BC_Robin, cell_pls::Cell ) = cal_jv( cell_mns, cell_pls )
cal_jvz( cell_mns::BC_Robin, cell_pls::Cell ) = cal_jv( cell_mns, cell_pls )

# pls側が空気
function cal_jv( cell_mns::Cell, cell_pls::BC_Robin )
    cal_vapour_transfer_pressure_diff( aldm = aldm(cell_pls), 
        pv_mns = pv(cell_mns), pv_pls = pv(cell_pls.air) ) - cell_pls.jv_added
end
cal_jvx( cell_mns::Cell, cell_pls::BC_Robin ) = cal_jv( cell_mns, cell_pls )
cal_jvy( cell_mns::Cell, cell_pls::BC_Robin ) = cal_jv( cell_mns, cell_pls )
cal_jvz( cell_mns::Cell, cell_pls::BC_Robin ) = cal_jv( cell_mns, cell_pls )

# Cell-第一種境界条件間
cal_jv(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_jv( cell_mns, cell_pls.cell )
cal_jv(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_jv( cell_mns.cell, cell_pls )
# Cell-第二種境界条件間
cal_jv(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.jv
cal_jv(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.jv
# BC_Robin-BC_Robin間
cal_jv(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_jv(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
# BC_Robin-第二種境界条件間
cal_jv(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_jv(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0

# 3次元用
# Cell-第一種境界条件間
cal_jvx(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_jv( cell_mns, cell_pls.cell )
cal_jvx(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_jv( cell_mns.cell, cell_pls )
cal_jvy(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_jv( cell_mns, cell_pls.cell )
cal_jvy(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_jv( cell_mns.cell, cell_pls )
cal_jvz(  cell_mns::Cell, cell_pls::BC_Dirichlet ) = cal_jv( cell_mns, cell_pls.cell )
cal_jvz(  cell_mns::BC_Dirichlet, cell_pls::Cell ) = cal_jv( cell_mns.cell, cell_pls )
# Cell-第二種境界条件間
cal_jvx(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.jv
cal_jvx(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.jv
cal_jvy(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.jv
cal_jvy(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.jv
cal_jvz(  cell_mns::Cell, cell_pls::BC_Neumann ) = cell_pls.jv
cal_jvz(  cell_mns::BC_Neumann, cell_pls::Cell ) = cell_mns.jv
# BC_Robin-BC_Robin間
cal_jvx(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
cal_jvy(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
cal_jvz(  cell_mns::BC_Robin, cell_pls::BC_Robin ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_jvx(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
cal_jvy(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
cal_jvz(  cell_mns::BC_Neumann, cell_pls::BC_Neumann ) = 0.0
# BC_Robin-第二種境界条件間
cal_jvx(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_jvx(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0
cal_jvy(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_jvy(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0
cal_jvz(  cell_mns::BC_Robin, cell_pls::BC_Neumann ) = 0.0
cal_jvz(  cell_mns::BC_Neumann, cell_pls::BC_Robin ) = 0.0

######################
# 湿気伝達（化学ポテンシャル差流れ）
cal_vapour_transfer_potential( ;aldmg::Float64, aldtg::Float64, dmiu::Float64, dtemp::Float64 ) = - aldmg * dmiu - aldtg * dtemp

function cal_vapour_transfer_potential_diff( ;aldmg::Float64, aldtg::Float64, miu_mns::Float64, miu_pls::Float64, temp_mns::Float64, temp_pls::Float64 );
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_vapour_transfer_potential_plswall( ;aldmg_mns::Float64, aldtg_mns::Float64, ldmg_pls::Float64, ldtg_pls::Float64, miu_mns::Float64, miu_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_pls::Float64 );
    aldmg = cal_transmittance( alpha = aldmg_mns, lam = ldmg_pls, dx2 = dx2_pls )
    aldtg = cal_transmittance( alpha = aldtg_mns, lam = ldtg_pls, dx2 = dx2_pls )
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_vapour_transfer_potential_mnswall( ;aldmg_pls::Float64, aldtg_pls::Float64, ldmg_mns::Float64, ldtg_mns::Float64, miu_mns::Float64, miu_pls::Float64, temp_mns::Float64, temp_pls::Float64, dx2_mns::Float64 );
    aldmg = cal_transmittance( alpha = aldmg_pls, lam = ldmg_mns, dx2 = dx2_pls )
    aldtg = cal_transmittance( alpha = aldtg_pls, lam = ldtg_mns, dx2 = dx2_pls )
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

##############################################
# $$$$$$ 水（液水） $$$$$$
# 液水伝導：基礎式
cal_liquid_conduction_potential( ;ldml::Float64, dmiu::Float64, dx2::Float64, nx = 0.0 ) = - ldml * ( dmiu / dx2 - nx * 9.806650 )

# 差分方程式
function cal_liquid_conduction_potential_diff( ;ldml_mns::Float64, ldml_pls::Float64, miu_mns::Float64, miu_pls::Float64, dx2_mns::Float64, dx2_pls::Float64, nx = 0.0 ) # nxは特に指定が無い場合0
    ldml = sum_resistance( val_mns = ldml_mns, val_pls = ldml_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_liquid_conduction_potential( ldml = ldml, dmiu = miu_pls - miu_mns, dx2 = dx2_mns + dx2_pls, nx = nx )
end

# 加重平均による計算方法
function cal_liquid_conduction_potential_diff_meanAve( ;ldml_mns::Float64, ldml_pls::Float64, miu_mns::Float64, miu_pls::Float64, dx2_mns::Float64, dx2_pls::Float64, nx = 0.0 ) # nxは特に指定が無い場合0
    ldml = cal_mean_average( val_mns = ldml_mns, val_pls = ldml_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_liquid_conduction_potential( ldml = ldml, dmiu = miu_pls - miu_mns, dx2 = dx2_mns + dx2_pls, nx = nx )
end

function cal_jl( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_liquid_conduction_potential_diff( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), nx = nx )
end
cal_jl(; cell_mns, cell_pls, nx = 0.0 ) = cal_jl(cell_mns, cell_pls, nx)

# x軸方向
function cal_jlx( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_liquid_conduction_potential_diff( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), nx = nx )
end
cal_jlx(; cell_mns, cell_pls, nx = 0.0 ) = cal_jlx(cell_mns, cell_pls, nx)
# y軸方向
function cal_jly( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_liquid_conduction_potential_diff( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dy(cell_mns) - dy2(cell_mns), dx2_pls = dy2(cell_pls), nx = nx )
end
cal_jly(; cell_mns, cell_pls, nx = 0.0 ) = cal_jly(cell_mns, cell_pls, nx)
# x軸方向
function cal_jlz( cell_mns::Cell, cell_pls::Cell, nx = 1.0 )
    cal_liquid_conduction_potential_diff( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dz(cell_mns) - dz2(cell_mns), dx2_pls = dz2(cell_pls), nx = nx )
end
cal_jlz(; cell_mns, cell_pls, nx = 1.0 ) = cal_jlz(cell_mns, cell_pls, nz)

# 1次元用
# Cell-第一種境界条件間
cal_jl(  cell_mns::Cell, cell_pls::BC_Dirichlet, nx = 0.0 ) = cal_jl( cell_mns, cell_pls.cell, nx )
cal_jl(  cell_mns::BC_Dirichlet, cell_pls::Cell, nx = 0.0 ) = cal_jl( cell_mns.cell, cell_pls, nx )
# Cell-BC_Robin間
cal_jl(  cell_mns::BC_Robin, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl_added
cal_jl(  cell_mns::Cell, cell_pls::BC_Robin, nx = 0.0 ) = - cell_pls.jl_added
# Cell-第二種境界条件間
cal_jl(  cell_mns::Cell, cell_pls::BC_Neumann, nx = 0.0 ) = cell_pls.jl
cal_jl(  cell_mns::BC_Neumann, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl
# BC_Robin-BC_Robin間
cal_jl(  cell_mns::BC_Robin, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_jl(  cell_mns::BC_Neumann, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
# BC_Robin-第二種境界条件間
cal_jl(  cell_mns::BC_Robin, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jl(  cell_mns::BC_Neumann, cell_pls::BC_Robin, nx = 0.0 ) = 0.0

# 3次元用
# Cell-第一種境界条件間
cal_jlx(  cell_mns::Cell, cell_pls::BC_Dirichlet, nx = 0.0 ) = cal_jl( cell_mns, cell_pls.cell, nx )
cal_jlx(  cell_mns::BC_Dirichlet, cell_pls::Cell, nx = 0.0 ) = cal_jl( cell_mns.cell, cell_pls, nx )
cal_jly(  cell_mns::Cell, cell_pls::BC_Dirichlet, nx = 0.0 ) = cal_jl( cell_mns, cell_pls.cell, nx )
cal_jly(  cell_mns::BC_Dirichlet, cell_pls::Cell, nx = 0.0 ) = cal_jl( cell_mns.cell, cell_pls, nx )
cal_jlz(  cell_mns::Cell, cell_pls::BC_Dirichlet, nx = 0.0 ) = cal_jl( cell_mns, cell_pls.cell, nx )
cal_jlz(  cell_mns::BC_Dirichlet, cell_pls::Cell, nx = 0.0 ) = cal_jl( cell_mns.cell, cell_pls, nx )
# Cell-BC_Robin間
cal_jlx( cell_mns::Cell, cell_pls::BC_Robin, nx = 0.0 ) = - cell_pls.jl_added
cal_jly( cell_mns::Cell, cell_pls::BC_Robin, nx = 0.0 ) = - cell_pls.jl_added
cal_jlz( cell_mns::Cell, cell_pls::BC_Robin, nx = 0.0 ) = - cell_pls.jl_added
cal_jlx( cell_mns::BC_Robin, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl_added
cal_jly( cell_mns::BC_Robin, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl_added
cal_jlz( cell_mns::BC_Robin, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl_added
# Cell-第二種境界条件間
cal_jlx(  cell_mns::Cell, cell_pls::BC_Neumann, nx = 0.0 ) = cell_pls.jl
cal_jlx(  cell_mns::BC_Neumann, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl
cal_jly(  cell_mns::Cell, cell_pls::BC_Neumann, nx = 0.0 ) = cell_pls.jl
cal_jly(  cell_mns::BC_Neumann, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl
cal_jlz(  cell_mns::Cell, cell_pls::BC_Neumann, nx = 0.0 ) = cell_pls.jl
cal_jlz(  cell_mns::BC_Neumann, cell_pls::Cell, nx = 0.0 ) = cell_mns.jl
# BC_Robin-BC_Robin間
cal_jlx(  cell_mns::BC_Robin, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
cal_jly(  cell_mns::BC_Robin, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
cal_jlz(  cell_mns::BC_Robin, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
# 第二種境界条件-第二種境界条件間
cal_jlx(  cell_mns::BC_Neumann, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jly(  cell_mns::BC_Neumann, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jlz(  cell_mns::BC_Neumann, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
# BC_Robin-第二種境界条件間
cal_jlx(  cell_mns::BC_Robin, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jlx(  cell_mns::BC_Neumann, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
cal_jly(  cell_mns::BC_Robin, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jly(  cell_mns::BC_Neumann, cell_pls::BC_Robin, nx = 0.0 ) = 0.0
cal_jlz(  cell_mns::BC_Robin, cell_pls::BC_Neumann, nx = 0.0 ) = 0.0
cal_jlz(  cell_mns::BC_Neumann, cell_pls::BC_Robin, nx = 0.0 ) = 0.0

function cal_jl_meanAve( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_liquid_conduction_potential_diff_meanAve( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), nx = nx )
end
cal_jl_meanAve(; cell_mns::Cell, cell_pls::Cell, nx = 0.0 ) = cal_jl_meanAve( cell_mns, cell_pls, nx)



##############################################
# $$$$$$ 溶液 $$$$$$
# 溶液伝導：基礎式
cal_solusion_conduction( ;dsw::Float64, dplc::Float64, dx2::Float64, rowsw::Float64, nx = 0.0 ) = - dsw * ( dplc / dx2 - nx * rowsw * 9.806650 )

# 差分方程式
function cal_solusion_conduction_diff( ;dsw_mns::Float64, dsw_pls::Float64, plc_mns::Float64, plc_pls::Float64, dx2_mns::Float64, dx2_pls::Float64, rowsw::Float64, nx = 0.0 ) # nxは特に指定が無い場合0
    dsw = sum_resistance( val_mns = dsw_mns, val_pls = dsw_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_solusion_conduction( dsw = dsw, dplc = plc_pls - plc_mns, dx2 = dx2_mns + dx2_pls, rowsw = rowsw, nx = nx )
end

# 加重平均による計算方法
function cal_solusion_conduction_diff_meanAve( ;dsw_mns::Float64, dsw_pls::Float64, plc_mns::Float64, plc_pls::Float64, dx2_mns::Float64, dx2_pls::Float64, rowsw::Float64, nx = 0.0 ) # nxは特に指定が無い場合0
    dsw = cal_mean_average( val_mns = dsw_mns, val_pls = dsw_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_solusion_conduction( dsw = dsw, dplc = plc_pls - plc_mns, dx2 = dx2_mns + dx2_pls, rowsw = rowsw, nx = nx )
end

function cal_Jvol( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_solusion_conduction_diff( 
        dsw_mns = dsw(cell_mns), 
        dsw_pls = dsw(cell_pls), 　#粘性による移動係数の変化もここで加える
        plc_mns = plc(cell_mns), plc_pls = plc(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), rowsw = (rowsw(cell_mns) + rowsw(cell_pls)) / 2, nx = nx )　
end
cal_Jvol(; cell_mns, cell_pls, nx = 0.0 ) = cal_Jvol(cell_mns, cell_pls, nx)

cal_Jvol( cell_mns::Cell, cell_pls::BC_Robin,  nx = 0.0 ) = 0.0
cal_Jvol( cell_mns::BC_Robin,  cell_pls::Cell, nx = 0.0 ) = 0.0

function cal_Jvol_meanAve( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_solusion_conduction_diff_meanAve( 
        dsw_mns = dsw(cell_mns), 
        dsw_pls = dsw(cell_pls), 　#粘性による移動係数の変化もここで加える
        plc_mns = plc(cell_mns), plc_pls = plc(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), rowsw = (rowsw(cell_mns) + rowsw(cell_pls)) / 2, nx = nx )
end
cal_Jvol_meanAve(; cell_mns::Cell, cell_pls::Cell, nx = 0.0 ) = cal_Jvol_meanAve( cell_mns, cell_pls, nx)

##############################################
# 水の移動：基礎式
function cal_water_conduction( ;Jvol::Float64, ds::Float64, dcs::Float64, dx2::Float64, cs::Float64, vs::Float64, vw::Float64, sigma::Float64 )
    jw_adv = (1 - (1 - sigma) * vs * cs) / vw * Jvol
    jw_diff = vs / vw * ds * dcs / dx2
    jw = jw_adv + jw_diff
    return jw, jw_adv, jw_diff
end                

# 差分方程式
function cal_water_conduction_diff( ;Jvol::Float64, ds_mns::Float64, ds_pls::Float64, cs_mns::Float64, cs_pls::Float64, 
                                                dx2_mns::Float64, dx2_pls::Float64, cs::Float64, vs::Float64, vw::Float64, sigma::Float64 )
    ds = sum_resistance( val_mns = ds_mns, val_pls = ds_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_water_conduction( Jvol = Jvol, ds = ds, dcs = cs_pls - cs_mns, dx2 = dx2_mns + dx2_pls, cs = cs, vs = vs, vw = vw, sigma = sigma )
end

# 加重平均による計算方法
function cal_water_conduction_diff_meanAve( ;Jvol::Float64, ds_mns::Float64, ds_pls::Float64, cs_mns::Float64, cs_pls::Float64, 
                                                   dx2_mns::Float64, dx2_pls::Float64, cs::Float64, vs::Float64, vw::Float64, sigma::Float64 ) 
    ds = cal_mean_average( val_mns = ds_mns, val_pls = ds_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_water_conduction( Jvol = Jvol, ds = ds, dcs = cs_pls - cs_mns, dx2 = dx2_mns + dx2_pls, cs = cs, vs = vs, vw = vw, sigma = sigma )
end

function cal_jw( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
        
    cal_water_conduction_diff( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), 
        cs = cs_in, vs = (vs(cell_mns) + vs(cell_pls)) / 2, vw = (vw(cell_mns) + vw(cell_pls)) / 2, sigma = sigma(cell_mns) )
end
cal_jw(; cell_mns, cell_pls, Jvol ) = cal_jw( cell_mns, cell_pls, Jvol )

cal_jw( cell_mns::Cell, cell_pls::BC_Robin,  Jvol ) = 0.0
cal_jw( cell_mns::BC_Robin,  cell_pls::Cell, Jvol ) = 0.0

function cal_jw_meanAve( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
    
    cal_water_conduction_diff_meanAve( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), 
        cs = cs_in, vs = (vs(cell_mns) + vs(cell_pls)) / 2, vw = (vw(cell_mns) + vw(cell_pls)) / 2, sigma = sigma(cell_mns) )
end
cal_jw_meanAve(; cell_mns, cell_pls, Jvol ) = cal_jw_meanAve(cell_mns, cell_pls, Jvol )

##############################################
# 塩の移動：基礎式
function cal_salt_conduction( ;Jvol::Float64, ds::Float64, dcs::Float64, dx2::Float64, cs::Float64, sigma::Float64 )
    # 高取修正
    js_adv = (1 - sigma) * cs * Jvol
    js_diff= - ds * dcs / dx2
    js = js_adv + js_diff
    return js, js_adv, js_diff
end      

a, b, c = cal_salt_conduction( Jvol = -10.0e-2, ds = 0.001, dcs = 0.2 , dx2 = 0.1, cs = 1.0 , sigma = 0.0)

# 差分方程式
function cal_salt_conduction_diff( ;Jvol::Float64, ds_mns::Float64, ds_pls::Float64, cs_mns::Float64, cs_pls::Float64, 
                                                dx2_mns::Float64, dx2_pls::Float64, cs::Float64, sigma::Float64 )
    ds = sum_resistance( val_mns = ds_mns, val_pls = ds_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_salt_conduction( Jvol = Jvol, ds = ds, dcs = cs_pls - cs_mns, dx2 = dx2_mns + dx2_pls, cs = cs, sigma = sigma )
end

# 加重平均による計算方法
function cal_salt_conduction_diff_meanAve( ;Jvol::Float64, ds_mns::Float64, ds_pls::Float64, cs_mns::Float64, cs_pls::Float64, 
                                                   dx2_mns::Float64, dx2_pls::Float64, cs::Float64, sigma::Float64 ) 
    ds = cal_mean_average( val_mns = ds_mns, val_pls = ds_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_salt_conduction( Jvol = Jvol, ds = ds, dcs = cs_pls - cs_mns, dx2 = dx2_mns + dx2_pls, cs = cs, sigma = sigma )
end

function cal_js( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
    
    cal_salt_conduction_diff( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), cs = cs_in, sigma = sigma(cell_mns) )
end
cal_js(; cell_mns, cell_pls, Jvol ) = cal_js( cell_mns, cell_pls, Jvol )

cal_js( cell_mns::Cell, cell_pls::BC_Robin,  Jvol ) = 0.0
cal_js( cell_mns::BC_Robin,  cell_pls::Cell, Jvol ) = 0.0

function cal_js_meanAve( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
    
    cal_salt_conduction_diff_meanAve( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx(cell_mns) - dx2(cell_mns), dx2_pls = dx2(cell_pls), cs = cs_in, sigma = sigma(cell_mns) )
end
cal_js_meanAve(; cell_mns, cell_pls, Jvol ) = cal_js_meanAve(cell_mns, cell_pls, Jvol )

function cal_newtemp_by_ODE(temp::Float64, A1::Float64, c1::Float64, c2::Float64, dt::Float64 )
    return ( temp + c2 / c1 ) * exp( c1/A1*dt ) - c2 / c1
end
cal_newtemp_by_ODE(;temp::Float64, A1::Float64, c1::Float64, c2::Float64, dt::Float64 ) = cal_newtemp_by_ODE(temp, A1, c1, c2, dt )

cal_A1(c::Float64, rho::Float64, V::Float64) = c * rho * V
cal_A1(cell::Cell) = crow(cell) * vol(cell)

cal_A1(cell::BC_Robin) = (1005.0 + 1846.0 * ah(cell) ) * ( 353.25/temp(cell) ) * vol(cell)

function cal_c1x(cell_mns::Cell, cell::Cell, cell_pls::Cell)
    return cal_c1x_mns(cell, cell_mns) + cal_c1x_pls(cell, cell_pls)
end

function cal_c1x_mns(cell::Cell, cell_mns::Cell)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    dlam_mns  = 1.0 / ( dlamx_mns(cell) + dlamx_pls(cell_mns)  )
    dldtg_mns = 1.0 / ( dldtgx_mns(cell) + dldtgx_pls(cell_mns)  )
    return - ( dlam_mns + r * dldtg_mns )
end

function cal_c1x_pls(cell::Cell, cell_pls::Cell)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    dlam_pls  = 1.0 / ( dlamx_pls(cell) + dlamx_mns(cell_pls)  )
    dldtg_pls = 1.0 / ( dldtgx_pls(cell) + dldtgx_mns(cell_pls)  )
    return - ( dlam_pls + r * dldtg_pls )
end

cal_c1x(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell)     = cal_c1x_mns(cell, cell_mns) + cal_c1x_pls(cell, cell_pls)
cal_c1x(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin) = cal_c1x_mns(cell, cell_mns) + cal_c1x_pls(cell, cell_pls)
cal_c1x(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin) = cal_c1x_mns(cell, cell_mns) + cal_c1x_pls(cell, cell_pls)

function cal_c1x_mns(cell::Cell, cell_mns::BC_Robin)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    return - ( alpha(cell_mns) + r * aldt(cell_mns) )
end

function cal_c1x_pls(cell::Cell, cell_pls::BC_Robin)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    return - ( alpha(cell_pls) + r * aldt(cell_pls) )
end

# メイン
function cal_c1(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1})
    return cal_c1_trans(cell, cell_trans) + cal_c1_vent( cell, cell_vent, Q_vent)
end

# 伝達成分
function cal_c1_trans(cell::BC_Robin, cell_else::Array{Cell,1})
    return - sum( [ alpha(cell) for i = 1:length(cell_else) ] )
end

# 換気成分
function cal_c1_vent( cell::BC_Robin, cell_else::Array{BC_Robin,1}, Q_vent::Array{Float64,1})
    return - sum( [ Q_vent[i] * (1005.0+1846.0*ah(cell)) * (353.25/temp(cell)) for i = 1:length(cell_else) ] )
end

function cal_c2x(cell_mns::Cell, cell::Cell, cell_pls::Cell)
    return cal_c2x_mns(cell, cell_mns) + cal_c2x_pls(cell, cell_pls)
end

function cal_c2x_mns(cell::Cell, cell_mns::Cell)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    dlam_mns  = 1.0 / ( dlamx_mns(cell) + dlamx_pls(cell_mns)  )
    dldtg_mns = 1.0 / ( dldtgx_mns(cell) + dldtgx_pls(cell_mns)  )
    dldmg_mns = 1.0 / ( dldmgx_mns(cell) + dldmgx_pls(cell_mns)  )
    return ( dlam_mns + r * dldtg_mns ) * temp(cell_mns) - r * dldmg_mns * ( miu(cell) - miu(cell_mns) )
end

function cal_c2x_pls(cell::Cell, cell_pls::Cell)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    dlam_pls  = 1.0 / ( dlamx_pls(cell) + dlamx_mns(cell_pls)  )
    dldtg_pls = 1.0 / ( dldtgx_pls(cell) + dldtgx_mns(cell_pls)  )
    dldmg_pls = 1.0 / ( dldmgx_pls(cell) + dldmgx_mns(cell_pls)  )
    return ( dlam_pls + r * dldtg_pls ) * temp(cell_pls) - r * dldmg_pls * ( miu(cell) - miu(cell_pls) )
end

cal_c2x(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell)     = cal_c2x_mns(cell, cell_mns) + cal_c2x_pls(cell, cell_pls)
cal_c2x(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin) = cal_c2x_mns(cell, cell_mns) + cal_c2x_pls(cell, cell_pls)
cal_c2x(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin) = cal_c2x_mns(cell, cell_mns) + cal_c2x_pls(cell, cell_pls)

function cal_c2x_mns(cell::Cell, cell_mns::BC_Robin)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    return ( alpha(cell_mns) + r * aldt(cell_mns) ) * temp(cell_mns) - r * aldmu(cell_mns) * ( miu(cell) - miu(cell_mns) )
end

function cal_c2x_pls(cell::Cell, cell_pls::BC_Robin)
    r = ( 597.5 - 0.559 * ( temp(cell) - 273.15 ) ) * 4.18605E+3
    return ( alpha(cell_pls) + r * aldt(cell_pls) ) * temp(cell_pls) - r * aldmu(cell_pls) * ( miu(cell) - miu(cell_pls) )
end

# メイン
function cal_c2(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1}, Hi::Float64)
    return cal_c2_trans(cell, cell_trans) + cal_c2_vent( cell, cell_vent, Q_vent) + cal_c2_source(Hi)
end

# 伝達成分
function cal_c2_trans(cell::BC_Robin, cell_else::Array{Cell,1})
    return sum( [alpha(cell) * temp(cell_else[i]) for i = 1:length(cell_else) ] )
end

# 換気成分
function cal_c2_vent( cell::BC_Robin, cell_else::Array{BC_Robin,1}, Q_vent::Array{Float64,1} )
    return sum( [ Q_vent[i] * (1005.0+1846.0*ah(cell_else[i])) * (353.25/temp(cell_else[i])) * temp(cell_else[i]) for i = 1:length(cell_else) ] )
end

function cal_c2_source(Hi::Float64)
    return Hi
end

# 多孔質材料中
cal_newtemp_by_ODE(cell_mns::Cell,     cell::Cell, cell_pls::Cell,     nx::Float64, dt::Float64 ) = cal_newtemp_by_ODE(temp(cell), cal_A1(cell), cal_c1x(cell_mns, cell, cell_pls), cal_c2x(cell_mns, cell, cell_pls), dt )
cal_newtemp_by_ODE(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell,     nx::Float64, dt::Float64 ) = cal_newtemp_by_ODE(temp(cell), cal_A1(cell), cal_c1x(cell_mns, cell, cell_pls), cal_c2x(cell_mns, cell, cell_pls), dt )
cal_newtemp_by_ODE(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin, nx::Float64, dt::Float64 ) = cal_newtemp_by_ODE(temp(cell), cal_A1(cell), cal_c1x(cell_mns, cell, cell_pls), cal_c2x(cell_mns, cell, cell_pls), dt )
cal_newtemp_by_ODE(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin, nx::Float64, dt::Float64 ) = cal_newtemp_by_ODE(temp(cell), cal_A1(cell), cal_c1x(cell_mns, cell, cell_pls), cal_c2x(cell_mns, cell, cell_pls), dt )

# 空気中
function cal_newtemp_by_ODE(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1}, Hi::Float64, dt::Float64)
     return cal_newtemp_by_ODE( temp(cell), cal_A1(cell), 
            cal_c1(cell, cell_trans, cell_vent, Q_vent), 
            cal_c2(cell, cell_trans, cell_vent, Q_vent, Hi), dt )
end

function cal_newmiu_by_ODE(miu::Float64, A2::Float64, c3::Float64, c4::Float64, dt::Float64 )
    return ( miu + c4 / c3 ) * exp( c3 / A2*dt ) - c4 / c3
end
cal_newmiu_by_ODE(;miu::Float64, A2::Float64, c3::Float64, c4::Float64, dt::Float64 ) = cal_newmiu_by_ODE(miu, A2, c3, c4, dt)

cal_A2(rhow::Float64, V::Float64, dphi::Float64) = rhow * V * dphi
cal_A2(cell::Cell) = 998.0 * vol(cell) * dphi(cell)

cal_A2(cell::Air) = ( 353.25/temp(cell) ) * vol(cell)
cal_A2(cell::BC_Robin) = ( 353.25/temp(cell) ) * vol(cell)

function cal_c3x(cell_mns::Cell, cell::Cell, cell_pls::Cell)
    return cal_c3x_mns(cell, cell_mns) + cal_c3x_pls(cell, cell_pls)
end

function cal_c3x_mns(cell::Cell, cell_mns::Cell)
    dldmg_mns  = 1.0 / ( dldmgx_mns(cell) + dldmgx_pls(cell_mns)  )
    dldml_mns  = 1.0 / ( dldmlx_mns(cell) + dldmlx_pls(cell_mns)  )
    return - ( dldmg_mns + dldml_mns )
end

function cal_c3x_pls(cell::Cell, cell_pls::Cell)
    dldmg_pls  = 1.0 / ( dldmgx_pls(cell) + dldmgx_mns(cell_pls)  )
    dldml_pls  = 1.0 / ( dldmlx_pls(cell) + dldmlx_mns(cell_pls)  )
    return - ( dldmg_pls + dldml_pls )
end

cal_c3x(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell)     = cal_c3x_mns(cell, cell_mns) + cal_c3x_pls(cell, cell_pls)
cal_c3x(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin) = cal_c3x_mns(cell, cell_mns) + cal_c3x_pls(cell, cell_pls)
cal_c3x(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin) = cal_c3x_mns(cell, cell_mns) + cal_c3x_pls(cell, cell_pls)

function cal_c3x_mns(cell::Cell, cell_mns::BC_Robin)
    return - aldmu(cell_mns)
end

function cal_c3x_pls(cell::Cell, cell_pls::BC_Robin)
    return - aldmu(cell_pls)
end

# メイン
function cal_c3(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1})
    return cal_c3_trans(cell, cell_trans) + cal_c3_vent( cell, cell_vent, Q_vent)
end

# 伝達成分
function cal_c3_trans(cell::BC_Robin, cell_else::Array{Cell,1})
    return - sum( [ aldm(cell)*cal_dah_dpv(pv(cell), patm(cell) ) for i = 1:length(cell_else) ] )
end

# 換気成分
function cal_c3_vent( cell::BC_Robin, cell_else::Array{BC_Robin,1}, Q_vent::Array{Float64,1})
    return - sum( [ Q_vent[i] * (353.25/temp(cell)) for i = 1:length(cell_else) ] )
end

function cal_c4x(cell_mns::Cell, cell::Cell, cell_pls::Cell, nx::Float64)
    return cal_c4x_mns(cell, cell_mns, nx) + cal_c4x_pls(cell, cell_pls, nx)
end

function cal_c4x_mns(cell::Cell, cell_mns::Cell, nx::Float64 )
    dldmg_mns  = 1.0 / ( dldmgx_mns(cell) + dldmgx_pls(cell_mns)  )
    dldml_mns  = 1.0 / ( dldmlx_mns(cell) + dldmlx_pls(cell_mns)  )
    dldtg_mns  = 1.0 / ( dldtgx_mns(cell) + dldtgx_pls(cell_mns)  )
    return ( dldmg_mns + dldml_mns ) * miu(cell_mns) - dldml_mns * nx * 9.806650 + dldtg_mns * ( temp(cell) - temp(cell_mns) )
end

function cal_c4x_pls(cell::Cell, cell_pls::Cell, nx::Float64 )
    dldmg_pls  = 1.0 / ( dldmgx_pls(cell) + dldmgx_mns(cell_pls)  )
    dldml_pls  = 1.0 / ( dldmlx_pls(cell) + dldmlx_mns(cell_pls)  )
    dldtg_pls  = 1.0 / ( dldtgx_pls(cell) + dldtgx_mns(cell_pls)  )
    return ( dldmg_pls + dldml_pls ) * miu(cell_pls) + dldml_pls * nx * 9.806650 + dldtg_pls * ( temp(cell_pls) - temp(cell) )
end

cal_c4x(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell,     nx::Float64 ) = cal_c4x_mns(cell, cell_mns, nx) + cal_c4x_pls(cell, cell_pls, nx)
cal_c4x(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin, nx::Float64 ) = cal_c4x_mns(cell, cell_mns, nx) + cal_c4x_pls(cell, cell_pls, nx)
cal_c4x(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin, nx::Float64 ) = cal_c4x_mns(cell, cell_mns, nx) + cal_c4x_pls(cell, cell_pls, nx)

function cal_c4x_mns(cell::Cell, cell_mns::BC_Robin, nx::Float64 )
    return aldmu(cell_mns) * miu(cell_mns) + aldt(cell_mns) * ( temp(cell) - temp(cell_mns) )
end

function cal_c4x_pls(cell::Cell, cell_pls::BC_Robin, nx::Float64 )
    return aldmu(cell_pls) * miu(cell_pls) + aldt(cell_pls) * ( temp(cell) - temp(cell_pls) )
end

# メイン
function cal_c4(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1}, Hi::Float64)
    return cal_c4_trans(cell, cell_trans) + cal_c4_vent( cell, cell_vent, Q_vent) + cal_c4_source(Hi)
end

# 伝達成分
function cal_c4_trans(cell::BC_Robin, cell_else::Array{Cell,1})
    return sum( [ aldm(cell)*cal_dah_dpv(pv(cell), patm(cell) ) * ah(cell_else[i]) for i = 1:length(cell_else) ] )
end

# 換気成分
function cal_c4_vent( cell::BC_Robin, cell_else::Array{BC_Robin,1}, Q_vent::Array{Float64,1})
    return sum( [ Q_vent[i] * (353.25/temp(cell_else[i])) * ah(cell_else[i]) for i = 1:length(cell_else) ] )
end

function cal_c4_source(Hi::Float64)
    return Hi
end

# 多孔質材料中
cal_newmiu_by_ODE(cell_mns::Cell,     cell::Cell, cell_pls::Cell,     nx::Float64, dt::Float64 )  = cal_newmiu_by_ODE(miu(cell), cal_A2(cell), cal_c3x(cell_mns, cell, cell_pls), cal_c4x(cell_mns, cell, cell_pls, nx), dt )
cal_newmiu_by_ODE(cell_mns::BC_Robin, cell::Cell, cell_pls::Cell,     nx::Float64, dt::Float64 )  = cal_newmiu_by_ODE(miu(cell), cal_A2(cell), cal_c3x(cell_mns, cell, cell_pls), cal_c4x(cell_mns, cell, cell_pls, nx), dt )
cal_newmiu_by_ODE(cell_mns::Cell,     cell::Cell, cell_pls::BC_Robin, nx::Float64, dt::Float64 )  = cal_newmiu_by_ODE(miu(cell), cal_A2(cell), cal_c3x(cell_mns, cell, cell_pls), cal_c4x(cell_mns, cell, cell_pls, nx), dt )
cal_newmiu_by_ODE(cell_mns::BC_Robin, cell::Cell, cell_pls::BC_Robin, nx::Float64, dt::Float64 )  = cal_newmiu_by_ODE(miu(cell), cal_A2(cell), cal_c3x(cell_mns, cell, cell_pls), cal_c4x(cell_mns, cell, cell_pls, nx), dt )

# 空気中
function cal_newAH_by_ODE(cell::BC_Robin, cell_trans::Array{Cell,1}, cell_vent::Array{BC_Robin,1}, Q_vent::Array{Float64,1}, Hi::Float64, dt::Float64)
    return cal_newmiu_by_ODE( ah(cell), cal_A2(cell), 
           cal_c3(cell, cell_trans, cell_vent, Q_vent), 
           cal_c4(cell, cell_trans, cell_vent, Q_vent, Hi), dt )
end