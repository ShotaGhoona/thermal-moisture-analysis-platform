include("./module_function/flux_and_balance_equation.jl")

module Porous_material_based_miu

include("./property_conversion.jl")
include("./module_function/vapour.jl")
include("./module_material_property/liquid_water.jl")

pc = property_conversion
wp = water_property

# Cell構造体の設定
mutable struct Cell
    i::Int       #= 位置  =#
    dx::Float64  #= 幅x   =#
    dy::Float64  #= 高さy =#   
    dz::Float64  #= 奥行z =#
    dx2::Float64 # 質点からセル端までの距離（一般的にはdxの半分）
    dy2::Float64
    dz2::Float64
    temp::Float64
    miu::Float64 # pvやphiなどは示量変数のため入れない
    material_name::String
    Cell() = new()
end 

# Cell構造体を用いた各種パラメータの読み込み方法
# 構造体パラメーター
i(state::Cell)= state.i
dx(state::Cell)= state.dx
dx2(state::Cell)= state.dx2 # 流量計算式と合わせ要注意

# 熱水分状態量
temp(state::Cell)= state.temp
miu(state::Cell) = state.miu
rh(state::Cell)  = convertMiu2RH( temp = state.temp, miu = state.miu )
pv(state::Cell)  = convertMiu2Pv( temp = state.temp, miu = state.miu )

phi(state::Cell) = pc.get_phi( state, state.material_name )
dphi(state::Cell)= pc.get_dphi(state, state.material_name )

# 材料熱物性値　※　材料物性値のファイルに含水率ベースのものがある場合注意
psi(state::Cell)  =  pc.get_psi( state.material_name )
C(state::Cell)    =  pc.get_C( state.material_name )
row(state::Cell)  =  pc.get_row( state.material_name )
crow(state::Cell) =  C(state) * row(state) + wp.Cr * wp.row * phi(state)

# 移動係数
lam(state::Cell)  =  pc.get_lam( state, state.material_name )
dw(state::Cell)   =  try; pc.get_dw( state, state.material_name ); catch; pc.get_dw_by_ldml( state, state.material_name ); end
dp(state::Cell)   =  try; pc.get_dp( state, state.material_name ); catch; pc.get_dp_by_ldg( state, state.material_name ); end
ldml(state::Cell) =  try; pc.get_ldml( state, state.material_name ); catch; pc.get_ldml_by_dw( state, state.material_name ); end
ldmg(state::Cell) =  try; pc.get_ldmg( state, state.material_name ); catch; pc.get_ldmg_by_dp( state, state.material_name ); end
ldtg(state::Cell) =  try; pc.get_ldtg( state, state.material_name ); catch; pc.get_ldtg_by_dp( state, state.material_name ); end

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

#############################
# CSVファイルを用いて壁を構築する関数
using CSV
using DataFrames

function input_cell_data(file_name::String)
    # 入力ファイルの読み込み
    file_directory = "./input_data/wall_data/"*string(file_name)*".csv"
    input_data = CSV.File( file_directory, header = 3) |> DataFrame
    # 空の開口条件データを作成
    cell = [ Cell() for i = 1 : length(input_data.i) ]
    
    # 入力ファイルに従ってデータを上書き
    for i = 1 : length(input_data.i)
        cell[i].i    = input_data.i[i]
        cell[i].dx   = input_data.dx[i]
        cell[i].temp = input_data.temp[i] + 273.15
        cell[i].material_name = input_data.material_name[i]
        cell[i].miu  = convertRH2Miu( temp = cell[i].temp, rh = input_data.rh[i] / 100 ) # vapour.jl内の関数を流用
        # 質点からの距離の設定
        try 
            cell[i].dx2 = input_data.dx2[i]
        catch
            if i == 1 || i == length(input_data.i)
                cell[i].dx2= cell[i].dx
            else
                cell[i].dx2= cell[i].dx / 2
            end
        end
    end
    return cell
end

function input_cell_data(;wall::Condition, file_name::String)
    wall.cell = input_cell_data(file_name)
