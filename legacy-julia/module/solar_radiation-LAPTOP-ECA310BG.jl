const JSTD = 1367.0

function cal_soldn( P::Float64, SINH::Float64 )
    return JSTD * P ^ ( 1.0 / SINH )
end
cal_soldn(; P::Float64, SINH::Float64 ) = cal_soldn( P, SINH )

function cal_solsn( P::Float64, SINH::Float64 )
    return 1.0 / 2.0 * JSTD * SINH * ( 1.0 - P ^ ( 1.0 / SINH ) ) / ( 1.0 - 1.4 *  log(P) )
end
cal_solsn(; P::Float64, SINH::Float64 ) = cal_solsn( P, SINH )

function SUNLHA( PHI::Float64, LON::Float64, TM::Float64, LONS::Float64, SINDLT::Float64, COSDLT::Float64, ET::Float64 )
    #RAD = 2.0 * PI / 360.0

    T = 15.0 * ( TM - 12.0 ) + ( LON - LONS ) + ET
    
    PHIRAD = PHI # * RAD
    TRAD   = T   # * RAD
    
    SINH   = sind(PHIRAD) * SINDLT + cosd(PHIRAD) * COSDLT * cosd(TRAD)
    COSH   = ( 1.0 - SINH ^ 2.0) ^ (1/2)
    SINA   = COSDLT * sind( TRAD ) / COSH
    COSA   = ( SINH * sind( PHIRAD ) - SINDLT ) / ( COSH * cosd( PHIRAD ) )
    
    return SINH, COSH, SINA, COSA
end
SUNLHA(; PHI::Float64, LON::Float64, TM::Float64, LONS::Float64, SINDLT::Float64, COSDLT::Float64, ET::Float64 ) = SUNLHA( PHI, LON, TM, LONS, SINDLT, COSDLT, ET )

function SUNLD( YEAR::Int, NDAY::Int )

    RAD = 2.0 * pi / 360.0
    DLTO= -23.43930 * RAD
    
    N = YEAR - 1968.0

    DO1 = 3.710 + 0.25960 * N - floor( ( N + 3.0 ) / 4.0 )
    
    M = 0.98560 * ( NDAY - DO1 )
    
    EPS = 12.39010 + 0.0172 * ( N + M / 360.0 )
    V   = M + 1.9140 * sind( M ) + 0.02 * sind( 2.0 * M )
    VEPS= ( V + EPS ) * RAD
    
    ET = (M - V) - atan( 0.0430 * sin( 2.0 * VEPS ) / ( 1.0 - 0.0430 * cos( 2.0 * VEPS ) ) ) / RAD
    
    SINDLT = cos(VEPS) * sin(DLTO)
    COSDLT = ( abs( 1.0- SINDLT ^ 2.0 ) )^( 1/2 )
    
    return SINDLT, COSDLT, ET
end
SUNLD(; YEAR::Int, NDAY::Int ) = SUNLD( YEAR, NDAY )

function cal_ALTI(SINH::Float64)
    return asin(SINH) * 180 / pi
end
cal_ALTI(;SINH::Float64) = cal_ALTI(SINH)

function cal_LATI(COSA::Float64, SINA::Float64)
    if SINA >= 0.0
        LATI = 90.0 - atan( COSA / SINA ) * 180 / pi
    elseif SINA <= 0.0
        LATI = -90.0 - atan( COSA / SINA ) * 180 / pi
    end
    return LATI
end
cal_LATI(;COSA::Float64, SINA::Float64) = cal_LATI(COSA, SINA)

function cal_NDAY( year::Int, month::Int, day::Int )
    if month == 1;      NDAY = day
    elseif month == 2;  NDAY = 31 + day
    elseif month == 3;  NDAY = 59 + day
    elseif month == 4;  NDAY = 90 + day
    elseif month == 5;  NDAY =120 + day
    elseif month == 6;  NDAY =151 + day
    elseif month == 7;  NDAY =181 + day
    elseif month == 8;  NDAY =212 + day
    elseif month == 9;  NDAY =243 + day
    elseif month == 10; NDAY =273 + day
    elseif month == 11; NDAY =304 + day
    elseif month == 12; NDAY =334 + day
    end
    
    # うるう年の計算
    if ( ( mod(year,4)==0 && mod(year,100)≠0) || ( mod(year,400)==0 ) ) && ( month > 2 )
        NDAY = NDAY + 1
    end
    
    return NDAY
end
cal_NDAY(; year::Int, month::Int, day::Int ) = cal_NDAY( year, month, day )

