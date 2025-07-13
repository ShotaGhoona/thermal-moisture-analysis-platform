const Rv = 8.314/0.018

function cal_Pvs(temp);
    return exp( -5800.22060 / temp + 1.3914993 - 4.8640239E-2 * temp + 4.1764768E-5 * (temp ^ 2.0) - 1.4452093E-8 * (temp ^ 3.0) + 6.5459673 * log(temp) )
end

# 多重ディスパッチによる別実装
cal_Pvs( ;temp ) = cal_Pvs( temp )

function cal_Pv_ByRH(temp::Float64, rh::Float64)
    return rh * cal_Pvs( temp = temp )
end

cal_Pv_ByRH( ;temp::Float64, rh::Float64 ) = cal_Pv_ByRH( temp, rh )

function cal_Pv_ByMiu(temp::Float64, miu::Float64 );
    rh = exp( miu / Rv / temp )
    return rh * cal_Pvs(temp = temp)
end

cal_Pv_ByMiu(;temp::Float64, miu::Float64 ) = cal_Pv_ByMiu( temp, miu )

function cal_DPvs( temp );
    DP = 10.795740 * 273.160 / temp / temp - 5.0280 / temp / log(10.0) + 
    ( 1.50475E-4 ) * 8.2969 / 273.16 * log(10.0)* 
    ( 10.0 ^ ( -8.29690 * ( temp / 273.160 - 1.0 ) ) ) + 
    ( 0.42873E-3 ) * 4.769550 * 273.160 / temp / temp * log(10.0) * 
    ( 10.0 ^ ( 4.769550 * ( 1.0 - 273.160 / temp ) ) )
    return cal_Pvs(temp = temp) * DP * log(10.0)
end

cal_DPvs( ;temp ) = cal_DPvs( temp )

function cal_DPvDT( temp, miu );
    pvs  = cal_Pvs( temp )
    dpvs = cal_DPvs( temp )
    return dpvs * exp( miu / Rv / temp ) - pvs * miu / Rv / temp / temp * exp( miu/ Rv/ temp)
end
cal_DPvDT(; temp, miu ) = cal_DPvDT( temp, miu )

function cal_DPvDMiu( temp, miu );
    pvs  = cal_Pvs( temp )
    return pvs / Rv / temp * exp( miu / Rv / temp )
end
cal_DPvDMiu(; temp, miu ) = cal_DPvDMiu( temp, miu )

function cal_drh_dmiu( temp::Float64, miu::Float64 )
    return ( 1.0 / Rv / temp ) * exp( miu / Rv / temp )
end
cal_drh_dmiu(; temp::Float64, miu::Float64 ) = cal_drh_dmiu( temp, miu )

function cal_dah_dpv(pv::Float64, patm::Float64=101325.0 )
    return 0.622 * patm / ( ( patm - pv )^2 )
end
cal_dah_dpv(;pv::Float64, patm::Float64=101325.0 ) = cal_dah_dpv(pv, patm )

function cal_dah_drh(temp::Float64, rh::Float64, patm::Float64=101325.0)
    pvs = cal_Pvs(temp)
    return 0.622 * pvs * patm / ( patm - pvs * rh )^2
end
cal_dah_drh(;temp::Float64, rh::Float64, patm::Float64=101325.0) = cal_dah_drh(temp, rh, patm)

convertRH2Pv( ;temp::Float64, rh::Float64 ) = rh * cal_Pvs( temp = temp )
convertRH2Pv( temp::Float64, rh::Float64 )  = convertRH2Pv( temp = temp, rh = rh )
convertPv2RH( ;temp::Float64, pv::Float64 ) = pv / cal_Pvs( temp = temp )

convertRH2Miu( ;temp::Float64, rh::Float64 )  = Rv * temp * log( rh )
convertMiu2RH( ;temp::Float64, miu::Float64 ) =  exp( miu / Rv / temp )
convertRH2AH( ;temp::Float64, rh::Float64, patm::Float64 = 101325.0 ) =  convertPv2AH( patm = patm, pv = convertRH2Pv( temp, rh ) )
function convertPv2Miu( ;temp::Float64, pv::Float64 );
    rh = convertPv2RH( temp = temp, pv = pv )
    return convertRH2Miu( temp = temp, rh = rh )
end

function convertMiu2Pv( ;temp::Float64, miu::Float64 );
    rh = convertMiu2RH( temp = temp, miu = miu )
    return convertRH2Pv( temp = temp, rh = rh )
end

convertPv2AH( ;patm::Float64, pv::Float64 ) = 0.622 * pv / ( patm - pv )
convertAH2Pv( ;patm::Float64, ah::Float64 ) = ah * patm / ( 0.622 + ah )
convertAH2RH( ;temp::Float64, patm::Float64, ah::Float64 ) = convertPv2RH( temp=temp, pv=convertAH2Pv( patm=patm, ah=ah ))


