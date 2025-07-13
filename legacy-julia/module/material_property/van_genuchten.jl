module van_Genuchten

# van_Genuchtenモジュールに用いる構造体
struct vG_parameter
    Alfa::Float64
    n::Float64
    m::Float64
    l::Float64
end    

# 水分化学ポテンシャルから飽和度を求める関数
function get_sl( ; vG::vG_parameter, miu::Float64  );
    return ( 1.0 + ( - vG.Alfa * miu ) ^ vG.n ) ^ ( - vG.m )
end

# 水分化学ポテンシャルから比透水係数を求める関数
function get_kl(; vG::vG_parameter, miu::Float64 );
    sl = get_sl( vG = vG, miu = miu )
    return ( sl ^ vG.l ) * ( ( 1.0 - ( 1.0 - sl ^ ( 1.0/ vG.m ) ) ^ vG.m ) ^ 2.0 )
end

# 含水率の水分化学ポテンシャル微分を求める関数
function get_dphi(; vG::vG_parameter, miu::Float64, phimax::Float64 );
    sl = get_sl( vG = vG, miu = miu )
    dphi = -( vG.Alfa * vG.m * phimax ) / ( 1.0 - vG.m ) * ( sl ^ ( 1.0 / vG.m ) ) * ( ( 1.0 - sl ^ ( 1.0 / vG.m ) ) ^ vG.m )
    return abs( dphi )
end

# 含水率から水分化学ポテンシャルを求める関数
function get_miu(; vG::vG_parameter, phimax::Float64, phi::Float64 );
    sl = phi / phimax
    return - ( ( ( sl ^ ( -1.0 / vG.m ) ) - 1.0 ) ^ ( 1.0 / vG.n ) ) / vG.Alfa
end

# 水分化学ポテンシャル勾配に対する液相水分伝導率を求める関数
function get_Lamdml(; vG::vG_parameter, Ksat::Float64, miu::Float64 );
    row = 1000.0        #塩溶液では密度変わるのでは
    g = 9.8
    kl = get_kl( vG = vG, miu = miu )
    return Ksat * kl * row / g
end

# 水分化学ポテンシャルから含水率を求める関数
function get_phi(; vG::vG_parameter, miu::Float64, phimax::Float64 );
    sl = get_sl( vG = vG, miu = miu )
    return phimax * sl
end

end

test_vG = van_Genuchten.vG_parameter( 10.0/98.0, 2.0, 1.0 - ( 1.0 / 2.0 ), 0.5 )

van_Genuchten.get_sl( vG = test_vG, miu = -1000.0 )

van_Genuchten.get_kl( vG = test_vG, miu = -1000.0 )

van_Genuchten.get_dphi( vG = test_vG, miu = -1000.0, phimax = 0.23 )

van_Genuchten.get_miu(vG = test_vG, phi = 0.20, phimax = 0.23 )

van_Genuchten.get_Lamdml( vG = test_vG, miu = -1000.0, Ksat = 0.0001 )

van_Genuchten.get_phi( vG = test_vG, miu = -1000.0, phimax = 0.23 )