end

end


c_para_test = Porous_material_based_miu.Cell()
c_para_test.dx = 0.001
c_para_test.dx2 = c_para_test.dx / 2.0
c_para_test.temp = 293.15
c_para_test.miu = -100.0
c_para_test.material_name = "bentheimer_sandstone"

c_para_test_v2 = Porous_material_based_miu.cell_construction( i = 1, dx = 0.001, temp = 293.15, rh = 0.99, material_name =  "bentheimer_sandstone")

Porous_material_based_miu.phi(c_para_test)

Porous_material_based_miu.ldmg(c_para_test)

c_para_test.temp = 10.0 + 273.15



module Air_based_RH

include("./module_function/vapour.jl")
include("./module_function/lewis_relation.jl")

mutable struct Air
    name::String  #= 名称  =#
    vol::Float64  #= 体積  =#
    temp::Float64
    rh::Float64
    alpha::Float64
    alphac::Float64
    alphar::Float64
    aldm::Float64
    Air() = new()
end 

# 構造体パラメーター
name(state::Air)= state.name
vol(state::Air)= state.vol

# 熱水分状態量
temp(state::Air)= state.temp
rh(state::Air) = state.rh
miu(state::Air) = convertRH2Miu( temp = state.temp, rh = state.rh )
pv(state::Air)  = convertRH2Pv( temp = state.temp, rh = state.rh )

# 移動係数
alpha(state::Air) = state.alphac + state.alphar
aldm(state::Air)  = state.aldm
aldt(state::Air)  = aldm(state) * cal_DPvDT( temp = state.temp, miu = miu(state) )
aldmu(state::Air) = aldm(state) * cal_DPvDMiu( temp = state.temp, miu = miu(state) )
aldm_by_alphac(state::Air) = Lewis_relation.cal_aldm( alpha = state.alphac , temp = state.temp )

function air_construction(; name::String = "No Name", 
        vol::Float64 = 1.0, temp::Float64, miu::Float64 = 0.0, rh::Float64 = 0.0, 
        alphac::Float64 = 4.9, alphar::Float64 = 4.4, aldm::Float64 = 0.0 )
    air = Air_based_RH.Air()
    air.name  = name
    air.vol = vol
    air.temp= temp
    air.alpha = alphac + alphar # 総合熱伝達率
    air.alphac= alphac # 対流熱伝達率
    air.alphar= alphar # 放射熱伝達率
    
    # 湿気伝達率
    if aldm == 0.0
        air.aldm = aldm_by_alphac(air)
    else
        air.aldm = aldm
    end
    
    if miu == 0.0
        air.rh = rh
    else
        air.rh = convertMiu2RH( temp = temp, miu = miu )
    end
    return air
end

end


air_test = Air_based_RH.air_construction(temp = 20.0 + 293.15)

air_test.temp = 300.0
air_test.rh   = 0.65
#air_test.alpha= 9.3
air_test.aldm

air_test.alphac

function cal_qs( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell )
    cell_para = Porous_material_based_miu
    return Flux.cal_heat_conduction_diff( lam_mns = cell_para.lam(cell_mns), lam_pls= cell_para.lam(cell_pls), 
        temp_mns = cell_para.temp(cell_mns), temp_pls = cell_para.temp(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls) )
end
cal_qs(;cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell ) = cal_qs( cell_mns, cell_pls )

function cal_qs_meanAve( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell )
    cell_para = Porous_material_based_miu
    return Flux.cal_heat_conduction_diff_meanAve( lam_mns = cell_para.lam(cell_mns), lam_pls= cell_para.lam(cell_pls), 
        temp_mns = cell_para.temp(cell_mns), temp_pls = cell_para.temp(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls) )
end
cal_qs_meanAve(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell ) = cal_qs_meanAve(cell_mns, cell_pls)

function cal_qs_air( cell_mns::Air_based_RH.Air, cell_pls::Porous_material_based_miu.Cell )
    Flux.cal_heat_transfer_diff( alpha = Air_based_RH.alpha(cell_mns), 
        temp_mns = Air_based_RH.temp(cell_mns), temp_pls = Porous_material_based_miu.temp(cell_pls) )
