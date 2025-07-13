include("cell.jl")
include("air.jl")
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
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls) )
end
cal_q(;cell_mns, cell_pls ) = cal_q( cell_mns, cell_pls )

function cal_q_meanAve( cell_mns::Cell, cell_pls::Cell )
    return cal_heat_conduction_diff_meanAve( lam_mns = lam(cell_mns), lam_pls= lam(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls) )
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

function cal_q( cell_mns::Air, cell_pls::Cell )
    return cal_heat_transfer_diff( 
        alpha    = alpha(cell_mns), 
        temp_mns = temp(cell_mns), 
        temp_pls = temp(cell_pls) )
end

function cal_q( cell_mns::Cell, cell_pls::Air )
    return cal_heat_transfer_diff( 
        alpha    = alpha(cell_pls), 
        temp_mns = temp(cell_mns), 
        temp_pls = temp(cell_pls) )
end

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
        dx2_mns  = dx2(cell_mns),  dx2_pls  = dx2(cell_pls) )
end
cal_jv(; cell_mns, cell_pls ) = cal_jv(cell_mns, cell_pls)

function cal_jv_meanAve( cell_mns::Cell, cell_pls::Cell )
    cal_vapour_permeance_potential_diff_meanAve( 
        ldmg_mns = ldmg(cell_mns), ldmg_pls = ldmg(cell_pls), 
        ldtg_mns = ldtg(cell_mns), ldtg_pls = ldtg(cell_pls), 
        miu_mns  = miu(cell_mns),  miu_pls  = miu(cell_pls), 
        temp_mns = temp(cell_mns), temp_pls = temp(cell_pls), 
        dx2_mns  = dx2(cell_mns),  dx2_pls  = dx2(cell_pls) )
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

function cal_jv( cell_mns::Air, cell_pls::Cell )
    cal_vapour_transfer_pressure_diff( aldm = aldm(cell_mns), 
        pv_mns = pv(cell_mns), pv_pls = pv(cell_pls) )
end

function cal_jv( cell_mns::Cell, cell_pls::Air )
    cal_vapour_transfer_pressure_diff( aldm = aldm(cell_pls), 
        pv_mns = pv(cell_mns), pv_pls = pv(cell_pls) )
end

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
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), nx = nx )
end
cal_jl(; cell_mns, cell_pls, nx = 0.0 ) = cal_jl(cell_mns, cell_pls, nx)

cal_jl( cell_mns::Cell, cell_pls::Air,  nx = 0.0 ) = 0.0
cal_jl( cell_mns::Air,  cell_pls::Cell, nx = 0.0 ) = 0.0

function cal_jl_meanAve( cell_mns::Cell, cell_pls::Cell, nx = 0.0 )
    cal_liquid_conduction_potential_diff_meanAve( 
        ldml_mns = ldml(cell_mns), ldml_pls = ldml(cell_pls), 
        miu_mns = miu(cell_mns), miu_pls = miu(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), nx = nx )
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

cal_Jvol( cell_mns::Cell, cell_pls::Air,  nx = 0.0 ) = 0.0
cal_Jvol( cell_mns::Air,  cell_pls::Cell, nx = 0.0 ) = 0.0

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
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), 
        cs = cs_in, vs = (vs(cell_mns) + vs(cell_pls)) / 2, vw = (vw(cell_mns) + vw(cell_pls)) / 2, sigma = sigma(cell_mns) )
end
cal_jw(; cell_mns, cell_pls, Jvol ) = cal_jw( cell_mns, cell_pls, Jvol )

cal_jw( cell_mns::Cell, cell_pls::Air,  Jvol ) = 0.0
cal_jw( cell_mns::Air,  cell_pls::Cell, Jvol ) = 0.0

function cal_jw_meanAve( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
    
    cal_water_conduction_diff_meanAve( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), 
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

a, b, c = cal_salt_conduction( Jvol = 10.0, ds = 0.001, dcs = 0.2 , dx2 = 0.1, cs = 1.0 , sigma = 0.0)

a

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
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), cs = cs_in, sigma = sigma(cell_mns) )
end
cal_js(; cell_mns, cell_pls, Jvol ) = cal_js( cell_mns, cell_pls, Jvol )

cal_js( cell_mns::Cell, cell_pls::Air,  Jvol ) = 0.0
cal_js( cell_mns::Air,  cell_pls::Cell, Jvol ) = 0.0

function cal_js_meanAve( cell_mns::Cell, cell_pls::Cell, Jvol )
    
    if Jvol > 0.0; cs_in = cs_vol(cell_mns)
        else; cs_in = cs_vol(cell_pls)
    end
    
    cal_salt_conduction_diff_meanAve( 
        Jvol = Jvol,
        ds_mns = ds(cell_mns), ds_pls = ds(cell_pls), 
        cs_mns = cs_vol(cell_mns), cs_pls = cs_vol(cell_pls), 
        dx2_mns = dx2(cell_mns), dx2_pls = dx2(cell_pls), cs = cs_in, sigma = sigma(cell_mns) )
end
cal_js_meanAve(; cell_mns, cell_pls, Jvol ) = cal_js_meanAve(cell_mns, cell_pls, Jvol )





test_cell1 = Cell()
test_cell1.dx = 0.0015
test_cell1.dx2 = test_cell1.dx / 2.0 
test_cell1.temp = 298.15
test_cell1.miu = -150.0
test_cell1.material_name = "bentheimer_sandstone"

test_cell2 = Cell()
test_cell2.dx = 0.002
test_cell2.dx2 = test_cell2.dx / 2.0 
test_cell2.temp = 295.15
test_cell2.miu = -200.0
test_cell2.material_name = "bentheimer_sandstone"

test_air = Air()
test_air.temp = 295.15
test_air.rh = 0.9
test_air.alpha = 10.0
test_air.aldm  = 1.0e-8

cal_jl( test_cell1, test_cell2 )

cal_q( test_air, test_cell1 )

cal_q( test_cell2, test_air )

cal_q( test_air, test_cell1 )

cal_q_meanAve( test_cell2, test_cell1 )

cal_jv( test_cell2, test_cell1 )

cal_jv( test_cell2, test_air )

cal_jv( test_air, test_cell1 )

cal_jv_meanAve( test_cell2, test_cell1 )

cal_jl( test_cell2, test_cell1, 1.0 )

cal_jl( test_cell2, test_air, 1.0 )

cal_jl_meanAve( test_cell2, test_cell1 )


