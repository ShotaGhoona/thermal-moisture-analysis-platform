function cal_phi_by_lam(phi0, a, b, c, lam)
    return - ( phi0 + a * atan( b*lam + c ) )
end
cal_phi_by_lam(;phi0, a, b, c, lam) = cal_phi_by_lam(phi0, a, b, c, lam)

cal_phi_by_lam(phi0 = 0.3, a = 0.43, b = 5.6, c = -8.6, lam = 1.2)

function cal_lam_by_phi(phi0, a, b, c, phi)
    return 1 / b * ( tan( - ( phi + phi0 ) / a ) -c )
end
cal_lam_by_phi(;phi0, a, b, c, phi) = cal_lam_by_phi(phi0, a, b, c, phi)

cal_lam_by_phi(phi0 = 0.3, a = 0.43, b = 5.6, c = -8.6, phi = cal_phi_by_lam(phi0 = 0.3, a = 0.43, b = 5.6, c = -8.6, lam = 1.2))

function cal_dphi_by_dlam(a, b, c, lam)
    return - a * b / ( 1 + ( b * lam + c )^2 )
end
cal_dphi_by_dlam(;a, b, c, lam) = cal_dphi_by_dlam(a, b, c, lam)

function cal_dlam_by_dphi(a, b, c, phi0, phi)
    return - 1 / ( b * cos( - ( phi + phi0 ) / a )^2 )
end
cal_dlam_by_dphi(;a, b, c, phi0, phi) = cal_dlam_by_dphi(a, b, c, phi0, phi)

function cal_int_lam_by_phi(a, b, c, phi_init, phi)
    return - c/b * ( phi - phi_init ) + a/b * log( abs(cos( 2*phi/a )) / abs( cos(( phi + phi_init )/a) ) )
end
cal_int_lam_by_phi(;a, b, c, phi_init, phi) = cal_int_lam_by_phi(a, b, c, phi_init, phi)

function cal_Dw_by_Boltzmann( a, b, c, phi_init, phi)
    #lam     = cal_lam_by_phi(phi_0, a, b, c, phi)
    #dphi    = cal_dphi_by_dlam(a, b, c, lam)
    dlam    = cal_dlam_by_dphi(a, b, c, phi_init, phi)
    int_lam = cal_int_lam_by_phi(a, b, c, phi_init, phi)
    return - ( 1 / 2 ) * dlam * int_lam 
end
cal_Dw_by_Boltzmann(; a, b, c, phi_init, phi) = cal_Dw_by_Boltzmann( a, b, c, phi_init, phi)

cal_Dw_by_Boltzmann( a = 0.43, b = 19400, c = -8.12, phi_init = 0.0, phi = 0.3)

function cal_ldml_by_Dw(Dw, dphi)
    rho_w = 1000.0
    return rho_w * Dw * dphi
end