end
cal_qs_air(; cell_mns::Air_based_RH.Air, cell_pls::Porous_material_based_miu.Cell ) = cal_qs_air(cell_mns, cell_pls)

function cal_qs_air( cell_mns::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air )
    Flux.cal_heat_transfer_diff( alpha = Air_based_RH.alpha(cell_pls), 
        temp_mns = Porous_material_based_miu.temp(cell_mns), temp_pls = Air_based_RH.temp(cell_pls) )
end
cal_qs_air(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air ) = cal_qs_air(cell_mns, cell_pls)

function cal_jv( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell )
    cell_para = Porous_material_based_miu
    Flux.cal_vapour_permeance_potential_diff( 
        ldmg_mns = cell_para.ldmg(cell_mns), ldmg_pls = cell_para.ldmg(cell_pls), 
        ldtg_mns = cell_para.ldtg(cell_mns), ldtg_pls = cell_para.ldtg(cell_pls), 
        miu_mns = cell_para.miu(cell_mns), miu_pls = cell_para.miu(cell_pls), 
        temp_mns = cell_para.temp(cell_mns), temp_pls = cell_para.temp(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls) )
end
cal_jv(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell ) = cal_jv(cell_mns, cell_pls)

function cal_jv_meanAve( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell )
    cell_para = Porous_material_based_miu
    Flux.cal_vapour_permeance_potential_diff_meanAve( 
        ldmg_mns = cell_para.ldmg(cell_mns), ldmg_pls = cell_para.ldmg(cell_pls), 
        ldtg_mns = cell_para.ldtg(cell_mns), ldtg_pls = cell_para.ldtg(cell_pls), 
        miu_mns = cell_para.miu(cell_mns), miu_pls = cell_para.miu(cell_pls), 
        temp_mns = cell_para.temp(cell_mns), temp_pls = cell_para.temp(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls) )
end
cal_jv_meanAve(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell ) = cal_jv_meanAve( cell_mns, cell_pls)

function cal_jv_air( cell_mns::Air_based_RH.Air, cell_pls::Porous_material_based_miu.Cell )
    Flux.cal_vapour_transfer_pressure_diff( aldm = Air_based_RH.aldm(cell_mns), 
        pv_mns = Air_based_RH.pv(cell_mns), pv_pls = Porous_material_based_miu.pv(cell_pls) )
end
cal_jv_air(; cell_mns::Air_based_RH.Air, cell_pls::Porous_material_based_miu.Cell ) = cal_jv_air(cell_mns, cell_pls)

function cal_jv_air( cell_mns::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air )
    Flux.cal_vapour_transfer_pressure_diff( aldm = Air_based_RH.aldm(cell_pls), 
        pv_mns = Porous_material_based_miu.pv(cell_mns), pv_pls = Air_based_RH.pv(cell_pls) )
end
cal_jv_air(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air ) = cal_jv_air(cell_mns, cell_pls)

function cal_jl( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, nx = 0.0 )
    cell_para = Porous_material_based_miu
    Flux.cal_liquid_conduction_potential_diff( 
        ldml_mns = cell_para.ldml(cell_mns), ldml_pls = cell_para.ldml(cell_pls), 
        miu_mns = cell_para.miu(cell_mns), miu_pls = cell_para.miu(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls), nx = nx )
end
cal_jl(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, nx = 0.0 ) = cal_jl(cell_mns, cell_pls, nx)

function cal_jl_meanAve( cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, nx = 0.0 )
    cell_para = Porous_material_based_miu
    Flux.cal_liquid_conduction_potential_diff_meanAve( 
        ldml_mns = cell_para.ldml(cell_mns), ldml_pls = cell_para.ldml(cell_pls), 
        miu_mns = cell_para.miu(cell_mns), miu_pls = cell_para.miu(cell_pls), 
        dx2_mns = cell_para.dx2(cell_mns), dx2_pls = cell_para.dx2(cell_pls), nx = nx )
