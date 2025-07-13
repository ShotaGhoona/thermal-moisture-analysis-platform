module metal_plate

# 空隙率
const psi = 0.001

# 材料密度
const row = 8050.0 #kg/m3

# 比熱
const C = 461.0 #J/kg

# 熱容量
get_crow() = C * row
get_crow( cell ) = get_crow()

### 水分特性 ###
# 含水率
function get_phi()
    return 0.001
end
get_phi( cell ) = get_phi()

function get_dphi()
    return 1.0e+30
end
get_dphi( cell ) = get_dphi()

# 含水率から水分化学ポテンシャルの算出
function get_miu_by_phi()
    return -10000.0
end
get_miu_by_phi( cell ) = get_miu_by_phi()

### 移動特性 ###
# 熱伝導率
const lam = 45.0

# 湿気依存
get_lam() = lam
get_lam( cell ) = get_lam()

# 水分移動
## 透水係数
get_dw() = 0.0
get_dw( cell ) = get_dw()

# 透湿率（湿気伝導率）
function get_dp()
    return 0.0
end
get_dp( cell ) = get_dp()

end