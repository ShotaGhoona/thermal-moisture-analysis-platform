function cal_WDR_at_wall(Rh::Float64, U::Float64, θ::Float64, α::Float64 = 0.222)
    return α * U * Rh * cos(θ)
end
cal_WDR_at_wall(; Rh::Float64, U::Float64, θ::Float64, α::Float64 = 0.222) = cal_WDR_at_wall(Rh, U, θ, α)