"""
    Psychrometrics

湿り空気の物性計算モジュール。
飽和水蒸気圧、湿度変換、微分係数を提供。

移行元: legacy-julia/module/function/vapour.jl
"""
module Psychrometrics

using ..PhysicsConstants: R_VAPOR, P_ATM

export cal_Pvs, cal_DPvs
export convertRH2Pv, convertPv2RH
export convertRH2Miu, convertMiu2RH
export convertPv2AH, convertAH2Pv
export convertRH2AH, convertAH2RH
export convertPv2Miu, convertMiu2Pv
export cal_DPvDT, cal_DPvDMiu
export cal_drh_dmiu, cal_dah_dpv, cal_dah_drh

#=============================================================================
  飽和水蒸気圧
=============================================================================#

"""
    cal_Pvs(temp::Float64) -> Float64

飽和水蒸気圧を計算する（Wexler-Hyland式）。

# Arguments
- `temp`: 温度 [K]

# Returns
- 飽和水蒸気圧 [Pa]

# Example
```julia
pvs = cal_Pvs(293.15)  # 20℃での飽和水蒸気圧
```
"""
function cal_Pvs(temp::Float64)
    return exp(-5800.22060 / temp + 1.3914993 -
               4.8640239e-2 * temp +
               4.1764768e-5 * temp^2 -
               1.4452093e-8 * temp^3 +
               6.5459673 * log(temp))
end

"""
    cal_DPvs(temp::Float64) -> Float64

飽和水蒸気圧の温度微分を計算する。

# Arguments
- `temp`: 温度 [K]

# Returns
- dPvs/dT [Pa/K]
"""
function cal_DPvs(temp::Float64)
    DP = 10.795740 * 273.160 / temp^2 -
         5.0280 / temp / log(10.0) +
         1.50475e-4 * 8.2969 / 273.16 * log(10.0) *
         10.0^(-8.29690 * (temp / 273.160 - 1.0)) +
         0.42873e-3 * 4.769550 * 273.160 / temp^2 * log(10.0) *
         10.0^(4.769550 * (1.0 - 273.160 / temp))
    return cal_Pvs(temp) * DP * log(10.0)
end

#=============================================================================
  基本変換関数
=============================================================================#

"""
    convertRH2Pv(temp::Float64, rh::Float64) -> Float64

相対湿度から水蒸気分圧を計算。

# Arguments
- `temp`: 温度 [K]
- `rh`: 相対湿度 [0-1]

# Returns
- 水蒸気分圧 [Pa]
"""
convertRH2Pv(temp::Float64, rh::Float64) = rh * cal_Pvs(temp)

"""
    convertPv2RH(temp::Float64, pv::Float64) -> Float64

水蒸気分圧から相対湿度を計算。

# Arguments
- `temp`: 温度 [K]
- `pv`: 水蒸気分圧 [Pa]

# Returns
- 相対湿度 [0-1]
"""
convertPv2RH(temp::Float64, pv::Float64) = pv / cal_Pvs(temp)

"""
    convertRH2Miu(temp::Float64, rh::Float64) -> Float64

相対湿度から水分化学ポテンシャルを計算。

# Arguments
- `temp`: 温度 [K]
- `rh`: 相対湿度 [0-1]（rh > 0）

# Returns
- 水分化学ポテンシャル [J/kg]
"""
convertRH2Miu(temp::Float64, rh::Float64) = R_VAPOR * temp * log(rh)

"""
    convertMiu2RH(temp::Float64, miu::Float64) -> Float64

水分化学ポテンシャルから相対湿度を計算。

# Arguments
- `temp`: 温度 [K]
- `miu`: 水分化学ポテンシャル [J/kg]（miu ≤ 0）

# Returns
- 相対湿度 [0-1]
"""
convertMiu2RH(temp::Float64, miu::Float64) = exp(miu / R_VAPOR / temp)

#=============================================================================
  水蒸気分圧 ↔ 水分化学ポテンシャル
=============================================================================#

"""
    convertPv2Miu(temp::Float64, pv::Float64) -> Float64

水蒸気分圧から水分化学ポテンシャルを計算。
"""
function convertPv2Miu(temp::Float64, pv::Float64)
    rh = convertPv2RH(temp, pv)
    return convertRH2Miu(temp, rh)
end

