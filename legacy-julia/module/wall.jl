include("cell.jl")
include("climate.jl")
include("boundary_condition.jl")

# 壁の構造
Base.@kwdef mutable struct Wall
    num::Int    = 1     # 壁番号
    name::String= "NoName"
    IP::Int     = 1     # 上流側室番号：BC_IPで室が定義できれば不要
    IM::Int     = 1     # 下流側室番号：BC_IMで室が定義できれば不要
    ION::Float64= 0.0   # 壁の向き[°]（0：水平　90：垂直　その他：傾斜角の値を入力）
    thickness::Float64  = 0.0       # 壁の厚み
    area::Float64       = 0.0       # 壁の面積
    K::Float64          = 0.0       # 熱貫流率
    Kp::Float64         = 0.0       # 湿気貫流率

    # 構造体を用いた値の保存
    cell::Array{Cell, 1}    = [Cell()]  # 壁を構成するセル（1次元の配列）
    BC_IP::Union{BC_Dirichlet, BC_Neumann, BC_Robin}    = BC_Robin()  # 上流側の境界条件
    BC_IM::Union{BC_Dirichlet, BC_Neumann, BC_Robin}    = BC_Robin()  # 下流側の境界条件
    target_model::Array     = []        # 解析対象モデル
end

########################################
# 出力用の関数
num(wall::Wall)     = wall.num
name(wall::Wall)    = wall.name
temp_IP(wall::Wall) = temp(wall.cell[0])
temp_IM(wall::Wall) = temp(wall.cell[end])
area(wall::Wall)    = wall.area
rh_IP(wall::Wall)   = rh(wall.cell[0])
rh_IM(wall::Wall)   = rh(wall.cell[end])
pv_IP(wall::Wall)   = pv(wall.cell[0])
pv_IM(wall::Wall)   = pv(wall.cell[end])

########################################
# 入力用の関数
function set_cell(wall::Wall, cell::Array{Cell, 1}) 
    wall.cell    = cells end
function set_BC_IP(wall::Wall, BC_IP::Union{BC_Dirichlet, BC_Neumann, BC_Robin}) 
    wall.BC_IP   = BC_IP end
function set_BC_IM(wall::Wall, BC_IM::Union{BC_Dirichlet, BC_Neumann, BC_Robin}) 
    wall.BC_IM   = BC_IM end
function set_air_IP(wall::Wall, air_IP::Air) 
    wall.BC_IP.air   = air_IP end
function set_air_IM(wall::Wall, air_IM::Air) 
    wall.BC_IM.air   = air_IM end

