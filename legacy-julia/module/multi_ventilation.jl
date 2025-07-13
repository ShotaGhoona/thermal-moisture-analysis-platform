using DataFrames
using CSV

mutable struct Network_configuration_VENT
    RM::Int # 室の数（外気含めず）
    BC::Int # 枝数
    IC::Array{Int} # インシデンス行列
    IDD::Array{Int} # ニュートン法に使用する行列
    DATE::Float64 # 日付
    Network_configuration_VENT() = new()
end

mutable struct Room_condtion_VENT
    TEM::Float64 # 絶対温度[K]
    VOL::Float64 # 室体積[m^3] 0からRMまでの配列
    RAW::Float64 # 空気の密度[kg/m3]
    P::Float64   # 床面圧力[Pa]
    PS::Float64  # 起圧力[Pa]
    DWW::Float64 # 室への正味の流量
    DDP::Float64 # 室圧力偏差[Pa]
    Room_condtion_VENT() = new()
end

mutable struct Outdoor_condtion_VENT
    TEM::Float64 # 絶対温度[K] 0からRMまでの配列
    VOL::Float64 # 室体積[m^3] 0からRMまでの配列
    RAW::Float64 # 空気の密度[kg/m3]
    WIN_DIR::Float64 #風向き
    WIN_V::Float64   #風速[m/s]
    Outdoor_condtion_VENT() = new()
end

mutable struct Opening_condition
    NON::Float64 #枝番号
    IP::Float64  # 上流側室番号
    IM::Float64  # 下流側室番号
    ION::Float64 # 開口向き
    D::Float64   # 開口状態
    B::Float64   # 開口の幅
    S::Float64   # 縦隙間本数：通常２、引き違い３
    HU::Float64  # 開口の上側の床面高さ
    HD::Float64  # 開口の下側の床面高さ
    HS::Float64  # 床面差(開口を挟んだ室同士の床面の高さの差)
    M::Float64   # n：隙間特性値
    MM::Float64  # nu：開口上端下端隙間特性値
    SV::Float64  # QV：縦開口圧力差9.8Paの時の容積流量（縦開口面積との記載もあり※要注意）
    SH::Float64  # QV：開口上端下端圧力差9.8Paの時の容積流量（横開口面積との記載もあり※要注意）
    WC::Float64  # 風圧係数（開口の向きによって決定）
    OPEN_DIR::Float64 # 開口の向き（方位）
    V_SM::Float64    # ？？？とりあえず1 同様枝数？
    RAW2_IP::Float64 # 枝上流側密度
    RAW2_IM::Float64 # 枝下流側密度
    PS::Float64      # 起圧力差
    DP::Float64      # 部屋の圧力差（どこで定義されている？⇒メインプログラムで計算）
    DRAW::Float64    # 枝上流の密度-下流の密度
    QV::Float64      # 縦方向開口1Pa時[m^3/s]を長辺長さで割ったもの[m^2/s]
    QH::Float64      # 横方向開口の1Pa時[m^3/s]を長辺長さで割ったもの[m^2/s]
    Opening_condition() = new()
end

function cal_datin()
        
    # 入力ファイルの読み込み
    vent_open_condition = CSV.File("./input_data/vent_open_condition.csv", header = 4) |> DataFrame;
    
    # 空の開口条件データを作成
    voc_data = [ Opening_condition() for i = 1 : length(vent_open_condition.BC) ]
        
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(vent_open_condition.BC)
        voc_data[i].NON = vent_open_condition.BC[i]
        voc_data[i].IP  = vent_open_condition.IP[i]
        voc_data[i].IM  = vent_open_condition.IM[i]
        voc_data[i].ION = vent_open_condition.ION[i]
        voc_data[i].D   = vent_open_condition.D[i]
        voc_data[i].B   = vent_open_condition.B[i]
        voc_data[i].S   = vent_open_condition.S[i]
        voc_data[i].HU  = vent_open_condition.HU[i]
        voc_data[i].HD  = vent_open_condition.HD[i]
        voc_data[i].HS  = vent_open_condition.HS[i]
        voc_data[i].M   = vent_open_condition.M[i]
        voc_data[i].MM  = vent_open_condition.MM[i]
        voc_data[i].SV  = vent_open_condition.QOO[i]
        #voc_data[i].QOO = vent_open_condition.QOO[i]
        voc_data[i].SH  = vent_open_condition.QU[i]
        #voc_data[i].QU  = vent_open_condition.QU[i]
        voc_data[i].OPEN_DIR  = vent_open_condition.WC[i]
        #voc_data[i].WC  = vent_open_condition.WC[i]
        voc_data[i].V_SM= vent_open_condition.V_SM[i]
    end
    
    return voc_data
end
function cal_qo_v1( Qo, p, n )
    return Qo * p ^ (1/n) 
end

function cal_qo_v2( alpha, A, rho, p )
    return alpha * A * ( 2.0 / rho * p ) ^ (1/2)
end

