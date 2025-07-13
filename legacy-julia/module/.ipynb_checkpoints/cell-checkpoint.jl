# Cell構造体の設定
mutable struct Cell
    i::Int       #= 位置  =#
    dx::Float64  #= 幅x   =#
    dy::Float64  #= 高さy =#   
    dz::Float64  #= 奥行z =#
    dx2::Float64 # 質点からセル端までの距離（一般的にはdxの半分）
    dy2::Float64 
    dz2::Float64
    temp::Float64  #= 温度 =#
    #miu_all::Float64　　#= 水分化学ポテンシャル =#
    miu::Float64   #= 水分化学ポテンシャルの毛管圧成分（いわゆる水分化学ポテンシャル）=#
    #miuo::Float64　　#= 水分化学ポテンシャルの浸透圧成分 =#
    rh::Float64　　#= 相対湿度 =#
    pv::Float64　　#= 水蒸気圧 =#
    phi::Float64　　#= 含水率 =#
    #molw::Float64　　##= 液水のモル濃度[mol/m3] =#
    #mols::Float64    ##= 塩のモル濃度[mol/m3] =#
    #sigma::Float64   ##= 反射係数 =#
    material_name::String　　#= 材料名 =#
    Cell() = new()
end 

include("./property_conversion.jl")
include("./module_function/vapour.jl")
#include("./liquid_NaCl.jl")

#include("./module_material_property/liquid_water.jl")
# ※liquid_water.jlはproperty_conversion.jlを読み込む際に含まれている。

pc = property_conversion
wp = water_property

# Cell構造体を用いた各種パラメータの読み込み方法
# 構造体パラメーター
i(state::Cell)= state.i
dx(state::Cell)= state.dx
dx2(state::Cell)= state.dx2 # 流量計算式と合わせ要注意

# 熱水分＋塩状態量
temp(state::Cell)= state.temp
miu(state::Cell) = state.miu
rh(state::Cell)  = convertMiu2RH( temp = state.temp, miu = state.miu )
pv(state::Cell)  = convertMiu2Pv( temp = state.temp, miu = state.miu )

phi(state::Cell) = property_conversion.get_phi( state, state.material_name )
dphi(state::Cell)= property_conversion.get_dphi(state, state.material_name )

#####################################
# 塩溶液移動計算用物性値
#miu_all(state::Cell) = state.miu + state.miuo
#miu(state::Cell) = pc.get_miu_by_phi( phi(state), state.material_name )
#miuo(state::Cell) = cal_OsmoticPotential( state.temp, xw(state) )

#rh(state::Cell)  = convertMiu2RH( temp = state.temp, miu = state.miu_all )
#pv(state::Cell)  = convertMiu2Pv( temp = state.temp, miu = state.miu_all )

#phi_by_miu(state::Cell) = pc.get_phi( phi(state), state.material_name )
#phi(state::Cell) = cal_volume( state.mols, state.molw )
#dphi(state::Cell)= pc.get_dphi( state, state.material_name )

#molw(state::Cell) = state.molw   ##液水のモル濃度[mol/m3]
#mols(state::Cell) = state.mols   ##塩のモル濃度[mol/m3]

#cs_kg(state::Cell) = cal_cs_kg( state.mols, state.molw )　　##塩濃度[kg(NaCl)/kg(H2O)]  
#cs_mol(state::Cell) = cal_cs_mol( state.mols, state.molw )　##塩濃度[mol(NaCl)/kg(H2O)] (molality) 
#cs_vol(state::Cell) = cal_cs_vol( state.mols, state.molw )　##塩濃度[mol(NaCl)/m3(Solution)] 
#rowsw(state::Cell) = cal_rowsw( state.mols, state.molw )　　##溶液の密度
#drowsw(state::Cell) = cal_rowsw( state.mols, state.molw )　　##溶液の密度の濃度[kg(NaCl)/kg(H2O)]微分  ※濃度[kg/kg']に対する微分
#xs(state::Cell) = cal_xs( state.mols, state.molw )  ##塩のモル分率
#xw(state::Cell) = cal_xw( state.mols, state.molw )　##水のモル分率
#vs(state::Cell) = cal_vs( state.mols, state.molw )  ##塩の部分モル体積[m3/mol]
#vw(state::Cell) = cal_vw( state.mols, state.molw )　##水の部分モル体積[m3/mol]

#visco(state::Cell) = cal_viscosity( state.mols, state.molw )  ##溶液の粘性係数[microPa s]
#kls(state::Cell) = cal_kls( state.mols, state.molw )  ##粘性を考慮した比透水係数
#plc(state::Cell) = convert_miulc_to_plc( miu(state), vw(state) )  ##毛管圧

