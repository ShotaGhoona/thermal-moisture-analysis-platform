include("room.jl")

# 隙間・開口の構造
Base.@kwdef mutable struct Opening
    # 入力情報
    BC::Int     = 1     # 枝番号
    IP::Int     = 1     # 上流側室番号
    IM::Int     = 1     # 下流側室番号
    Type::String    = "NaN"# 計算タイプ（gap：隙間、opening：開口、constant：換気量入力、fan：換気ファンなど）
    Qup::Float64    = 0.0  # 上流室方向流量[m3/s] 
    Qdw::Float64    = 0.0  # 下流室方向流量[m3/s] 
    ION::String     = "NaN"# 壁の向き（VT:鉛直壁の開口　HN：天井開口）
    DIR_IP::String  = "NaN"   # 上流側開口方位
    DIR_IM::String  = "NaN"   # 下流側開口方位
    B::Float64  = 0.0   # 開口の幅[m]
    S::Float64  = 2     # 縦隙間本数(扉なら２, 引き違いなら３)
    H::Float64  = 0.0   # 開口高さ（HU-HD）計算により求めるため入力値としては不要
    HU::Float64 = 0.0   # 開口高さ（開口上側）[m]
    HD::Float64 = 0.0   # 開口高さ（開口下側）[m]
    #HS::Float64 = 0.0   # 床面差[m]
    M::Float64  = 0.0   # 隙間特性値
    MM::Float64 = 0.0   # 隙間特性値(開口下端)
    α::Float64  = 0.0   # 流量係数
    A::Float64  = 0.0   # 開口面積
    SV::Float64 = 0.0   # 縦開口面積
    SH::Float64 = 0.0   # 横開口面積
    QOO::Float64= 0.0   # 容積流量(9.8Pa時)
    QU::Float64 = 0.0   # 開口下端容積流量(9.8Pa時)
    QV::Float64= 0.0    # 縦方向開口流量(9.8Pa時)
    QH::Float64 = 0.0   # 横方向開口流量(9.8Pa時)
    WC_IP::Float64  = 0.0   # 上流側風圧係数
    WC_IM::Float64  = 0.0   # 下流側風圧係数
    V_SM::Int   = 0.0       # 同様枝数

    # 計算情報
    room_IP::Union{Room, Climate}   = Room() # 上流側室情報
    room_IM::Union{Room, Climate}   = Room() # 下流側室情報
    dP::Float64 = 0.0   # 圧力差
    flux::Dict{String, Float64} = Dict( "W"     => 0.0, # 開口の正味流量
                                        "WU"    => 0.0, # 開口の正方向流量
                                        "WD"    => 0.0, # 開口の負方向流量
                                        "DW"    => 0.0, # 開口の正味流量の圧力差微分
                                        "DWU"   => 0.0, # 開口の正方向流量の圧力差微分
                                        "DWD"   => 0.0) # 開口の負方向量の圧力差微分

end

########################################
# 出力用の関数
IP(opening::Opening)        = opening.IP
IM(opening::Opening)        = opening.IM
room_IP(opening::Opening)   = opening.room_IP
room_IM(opening::Opening)   = opening.room_IM
WC_IP(opening::Opening)     = opening.WC_IP
WC_IM(opening::Opening)     = opening.WC_IM
DIR_IP(opening::Opening)    = opening.DIR_IP
DIR_IM(opening::Opening)    = opening.DIR_IM
Type(opening::Opening)      = opening.Type
Qup(opening::Opening)       = opening.Qup
Qdw(opening::Opening)       = opening.Qdw


function input_opening_data(file_name::String, header::Int = 3)
    
    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./")
        file_directory = file_name
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv")
        file_directory = "../input_data/building_network_model/"*string(file_name)
    # ファイル名のみが書かれている場合、
    else
        file_directory = "../input_data/building_network_model/"*string(file_name)*".csv"        
    end
    
    input_data = CSV.File( file_directory, header = header) |> DataFrame
    
    # 空の壁データを作成
    data = [ Opening() for i = 1 : length(input_data.BC) ]
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.BC)
        #####################################
        # 壁の基本情報の入力
        data[i].BC   = input_data.BC[i]
        data[i].IP   = input_data.IP[i]
        data[i].IM   = input_data.IM[i]
        data[i].Type = input_data.Type[i]
        data[i].Qup  = input_data.Qup[i]
        data[i].Qdw  = input_data.Qdw[i]
        data[i].ION  = input_data.ION[i]
        try data[i].DIR_IP  = input_data.DIR_IP[i] catch end
        try data[i].DIR_IM  = input_data.DIR_IM[i] catch end
        data[i].B    = input_data.B[i]
        data[i].S    = input_data.S[i]
        data[i].HU   = input_data.HU[i]
        data[i].HD   = input_data.HD[i]
        try data[i].HS   = input_data.HS[i] catch end
        data[i].M    = input_data.M[i]
        data[i].MM   = input_data.MM[i]
        data[i].α    = input_data.alpha[i]
        data[i].A    = input_data.A[i]
        data[i].SV   = input_data.SV[i]
        data[i].SH   = input_data.SH[i]
        try data[i].QOO  = input_data.QOO[i] catch end
        try data[i].QU   = input_data.QU[i] catch end
        try data[i].QV  = input_data.QV[i] catch end
        try data[i].QH   = input_data.QH[i] catch end
        try data[i].WC   = input_data.WC[i] catch end
        try data[i].WC_IP   = input_data.WC_IP[i]  catch end
        try data[i].WC_IM   = input_data.WC_IM[i]  catch end
        data[i].V_SM = input_data.V_SM[i]
    
        # 壁の方位は？IP, IMを用いて方位を定義すべき？
    end
    return data
end

input_opening_data(;file_name::String, header::Int = 3) = input_opening_data(file_name, header)