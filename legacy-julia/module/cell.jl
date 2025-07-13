# Cell構造体の設定
Base.@kwdef mutable struct Cell
    i::Array{Int, 1}      = [   1,   1,   1 ] #= 位置番号 =#
    xyz::Array{Float64,1} = [ 0.0, 0.0, 0.0 ] #= 位置座標 =#
    dx::Float64      = 1.0   #= 幅x   =#
    dy::Float64      = 1.0   #= 高さy =#
    dz::Float64      = 1.0   #= 奥行z =#
    dx2::Float64     = 1.0   # 質点からセル端までの距離（一般的にはdxの半分）
    dy2::Float64     = 1.0   
    dz2::Float64     = 1.0   
    temp::Float64    = 0.0   #= 温度 =#
    miu::Float64     = 0.0   #= 水分化学ポテンシャルの毛管圧成分（いわゆる水分化学ポテンシャル）=#
    rh::Float64      = 0.0   #= 相対湿度 =#
    pv::Float64      = 0.0   #= 水蒸気圧 =#
    phi::Float64     = 0.0   #= 含水率 =#
    p_atm::Float64   = 101325.0 #= 空気の全圧（≒大気圧） =#
    material_name::String   = "NoName"  #= 材料名 =#
    Q::Array{Array{Float64, 1}, 1}     = [[0.0,0.0,0.0],[0.0,0.0,0.0]] # Cellに流入・流出する熱流量    （［x,y,z（流入）］,［x,y,z（流出）］）
    Jv::Array{Array{Float64, 1}, 1}    = [[0.0,0.0,0.0],[0.0,0.0,0.0]] # Cellに流入・流出する水蒸気流量（［x,y,z（流入）］,［x,y,z（流出）］）
    Jl::Array{Array{Float64, 1}, 1}    = [[0.0,0.0,0.0],[0.0,0.0,0.0]] # Cellに流入・流出する液水流量  （［x,y,z（流入）］,［x,y,z（流出）］）
end 

include("./property_conversion.jl")
include("./function/vapour.jl")

pc = property_conversion
wp = water_property

# Cell構造体を用いた各種パラメータの読み込み方法
# 構造体パラメーター
i(state::Cell)   = state.i
dx(state::Cell)  = state.dx
dx2(state::Cell) = state.dx2 # 流量計算式と合わせ要注意
dy(state::Cell)  = state.dy
dy2(state::Cell) = state.dy2 # 流量計算式と合わせ要注意
dz(state::Cell)  = state.dz
dz2(state::Cell) = state.dz2 # 流量計算式と合わせ要注意
vol(state::Cell) = state.dx * state.dy * state.dz

# 熱水分＋塩状態量
temp(state::Cell)= state.temp
miu(state::Cell) = state.miu
rh(state::Cell)  = convertMiu2RH( temp = state.temp, miu = state.miu )
pv(state::Cell)  = convertMiu2Pv( temp = state.temp, miu = state.miu )
patm(state::Cell)= state.p_atm
ah(state::Cell)  = convertPv2AH( patm = state.p_atm, pv = pv(state) )
phi(state::Cell) = property_conversion.get_phi( state, state.material_name )
dphi(state::Cell)= property_conversion.get_dphi(state, state.material_name )

#####################################
material_name(state::Cell)  =   state.material_name

# 材料熱物性値　※　材料物性値のファイルに含水率ベースのものがある場合注意
psi(state::Cell)  =  pc.get_psi( state.material_name )
C(state::Cell)    =  pc.get_C( state.material_name )
row(state::Cell)  =  pc.get_row( state.material_name )
crow(state::Cell) =  C(state) * row(state) + wp.Cr * wp.row * phi(state)

# 移動係数
lam(state::Cell)  =  pc.get_lam( state, state.material_name )
dw(state::Cell)   =  try; pc.get_dw( state, state.material_name ); catch; pc.get_dw_by_ldml( state, state.material_name ); end
dp(state::Cell)   =  try; pc.get_dp( state, state.material_name ); catch; pc.get_dp_by_ldmg( state, state.material_name ); end
ldml(state::Cell) =  try; pc.get_ldml( state, state.material_name ); catch; pc.get_ldml_by_dw( state, state.material_name ); end
ldmg(state::Cell) =  try; pc.get_ldmg( state, state.material_name ); catch; pc.get_ldmg_by_dp( state, state.material_name ); end
ldtg(state::Cell) =  try; pc.get_ldtg( state, state.material_name ); catch; pc.get_ldtg_by_dp( state, state.material_name ); end
# 熱抵抗
Rthx(state::Cell) =  dx(state)/lam(state)
Rthy(state::Cell) =  dy(state)/lam(state)
Rthz(state::Cell) =  dz(state)/lam(state)
# 湿気抵抗
Rdpx(state::Cell) =  dx(state)/dp(state)
Rdpy(state::Cell) =  dy(state)/dp(state)
Rdpz(state::Cell) =  dz(state)/dp(state)