#####################################

# 材料熱物性値　※　材料物性値のファイルに含水率ベースのものがある場合注意
psi(state::Cell)  =  pc.get_psi( state.material_name )
C(state::Cell)    =  pc.get_C( state.material_name )
row(state::Cell)  =  pc.get_row( state.material_name )
crow(state::Cell) =  C(state) * row(state) + wp.Cr * wp.row * phi(state)

# 移動係数
lam(state::Cell)  =  pc.get_lam( state, state.material_name )
dw(state::Cell)   =  try; pc.get_dw( state, state.material_name ); catch; pc.get_dw_by_ldml( state, state.material_name ); end
#dsw(state::Cell)  = dw(state) * kls(state) / rowsw(state) / 9.806650
dp(state::Cell)   =  try; pc.get_dp( state, state.material_name ); catch; pc.get_dp_by_ldmg( state, state.material_name ); end
ldml(state::Cell) =  try; pc.get_ldml( state, state.material_name ); catch; pc.get_ldml_by_dw( state, state.material_name ); end
ldmg(state::Cell) =  try; pc.get_ldmg( state, state.material_name ); catch; pc.get_ldmg_by_dp( state, state.material_name ); end
ldtg(state::Cell) =  try; pc.get_ldtg( state, state.material_name ); catch; pc.get_ldtg_by_dp( state, state.material_name ); end

#ds(state::Cell) = cal_de()  ##NaClの拡散係数[m2/s]89
#sigma(state::Cell) = state.sigma  ##反射係数 


function set_value_all_by_molw_mols(state::Cell)
    state.miu = miu(state)
    state.miuo = miuo(state)
    state.miu_all  = miu_all(state)
    state.rh = rh(state)
    state.pv = pv(state)
    state.phi = phi(state)
    return 
end

using CSV
using DataFrames

function input_cell_data(file_name::String)
    
    # 入力ファイルの読み込み
    # 相対パスを入力の上指定さえれている場合、
    if contains(file_name, "./")
        file_directory = file_name
    # ファイル名＋csvの形で書かれている場合、
    elseif contains(file_name, ".csv")
        file_directory = "./input_data/wall_data/cell_data/"*string(file_name)
    # ファイル名のみが書かれている場合、
    else
        file_directory = "./input_data/wall_data/cell_data/"*string(file_name)*".csv"        
    end
    
    input_data = CSV.File( file_directory, header = 3) |> DataFrame
    # 空の開口条件データを作成
    cells = [ Cell() for i = 1 : length(input_data.i) ]
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.i)
        cells[i].i    = input_data.i[i]
        cells[i].dx   = input_data.dx[i]
        cells[i].temp = input_data.temp[i] + 273.15
        cells[i].material_name = input_data.material_name[i]
        cells[i].miu  = convertRH2Miu( temp = input_data.temp[i] + 273.15, rh = input_data.rh[i] / 100 ) # vapour.jl内の関数を流用
        # 質点からの距離の設定
        try 
            cells[i].dx2 = input_data.dx2[i]
        catch
            if i == 1 || i == length(input_data.i)
                cells[i].dx2= cells[i].dx
            else
                cells[i].dx2= cells[i].dx / 2
            end
        end
    end
    return cells
end


# 読み込み例
# input_cell_data("../input_data/wall_data/cell_data/wall1.csv")

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

function cal_newtemp( cell::Cell, dq::Float64, W::Float64, time::Float64 );
    return cal_newtemp( crow(cell), temp(cell), dq, W, dx(cell), time )
end
cal_newtemp(; cell::Cell, dq::Float64, W::Float64 = 0.0, time::Float64 ) = cal_newtemp( cell, dq, W, time )  

# 水分化学ポテンシャル収支式
function cal_newmiu( dphi::Float64, miu::Float64, djw::Float64, dx::Float64, dt::Float64 )
    roww = 1000.0 #水の密度(density of water)[kg/m3]
    return miu + djw / dx / dphi * ( dt / roww )
end

# 含水率収支式
function cal_newphi( phi::Float64, djw::Float64, dx::Float64, dt::Float64 )
    roww = 1000.0 #水の密度(density of water)[kg/m3]    
    return phi + djw / dx * ( dt / roww )
end

function cal_newmiu( cell::Cell, djv::Float64, djl::Float64, time::Float64 )
    return cal_newmiu( dphi(cell), miu(cell), djv+djl, dx(cell), time )
end
cal_newmiu(; cell::Cell, djv::Float64, djl::Float64 = 0.0, time::Float64 ) = cal_newmiu( cell, djv, djl, time )

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


