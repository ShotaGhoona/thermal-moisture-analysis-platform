module Lewis_relation

# ルイス数
const Le = 1.0

# 乾燥空気の定圧比熱
const cp = 1006.0

# 乾燥空気の密度
const row = 1.293

# 水の気体定数
const Rv = 8.31441 / 0.01802

# ルイスの関係（Lewis relation）
cal_aldm( ; temp::Float64, alpha::Float64 ) = alpha / ( Le * cp * row * Rv * temp )

end

# 使用例
Lewis_relation.cal_aldm( alpha = 23.0 , temp = 283.15 )