function input_wall_data(file_name::String, header::Int = 3)
    
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

    # 入力ファイルの読み込み
    input_data = CSV.File( file_directory, header = header) |> DataFrame
    
    # 空の壁データを作成
    data = [ Wall() for i = 1 : length(input_data.num) ]
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.num)
        #####################################
        # 壁の基本情報の入力
        data[i].num  = input_data.num[i]
        data[i].IP   = input_data.IP[i]
        data[i].IM   = input_data.IM[i]
        data[i].ION  = input_data.ION[i]
        data[i].thickness  = input_data.thickness[i]
        data[i].area = input_data.area[i]

        #####################################
        # 壁の作成
        # 自動分割の場合
        if string(input_data.Type[i]) == string(0)
            wall = [ Cell() for j = 1 : input_data.div_num[i] ]
            for j = 1 : input_data.div_num[i]
                wall[j].i    = [ j, 1, 1 ]
                wall[j].temp = input_data.temp[i] + 273.15
                wall[j].miu  = convertRH2Miu( temp = wall[j].temp, rh = input_data.rh[i] / 100 )
                wall[j].material_name = input_data.material_name[i]
                # セル幅の設定
                if j == 1
                    wall[j].dx = data[i].thickness / (input_data.div_num[i] - 1 ) / 2
                    wall[j].dx2= 0.0
                elseif j == input_data.div_num[i]
                    wall[j].dx = data[i].thickness / (input_data.div_num[i] - 1 ) / 2
                    wall[j].dx2= wall[j].dx
                else
                    wall[j].dx = data[i].thickness / (input_data.div_num[i]-1)
                    wall[j].dx2= wall[j].dx / 2
                end
            end
            # wallの入力
            data[i].cell = wall

        # 手動分割の場合
        else
            data[i].name  = input_data.Type[i]
            cell_data = []
            try 
                cell_data = CSV.File( "./input_data/building_network_model/cell_data/"*string(input_data.Type[i])*".csv", header = 3) |> DataFrame
            catch 
                cell_data = CSV.File( "../input_data/building_network_model/cell_data/"*string(input_data.Type[i])*".csv", header = 3) |> DataFrame
            end
            wall = [ Cell() for j = 1 : length(cell_data.i) ]
            for j = 1 : length(cell_data.i)
                # Cellに対する条件入力
                wall[j].i               = [ cell_data.i[j], 1, 1 ]
                wall[j].dx              = cell_data.dx[j]
                wall[j].temp            = cell_data.temp[j] + 273.15
                wall[j].material_name   = cell_data.material_name[j]
                # 水分状態の入力
                try wall[j].miu = cell_data.miu[j]
                catch
                    try 
                        wall[j].miu = convertRH2Miu( temp = cell_data.temp[j] + 273.15, rh = cell_data.rh[j] / 100 ) # vapour.jl内の関数を流用
                    catch 
                        wall[j].miu = get_miu_by_phi(wall[j], wall[j].material_name) # property_conversion.jl内の関数を流用
                    end
                end
                # 質点からの距離dx2の設定
                try 
                    wall[j].dx2 = cell_data.dx2[j]
                catch 
                    if j == 1 || j == length(cell_data.i)
                        wall[j].dx2= wall[j].dx
                    else 
                        wall[j].dx2= wall[j].dx / 2
                    end
                end
            # wallの入力
            data[i].cell = wall
            end
        end

        #####################################
        # 境界条件の入力
        # 上流側境界条件：0側
        if  data[i].IP  == 0        # Dirichlet境界条件
            set_BC_IP(data[i], BC_Dirichlet(cell = deepcopy(wall[1])))
        elseif  data[i].IP  == -1   # Neumann境界条件
            set_BC_IP(data[i], BC_Neumann())
            data[i].BC_IP.q         = input_data.q[i]
            data[i].BC_IP.jv        = input_data.jv[i]
            data[i].BC_IP.jl        = input_data.jl[i]
        else
            data[i].BC_IP.cell      = data[i].cell[1]
            data[i].BC_IP.θ["a"]    = direction[input_data.dir_IP[i]] - 180.0 # 面する方角と相対する方角（airに対するcell側の方向）
            data[i].BC_IP.θ["e"]    = input_data.ION[i]
            data[i].BC_IP.ar        = input_data.ar_IP[i]
            data[i].BC_IP.er        = input_data.er_IP[i]
            data[i].BC_IP.alphac    = input_data.alphac_IP[i]
            data[i].BC_IP.alphar    = input_data.alphar_IP[i]
            data[i].BC_IP.alpha     = data[i].BC_IP.alphac + data[i].BC_IP.alphar
            # aldmが欠損値の場合、lewis関係から算出する
            data[i].BC_IP.aldm   = if ismissing(input_data.aldm_IP[i]); Lewis_relation.cal_aldm( temp = 293.15, alpha = data[i].BC_IP.alphac ); else; input_data.aldm_IP[i]; end
        end

        # 下流側境界条件：end側
        if  data[i].IM == 0 # Dirichlet境界条件
            set_BC_IM(data[i], BC_Dirichlet(cell = deepcopy(wall[end])))
        elseif  data[i].IM  == -1   # Neumann境界条件
            set_BC_IM(data[i], BC_Neumann())
            data[i].BC_IM.q         = input_data.q[i]
            data[i].BC_IM.jv        = input_data.jv[i]
            data[i].BC_IM.jl        = input_data.jl[i]
        else
            if data[i].IM  == 0 
                data[i].BC_IM.θ["a"]    = direction[input_data.dir_IM[i]] # ※地盤側境界の場合、特別な操作とする。
            else
                data[i].BC_IM.θ["a"]    = direction[input_data.dir_IM[i]] - 180.0 # 面する方角と相対する方角（airに対するcell側の方向）
            end
            data[i].BC_IM.cell      = data[i].cell[length(data[i].cell)]
            data[i].BC_IM.θ["e"]    = 180.0 - input_data.ION[i]
            data[i].BC_IM.ar        = input_data.ar_IM[i]
            data[i].BC_IM.er        = input_data.er_IM[i]
            data[i].BC_IM.alphac    = input_data.alphac_IM[i]
            data[i].BC_IM.alphar    = input_data.alphar_IM[i]
            data[i].BC_IM.alpha     = data[i].BC_IM.alphac + data[i].BC_IM.alphar
            data[i].BC_IM.aldm      = if ismissing(input_data.aldm_IM[i]); Lewis_relation.cal_aldm( temp = 293.15, alpha = data[i].BC_IM.alphac ); else; input_data.aldm_IM[i]; end
        end

        data[i].target_model = vcat(data[i].BC_IP, data[i].cell, data[i].BC_IM)

    end
    return data
end