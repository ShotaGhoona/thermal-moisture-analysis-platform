module paper_washi

# 空隙率
const psi = 0.6

# 材料密度 400-600程度
# 経年・楮と雁皮の配合割合によっても異なる[7]
# 雁皮のみであれば最大700程度、楮のみであれば430程度[7]
# 美濃和紙490, 黒谷紙356, 石州紙452, 雁皮紙596[1]
# 鳥の子480-510という事例もあり[8]
# 間似合紙（粘土混入）については雁皮紙と密度がさほど変わらない可能性あり[7]（2-3タルク添加による物性値変化と藩札料紙）
const row = 600.0 #kg/m3 

# 比熱 1300-1500程度
const C = 1350.0 #J/kgK

############################
# 水の密度
const roww = 1000.0 #kg/m3
#理想気体定数
const R = 8.314 # J/(mol K)
# 水のモル質量
const Mw = 0.018 # kg/mol
# 水蒸気のガス定数
Rv = R / Mw # J/(kg K)
# 水の熱容量
const croww = 1000.0 * 4.18605e+3

# miu ⇒　rh の変換係数
function convertMiu2RH( ;temp::Float64, miu::Float64 );
    return exp( miu / Rv / temp )
end

# 熱容量
get_crow( ;phi::Float64 ) = C * row + croww * phi
get_crow( cell ) = get_crow( phi = get_phi( cell ) )

### 水分特性 ###

# van-Genuchten用情報
include("./van_genuchten.jl")

BeSand_vG = van_Genuchten.vG_parameter( 
    0.000133,
    1.5284,
    1.0 - ( 1.0 / 1.5284 ),
    0.5
)

# 毛管飽和含水率
const phimax = 0.16

# 含水率 実測値 by Belsorp
get_phi( ;miu::Float64 ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = miu, phimax = phimax )
get_phi( cell ) = van_Genuchten.get_phi( vG = BeSand_vG, miu = cell.miu, phimax = phimax )

# 含水率の水分化学ポテンシャル微分
get_dphi( ;miu::Float64 ) = van_Genuchten.get_dphi( vG = BeSand_vG, miu = miu, phimax = phimax )
get_dphi( cell ) = get_dphi( miu = cell.miu )

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( ;phi::Float64 ) = van_Genuchten.get_miu(vG = BeSand_vG, phi = phi, phimax = phimax )
get_miu_by_phi( cell ) = get_miu_by_phi( phi = cell.phi )

### 移動特性 ###
# 熱伝導率 0.065～0.108程度[3]
const lam = 0.08 # 参考文献[2]
# 湿気依存
get_lam( ;phi::Float64 ) = lam # + 3.14e-4 * phi * 1000.0
get_lam( cell ) = get_lam( phi = get_phi( cell ) )

# 透水係数
# dw = 3.2e-13 * exp(0.015 * phi * 1000)
get_ldml( cell ) = 0.0

# 透湿率（湿気伝導率）：実測値 by カップ法
get_dp( cell ) = 8.25e-12  #1.4e-12 

end