cal_QOO( QOO, G, M ) = QOO * (1/G) ^ (1/M) / 3600.0
cal_QU( QU, G, M )   = QU * (1/G) ^ (1/M) / 3600.0

cal_QV(AI, SV, RAW) = AI * SV / 10.0^3 * ( 2.0 / RAW )^( 1/2 )
cal_QH(AI, SH, RAW) = AI * SH / 10.0^3 * ( 2.0 / RAW )^( 1/2 )


function cal_ic( NC::Network_configuration_VENT, OC::Array{Opening_condition, 1} )
    # RM+1であるので外気を含めたインシデンス行列を求めている。
    NC.IC = zeros( Int, NC.RM+1, NC.BC )
    for i = 1 : NC.BC
        NC.IC[ OC[i].IP, i ] =  1
        NC.IC[ OC[i].IM, i ] = -1
    end
    return NC
end

function cal_ic(; NC, OC ); return cal_ic( NC, OC ); end

function cal_assum_floor_p( 
        NC::Network_configuration_VENT,
        Room::Array{Room_condtion_VENT, 1},
        );
    NN   = 50
    XMOD = 10.0e+6
    XMOD1= XMOD + 1.0
    X    = NN

    for i = 1 : NC.RM
        Room[i].P = mod( X, XMOD1 ) / XMOD
        X    = 15.0 * X
        if X > 1.0e+20 
            X = X / 1.0e+14
        end
    end
    Room[NC.RM+1].P = 0.0
    
    return Room
end

cal_assum_floor_p( NC::Network_configuration_VENT ) = cal_assum_floor_p( NC.RM )
cal_assum_floor_p(;NC::Network_configuration_VENT ) = cal_assum_floor_p( NC.RM )

module zone_Ps

# 各節点における密度
cal_RAW2( TEM2 ) = 353.25 / TEM2
# 枝間の密度差
cal_DRAW( RAW2_IP, RAW2_IM ) = RAW2_IP - RAW2_IM
# WSは不明。WS自体が0なので一旦無視する。Wind Speed？
cal_WS( RAW2, WS ) = RAW2 * WS / 3600.0
cal_PS( RAW2_IP, RAW2_RM, HS, G ) =  - ( RAW2_IP - RAW2_RM ) * HS * G

end


# 起圧力PSの計算（開口の床面における外気との圧力差）、床高さと密度差による圧力ー外部風による圧力
function cal_PS( NC::Network_configuration_VENT, 
        Room::Array{Room_condtion_VENT, 1}, 
        Outdoor::Outdoor_condtion_VENT, 
        OC::Array{Opening_condition, 1} )
    
    cal_RAW( TEM ) = 353.25 / TEM
    G = 9.80665
    
    # 全ての枝について気圧力を計算
    for  i = 1 : NC.BC
        # 床面差で場合分け
        if OC[i].HS < 0
            # 修正2021/03/16 高取
            if Int(OC[i].IP) ≠ 0
                OC[i].PS = - ( cal_RAW( Room[Int(OC[i].IP)].TEM ) - cal_RAW(Outdoor.TEM) ) * OC[i].HS * G
            else
                OC[i].PS = 0
            end
        
        # 床の高さが地表高さよりも高い時
        elseif OC[i].HS > 0
            if Int(OC[i].IM) ≠ 0
                OC[i].PS = - ( cal_RAW( Room[Int(OC[i].IM)].TEM ) - cal_RAW(Outdoor.TEM) ) * OC[i].HS * G
            else
                OC[i].PS = 0
            end
                
        # 床の高さが等しいとき
        elseif OC[i].HS == 0
            OC[i].PS = 0.0
        end
        
        # 風による圧力を引いておく。（下流側なので引いておかないといけない）
        OC[i].PS = OC[i].PS - OC[i].WC * cal_RAW(Outdoor.TEM) * Outdoor.WIN_V ^ 2.0 / 2.0 
    end
    
    return OC
end

function cal_WC( OC::Opening_condition )
    if     OC.OPEN_DIR == 0; OC.WC = 0.75
    elseif OC.OPEN_DIR == 1; OC.WC = 0.75
    elseif OC.OPEN_DIR == 2; OC.WC = 0.4
    elseif OC.OPEN_DIR == 3; OC.WC = 0.15
    elseif OC.OPEN_DIR == 4; OC.WC =-0.4
    elseif OC.OPEN_DIR == 5; OC.WC =-0.5
    elseif OC.OPEN_DIR == 6; OC.WC =-0.5
    elseif OC.OPEN_DIR == 7; OC.WC =-0.5
    elseif OC.OPEN_DIR == 8; OC.WC =-0.5
    elseif OC.OPEN_DIR == 9; OC.WC =-0.5
    elseif OC.OPEN_DIR ==10; OC.WC =-0.5
    elseif OC.OPEN_DIR ==11; OC.WC =-0.5
    elseif OC.OPEN_DIR ==12; OC.WC =-0.4
    elseif OC.OPEN_DIR ==13; OC.WC = 0.15
    elseif OC.OPEN_DIR ==14; OC.WC = 0.4
    elseif OC.OPEN_DIR ==15; OC.WC = 0.75
    else OC.WC = 0.0
    end
    return OC
