module Flux

const grav = 9.806650

# 抵抗値の平均化
function sum_resistance( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    #if val_mns <= 0 or val_pls <= 0:
    #    lam = 0.0 
    #else:
    return (len_mns + len_pls) / ( len_mns / val_mns + len_pls / val_pls )
end

# 調和平均による平均化
function cal_mean_average( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    return ( val_mns * len_mns + val_pls * len_pls ) / ( len_mns + len_pls )
end

# （境界面）貫流値として足し合わせる場合
function cal_transmittance( ;alpha::Float64, lam::Float64, dx2::Float64 )
    return ( 1.0 ) / ( 1.0 / alpha + dx / ( 2.0 * lam ) )
end

##############################################
# $$$$$$ 熱 $$$$$$
# 熱伝導
# 基礎式
cal_heat_conduction( ;lam::Float64, dtemp::Float64, dx2::Float64 ) = - lam * dtemp / dx2

# 差分方程式（質点の位置に注意）
function cal_heat_conduction_diff( ;lam_mns, lam_pls, temp_mns, temp_pls, dx2_mns, dx2_pls )
    lam = sum_resistance( val_mns = lam_mns, val_pls = lam_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_heat_conduction( lam = lam, dtemp = temp_pls - temp_mns, dx2 = dx2_mns + dx2_pls )
end

# 調和平均による計算方法
function cal_heat_conduction_diff_meanAve( ;lam_mns, lam_pls, temp_mns, temp_pls, dx2_mns, dx2_pls )
    lam = cal_mean_average( val_mns = lam_mns, val_pls = lam_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_heat_conduction( lam = lam, dtemp = temp_pls - temp_mns, dx2 = dx2_mns + dx2_pls )
end

######################
# 熱伝達
# 質点を境界に置く場合
cal_heat_transfer( ;alpha::Float64, dtemp::Float64 ) = - alpha *  dtemp 

function cal_heat_transfer_diff( ;alpha, temp_mns, temp_pls );
    return cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_heat_transfer_plswall( ;alpha_mns, lam_pls, temp_mns, temp_pls, dx2_pls );
    alpha = cal_transmittance( alpha = alpha_mns, lam = lam_pls, dx2 = dx2_pls )
    return cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_heat_transfer_mnswall( ;alpha_pls, lam_mns, temp_mns, temp_pls, dx2_mns );
    alpha = cal_transmittance( alpha = alpha_pls, lam = lam_mns, dx2 = dx2_mns )
    return cal_heat_transfer( alpha = alpha, dtemp = temp_pls - temp_mns )
end


##############################################
# $$$$$$ 湿気（水蒸気） $$$$$$
# 湿気伝導（圧力差流れ）
# 基礎式
cal_vapour_permeance_pressure( ;dp::Float64, dpv::Float64, dx2::Float64 ) = - dp * dpv / dx2

# 差分方程式
function cal_vapour_permeance_pressure_diff( ;dp_mns, dp_pls, pv_mns, pv_pls, dx2_mns, dx2_pls )
    dp = sum_resistance( val_mns = dp_mns, val_pls = dp_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_pressure( dp = dp, dpv = pv_pls - pv_mns, dx2 = dx2_mns + dx2_pls )
end

# 湿気伝導（水分化学ポテンシャル流れ）
cal_vapour_permeance_potential( ;ldmg, ldtg, dmiu, dtemp, dx2 ) = - ( ldmg * dmiu / dx2 + ldtg * dtemp / dx2 )

# 差分方程式
function cal_vapour_permeance_potential_diff( ;ldmg_mns, ldmg_pls, ldtg_mns, ldtg_pls, miu_mns, miu_pls, temp_mns, temp_pls, dx2_mns, dx2_pls )
    ldmg = sum_resistance( val_mns = ldmg_mns, val_pls = ldmg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    ldtg = sum_resistance( val_mns = ldtg_mns, val_pls = ldtg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_potential( ldmg = ldmg, ldtg = ldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns, dx2 = dx2 = dx2_mns + dx2_pls )
end

# 調和平均による計算方法
function cal_vapour_permeance_potential_diff_meanAve( ;ldmg_mns, ldmg_pls, ldtg_mns, ldtg_pls, miu_mns, miu_pls, temp_mns, temp_pls, dx2_mns, dx2_pls )
    ldmg = cal_mean_average( val_mns = ldmg_mns, val_pls = ldmg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    ldtg = cal_mean_average( val_mns = ldtg_mns, val_pls = ldtg_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_vapour_permeance_potential( ldmg = ldmg, ldtg = ldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns, dx2 = dx2 = dx2_mns + dx2_pls )
end

######################
# 湿気伝達（圧力差流れ）
cal_vapour_transfer_pressure( ;aldm::Float64, dpv::Float64 ) = - aldm * dpv

function cal_vapour_transfer_pressure_diff( ;aldm, pv_mns, pv_pls );
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_vapour_transfer_pressure_plswall( ;aldm_mns, dp_pls, pv_mns, pv_pls, dx2_pls );
    aldm = cal_transmittance( alpha = aldm_mns, lam = dp_pls, dx2 = dx2_pls )
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_vapour_transfer_pressure_mnswall( ;aldm_pls, dp_mns, pv_mns, pv_pls, dx2_mns );
    aldm = cal_transmittance( alpha = aldm_pls, lam = dp_mns, dx2 = dx2_mns )
    return cal_vapour_transfer_pressure( aldm = aldm, dpv = pv_pls - pv_mns )
end

######################
# 湿気伝達（化学ポテンシャル差流れ）
cal_vapour_transfer_potential( ;aldmg::Float64, aldtg::Float64, dmiu::Float64, dtemp::Float64 ) = - aldmg * dmiu - aldtg * dtemp

function cal_vapour_transfer_potential_diff( ;aldmg, aldtg, miu_mns, miu_pls, temp_mns, temp_pls );
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は右（pls）側）
function cal_vapour_transfer_potential_plswall( ;aldmg_mns, aldtg_mns, ldmg_pls, ldtg_pls, miu_mns, miu_pls, temp_mns, temp_pls, dx2_pls );
    aldmg = cal_transmittance( alpha = aldmg_mns, lam = ldmg_pls, dx2 = dx2_pls )
    aldtg = cal_transmittance( alpha = aldtg_mns, lam = ldtg_pls, dx2 = dx2_pls )
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

# 質点が材料内部にある場合（壁は左（mns）側）
function cal_vapour_transfer_potential_mnswall( ;aldmg_pls, aldtg_pls, ldmg_mns, ldtg_mns, miu_mns, miu_pls, temp_mns, temp_pls, dx2_mns );
    aldmg = cal_transmittance( alpha = aldmg_pls, lam = ldmg_mns, dx2 = dx2_pls )
    aldtg = cal_transmittance( alpha = aldtg_pls, lam = ldtg_mns, dx2 = dx2_pls )
    return cal_vapour_transfer_potential( aldmg = aldmg, aldtg = aldtg, dmiu = miu_pls - miu_mns, dtemp = temp_pls - temp_mns )
end

##############################################
# $$$$$$ 水（液水） $$$$$$
# 液水伝導
# 基礎式
cal_liquid_conduction_potential( ;ldml::Float64, dmiu::Float64, dx2::Float64, nx = 0.0 ) = - ldml * ( dmiu / dx2 - nx * grav )

# 差分方程式
function cal_liquid_conduction_potential_diff( ;ldml_mns, ldml_pls, miu_mns, miu_pls, dx2_mns, dx2_pls, nx = 0.0 ) # nxは特に指定が無い場合0
    ldml = sum_resistance( val_mns = ldml_mns, val_pls = ldml_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_liquid_conduction_potential( ldml = ldml, dmiu = miu_pls - miu_mns, dx2 = dx2_mns + dx2_pls, nx = nx )
end

# 調和平均による計算方法
function cal_liquid_conduction_potential_diff_meanAve( ;ldml_mns, ldml_pls, miu_mns, miu_pls, dx2_mns, dx2_pls, nx = 0.0 ) # nxは特に指定が無い場合0
    ldml = cal_mean_average( val_mns = ldml_mns, val_pls = ldml_pls, len_mns = dx2_mns, len_pls = dx2_pls )
    return cal_liquid_conduction_potential( ldml = ldml, dmiu = miu_pls - miu_mns, dx2 = dx2_mns + dx2_pls, nx = nx )
end

end

module balance_equation

#Cr：水の比熱(specific heat of water)[J/(kg・K)]
const Cr = 4.18605E+3

#roww：水の密度(density of water)[kg/m3]
const roww = 1000.0

# 潜熱変化量
latent_heat(temp) = ( 597.5 - 0.559 * ( temp - 273.15 ) ) * Cr
latent_heat(;temp) = latent_heat(temp)

##########################################
# 熱収支式
cal_newtemp(crow::Float64, temp::Float64, dq::Float64, W::Float64, dx::Float64, dt::Float64 ) = temp + ( dq - latent_heat( temp ) * W ) / dx * ( dt / crow )
    
##########################################
# 水分化学ポテンシャル収支式
cal_newmiu( dphi::Float64, miu::Float64, djw::Float64, dx::Float64, dt::Float64 ) = miu + djw / dx / dphi * ( dt / roww )

##########################################
# 含水率収支式
cal_newphi( phi::Float64, djw::Float64, dx::Float64, dt::Float64 ) = phi + djw / dx * ( dt / roww )

end

module balance_equation_by_ODE

#grav：重力加速度
const grav = 9.806650

#Cr：水の比熱(specific heat of water)[J/(kg・K)]
const Cr = 4.18605E+3

#roww：水の密度(density of water)[kg/m3]
const roww = 1000.0

# 潜熱変化量
latent_heat(temp) = ( 597.5 - 0.559 * ( temp - 273.15 ) ) * Cr
latent_heat(;temp) = latent_heat(temp)

##########################################
# 熱収支式
function cal_newtemp(temp::Float64, A1::Float64, c1::Float64, c2::Float64, dt::Float64 ) 
    return ( temp + c2/c1 ) * exp( c1/A1 * dt ) - c2/c1
end
cal_newtemp(;temp, A1, c1, c2, dt) =  cal_newtemp(temp, A1, c1, c2, dt)

##########################################
# 水分化学ポテンシャル収支式
function cal_newmiu(miu::Float64, A2::Float64, c3::Float64, c4::Float64, dt::Float64 )
    return ( miu + c4/c3 ) * exp( c3/A2 * dt ) - c4/c3
end
cal_newmiu(;miu, A2, c3, c4, dt) = cal_newmiu(miu, A2, c3, c4, dt)

##########################################
# 定数の計算式
function cal_A1(; crow::Float64, vol::Float64 )
    return crow * vol
end

function cal_A2(; vol::Float64, dphi::Float64 )
    return roww * vol * dphi
end

##########################################
# 材料内に流量計算の場合
# 略称　⇒　mns:minus, pls:plus, cen::center
function cal_c1(; lam_mns::Float64, lam_pls::Float64, ldtg_mns::Float64, ldtg_pls::Float64, r::Float64, dx2_mns::Float64, dx2_pls::Float64)
    return - ( lam_mns / dx2_mns + lam_pls / dx2_pls + r * ( ldtg_mns / dx2_mns + ldtg_pls / dx2_pls) )
end

function cal_c2(; temp_mns::Float64, temp_pls::Float64, miu_mns::Float64, miu_pls::Float64, miu_cen::Float64, 
        lam_mns::Float64, lam_pls::Float64, ldmg_mns::Float64, ldmg_pls::Float64, ldtg_mns::Float64, ldtg_pls::Float64,
        r::Float64, dx2_mns::Float64, dx2_pls::Float64)
    return ( lam_mns + r*ldtg_mns ) / dx2_mns * temp_mns + ( lam_pls + r*ldtg_pls ) / dx2_pls * temp_pls + 
    r *( ldmg_pls/dx2_pls * ( miu_pls - miu_cen ) - ldmg_mns/dx2_mns * ( miu_cen - miu_mns ) )
end

function cal_c3(; ldm_mns::Float64, ldm_pls::Float64, dx2_mns::Float64, dx2_pls::Float64)
    return - ( ldm_pls / dx2_pls + ldm_mns / dx2_mns )
end

function cal_c4(; temp_mns::Float64, temp_pls::Float64, temp_cen::Float64, miu_mns::Float64, miu_pls::Float64,
        ldm_mns::Float64, ldm_pls::Float64, ldt_mns::Float64, ldt_pls::Float64, 
        dx2_mns::Float64, dx2_pls::Float64, nx::Float64)
    return ( ldm_mns / dx2_mns * miu_mns + ldm_pls / dx2_pls * miu_pls ) + 
    ( ldt_pls / dx2_pls * ( temp_pls - temp_cen ) - ldt_mns / dx2_mns * ( temp_cen - temp_mns ) ) - 
    ( ldm_mns - ldm_pls ) * nx * grav
    # 重力項のところ正しい？
end

##########################################
# 空気境界における計算の場合
# （多重ディスパッチで実装）
function cal_c1_BC(; lam::Float64, alpha::Float64, ldtg::Float64, aldt::Float64 = 0, r::Float64, dx2::Float64)
    return - ( alpha + lam / dx2 + r * ( aldt + ldtg / dx2) )
end

function cal_c2_BC(; temp_wall::Float64, temp_air::Float64, miu_wall::Float64, miu_air::Float64, miu_surf::Float64, 
        lam::Float64, alpha::Float64, ldmg::Float64, aldmu::Float64, ldtg::Float64, aldt::Float64,
        r::Float64, dx2::Float64, heat_gain::Float64 )
    return ( alpha + r*aldt ) * temp_air + ( lam + r * ldtg ) / dx2 * temp_wall + 
    r *( ldmg/dx2 * ( miu_wall - miu_surf ) - aldmu * ( miu_surf - miu_air ) ) + heat_gain
end

# aldmuの入力値が無い場合断湿境界条件
function cal_c3_BC(; ldm::Float64, aldmu::Float64, dx2::Float64)
    return - ( aldmu + ldm / dx2 )
end

function cal_c4_BC(; temp_wall::Float64, temp_air::Float64, temp_surf::Float64, miu_wall::Float64, miu_air::Float64,
        ldm::Float64, aldmu::Float64, ldt::Float64, aldt::Float64, dx2::Float64, nx::Float64, moisture_gain::Float64)
    return aldmu * miu_air + ldm/dx2 * miu_wall + 
    ldt / dx2 * ( temp_wall - temp_surf ) - aldt * ( temp_surf - temp_air ) - 
    ldm * nx * grav + moisture_gain
end
# 留意事項：+-の符号に注意　⇒　centerに向かう熱流・水分流と考えれば問題ない。・重力項要注意

###################################################
# 材料物性値の平均化方法
# 抵抗値として足し合わせる
function sum_resistance( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    return (len_mns + len_pls) / ( len_mns / val_mns + len_pls / val_pls )
end

# 調和平均を取る
function cal_mean_average( ;val_mns::Float64, val_pls::Float64, len_mns::Float64, len_pls::Float64 );
    return ( val_mns * len_mns + val_pls * len_pls ) / ( len_mns + len_pls )
end

end


