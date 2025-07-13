module vented_air_space

# 空隙率
const psi = 1.0

# 材料密度
const row = 1.293 #kg/m3 

# 比熱
const C = 1006.0 #J/kg 鉱物性の建材の標準的な値

# 熱容量
get_crow( cell ) = C * row

const Le = 1.0  # ルイス数
const Rv = 8.31441 / 0.01802    # 水の気体定数

### 水分特性 ###

# 含水率
get_phi( cell ) = 0.0

# 含水率の水分化学ポテンシャル微分
# dphi/dmiu = dphi/drh * drh/dmiu
get_dphi( cell ) = 0.0

# 含水率から水分化学ポテンシャルの算出
get_miu_by_phi( cell ) = 0.0

### 移動特性 ###
# 熱伝導率（熱抵抗換算）
get_lam( cell ) = 
    if cell.dx >= 0.01
        cell.dx / 0.09
    elseif cell.dx < 0.01
        cell.dx / ( 0.09 * cell.dx * 100.0 )
    end

# 透湿率（湿気伝導率）
# ルイスの関係（Lewis relation）より算出
function get_dp( cell )
    alpha = get_lam( cell ) / cell.dx - 4.4 # 放射熱伝達率を引いている
    return cell.dx * alpha / ( Le * C * row * Rv * cell.temp )
end
# 透水係数
get_ldml( cell ) = 0.0

end