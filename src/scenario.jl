const SIGNALS = (:sparse, :grouped, :dense)
const SIGN_PATTERNS = (:aligned, :contrast)

"""
    Scenario(; n, p, rho, n_factors, signal, signs, n_active, snr)

One point of the design space.

- `n`, `p`: training observations and available features.
- `rho`, `n_factors`: features are unit-variance and load on one of `n_factors`
  latent factors with within-factor correlation `rho`. The covariance has about
  `n_factors` spikes of size `1 - rho + rho * p / n_factors` above a tail of
  `p - n_factors` eigenvalues equal to `1 - rho`.
- `signal`: where effects sit. `:sparse` scatters `n_active` features at random,
  `:grouped` packs them into as few factors as possible, `:dense` uses all of `p`.
- `signs`: `:aligned` makes every effect positive, which loads the signal on the
  spikes. `:contrast` alternates signs within each factor, which cancels the loading
  of factors holding an even number of active features: `:dense` and `:grouped`
  signals with even counts sit in the tail, while `:sparse` can keep part of its signal
  on the spikes.
- `snr`: signal variance over noise variance. Signal variance is always one.
"""
Base.@kwdef struct Scenario
    n::Int = 100
    p::Int = 2000
    rho::Float64 = 0.0
    n_factors::Int = 1
    signal::Symbol = :sparse
    signs::Symbol = :aligned
    n_active::Int = 10
    snr::Float64 = 4.0

    function Scenario(n, p, rho, n_factors, signal, signs, n_active, snr)
        n > 0 && p > 0 || throw(ArgumentError("n and p must be positive"))
        0 <= rho < 1 || throw(ArgumentError("rho must be in [0, 1)"))
        1 <= n_factors <= p || throw(ArgumentError("n_factors must be in 1:p"))
        signal in SIGNALS || throw(ArgumentError("unknown signal: $signal"))
        signs in SIGN_PATTERNS || throw(ArgumentError("unknown signs: $signs"))
        1 <= n_active <= p || throw(ArgumentError("n_active must be in 1:p"))
        snr > 0 || throw(ArgumentError("snr must be positive"))
        return new(n, p, rho, n_factors, signal, signs, n_active, snr)
    end
end

"""Eigenstructure of the population covariance, in the terms of Bartlett et al."""
function spectrum(s::Scenario)
    iszero(s.rho) && return (; spike=1.0, n_spikes=0, tail_rank=s.p)
    return (;
        spike=1 - s.rho + s.rho * s.p / s.n_factors, n_spikes=s.n_factors,
        tail_rank=s.p - s.n_factors,
    )
end

"""Block covariance `(1 - rho) * I + rho * Σ_g 1_g 1_g'` of the features."""
struct BlockCovariance
    rho::Float64
    factor_of::Vector{Int}
    n_factors::Int
end

function Base.Matrix(c::BlockCovariance)
    same_factor = c.factor_of .== permutedims(c.factor_of)
    return (1 - c.rho) * I + c.rho * same_factor
end

"""Sum of `v` within each factor. `v` may cover only the leading features."""
function factor_totals(c::BlockCovariance, v)
    totals = zeros(c.n_factors)
    for (j, value) in enumerate(v)
        totals[c.factor_of[j]] += value
    end
    return totals
end

"""`v' * covariance * v`, with any omitted trailing coordinates taken as zero."""
quadratic(c::BlockCovariance, v) =
    (1 - c.rho) * sum(abs2, v) + c.rho * sum(abs2, factor_totals(c, v))

"""Share of `beta`'s signal variance that lies along the covariance spikes."""
function signal_share(c::BlockCovariance, beta)
    sizes = [count(==(g), c.factor_of) for g in 1:c.n_factors]
    totals = factor_totals(c, beta)
    # Each factor's eigenvalue times the squared projection of `beta` on that factor.
    along_spikes = sum((1 - c.rho .+ c.rho .* sizes) .* totals .^ 2 ./ sizes)
    return along_spikes / quadratic(c, beta)
end

"""
Sorted active features: all of them if `:dense`, otherwise the first `n_active` in `order`,
taken factor by factor if `:grouped`. `order` is the shared random priority over features,
which keeps active sets paired.
"""
function active_features(s::Scenario, order, factor_of)
    s.signal == :dense && return collect(1:s.p)
    s.signal == :sparse && return sort(order[1:s.n_active])
    factor_in_order = factor_of[order]
    packed = reduce(vcat, [order[factor_in_order .== g] for g in unique(factor_in_order)])
    return sort(packed[1:s.n_active])
end

function true_coefficients(s::Scenario, covariance, active)
    beta = zeros(s.p)
    beta[active] .= 1.0
    if s.signs == :contrast
        for g in 1:s.n_factors
            members = filter(j -> covariance.factor_of[j] == g, active)
            beta[members] .= (-1.0) .^ eachindex(members)
        end
    end
    return beta ./ sqrt(quadratic(covariance, beta))
end

"""
Draw a training set. Population quantities replace a test set, so risk is exact.
Returns `(; X, y, beta, noise_std, covariance)`, the `data` that metrics and the study take.

Features are assigned to factors at random, so the leading `k` columns are a
representative subset and prefixes trace a clean path in `p`. The same seed gives
the same noise, idiosyncratic features, assignment shuffle and feature priority for
every scenario with equal `n` and `p`, which pairs scenarios across design factors.
The assignment itself also needs equal `n_factors`, since the shuffle permutes labels
that depend on it.
"""
function simulate(s::Scenario, seed)
    # `factors` changes size between scenarios, so it is drawn last to keep them paired.
    rng = Xoshiro(seed)
    noise = randn(rng, s.n)
    idiosyncratic = randn(rng, s.n, s.p)
    factor_of = shuffle(rng, mod1.(1:s.p, s.n_factors))
    order = randperm(rng, s.p)
    factors = randn(rng, s.n, s.n_factors)

    covariance = BlockCovariance(s.rho, factor_of, s.n_factors)
    beta = true_coefficients(s, covariance, active_features(s, order, factor_of))
    X = sqrt(1 - s.rho) .* idiosyncratic .+ sqrt(s.rho) .* factors[:, factor_of]
    noise_std = sqrt(1 / s.snr)
    return (; X, y=X * beta + noise_std * noise, beta, noise_std, covariance)
end