# 各Cellの質点から境界面までの抵抗
dlamx_mns(cell::Cell)  = dx2(cell) / lam(cell)
dlamx_pls(cell::Cell)  = (dx(cell)-dx2(cell)) / lam(cell)
dldtgx_mns(cell::Cell) = dx2(cell) / ldtg(cell)
dldtgx_pls(cell::Cell) = (dx(cell)-dx2(cell)) / ldtg(cell)
dldmgx_mns(cell::Cell) = dx2(cell) / ldmg(cell)
dldmgx_pls(cell::Cell) = (dx(cell)-dx2(cell)) / ldmg(cell)
dldmlx_mns(cell::Cell)  = dx2(cell) / ldml(cell)
dldmlx_pls(cell::Cell)  = (dx(cell)-dx2(cell)) / ldml(cell)

using CSV
using DataFrames

function input_cell_data(file_name::String, header_num::Int = 3)
    
    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./"); file_path = file_name
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv"); file_path = "./input_data/1D_model/"*string(file_name)
    # ファイル名のみが書かれている場合、
    else; file_path = "./input_data/1D_model/"*string(file_name)*".csv"        
    end
    input_data = CSV.File( file_path, header = header_num) |> DataFrame

    # 空の開口条件データを作成
    target_model = [if input_data.type[i] == "BC_Neumann"; BC_Neumann() 
                    elseif input_data.type[i] ==  "BC_Robin"; BC_Robin() 
                    elseif input_data.type[i] ==  "Cell"    ; Cell() end
                    for i = 1 : length(input_data.type) ] 
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.i)
        # Cellに対する条件入力
        if input_data.type[i]    ==  "Cell"
            target_model[i].i    = [ input_data.i[i], 1, 1 ]
            target_model[i].dx   = input_data.dx[i]
            target_model[i].temp = input_data.temp[i] + 273.15
            target_model[i].material_name = input_data.name[i]
            # 水分状態の入力
            try target_model[i].miu = input_data.miu[i]
            catch
                try 
                    target_model[i].miu = convertRH2Miu( temp = input_data.temp[i] + 273.15, rh = input_data.rh[i] / 100 ) # vapour.jl内の関数を流用
                catch 
                    target_model[i].miu = get_miu_by_phi(target_model[i], target_model[i].material_name) # property_conversion.jl内の関数を流用
                end
            end
            # 質点からの距離dx2の設定
            try 
                target_model[i].dx2 = input_data.dx2[i]
            catch 
                if i == 1 || i == length(input_data.i); target_model[i].dx2= target_model[i].dx
                else target_model[i].dx2= target_model[i].dx / 2end
            end

        # 第三種境界条件
        elseif input_data.type[i] == "BC_Robin"
            target_model[i].air.name = input_data.name[i]
            target_model[i].air.vol  = input_data.dx[i]
            target_model[i].air.temp     = input_data.temp[i] + 273.15
            # 水分状態の入力
            try 
                target_model[i].air.rh = input_data.rh[i] / 100.0
            catch 
                target_model[i].air.rh  = convertMiu2RH( temp = input_data.temp[i] + 273.15, miu = input_data.miu[i] )
            end
            # 伝達係数の入力
            # 熱伝達率
            try 
                target_model[i].alphac = input_data.alphac[i]
                target_model[i].alphar = input_data.alphar[i]
                target_model[i].alpha  = input_data.alphac[i] + input_data.alphar[i]
            catch
                target_model[i].alpha  = input_data.alpha[i]
            end
            # 湿気伝達率
            try 
                if input_data.aldm[i] == 0; target_model[i].aldm = aldm_by_alphac(target_model[i])
                else; target_model[i].aldm = input_data.aldm[i]
                end
            catch
                target_model[i].aldm = aldm_by_alphac(target_model[i])
            end
        end
        
    end
    return target_model
end


# 読み込み例
# input_cell_data("../input_data/wall_data/cell_data/wall1.csv")
# input_cell_data("../input_data/1D_model/WG_benchmark_stage0.csv")

#########################################################
                ### 以下便利ツール ###
#########################################################