end
cal_jl_meanAve(; cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, nx = 0.0 ) = cal_jl_meanAve( cell_mns, cell_pls, nx)

c_para_test.temp = 293.15

c_para = Porous_material_based_miu
cell1 = c_para_test
air = air_test

cell2 = Porous_material_based_miu.Cell()
cell2.dx = 0.0015
cell2.dx2 = cell2.dx / 2.0 
#cell2.temp = 298.15
#cell2.miu = -150.0
cell2.temp = cell1.temp
cell2.miu = cell1.miu
cell2.material_name = "bentheimer_sandstone"

c_para_test

Porous_material_based_miu.pv(cell2)

cal_qs( cell1, cell2 )

cal_qs_air( air, cell1 )

cell1.temp

cal_qs_air( cell2, air )

cal_jl( cell2, cell1, 1.0 )

cal_jv( cell2, cell1 )

cal_jl_meanAve( cell2, cell1 )

cal_qs_meanAve( cell2, cell1 )

function cal_newtemp(; cell, qs_mns, qs_pls, jv_mns = 0.0, jv_pls = 0.0, time );
    cell_para = Porous_material_based_miu
    return balance_equation.cal_newtemp( cell_para.crow(cell), cell_para.temp(cell), qs_mns - qs_pls, - ( jv_mns - jv_pls ), cell_para.dx(cell), time )
end

function cal_newmiu(; cell, jv_mns = 0.0, jv_pls = 0.0, jl_mns = 0.0, jl_pls = 0.0, time )
    cell_para = Porous_material_based_miu
    return balance_equation.cal_newmiu( cell_para.dphi(cell), cell_para.miu(cell), ( jv_mns + jl_mns ) - ( jv_pls + jl_pls ), cell_para.dx(cell), time )
end

function cal_newphi(; cell, jv_mns = 0.0, jv_pls = 0.0, jl_mns = 0.0, jl_pls = 0.0, time )
    cell_para = Porous_material_based_miu
    return balance_equation.cal_newphi( cell_para.phi(cell), ( jv_mns + jl_mns ) - ( jv_pls + jl_pls ), cell_para.dx(cell), time )
end



air

cal_newtemp( cell = cell1, qs_mns = cal_qs_air(air, cell1), qs_pls = cal_qs(cell1, cell2), jv_mns = cal_jv_air(air, cell1), jv_pls = cal_jv(cell1, cell2), time = 0.1 )

cal_newmiu( cell = cell1, jv_mns = cal_jv_air(air,cell1), jv_pls = cal_jv(cell1, cell2), jl_mns = 0.0, jl_pls = cal_jl(cell1, cell2), time = 0.1 )



lam(cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell)  = balance_equation_by_ODE.sum_resistance( val_mns = Porous_material_based_miu.lam(cell_mns),  val_pls = Porous_material_based_miu.lam(cell_pls),  len_mns = Porous_material_based_miu.dx2(cell_mns), len_pls = Porous_material_based_miu.dx2(cell_pls) )
ldmg(cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell) = balance_equation_by_ODE.sum_resistance( val_mns = Porous_material_based_miu.ldmg(cell_mns), val_pls = Porous_material_based_miu.ldmg(cell_pls), len_mns = Porous_material_based_miu.dx2(cell_mns), len_pls = Porous_material_based_miu.dx2(cell_pls) )
ldtg(cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell) = balance_equation_by_ODE.sum_resistance( val_mns = Porous_material_based_miu.ldtg(cell_mns), val_pls = Porous_material_based_miu.ldtg(cell_pls), len_mns = Porous_material_based_miu.dx2(cell_mns), len_pls = Porous_material_based_miu.dx2(cell_pls) )
ldm(cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell)  = balance_equation_by_ODE.sum_resistance( val_mns = Porous_material_based_miu.ldml(cell_mns) + Porous_material_based_miu.ldmg(cell_mns), val_pls = Porous_material_based_miu.ldml(cell_pls) + Porous_material_based_miu.ldmg(cell_pls), len_mns = Porous_material_based_miu.dx2(cell_mns), len_pls = Porous_material_based_miu.dx2(cell_pls) )
ldt(cell_mns::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell)  = balance_equation_by_ODE.sum_resistance( val_mns = Porous_material_based_miu.ldtl(cell_mns) + Porous_material_based_miu.ldtg(cell_mns), val_pls = Porous_material_based_miu.ldtl(cell_pls) + Porous_material_based_miu.ldtg(cell_pls), len_mns = Porous_material_based_miu.dx2(cell_mns), len_pls = Porous_material_based_miu.dx2(cell_pls) )