end

# 配列での入力の場合
function cal_WC( OC::Array{Opening_condition, 1} )
    [ cal_WC(OC[i]) for i = 1:length(OC) ]
    return OC
end

# 法隆寺ver 水平から反時計回りに10°傾いていることを考慮
function cal_WC_HRJ( OC::Opening_condition )
    if     OC.OPEN_DIR == 0; OC.WC = 0.75
    elseif OC.OPEN_DIR == 1; OC.WC = 0.75
    elseif OC.OPEN_DIR == 2; OC.WC = 0.7
    elseif OC.OPEN_DIR == 3; OC.WC = 0.3
    elseif OC.OPEN_DIR == 4; OC.WC =-0.1
    elseif OC.OPEN_DIR == 5; OC.WC =-0.4
    elseif OC.OPEN_DIR == 6; OC.WC =-0.5
    elseif OC.OPEN_DIR == 7; OC.WC =-0.5
    elseif OC.OPEN_DIR == 8; OC.WC =-0.5
    elseif OC.OPEN_DIR == 9; OC.WC =-0.5
    elseif OC.OPEN_DIR ==10; OC.WC =-0.5
    elseif OC.OPEN_DIR ==11; OC.WC =-0.5
    elseif OC.OPEN_DIR ==12; OC.WC =-0.2
    elseif OC.OPEN_DIR ==13; OC.WC = 0.25
    elseif OC.OPEN_DIR ==14; OC.WC = 0.6
    elseif OC.OPEN_DIR ==15; OC.WC = 0.75
    else OC.WC = 0.0
    end
    return OC
end

function cal_flux_ventilation_by_OC(OC::Opening_condition)
    return cal_flux_ventilation( 
        ION = OC.ION, D  = OC.D, 
        A   = OC.A,   B  = OC.B,  S  = OC.S, 
        H   = OC.H,   HU = OC.HU, HD = OC.HD, 
        M   = OC.M,   MM = OC.MM, 
        RAW2_IP = OC.RAW2_IP, RAW2_IM = OC.RAW2_IM, 
        DP  = OC.DP, DRAW= OC.DRAW, 
        QV  = OC.QV, QH  = OC.QH )
end

# 配列での入力の場合
function cal_flux_ventilation_by_OC( OC::Array{Opening_condition, 1} )
    flux = [ cal_flux_ventilation_by_OC(OC[i]) for i = 1:length(OC) ]
    return flux
end

# 室への正味流量
function cal_DWW( 
        NC::Network_configuration_VENT, 
        Room::Array{Room_condtion_VENT, 1}, 
        OC::Array{Opening_condition, 1} )
    
    for i = 1 : NC.RM
        Room[i].DWW = 0.0
        for j = 1 : NC.BC
            Room[i].DWW = Room[i].DWW + NC.IC[i,j] * OC.W[j]
        end
    end
    return Room
end

function cal_IDD(
        NC::Network_configuration_VENT,
        OC::Array{Opening_condition, 1} );
    
    IDD = zeros(Float64, NC.RM, NC.RM)
    # IP：壁に対しての上流室、IM：壁に対しての下流室
    for i = 1 : NC.BC
        IDD[ OC[i].IP, OC[i].IP ] = IDD[OC[i].IP, OC[i].IP] + OC[i].DW #([I][∂f/∂p][I'])
        IDD[ OC[i].IP, OC[i].IM ] = IDD[OC[i].IP, OC[i].IM] - OC[i].DW
        IDD[ OC[i].IM, OC[i].IP ] = IDD[OC[i].IP, OC[i].IM]
        IDD[ OC[i].IM, OC[i].IM ] = IDD[OC[i].IM, OC[i].IM] + OC[i].DW
    end
    NC.IDD = IDD
    return NC
end    

function cal_GAUSE( 
        NC::Network_configuration_VENT,
        Room::Array{Room_condtion_VENT, 1} );
    
    # NCはRMまでしかないから計算できないのでは？
    for i = 1 : NC.RM
        NC.IDD[ i, NC.RM+1 ] = Room.DWW[I]
    end
    
    for IK = 1 : NC.RM
        PIVOT = NC.IDD[IK,IK]
        for IJ = IK : NC.RM + 1
            NC.IDD[IK,IJ] = NC.IDD[IK,IJ] / PIVOT
        end
        
        for I = 1 : NC.RM
            if I == IK
                continue # I == IKならばループの最初に戻る。
            end
            
            CIK = NC.IDD[I,IK] # CIKこの式はcontinueの前では...？
            
            for IJ = IK : RM+1
                NC.IDD[I,IJ] = NC.IDD[I,IJ] - CIK * NC.IDD[IK,IJ]
            end
        end
    end

    for i = 1 : RM
        Room.DDP[i] = NC.IDD[ i, RM+1 ]
    end

    return Room
end