"""
    convertMiu2Pv(temp::Float64, miu::Float64) -> Float64

水分化学ポテンシャルから水蒸気分圧を計算。
"""
function convertMiu2Pv(temp::Float64, miu::Float64)
    rh = convertMiu2RH(temp, miu)
    return convertRH2Pv(temp, rh)
end

#=============================================================================
  絶対湿度変換
=============================================================================#

"""
    convertPv2AH(pv::Float64, patm::Float64=P_ATM) -> Float64

水蒸気分圧から絶対湿度（重量絶対湿度）を計算。

# Arguments
- `pv`: 水蒸気分圧 [Pa]
- `patm`: 大気圧 [Pa]（デフォルト: 101325）

# Returns
- 絶対湿度 [kg/kg']（乾き空気1kgあたりの水蒸気量）
"""
convertPv2AH(pv::Float64, patm::Float64=P_ATM) = 0.622 * pv / (patm - pv)

"""
    convertAH2Pv(ah::Float64, patm::Float64=P_ATM) -> Float64

絶対湿度から水蒸気分圧を計算。

# Arguments
- `ah`: 絶対湿度 [kg/kg']
- `patm`: 大気圧 [Pa]

# Returns
- 水蒸気分圧 [Pa]
"""
convertAH2Pv(ah::Float64, patm::Float64=P_ATM) = ah * patm / (0.622 + ah)

"""
    convertRH2AH(temp::Float64, rh::Float64, patm::Float64=P_ATM) -> Float64

相対湿度から絶対湿度を計算。
"""
convertRH2AH(temp::Float64, rh::Float64, patm::Float64=P_ATM) =
    convertPv2AH(convertRH2Pv(temp, rh), patm)

"""
    convertAH2RH(temp::Float64, ah::Float64, patm::Float64=P_ATM) -> Float64

絶対湿度から相対湿度を計算。
"""
convertAH2RH(temp::Float64, ah::Float64, patm::Float64=P_ATM) =
    convertPv2RH(temp, convertAH2Pv(ah, patm))

#=============================================================================
  微分係数
=============================================================================#

"""
    cal_DPvDT(temp::Float64, miu::Float64) -> Float64

水蒸気分圧の温度偏微分（μ一定）。

∂Pv/∂T|_μ = Pvs * (dPvs/dT / Pvs - μ/(Rv*T²)) * exp(μ/(Rv*T))
"""
function cal_DPvDT(temp::Float64, miu::Float64)
    pvs = cal_Pvs(temp)
    dpvs = cal_DPvs(temp)
    rh = exp(miu / R_VAPOR / temp)
    return dpvs * rh - pvs * miu / R_VAPOR / temp^2 * rh
end

"""
    cal_DPvDMiu(temp::Float64, miu::Float64) -> Float64

水蒸気分圧の水分化学ポテンシャル偏微分（T一定）。

∂Pv/∂μ|_T = Pvs / (Rv * T) * exp(μ/(Rv*T))
"""
function cal_DPvDMiu(temp::Float64, miu::Float64)
    pvs = cal_Pvs(temp)
    return pvs / R_VAPOR / temp * exp(miu / R_VAPOR / temp)
end

"""
    cal_drh_dmiu(temp::Float64, miu::Float64) -> Float64

相対湿度の水分化学ポテンシャル微分。

∂rh/∂μ = (1/(Rv*T)) * exp(μ/(Rv*T))
"""
cal_drh_dmiu(temp::Float64, miu::Float64) =
    (1.0 / R_VAPOR / temp) * exp(miu / R_VAPOR / temp)

"""
    cal_dah_dpv(pv::Float64, patm::Float64=P_ATM) -> Float64

絶対湿度の水蒸気分圧微分。

∂ah/∂Pv = 0.622 * Patm / (Patm - Pv)²
"""
cal_dah_dpv(pv::Float64, patm::Float64=P_ATM) =
    0.622 * patm / (patm - pv)^2

"""
    cal_dah_drh(temp::Float64, rh::Float64, patm::Float64=P_ATM) -> Float64

絶対湿度の相対湿度微分。

∂ah/∂rh = 0.622 * Pvs * Patm / (Patm - Pvs*rh)²
"""
function cal_dah_drh(temp::Float64, rh::Float64, patm::Float64=P_ATM)
    pvs = cal_Pvs(temp)
    return 0.622 * pvs * patm / (patm - pvs * rh)^2
end

end # module
