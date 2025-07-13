cal_air_flux_by_VR( n::Float64, V::Float64 ) = 1.0 / 3600.0 * (dp)^(1/n)
cal_air_flux_by_VR(;n::Float64, V::Float64 ) = cal_air_flux_by_VR( n, V )

cal_air_flux_by_leakage( k::Float64, dp::Float64, n::Float64 ) = k * (dp)^(1/n)
cal_air_flux_by_leakage(;k::Float64, dp::Float64, n::Float64 ) = cal_air_flux_by_leakage( k, dp, n )

cal_dQdp_by_leakage( k::Float64, dp::Float64, n::Float64 ) = k / n * dp ^ ((1-n)/n)
cal_dQdp_by_leakage(;k::Float64, dp::Float64, n::Float64 ) = cal_dQdp( k, dp, n ) 

cal_air_flux_by_opening( alpha::Float64, A::Float64, rho::Float64, dp::Float64 ) = alpha * A * (2/rho)^(1/2) * dp ^ (1/2)
cal_air_flux_by_opening(;alpha::Float64, A::Float64, rho::Float64, dp::Float64 ) = cal_air_flux_by_opening( alpha, A, rho, dp )

module flux_leakage_isothermal
    SU(RAW::Float64, QH::Float64, B::Float64, DP::Float64, MM::Float64)     =   RAW * QH * B * abs(DP)^(1/MM)
    SS(RAW::Float64, QV::Float64, S::Float64, H::Float64,  DP::Float64, M::Float64)   = RAW * QV * S * H * abs(DP)^(1/M)
    UC(RAW::Float64, QH::Float64, B::Float64, DP::Float64, MM::Float64)     =   RAW * QH * B * abs(DP)^(1/MM)
    
    function WU(RAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, H::Float64, DP::Float64, M::Float64, MM::Float64)
        return SU(RAW, QH, B, DP, MM) + SS(RAW, QV, S, H,  DP, M) + UC(RAW, QH, B, DP, MM)
    end
    
    # DPによる微分
    DSU(RAW::Float64, QH::Float64, B::Float64, DP::Float64, MM::Float64)   =   RAW * QH * B / MM * abs(DP) ^ ((1-MM)/MM)
    DSS(RAW::Float64, QV::Float64, S::Float64, H::Float64,  DP::Float64, M::Float64)  = RAW * QV * S * H / M * abs(DP) ^ ((1-M)/M)
    DUC(RAW::Float64, QH::Float64, B::Float64, DP::Float64, MM::Float64)   =   RAW * QH * B / MM * abs(DP) ^ ((1-MM)/MM)
    
    function DWU(RAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, H::Float64, DP::Float64, M::Float64, MM::Float64)
        return DSU(RAW, QH, B, DP, MM) + DSS(RAW, QV, S, H,  DP, M) + DUC(RAW, QH, B, DP, MM)
    end
end

module flux_ventilation_isothermal
    WU( A::Float64, B::Float64, H::Float64, DP::Float64, RAW::Float64)   = A * B * H * (2/RAW)^(1/2) * abs(DP) ^ (1/2)
    DWU(A::Float64, B::Float64, H::Float64, DP::Float64, RAW::Float64)   = A * B * H * ( 2.0 * RAW )^0.5 / 2.0 * abs(DP) ^ ((1-2)/2)
end

module flux_leakage_noniso_uniflow

const G = 9.80665

function cal_SS(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64)
    return RAW * QV * S * M / ( 1.0+M ) * ( abs(DRAW)*G )^( 1.0/M ) * abs( HNU^( (1.0+M)/M ) - HND^( (1.0+M)/M) )
end

# 上辺と縦開口部分の隙間を通る流量。隙間と下辺の隙間で隙間特性値が分けてある。SU:[kg/s]
SU(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HNU::Float64, MM::Float64)  = RAW * QH * B * ( abs(DRAW) * G * HNU)^( 1.0/MM )
SS(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64)  = cal_SS(RAW, DRAW, QV, S, HNU, HND, M)

#下辺の隙間を通る流量
UC(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HND::Float64, MM::Float64) = RAW * QH * B * ( abs(DRAW) * G * HND )^( 1.0/MM )