function cal_newvalue_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, nx::Float64, heat_gain::Float64, moisture_gain::Float64 );
    val = Porous_material_based_miu
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(val.temp(cell_cen))
    
    # A1, A2の計算
    A1 = ODE.cal_A1( crow = val.crow(cell_cen), vol = val.dx(cell_cen) )
    A2 = ODE.cal_A2( vol  = val.dx(cell_cen),  dphi = val.dphi(cell_cen) )
    
    c1 = ODE.cal_c1( lam_mns = lam(cell_mns, cell_cen), lam_pls = lam(cell_cen, cell_pls), ldtg_mns = ldtg(cell_mns, cell_cen), ldtg_pls = ldtg(cell_cen, cell_pls), 
        r = r, dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))
    c2 = ODE.cal_c2( temp_mns = val.temp(cell_mns), temp_pls = val.temp(cell_pls), miu_mns = val.miu(cell_mns), miu_pls = val.miu(cell_pls), miu_cen = val.miu(cell_cen), 
        lam_mns = lam(cell_mns, cell_cen), lam_pls = lam(cell_cen, cell_pls), ldmg_mns = ldmg(cell_mns, cell_cen), ldmg_pls = ldmg(cell_cen, cell_pls), ldtg_mns = ldtg(cell_mns, cell_cen), ldtg_pls = ldtg(cell_cen, cell_pls),
        r = r, dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))
    c3 = ODE.cal_c3( ldm_mns = ldm(cell_mns, cell_cen), ldm_pls = ldm(cell_cen, cell_pls), dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))
    
    # ここでは液水の温度勾配水分拡散係数は無視している。
    c4 = ODE.cal_c4( temp_mns = val.temp(cell_mns), temp_pls = val.temp(cell_pls), temp_cen = val.temp(cell_cen), miu_mns = val.miu(cell_mns), miu_pls = val.miu(cell_pls),
        ldm_mns = ldm(cell_mns, cell_cen), ldm_pls = ldm(cell_cen, cell_pls), ldt_mns = ldtg(cell_mns, cell_cen), ldt_pls = ldtg(cell_cen, cell_pls), 
        dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls), nx = nx )
    
    return ODE.cal_newtemp( val.temp(cell_cen), A1, c1, c2, dt),  ODE.cal_newmiu( val.miu(cell_cen), A2, c3, c4, dt)
end

function cal_newtemp_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, heat_gain::Float64 );
    val = Porous_material_based_miu
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(val.temp(cell_cen))
    
    # A1の計算
    A1 = ODE.cal_A1( crow = val.crow(cell_cen), vol = val.dx(cell_cen) )
    
    c1 = ODE.cal_c1( lam_mns = lam(cell_mns, cell_cen), lam_pls = lam(cell_cen, cell_pls), ldtg_mns = ldtg(cell_mns, cell_cen), ldtg_pls = ldtg(cell_cen, cell_pls), 
        r = r, dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))
    c2 = ODE.cal_c2( temp_mns = val.temp(cell_mns), temp_pls = val.temp(cell_pls), miu_mns = val.miu(cell_mns), miu_pls = val.miu(cell_pls), miu_cen = val.miu(cell_cen), 
        lam_mns = lam(cell_mns, cell_cen), lam_pls = lam(cell_cen, cell_pls), ldmg_mns = ldmg(cell_mns, cell_cen), ldmg_pls = ldmg(cell_cen, cell_pls), ldtg_mns = ldtg(cell_mns, cell_cen), ldtg_pls = ldtg(cell_cen, cell_pls),
        r = r, dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))    
    
    return ODE.cal_newtemp( val.temp(cell_cen), A1, c1, c2, dt)
