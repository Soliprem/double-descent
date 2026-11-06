# Two-sided 95% critical value of the standard normal.
const NORMAL_95 = 1.959963984540054

"""
Exact out-of-sample MSE above the noise floor. Omitted coefficients count as zero.
Signal variance is one by construction, so risks read as shares of it.
"""
function excess_risk(coefficients, data)
    delta = -copy(data.beta)
    delta[eachindex(coefficients)] .+= coefficients
    return quadratic(data.covariance, delta)
end

"""Share of the signal recovered: one is perfect, zero matches predicting zero."""
signal_r2(coefficients, data) = 1 - excess_risk(coefficients, data)

"""
Expected excess risk given the features, split into its two sources for the fit
`pseudoinverse * y`. Benign overfitting means `variance` vanishes: the fit
absorbs the noise without it reaching new predictions.
"""
function risk_decomposition(pseudoinverse, data)
    expected_coefficients = pseudoinverse * (data.X * data.beta)
    unit_noise_risk = sum(quadratic(data.covariance, column)
                          for column in eachcol(pseudoinverse))
    return (;
        bias2=excess_risk(expected_coefficients, data),
        variance=data.noise_std^2 * unit_noise_risk,
    )
end

"""Cosine of the angle between `a` and `b`. An all-zero `a` scores zero, not NaN."""
cosine(a, b) = iszero(a) ? 0.0 : dot(a, b) / (norm(a) * norm(b))

"""
How far `coefficients` can be read as the true effects.

- `coef_r2`: `1 - |coefficients - beta|² / |beta|²`; zero matches reporting all zeros.
- `attenuation`: slope of `coefficients` on `beta`; about `n / p` for isotropic min-norm.
- `cosine`: agreement in direction, ignoring scale.
- `sign_agreement`: share of true effects with the right sign.
- `top_precision`: share of the largest `n_active` coefficients that are truly active,
  for `n_active` true effects. Undefined for dense signals.
- `factor_cosine`: `cosine` of the within-factor totals, the quantity correlated
  features can still identify when individual effects cannot be separated.
  Undefined without correlation, or if the true totals cancel.
"""
function coefficient_quality(coefficients, data)
    beta, covariance = data.beta, data.covariance
    active_mask = .!iszero.(beta)
    n_active = count(active_mask)
    largest = partialsortperm(abs.(coefficients), 1:n_active; rev=true)
    fitted_totals = factor_totals(covariance, coefficients)
    true_totals = factor_totals(covariance, beta)
    totals_defined = covariance.rho > 0 && norm(true_totals) > sqrt(eps()) * norm(beta)
    return (;
        coef_r2=1 - sum(abs2, coefficients - beta) / sum(abs2, beta),
        attenuation=dot(coefficients, beta) / sum(abs2, beta),
        cosine=cosine(coefficients, beta),
        sign_agreement=mean(sign.(coefficients[active_mask]) .== sign.(beta[active_mask])),
        top_precision=n_active == length(beta) ? NaN : mean(active_mask[largest]),
        factor_cosine=totals_defined ? cosine(fitted_totals, true_totals) : NaN,
    )
end

"""
Per-coefficient 95% tests for the min-norm fit `coefficients = pseudoinverse * y`.

Given `X`, coefficient `j` is Gaussian with mean `P_jj beta_j + Σ_{k≠j} P_jk beta_k`,
for the row-space projection `P`, and standard deviation `noise_std * |row j of X⁺|`.
Two scales for that standard deviation are compared:

- `noise`: the true noise level, unavailable in practice since interpolation
  leaves no residuals. It ignores the sum over `k`, the leakage from other effects.
- `total`: the root mean square of `y`. Feasible, and it charges the leakage
  as noise, which is the right variance under isotropy with `p >> n`.

Rejection of `beta_j = 0` does not depend on rescaling by `P_jj`. Coverage is
of the rescaled interval around `coefficients[j] / P_jj`, the estimate with
attenuation undone.
"""
function coefficient_tests(pseudoinverse, coefficients, data)
    beta = data.beta
    active_mask = .!iszero.(beta)
    unit_se = sqrt.(vec(sum(abs2, pseudoinverse; dims=2)))
    leverage = vec(sum(pseudoinverse .* data.X'; dims=2))  # `P_jj`, since `P = X⁺X`
    function rates(scale)
        margin = NORMAL_95 .* scale .* unit_se
        rejected = abs.(coefficients) .> margin
        covered = abs.(coefficients ./ leverage .- beta) .<= margin ./ leverage
        return (;
            type1=all(active_mask) ? NaN : mean(rejected[.!active_mask]),
            power=mean(rejected[active_mask]), coverage=mean(covered[active_mask]),
        )
    end
    noise, total = rates(data.noise_std), rates(sqrt(mean(abs2, data.y)))
    return (;
        type1_noise=noise.type1, power_noise=noise.power, coverage_noise=noise.coverage,
        type1_total=total.type1, power_total=total.power, coverage_total=total.coverage,
    )
end
