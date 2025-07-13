module property_conversion

#####################################################
# 辞書型データの作成
# 材料物性データを保持している辞書型リストの作成
prop_list = Dict{String, Any}()

# 材料物性データのロード
include(string("./material_property/bentheimer_sandstone.jl"))
include(string("./material_property/benchmark_EN15026.jl"))
include(string("./material_property/tuff_motomachi.jl"))
include(string("./material_property/tuff_motomachi_v2.jl"))
include(string("./material_property/tuff_motomachi_v3.jl"))
include(string("./material_property/loamy_sand.jl"))
include(string("./material_property/plainfield_sand.jl"))
include(string("./material_property/sandy_clay_loam.jl"))
include(string("./material_property/mud_wall.jl"))
include(string("./material_property/plywood.jl"))
include(string("./material_property/extruded_polystyrene.jl"))
include(string("./material_property/asphalt_felt.jl"))
include(string("./material_property/ceramic_siding.jl"))
include(string("./material_property/breathable_water_proof_sheet.jl"))
include(string("./material_property/glass_wool_16K.jl"))
include(string("./material_property/glass_wool_16K_original.jl"))
include(string("./material_property/glass_wool_hokoi.jl"))
include(string("./material_property/moisture_proof_sheet.jl"))
include(string("./material_property/mortar.jl"))
include(string("./material_property/plasterboard.jl"))
include(string("./material_property/structural_plywood.jl"))
include(string("./material_property/vented_air_space.jl"))
include(string("./material_property/concrete_goran.jl"))
include(string("./material_property/metal_plate.jl"))
include(string("./material_property/paper.jl"))
include(string("./material_property/ALC.jl"))

# 辞書の登録
prop_list["bentheimer_sandstone"] = bentheimer_sandstone
prop_list["benchmark_EN15026"] = benchmark_EN15026
prop_list["tuff_motomachi"] = tuff_motomachi
prop_list["tuff_motomachi_v2"] = tuff_motomachi_v2
prop_list["tuff_motomachi_v3"] = tuff_motomachi_v3
prop_list["loamy_sand"] = loamy_sand
prop_list["plainfield_sand"] = plainfield_sand
prop_list["sandy_clay_loam"] = sandy_clay_loam
prop_list["mud_wall"] = mud_wall
prop_list["plywood"] = plywood
prop_list["extruded_polystyrene"] = extruded_polystyrene
prop_list["asphalt_felt"] = asphalt_felt
prop_list["ceramic_siding"] = ceramic_siding
prop_list["extruded_polystyrene"] = extruded_polystyrene
prop_list["breathable_water_proof_sheet"] = breathable_water_proof_sheet
prop_list["glass_wool_16K"] = glass_wool_16K
prop_list["glass_wool_16K_original"] = glass_wool_16K_original
prop_list["glass_wool_hokoi"] = glass_wool_hokoi
prop_list["moisture_proof_sheet"] = moisture_proof_sheet
prop_list["mortar"] = mortar
prop_list["plasterboard"] = plasterboard
prop_list["structural_plywood"] = structural_plywood
prop_list["vented_air_space"] = vented_air_space
prop_list["concrete_goran"] = concrete_goran
prop_list["metal_plate"] = metal_plate
prop_list["paper"] = paper
prop_list["ALC"] = ALC

#####################################################
const grav = 9.806650

include("./function/vapour.jl")
include("./material_property/liquid_water.jl")

# 関係式
# 水蒸気圧の水分化学ポテンシャル微分
cal_dpdmiu( cell ) = cal_Pvs( temp = cell.temp ) * exp( cell.miu / Rv / cell.temp ) / Rv / cell.temp

# 水蒸気圧の温度微分
cal_dpdT( cell ) = exp( cell.miu / Rv / cell.temp ) * ( cal_DPvs( temp = cell.temp ) - cal_Pvs( temp = cell.temp ) * cell.miu / Rv / ( cell.temp^2.0 ) )

# 熱容量（液水の熱容量を加えた場合）
cal_crow_add_water( cell ) = cell.crow + water_property.Cr * water_property.row * cell.phi


######################################################
# 材料特性値の取得
# 空隙率
get_psi(material_name::String) = prop_list[material_name].psi

# 比熱
get_C(material_name::String) = prop_list[material_name].C

# 材料密度
get_row(material_name::String) = prop_list[material_name].row

# 熱容量
get_crow(material_name::String) = prop_list[material_name].crow


#######################################################
# 水分特性値の取得
# 含水率
get_phi(cell, material_name::String) = prop_list[material_name].get_phi(cell)

# 含水率の水分化学ポテンシャル微分
get_dphi(cell, material_name::String) = prop_list[material_name].get_dphi(cell)

# 含水率から水分化学ポテンシャルを計算する関数
get_miu_by_phi(cell, material_name::String) = prop_list[material_name].get_miu_by_phi(cell)
get_miu_by_phi(phi::Float64, material_name::String) = prop_list[material_name].get_miu_by_phi(phi = phi)



#######################################################
# 移動係数の取得
### 熱 ###
# 熱伝導率（固体実質部）
get_lam(cell, material_name::String) = prop_list[material_name].get_lam(cell)