end

function cal_newmiu_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, nx::Float64, moisture_gain::Float64 );
    val = Porous_material_based_miu
    ODE = balance_equation_by_ODE
    
    # A2の計算
    A2 = ODE.cal_A2( vol  = val.dx(cell_cen),  dphi = val.dphi(cell_cen) )
    
    c3 = ODE.cal_c3( ldm_mns = ldm(cell_mns, cell_cen), ldm_pls = ldm(cell_cen, cell_pls), dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls))    
    # ここでは液水の温度勾配水分拡散係数は無視している。
    c4 = ODE.cal_c4( temp_mns = val.temp(cell_mns), temp_pls = val.temp(cell_pls), temp_cen = val.temp(cell_cen), miu_mns = val.miu(cell_mns), miu_pls = val.miu(cell_pls),
        ldm_mns = ldm(cell_mns, cell_cen), ldm_pls = ldm(cell_cen, cell_pls), ldt_mns = ldtg(cell_mns, cell_cen), ldt_pls = ldtg(cell_cen, cell_pls), 
        dx2_mns = val.dx2(cell_mns), dx2_pls = val.dx2(cell_pls), nx = nx )
    
    return ODE.cal_newmiu( val.miu(cell_cen), A2, c3, c4, dt)
end

# mnsが空気(air)、cenが壁表面(surf)、plsが壁内部(wall)
function cal_newvalue_by_ODE( cell_mns::Air_based_RH.Air, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, nx::Float64, heat_gain::Float64, moisture_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(valw.temp(cell_cen))
    
    # A1, A2の計算
    A1 = ODE.cal_A1( crow = valw.crow(cell_cen), vol = valw.dx(cell_cen) )
    A2 = ODE.cal_A2( vol  = valw.dx(cell_cen),  dphi = valw.dphi(cell_cen) )
    
    c1 = ODE.cal_c1_BC( lam = lam(cell_cen, cell_pls), alpha = Air_based_RH.alpha(cell_mns), ldtg = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns), r = r, dx2 = valw.dx2(cell_pls))
    c2 = ODE.cal_c2_BC( temp_wall = valw.temp(cell_pls), temp_air = vala.temp(cell_mns), miu_wall = valw.miu(cell_pls), miu_air = vala.miu(cell_mns), miu_surf = valw.miu(cell_cen), 
        lam = lam(cell_cen, cell_pls), alpha = Air_based_RH.alpha(cell_mns), ldmg = ldmg(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), ldtg = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns),
        r = r, dx2 = valw.dx2(cell_pls), heat_gain = heat_gain )    
    c3 = ODE.cal_c3_BC( ldm = ldm(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), dx2 = valw.dx2(cell_pls))
    c4 = ODE.cal_c4_BC( temp_wall = valw.temp(cell_pls), temp_air = vala.temp(cell_mns), temp_surf = valw.temp(cell_cen), miu_wall = valw.miu(cell_pls), miu_air = vala.miu(cell_mns),
        ldm = ldm(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), ldt = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns), dx2 = valw.dx2(cell_pls), nx = nx, moisture_gain = moisture_gain)    
    return ODE.cal_newtemp( valw.temp(cell_cen), A1, c1, c2, dt),  ODE.cal_newmiu( valw.miu(cell_cen), A2, c3, c4, dt)
end