function cal_solar_radiation( year::Int, month::Int, day::Int, hour::Int, min::Int, sec::Int, 
    PHI::Float64, LON::Float64, LONS::Float64, P::Float64 )

    NDAY  = cal_NDAY( year, month, day )
    
    # 地方標準時
    TM = Float64(hour) + Float64(min) / 60.0 + Float64(sec) / 3600.0
    
    # 赤緯の計算
    SINDLT, COSDLT, ET = SUNLD( YEAR = year, NDAY = NDAY )
    
    # 太陽高度・太陽方位角の計算
    SINH, COSH, SINA, COSA = SUNLHA( PHI, LON, TM, LONS, SINDLT, COSDLT, ET )

    # 2024/11/28追記：壁面日射量が合わなかったため修正
    #LATI = 180.0 - acos(COSA) * 180.0 / pi
    if SINA >= 0.0
        LATI = 90.0 - atan(COSA/SINA) * 180.0 / pi
    elseif SINA < 0.0
        LATI = - 90.0 - atan(COSA/SINA) * 180.0 / pi
    end
    ALTI = asin(SINH) * 180.0 / pi
    
    # 日射量の計算
    # 太陽高度が0以上のとき
    if SINH > 0
        SOLDN = cal_soldn( P, SINH )
        SOLSN = cal_solsn( P, SINH )
    # 太陽が沈んでいるとき
    else
        SOLDN = 0.0
        SOLSN = 0.0
    end
    
    return SOLDN, SOLSN, LATI, ALTI
end
cal_solar_radiation(; year::Int, month::Int, day::Int, hour::Int, min::Int, sec::Int, PHI::Float64, LON::Float64, LONS::Float64, P::Float64) = cal_solar_radiation( year, month, day, hour, min, sec, PHI, LON, LONS, P)

function cal_direct_solar_radiation_at_wall( SOLDN::Float64, ALTI::Float64, LATI::Float64, θe::Float64, θa::Float64,
    LATI_started::Float64 = -180.0, LATI_limited::Float64 = 360.0, ALTI_started::Float64 = -180.0, ALTI_limited::Float64 = 360.0 )
    RAD = 180 / pi
    COSI = cos( θe / RAD ) * sin( ALTI / RAD ) + sin( θe / RAD ) * cos( ALTI / RAD ) * cos( ( LATI - θa ) / RAD )

    if (COSI >= 0.0)
        # 直達日射の遮蔽がない場合
        if LATI >= LATI_started && LATI <= LATI_limited && ALTI >= ALTI_started && ALTI <= ALTI_limited
            RADDN = SOLDN * COSI
        # 直達日射の遮蔽がある場合
        else
            RADDN = 0.0
        end
    else
        RADDN = 0.0
    end    

    return RADDN
end

cal_direct_solar_radiation_at_wall(; SOLDN::Float64, ALTI::Float64, LATI::Float64, θe::Float64, θa::Float64,
    LATI_started::Float64 = -180.0, LATI_limited::Float64 = 360.0, ALTI_started::Float64 = -180.0, ALTI_limited::Float64 = 360.0 ) = 
        cal_direct_solar_radiation_at_wall( SOLDN, ALTI, LATI, θe, θa, LATI_started, LATI_limited, ALTI_started, ALTI_limited )

function cal_diffused_solar_radiation_at_wall( SOLSN::Float64, θe::Float64 )
    RAD = 180 / pi
    # RADSN = SOLSN * ( abs( ( 180.0 - γ ) / 180.0 ) )
    RADSN = SOLSN * ( ( 1.0 + cos( θe / RAD ) ) / 2.0 )
    return RADSN
end
cal_diffused_solar_radiation_at_wall(; SOLSN::Float64, θe::Float64 ) = cal_diffused_solar_radiation_at_wall( SOLSN, θe )

function cal_reflected_solar_radiation_by_ground( rho::Float64, SOLDN::Float64, SOLSN::Float64, θe::Float64 )
    return rho * ( SOLSN + SOLDN ) * ( ( 1.0 - cos( θe / (180 / pi) ) ) / 2.0 )
end
cal_reflected_solar_radiation_by_ground(; SOLDN::Float64, SOLSN::Float64, θe::Float64, rho::Float64 = 0.2 ) = cal_reflected_solar_radiation_by_ground( rho, SOLDN, SOLSN, θe )

function cal_flux_thermal_radiation( temp::Float64, ε::Float64 )
    return ε * temp ^ 4 * 5.67e-8
end

function cal_flux_thermal_radiation_in_atmospher_cloudless( temp::Float64, f::Float64 )
    return 5.67e-8 * temp ^4 * ( 0.51 + 0.0066 * f^(1/2) ) 
end

function cal_flux_thermal_radiation_in_atmospher_cloudy( temp::Float64, f::Float64, n::Int )
    return 0.75 * (n/10)^2 * 5.67e-8 * temp ^4 + ( 1.0 - 0.75 * (n/10)^2 ) * cal_flux_thermal_radiation_in_atmospher_cloudless( temp, f )
end

function cal_effective_thermal_radiation_at_wall( temp_wall::Float64, temp_air::Float64, ε::Float64, pv::Float64, n::Int, θe::Float64 )
    Qr      = cal_flux_thermal_radiation( temp_wall, ε )
    Qrad    = cal_flux_thermal_radiation_in_atmospher_cloudy( temp_air, pv, n )
    return ( ( 1.0 + cos( θe / (180 / pi) ) ) / 2.0 ) * ( Qrad - Qr )
end

cal_effective_thermal_radiation_at_wall(; temp_wall::Float64, temp_air::Float64, ε::Float64, pv::Float64, n::Int, θe::Float64 ) = cal_effective_thermal_radiation_at_wall( temp_wall, temp_air, ε, pv, n, θe )