# 枝の正味流量[kg/s]
function WU(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return SU(RAW, DRAW, QH, B, HNU, MM) + SS(RAW, DRAW, QV, S, HNU, HND, M) + UC(RAW, DRAW, QH, B, HND, MM)
end

# DPによる微分
DSU(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HNU::Float64, MM::Float64)   = RAW * QH * B * ( abs(DRAW ) * G * HNU )^( (1.0-MM ) / MM ) / MM
DSS(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64) = S * RAW * QV * ( abs(DRAW) * G )^( (1.0-M)/M ) * abs( HNU^( 1.0/M ) - HND^( 1.0/M ) )
DUC(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HND::Float64, MM::Float64)   = RAW * QH * B * ( abs(DRAW) * G * HND )^( ( 1.0-MM ) /MM ) / MM

function DWU(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return DSU(RAW, DRAW, QH, B, HNU, MM) + DSS(RAW, DRAW, QV, S, HNU, HND, M) + DUC(RAW, DRAW, QH, B, HND, MM)
end

end

module flux_ventilation_noniso_uniflow

const G = 9.80665

# 中立軸高さが上下端の外側にあるとき：式は同じだが密度の取り方（上流側か下流側か）が異なる
WU(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, HNU::Float64, HND::Float64) = 2.0 / 3.0 * A * B * (2.0 * RAW * abs(DRAW) * G )^0.5 * abs( HNU^1.5 - HND^1.5 )
#WD(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, HNU::Float64, HND::Float64) = 2.0 / 3.0 * A * B * (2.0 * RAW * abs(DRAW) * G )^0.5 * abs( HNU^1.5 - HND^1.5 )
DWU(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, HNU::Float64, HND::Float64)= A* B * (2.0 * RAW)^0.5 * ( abs(DRAW) * G )^(-0.5) * abs( HNU^0.5 - HND^0.5 )
#DWD(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, HNU::Float64, HND::Float64)= A* B * (2.0 * RAW)^0.5 * ( abs(DRAW) * G )^(-0.5) * abs( HNU^0.5 - HND^0.5 )

end

module flux_leakage_noniso_crossflow

const G = 9.80665

# 上辺と縦開口部（中性帯より上側）の隙間を通る流量。隙間と下辺の隙間で隙間特性値が分けてある。SU:[kg/s]
SU(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HNU::Float64, MM::Float64)     = RAW * QH * B * ( abs(DRAW) * G * HNU )^( 1.0/MM )
SSU(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HNU::Float64, M::Float64) = RAW * QV * S * M * ( abs(DRAW) * G )^( 1.0/M ) * HNU^( ( 1.0+M ) / M ) / ( 1.0+M )
# 下辺と縦開口部（中性帯より下側）の隙間を通る流量
UC(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HND::Float64, MM::Float64) = RAW * QH * B * ( abs(DRAW) * G * HND )^( 1.0/MM )
SSD(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HND::Float64, M::Float64) = RAW * QV * S * M * ( abs(DRAW) * G )^( 1.0/M ) * HND^( ( 1.0+M ) / M ) / ( 1.0+M )

# 枝の正味流量[kg/s]
function WU(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return SU(RAW, DRAW, QH, B, HNU, MM) + SSU(RAW, DRAW, QV, S, HNU, M)
end
function WD(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return UC(RAW, DRAW, QH, B, HND, MM) + SSD(RAW, DRAW, QV, S, HND, M)
end

# DPによる微分
DSU(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HNU::Float64, MM::Float64)   = RAW * QH * B * ( abs(DRAW ) * G * HNU )^( (1.0-MM ) / MM ) / MM
DSSU(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HNU::Float64, M::Float64) = S * RAW * QV * ( abs(DRAW) * G )^( ( 1.0-M ) / M ) * HNU^( 1.0/M )
DUC(RAW::Float64, DRAW::Float64, QH::Float64, B::Float64, HND::Float64, MM::Float64)   = RAW * QH * B * ( abs(DRAW) * G * HND )^( ( 1.0-MM ) /MM ) / MM
DSSD(RAW::Float64, DRAW::Float64, QV::Float64, S::Float64, HND::Float64, M::Float64) = S * RAW * QV * ( abs(DRAW) * G )^( ( 1.0-M ) / M ) * HND^( 1.0/M )

function DWU(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return DSU(RAW, DRAW, QH, B, HNU, MM) + DSSU(RAW, DRAW, QV, S, HNU, M)
end
function DWD(RAW::Float64, DRAW::Float64, QH::Float64, QV::Float64, B::Float64, S::Float64, HNU::Float64, HND::Float64, M::Float64, MM::Float64)
    return DUC(RAW, DRAW, QH, B, HND, MM) + DSSD(RAW, DRAW, QV, S, HND, M)
end

end

module flux_ventilation_noniso_crossflow

const G = 9.80665

# 中立軸高さが上下端の内側にあるとき：
WU(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, Hight::Float64) = 2.0 / 3.0 * A * B * ( 2.0 * abs(DRAW) * G )^0.5 * RAW^0.5 * Hight^1.5
WD(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, Hight::Float64) = 2.0 / 3.0 * A * B * ( 2.0 * abs(DRAW) * G )^0.5 * RAW^0.5 * Hight^1.5
DWU(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, Hight::Float64)= A* B * 2.0^0.5 * ( abs(DRAW) * G )^(-0.5) * ( RAW * Hight )^0.5
DWD(A::Float64, B::Float64, DRAW::Float64, RAW::Float64, Hight::Float64)= A* B * 2.0^0.5 * ( abs(DRAW) * G )^(-0.5) * ( RAW * Hight )^0.5

end

# 風圧力の計算
function cal_wind_pressure_force(C::Float64, rho::Float64, v::Float64)
    return (1.0 / 2.0) * C * rho * v ^ 2.0
end
cal_wind_pressure_force(; C::Float64, rho::Float64, v::Float64) = cal_wind_pressure_force(C, rho, v)

# AfW：Angle from Wind direction
function cal_wind_pressure_coefficient( AfW::Float64 )
    if AfW < -180.0
        AfW = AfW + 360.0
    end
    # 0°~30°
    if ( -30.0 <= AfW && AfW <= 30  ) || ( 330.0 <= AfW )
        C = 0.75
    # 30°~75°
    elseif ( -75.0 <= AfW && AfW <= -30.0  )
        C = 1.25 + 0.75 / 45.0 * AfW
    elseif ( 30.0 <= AfW && AfW <= 75.0  )
        C = 1.25 - 0.75 / 45.0 * AfW
    elseif ( 285.0 <= AfW && AfW <= 330.0  )
        C = 1.25 + 0.75 / 45.0 * ( AfW - 360.0 )
    # 75°~90°
    elseif ( -90.0 <= AfW && AfW <= -75.0  )
        C = 2.0 + 0.4 / 15.0 * AfW
    elseif ( 75.0 <= AfW && AfW <= 90.0  )
        C = 2.0 - 0.4 / 15.0 * AfW
    elseif ( 270.0 <= AfW && AfW <= 285.0  )
        C = 2.0 + 0.4 / 15.0 * ( AfW - 360.0 )
    # 90°~105°
    elseif ( -105.0 <= AfW && AfW <= -90.0  )
        C = 0.2 + 0.1 / 15.0 * AfW
    elseif ( 90.0 <= AfW && AfW <= 105.0  )
        C = 0.2 - 0.1 / 15.0 * AfW
    elseif ( 255.0 <= AfW && AfW <= 270.0  )
        C = 0.2 + 0.1 / 15.0 * ( AfW - 360.0 )
    # 90°~105°
    elseif ( -180.0 <= AfW && AfW <= -105.0  ) || ( 105.0 <= AfW && AfW <= 255.0 )
        C = -0.5
    end
    return C
end

function cal_flux_ventilation( ION, Type, DP, DRAW, A, B, S, HU, HD, M, MM, RAW_IP, RAW_IM, QV, QH )
    
    # 重力加速度
    G = 9.80665

    # 開口の高さ＝開口上端高さー開口下端高さ
    H = HU - HD
    
    #####################################    
    #鉛直開口
    if ION == "VT"
        ############
        # 温度差なし
        if DRAW == 0.0

            # 仮定した起圧力と実際の気圧力との差がないとき
            if DP == 0.0
                WU  = 0.0
                WD  = 0.0
                DWU = 1.0e-5
                DWD = 1.0e-5

            # 起圧力差DPが正の時
            elseif DP > 0
                WD  = 0.0
                DWD = 0.0
                # 1) 隙間における漏気
                if Type == "gap"
                    WU  = flux_leakage_isothermal.WU(RAW_IP, QH, QV, B, S, H, DP, M, MM)
                    DWU = flux_leakage_isothermal.DWU(RAW_IP, QH, QV, B, S, H, DP, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WU  = flux_ventilation_isothermal.WU(A, B, H, DP, RAW_IP)
                    DWU = flux_ventilation_isothermal.DWU(A, B, H, DP, RAW_IP)
                end
            # 起圧力差DPが負の時
            elseif DP < 0
                WU  = 0.0
                DWU = 0.0
                # 1) 隙間における漏気
                if Type == "gap"
                    WD  = flux_leakage_isothermal.WU(RAW_IM, QH, QV, B, S, H, DP, M, MM)
                    DWD = flux_leakage_isothermal.DWU(RAW_IM, QH, QV, B, S, H, DP, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WD  = flux_ventilation_isothermal.WU(A, B, H, DP, RAW_IM)
                    DWD = flux_ventilation_isothermal.DWU(A, B, H, DP, RAW_IM)
                end
            end
            
        ############
        # 温度差が存在するとき
        else
            HN  = DP / ( DRAW * G ) #中立軸高さ
            HNU = abs( HU - HN ) # 上端から中立軸高さまでの距離
            HND = abs( HD - HN ) # 下端から中立軸高さまでの距離
            
            # 中立軸高さが上下端外にあるとき　＆　上流側？への流れのとき（上流・下流の向きは用件等）
            if (DRAW < 0 && HN <= HD) || ( DRAW > 0 && HN >= HU )
                WD  = 0.0
                DWD = 0.0
                # 1) 隙間における漏気
                if Type == "gap"
                    WU  = flux_leakage_noniso_uniflow.WU(RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWU = flux_leakage_noniso_uniflow.DWU(RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WU  = flux_ventilation_noniso_uniflow.WU(A, B, DRAW, RAW_IP, HNU, HND)
                    DWU = flux_ventilation_noniso_uniflow.DWU(A, B, DRAW, RAW_IP, HNU, HND)
                end

            # 中立軸高さが上下端外にあるとき　＆　下流側？への流れのとき
            elseif ( DRAW < 0 && HN >= HU ) || ( DRAW > 0 && HN <= HD )
                WU  = 0.0
                DWU = 0.0
                # 1) 隙間における漏気
                if Type == "gap"
                    WD  = flux_leakage_noniso_uniflow.WU(RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWD = flux_leakage_noniso_uniflow.DWU(RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WD  = flux_ventilation_noniso_uniflow.WU(A, B, DRAW, RAW_IM, HNU, HND)
                    DWD = flux_ventilation_noniso_uniflow.DWU(A, B, DRAW, RAW_IM, HNU, HND)
                end
            
            # 中立軸高さが上下端内にあるとき　＆　密度差が負のとき
            elseif DRAW < 0 && HD < HN && HN < HU 
                # 1) 隙間における漏気
                if Type == "gap"
                    WU  = flux_leakage_noniso_crossflow.WU( RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    WD  = flux_leakage_noniso_crossflow.WD( RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWU = flux_leakage_noniso_crossflow.DWU(RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWD = flux_leakage_noniso_crossflow.DWD(RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WU  = flux_ventilation_noniso_crossflow.WU( A, B, DRAW, RAW_IP, HNU )
                    WD  = flux_ventilation_noniso_crossflow.WD( A, B, DRAW, RAW_IM, HND )
                    DWU = flux_ventilation_noniso_crossflow.DWU( A, B, DRAW, RAW_IP, HNU )
                    DWD = flux_ventilation_noniso_crossflow.DWD( A, B, DRAW, RAW_IM, HND )
                end
                
            # 中立軸高さが上下端内にあるとき　＆　密度差が負のとき
            elseif DRAW > 0 && HD < HN && HN < HU
                # 1) 隙間における漏気
                if Type == "gap"
                    WU  = flux_leakage_noniso_crossflow.WD( RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    WD  = flux_leakage_noniso_crossflow.WU( RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWU = flux_leakage_noniso_crossflow.DWD(RAW_IP, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                    DWD = flux_leakage_noniso_crossflow.DWU(RAW_IM, DRAW, QH, QV, B, S, HNU, HND, M, MM)
                # 2) 開口における漏気
                elseif Type == "opening"
                    WU  = flux_ventilation_noniso_crossflow.WU( A, B, DRAW, RAW_IP, HND )
                    WD  = flux_ventilation_noniso_crossflow.WD( A, B, DRAW, RAW_IM, HNU )
                    DWU = flux_ventilation_noniso_crossflow.DWU( A, B, DRAW, RAW_IP, HND )
                    DWD = flux_ventilation_noniso_crossflow.DWD( A, B, DRAW, RAW_IM, HNU )
                end
            end
        end

    elseif ION == 1
        println("まだ実装されてないよ")        
    end

    W   = WU - WD # Wを矢印の方向に合わせて、正負を変換している。
    DW  = DWU + DWD # 微分の計算
    
    return W, WU, WD, DW, DWU, DWD
end

cal_flux_ventilation(; ION, Type, DP, DRAW, A, B, S, HU, HD, M, MM, RAW_IP, RAW_IM, QV, QH) = cal_flux_ventilation( ION, Type, DP, DRAW, A, B, S, HU, HD, M, MM, RAW_IP, RAW_IM, QV, QH )

test_vf = cal_flux_ventilation( 
    ION = "VT", 
    Type= "gap", 
    DP  = 0.0, 
    DRAW= 0.1, 
    A   = 3.0, 
    B   = 1.0, 
    S   = 0.0, 
    HU  = 5.0, 
    HD  = 1.0, 
    M   = 2.0, 
    MM  = 2.0, 
    RAW_IP = 2.0, 
    RAW_IM = 2.0, 
    QV      = 1.0, 
    QH      = 1.0 )