# mnsが空気(air)、cenが壁表面(surf)、plsが壁内部(wall)
function cal_newtemp_by_ODE( cell_mns::Air_based_RH.Air, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, heat_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(valw.temp(cell_cen))
    
    # A2の計算
    A1 = ODE.cal_A1( crow = valw.crow(cell_cen), vol = valw.dx(cell_cen) )
    
    c1 = ODE.cal_c1_BC( lam = lam(cell_cen, cell_pls), alpha = Air_based_RH.alpha(cell_mns), ldtg = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns), r = r, dx2 = valw.dx2(cell_pls))
    c2 = ODE.cal_c2_BC( temp_wall = valw.temp(cell_pls), temp_air = vala.temp(cell_mns), miu_wall = valw.miu(cell_pls), miu_air = vala.miu(cell_mns), miu_surf = valw.miu(cell_cen), 
        lam = lam(cell_cen, cell_pls), alpha = Air_based_RH.alpha(cell_mns), ldmg = ldmg(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), ldtg = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns),
        r = r, dx2 = valw.dx2(cell_pls), heat_gain = heat_gain )    
    return ODE.cal_newtemp( valw.temp(cell_cen), A1, c1, c2, dt)
end

# mnsが空気(air)、cenが壁表面(surf)、plsが壁内部(wall)
function cal_newmiu_by_ODE( cell_mns::Air_based_RH.Air, cell_cen::Porous_material_based_miu.Cell, cell_pls::Porous_material_based_miu.Cell, 
        dt, nx::Float64, moisture_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    # A2の計算
    A2 = ODE.cal_A2( vol  = valw.dx(cell_cen),  dphi = valw.dphi(cell_cen) )
    
    c3 = ODE.cal_c3_BC( ldm = ldm(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), dx2 = valw.dx2(cell_pls))
    c4 = ODE.cal_c4_BC( temp_wall = valw.temp(cell_pls), temp_air = vala.temp(cell_mns), temp_surf = valw.temp(cell_cen), miu_wall = valw.miu(cell_pls), miu_air = vala.miu(cell_mns),
        ldm = ldm(cell_cen, cell_pls), aldmu = Air_based_RH.aldmu(cell_mns), ldt = ldtg(cell_cen, cell_pls), aldt = Air_based_RH.aldt(cell_mns), dx2 = valw.dx2(cell_pls), nx = nx, moisture_gain = moisture_gain)    
    return ODE.cal_newmiu( valw.miu(cell_cen), A2, c3, c4, dt)
end

# mnsが壁内部(wall)、cenが壁表面(surf)、plsが空気(air)
function cal_newvalue_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air, 
        dt, nx::Float64, heat_gain::Float64, moisture_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(valw.temp(cell_cen))
    
    # A1, A2の計算
    A1 = ODE.cal_A1( crow = valw.crow(cell_cen), vol = valw.dx(cell_cen) )
    A2 = ODE.cal_A2( vol  = valw.dx(cell_cen),  dphi = valw.dphi(cell_cen) )
    
    c1 = ODE.cal_c1_BC( lam = lam(cell_mns, cell_cen), alpha = Air_based_RH.alpha(cell_pls), ldtg = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls), r = r, dx2 = valw.dx2(cell_mns))
    c2 = ODE.cal_c2_BC( temp_wall = valw.temp(cell_mns), temp_air = vala.temp(cell_pls), miu_wall = valw.miu(cell_mns), miu_air = vala.miu(cell_pls), miu_surf = valw.miu(cell_cen), 
        lam = lam(cell_mns, cell_cen), alpha = Air_based_RH.alpha(cell_pls), ldmg = ldmg(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), ldtg = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls),
        r = r, dx2 = valw.dx2(cell_mns), heat_gain = heat_gain )
    c3 = ODE.cal_c3_BC( ldm = ldm(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), dx2 = valw.dx2(cell_mns))
    c4 = ODE.cal_c4_BC( temp_wall = valw.temp(cell_mns), temp_air = vala.temp(cell_pls), temp_surf = valw.temp(cell_cen), miu_wall = valw.miu(cell_mns), miu_air = vala.miu(cell_pls),
        ldm = ldm(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), ldt = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls), dx2 = valw.dx2(cell_mns), nx = nx, moisture_gain = moisture_gain)    
    return ODE.cal_newtemp( valw.temp(cell_cen), A1, c1, c2, dt),  ODE.cal_newmiu( valw.miu(cell_cen), A2, c3, c4, dt)   