# Cell構造体を構築する関数の設定
function cell_construction(; i::Int = 0, 
        dx::Float64, dy::Float64=1.0, dz::Float64=1.0,
        dx2::Float64=0.0, dy2::Float64=0.0, dz2::Float64=0.0,
        temp::Float64, miu::Float64 = 0.0, rh::Float64=0.0, phi::Float64=0.0,
        material_name::String )
    cell = Cell()
    cell.i  = i
    cell.dx = dx
    cell.dy = dy
    cell.dz = dz
    cell.temp= temp
    cell.material_name = material_name
    
    if miu == 0.0
        if phi == 0.0; cell.miu = convertRH2Miu( temp = temp, rh = rh )
        elseif rh == 0.0; cell.miu = pc.get_miu_by_phi( phi, cell.material_name ); end
    else; cell.miu = miu
    end
    
    # 質点からセル端までの距離
    if dx2 == 0.0; cell.dx2 = cell.dx / 2.0; else; cell.dx2 = dx2; end
    if dy2 == 0.0; cell.dy2 = cell.dy / 2.0; else; cell.dy2 = dy2; end
    if dz2 == 0.0; cell.dz2 = cell.dz / 2.0; else; cell.dz2 = dz2; end
    
    return cell
end

#############################
# 壁を構築する関数
function wall_construction(; len::Float64, partitions::Int, temp_init::Float64, 
        miu_init::Float64 = 0.0, rh_init::Float64=0.0, phi_init::Float64=0.0,
        material_name::String )
    # 境界面ではcellの幅を半分とし、境界面ではdx=dx2とする　→　分割数に注意（例：3mmの壁は3ではなく4で分割すること）
    dx = [ if i == 1 || i == partitions; len / (partitions-1) / 2; else; len / (partitions-1) end for i = 1 : partitions ]
    dx2= [ if i == 1 || i == partitions; dx[i]; else; dx[i]/2 end for i = 1 : partitions ]
    # 暫定的に1次元のみとしておく。2次元以降については後ほど実装
    return [ cell_construction( i = i, dx=dx[i], dx2=dx2[i], temp=temp_init, miu=miu_init, rh=rh_init, phi=phi_init, material_name = material_name ) for i = 1:partitions ]
end

# 熱収支式
function cal_newtemp(crow::Float64, temp::Float64, dq::Float64, W::Float64, dx::Float64, dt::Float64 )
    Cr = 4.18605E+3 #水の比熱(specific heat of water)[J/(kg・K)]
    latent_heat = ( 597.5 - 0.559 * ( temp - 273.15 ) ) * Cr # 潜熱
    return temp + ( dq - latent_heat * W ) / dx * ( dt / crow )
end

function cal_newtemp(crow::Float64, temp::Float64, dqx::Float64, dqy::Float64, dqz::Float64, 
        djvx::Float64, djvy::Float64, djvz::Float64, 
        Ayz::Float64, Azx::Float64, Axy::Float64,
        dx::Float64, dy::Float64, dz::Float64, dt::Float64 )
    Cr = 4.18605E+3 #水の比熱(specific heat of water)[J/(kg・K)]
    latent_heat = ( 597.5 - 0.559 * ( temp - 273.15 ) ) * Cr # 潜熱
    return temp + ( Ayz*dqx + Azx*dqy + Axy*dqz ) - latent_heat * ( Ayz*djvx + Azx*djvy + Axy*djvz ) / ( dx*dy*dz ) * ( dt / crow )
end

function cal_newtemp( cell::Cell, dq::Float64, W::Float64, time::Float64 );
    return cal_newtemp( crow(cell), temp(cell), dq, W, dx(cell), time )
end
cal_newtemp(; cell::Cell, dq::Float64, W::Float64 = 0.0, time::Float64 ) = cal_newtemp( cell, dq, W, time )  

function cal_newtemp( cell::Cell, dqx::Float64, dqy::Float64, dqz::Float64, 
    djvx::Float64, djvy::Float64, djvz::Float64, time::Float64 );
    return cal_newtemp( crow(cell), temp(cell), dqx, dqy, dqz, djvx, djvy, djvz, 
        dy(cell)*dz(cell), dz(cell)*dx(cell), dx(cell)*dy(cell), dx(cell), dy(cell), dz(cell), time )
end
cal_newtemp(; cell::Cell, dqx::Float64, dqy::Float64, dqz::Float64, djvx::Float64, djvy::Float64, djvz::Float64, time::Float64 ) = cal_newtemp( cell, dqx, dqy, dqz, djvx, djvy, djvz, time )  