### 水（液） ###
# 液相水分伝導率
get_dw(cell, material_name::String) = prop_list[material_name].get_dw(cell)
get_dw_by_ldml(cell, material_name::String) = prop_list[material_name].get_ldml(cell) / water_property.row * grav

# 水分化学ポテンシャル勾配に対する液相水分伝導率
get_ldml(cell, material_name::String) = prop_list[material_name].get_ldml(cell)
get_ldml_by_dw(cell, material_name::String) = prop_list[material_name].get_dw(cell) * water_property.row / grav

### 水（気） ###
# 気相水分伝導率
get_dp(cell, material_name::String) = prop_list[material_name].get_dp(cell)
get_dp_by_ldmg(cell, material_name::String) = prop_list[material_name].get_ldmg(cell) / cal_dpdmiu( cell ) + prop_list[material_name].get_ldtg(cell) / cal_dpdT( cell )

# 水分化学ポテンシャル勾配に対する気相水分伝導率
get_ldmg(cell, material_name::String) = prop_list[material_name].get_ldmg(cell)
get_ldmg_by_dp(cell, material_name::String) = prop_list[material_name].get_dp(cell) * cal_dpdmiu( cell )

# 温度勾配に対する気相水分伝導率
get_ldtg(cell, material_name::String) = prop_list[material_name].get_ldtg(cell)
get_ldtg_by_dp(cell, material_name::String) = prop_list[material_name].get_dp(cell) * cal_dpdT( cell )


end


pc = property_conversion

include("./material_property/liquid_water.jl")

# 各物性を保持する構造体
mutable struct get_function_material_property
    psi ; C ; row ; crow ; 
    phi ; dphi ; miu ;
    lam ; dw ; dp ;
    ldml;ldmg; ldtg
    get_function_material_property() = new()
end

# 関数形で保持する場合はこちら
function set_function_material_property( material_name )
    prop = get_function_material_property()
    prop.psi  =  pc.get_psi
    prop.C    =  pc.get_C
    prop.row  =  pc.get_row
    prop.crow =  pc.cal_crow_add_water
    prop.phi  =  pc.get_phi
    prop.dphi =  pc.get_dphi
    prop.miu  =  pc.get_miu_by_phi
    prop.lam  =  pc.get_lam
    prop.dw   =  try; pc.get_dw;   catch; pc.get_dw_by_ldml; end
    prop.dp   =  try; pc.get_dp;   catch; pc.get_dp_by_ldmg; end
    prop.ldml =  try; pc.get_ldml; catch; pc.get_ldml_by_dw; end
    prop.ldmg =  try; pc.get_ldmg; catch; pc.get_ldmg_by_dp; end
    prop.ldtg =  try; pc.get_ldtg; catch; pc.get_ldtg_by_dp; end  
    return prop
end

# 物性値と移動係数を分離
#　熱水分物性
function set_function_hygrothermal_property( material_name )
    prop = get_function_material_property()
    prop.psi  =  pc.get_psi
    prop.C    =  pc.get_C
    prop.row  =  pc.get_row
    prop.crow =  pc.cal_crow_add_water
    prop.phi  =  pc.get_phi
    prop.dphi =  pc.get_dphi
    prop.miu  =  pc.get_miu_by_phi
    return prop
end

# 移動係数
function set_function_transfer_coefficient( material_name )
    prop = get_function_material_property()
    prop.lam  =  pc.get_lam
    prop.dw   =  try; pc.get_dw;   catch; pc.get_dw_by_ldml; end
    prop.dp   =  try; pc.get_dp;   catch; pc.get_dp_by_ldmg; end
    prop.ldml =  try; pc.get_ldml; catch; pc.get_ldml_by_dw; end
    prop.ldmg =  try; pc.get_ldmg; catch; pc.get_ldmg_by_dp; end
    prop.ldtg =  try; pc.get_ldtg; catch; pc.get_ldtg_by_dp; end  
    return prop
end

# 値で保持する場合はこちら
function set_value_material_property( cell, material_name )
    prop = get_function_material_property()
    prop.psi  =  pc.get_psi( material_name )
    prop.C    =  pc.get_C( material_name )
    prop.row  =  pc.get_row( material_name )
    prop.crow =  prop.C * prop.row + water_property.Cr * water_property.row * cell.phi
    prop.phi  =  pc.get_phi( cell, material_name )
    prop.dphi =  pc.get_dphi( cell, material_name )
    prop.miu  =  pc.get_miu_by_phi( cell, material_name )
    prop.lam  =  pc.get_lam( cell, material_name )
    prop.dw   =  try; pc.get_dw( cell, material_name );   catch; pc.get_dw_by_ldml( cell, material_name ); end
    prop.dp   =  try; pc.get_dp( cell, material_name );   catch; pc.get_dp_by_ldmg( cell, material_name ); end
    prop.ldml =  try; pc.get_ldml( cell, material_name ); catch; pc.get_ldml_by_dw( cell, material_name ); end
    prop.ldmg =  try; pc.get_ldmg( cell, material_name ); catch; pc.get_ldmg_by_dp( cell, material_name ); end
    prop.ldtg =  try; pc.get_ldtg( cell, material_name ); catch; pc.get_ldtg_by_dp( cell, material_name ); end      
    return prop
end