end

# mnsが壁内部(wall)、cenが壁表面(surf)、plsが空気(air)
function cal_newtemp_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air, 
        dt, heat_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(valw.temp(cell_cen))
    
    # A1の計算
    A1 = ODE.cal_A1( crow = valw.crow(cell_cen), vol = valw.dx(cell_cen) )
    
    c1 = ODE.cal_c1_BC( lam = lam(cell_mns, cell_cen), alpha = Air_based_RH.alpha(cell_pls), ldtg = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls), r = r, dx2 = valw.dx2(cell_mns))
    c2 = ODE.cal_c2_BC( temp_wall = valw.temp(cell_mns), temp_air = vala.temp(cell_pls), miu_wall = valw.miu(cell_mns), miu_air = vala.miu(cell_pls), miu_surf = valw.miu(cell_cen), 
        lam = lam(cell_mns, cell_cen), alpha = Air_based_RH.alpha(cell_pls), ldmg = ldmg(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), ldtg = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls),
        r = r, dx2 = valw.dx2(cell_mns), heat_gain = heat_gain )
    return ODE.cal_newtemp( valw.temp(cell_cen), A1, c1, c2, dt)
end

# mnsが壁内部(wall)、cenが壁表面(surf)、plsが空気(air)
function cal_newmiu_by_ODE( cell_mns::Porous_material_based_miu.Cell, cell_cen::Porous_material_based_miu.Cell, cell_pls::Air_based_RH.Air, 
        dt, nx::Float64, moisture_gain::Float64 );
    valw = Porous_material_based_miu
    vala = Air_based_RH
    ODE = balance_equation_by_ODE
    
    r = ODE.latent_heat(valw.temp(cell_cen))
    
    # A2の計算
    A2 = ODE.cal_A2( vol  = valw.dx(cell_cen),  dphi = valw.dphi(cell_cen) )
    
    c3 = ODE.cal_c3_BC( ldm = ldm(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), dx2 = valw.dx2(cell_mns))
    c4 = ODE.cal_c4_BC( temp_wall = valw.temp(cell_mns), temp_air = vala.temp(cell_pls), temp_surf = valw.temp(cell_cen), miu_wall = valw.miu(cell_mns), miu_air = vala.miu(cell_pls),
        ldm = ldm(cell_mns, cell_cen), aldmu = Air_based_RH.aldmu(cell_pls), ldt = ldtg(cell_mns, cell_cen), aldt = Air_based_RH.aldt(cell_pls), dx2 = valw.dx2(cell_mns), nx = nx, moisture_gain = moisture_gain)    
    return ODE.cal_newmiu( valw.miu(cell_cen), A2, c3, c4, dt)   
end

cal_newvalue_by_ODE(; cell_mns, cell_cen, cell_pls, dt, nx = 0.0, heat_gain = 0.0, moisture_gain = 0.0 ) = cal_newvalue_by_ODE( cell_mns, cell_cen, cell_pls, dt, nx, heat_gain, moisture_gain )
cal_newtemp_by_ODE( ; cell_mns, cell_cen, cell_pls, dt, heat_gain = 0.0 )               = cal_newtemp_by_ODE( cell_mns, cell_cen, cell_pls, dt, heat_gain )
cal_newmiu_by_ODE(  ; cell_mns, cell_cen, cell_pls, dt, nx = 0.0, moisture_gain = 0.0 ) = cal_newmiu_by_ODE(  cell_mns, cell_cen, cell_pls, dt, nx, moisture_gain )

cal_newvalue_by_ODE( cell_mns = cell1, cell_cen = cell2, cell_pls = air, dt = 0.1 )

cal_newtemp_by_ODE( cell_mns = cell1, cell_cen = cell2, cell_pls = air, dt = 0.1 )

cal_newmiu_by_ODE( cell_mns = cell1, cell_cen = cell2, cell_pls = air, dt = 0.1 )