# 水分化学ポテンシャル収支式
function cal_newmiu( dphi::Float64, miu::Float64, djw::Float64, dx::Float64, dt::Float64 )
    roww = 1000.0 #水の密度(density of water)[kg/m3]
    return miu + djw / dx / dphi * ( dt / roww )
end

function cal_newmiu(dphi::Float64, miu::Float64,
    djwx::Float64, djwy::Float64, djwz::Float64,
    Ayz::Float64, Azx::Float64, Axy::Float64,
    dx::Float64, dy::Float64, dz::Float64, dt::Float64 )
    roww = 1000.0 #水の密度(density of water)[kg/m3]
    return miu + ( Ayz*djwx + Azx*djwy + Axy*djwz ) / ( dx*dy*dz ) / dphi * ( dt / roww )
end

# 含水率収支式
function cal_newphi( phi::Float64, djw::Float64, dx::Float64, dt::Float64 )
    roww = 1000.0 #水の密度(density of water)[kg/m3]    
    return phi + djw / dx * ( dt / roww )
end

# 水蒸気の水分容量
function cal_vapour_capacity( temp::Float64, rh::Float64, miu::Float64, patm::Float64, psi::Float64, phi::Float64 )
    rhoa=  353.25 / temp
    return rhoa * ( psi - phi ) * cal_dah_drh(temp, rh, patm) * cal_drh_dmiu( temp, miu )
end
cal_vapour_capacity( cell::Cell) = cal_vapour_capacity( temp(cell), rh(cell), miu(cell), patm(cell), psi(cell), phi(cell) )
cal_vapour_capacity(; temp::Float64, rh::Float64, miu::Float64, patm::Float64, psi::Float64, phi::Float64 ) = cal_vapour_capacity( temp, rh, miu, patm, psi, phi )

function cal_newmiu( cell::Cell, djv::Float64, djl::Float64, time::Float64 )
    return cal_newmiu( dphi(cell), miu(cell), djv+djl, dx(cell), time )
end
cal_newmiu(; cell::Cell, djv::Float64, djl::Float64 = 0.0, time::Float64 ) = cal_newmiu( cell, djv, djl, time )

function cal_newmiu( cell::Cell, djwx::Float64, djwy::Float64, djwz::Float64, time::Float64 );
    return cal_newmiu( dphi(cell), miu(cell), djwx, djwy, djwz, 
        dy(cell)*dz(cell), dz(cell)*dx(cell), dx(cell)*dy(cell), dx(cell), dy(cell), dz(cell), time )
end
cal_newmiu(; cell::Cell, djwx::Float64, djwy::Float64, djwz::Float64, time::Float64 ) = cal_newmiu( cell, djwx, djwy, djwz, time )  

function cal_newmiu_with_vapour( cell::Cell, djv::Float64, djl::Float64, time::Float64 )
    vcap = cal_vapour_capacity( temp(cell), rh(cell), miu(cell), patm(cell), psi(cell), phi(cell) )
    return cal_newmiu( dphi(cell) + vcap /1000.0, miu(cell), djv+djl, dx(cell), time )
end
cal_newmiu_with_vapour(; cell::Cell, djv::Float64, djl::Float64 = 0.0, time::Float64 ) = cal_newmiu( cell, djv, djl, time )

function cal_newphi( cell::Cell, djv::Float64, djl::Float64, time::Float64 )
    return cal_newphi( phi(cell), djv + djl, dx(cell), time )
end
cal_newphi(; cell::Cell, djv::Float64, djl::Float64 = 0.0, time::Float64 ) = cal_newphi( cell, djv, djl, time )

# 水分収支式
function cal_newmolw( molw::Float64, djv::Float64, djw::Float64, dx::Float64, dt::Float64 )
    return molw + ( djv + djw ) / dx * dt
end

function cal_newmolw( cell::Cell, djv::Float64, djw::Float64, time::Float64 )
    Mw = 18.015 / 1000.0
    return cal_newmolw( molw(cell), djv / Mw , djw, dx(cell), time )    #jvは単位[kg/m2s]で求めているので[mol/m2s]に単位を変換
end

cal_newmolw(; cell::Cell, djv::Float64, djw::Float64, time::Float64 ) = cal_newmolw( cell, djv, djw, time )

# 塩分収支式
function cal_newmols( mols::Float64, djs::Float64, dx::Float64, dt::Float64 )
    return mols + djs / dx * dt
end

function cal_newmols( cell::Cell, djs::Float64, time::Float64 )
    return cal_newmols( mols(cell), djs, dx(cell), time )   
end

cal_newmols(; cell::Cell, djs::Float64, time::Float64 ) = cal_newmols( cell, djs, time )


