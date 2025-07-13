#using PyPlot 
#using PyCall
#np = pyimport("numpy")

const R = 8.314456
const Rv = 8.314456 / 0.018016

const F = 9.6485 * 10000.0

const Mw = 18.015 / 1000.0
const Ms = 58.44 / 1000.0

function cal_cs_kg( mols, molw )
    return Ms * mols / ( Mw * molw )
end

function cal_cs_mol( mols, molw )
    return mols / ( Mw * molw )
end

function cal_cs_vol( mols, molw )
    vol = cal_volume( mols, molw )
    return mols / vol
end

function cal_mols_by_cs_mol(cs, molw)
    return cs * Mw * molw
end

function cal_rowsw_cs( molal )
    return -303.34 * (( molal * Ms) ^ 2.0 ) + 667.04 * (molal * Ms) + 1000.0
end
    
function cal_drowsw_cs( molal )
    return -606.68 * (molal * Ms) + 667.04
end

function cal_rowsw( mols, molw )
    return cal_rowsw_cs( cal_cs_mol( mols, molw ) )
end
    
function cal_drowsw( mols, molw )
    return cal_drowsw_cs( cal_cs_mol( mols, molw ) )
end


function cal_xs( mols, molw )
    return  2.0 * mols / ( molw + 2.0 * mols )
end

function cal_xw( mols, molw )
    return  molw / ( molw + 2.0 * mols )
end


#　volume　と　塩濃度[mol/kg]　から　各塩のモル量を算出する
function cal_molw( vol, molal )
    return cal_rowsw_cs( molal ) * vol / ( (1.0 + molal * Ms ) * Mw )
end

function cal_mols( vol, molal )
    if molal == 0.0;
        return 0.0
        else;
        return cal_rowsw_cs( molal ) * vol / ( Ms + 1.0 / molal )
    end
end


function cal_volume( mols, molw )
    return ( Ms * mols + Mw * molw ) / cal_rowsw( mols, molw )
end


function cal_vw( mols, molw )
    cs = cal_cs_kg( mols, molw )
    rowsw = cal_rowsw( mols, molw )
    drowsw= cal_drowsw( mols, molw )
    return Mw / rowsw * ( 1.0 + cs * ( 1.0 + cs ) * ( drowsw / rowsw ) )
end
    
function cal_vs( mols, molw )
    cs = cal_cs_kg( mols, molw )
    rowsw = cal_rowsw( mols, molw )
    drowsw= cal_drowsw( mols, molw )
    return Ms / rowsw * ( 1.0 - ( 1.0 + cs ) * ( drowsw / rowsw ) )
end


function cal_viscosity( mols, molw )
    return 4204.0 * ( cal_cs_kg( mols, molw ) ^ 2 ) + 1224.2 * cal_cs_kg( mols, molw ) + 1000.2
end


function cal_kls( mols, molw )
     return ( cal_rowsw( mols, molw ) / cal_rowsw( 0.0, molw ) ) * ( cal_viscosity( 0.0, molw ) / cal_viscosity( mols, molw ) )
end


function cal_LPfromLDML( ldml, mols, molw )
     return ldml / ( cal_rowsw( mols, molw ) * 1000.0 ) 
end

function cal_OsmoticPotential( temp, xw )
    return Rv * temp * log( xw )
end
    
function cal_OsmoticPressure( temp, cs )
    return R * temp * cs * 2.0  #要注意（電解質の場合浸透圧は2倍になる？）
end


function convert_miulc_to_plc(miulc, vw)
    return miulc * Mw / vw
end

function cal_de()
    return 17.1 * 10 ^(-6) / ( 100.0 ^ 2.0 ) 
end

function cal_omega( temp )
    return cal_de() / ( R * temp )
end


