using Random, LinearAlgebra

"""
    synthetic_data(seed; kind=:sparse, rho=0.0, ...)

Gaussian regression with sparse, dense, or group-sparse coefficients. Groups are
contiguous blocks of `group_size` features with within-group correlation `rho`.
Sparse and group-sparse signals have exactly `n_active` nonzero coefficients;
group-sparse signals activate whole groups. All effects are positive and scaled
so the population signal variance beta' * covariance * beta is `signal_std^2`.
Support locations are random, never ordered using the test outcomes.
"""
function synthetic_data(seed; kind=:sparse, rho=0.0, n_train=40, n_test=2000,
    p_max=160, n_active=10, group_size=5, signal_std=1.0, noise_std=0.5)
    kind in (:sparse, :dense, :group_sparse) || throw(ArgumentError("Unknown signal kind: $kind"))
    0 <= rho < 1 || throw(ArgumentError("rho must be in [0, 1)"))
    n_train > 0 && n_test > 0 || throw(ArgumentError("Sample sizes must be positive"))
    group_size > 0 && p_max > 0 && p_max % group_size == 0 ||
        throw(ArgumentError("p_max must be a positive multiple of group_size"))
    1 <= n_active <= p_max || throw(ArgumentError("n_active must be between 1 and p_max"))
    kind != :group_sparse || n_active % group_size == 0 ||
        throw(ArgumentError("Group-sparse n_active must be a multiple of group_size"))
    isfinite(signal_std) && signal_std > 0 || throw(ArgumentError("signal_std must be positive and finite"))
    isfinite(noise_std) && noise_std >= 0 || throw(ArgumentError("noise_std must be nonnegative and finite"))

    rng = MersenneTwister(seed)
    n_groups = p_max ÷ group_size
    groups = repeat(1:n_groups, inner=group_size)
    # Always draw both components, including at rho=0, to pair the scenarios.
    Z_train = randn(rng, n_train, p_max)
    Z_test = randn(rng, n_test, p_max)
    G_train = randn(rng, n_train, n_groups)
    G_test = randn(rng, n_test, n_groups)
    X_train = sqrt(1 - rho) .* Z_train + sqrt(rho) .* G_train[:, groups]
    X_test = sqrt(1 - rho) .* Z_test + sqrt(rho) .* G_test[:, groups]
    noise_train = noise_std .* randn(rng, n_train)
    noise_test = noise_std .* randn(rng, n_test)

    support = if kind == :dense
        collect(1:p_max)
    elseif kind == :sparse
        sort(randperm(rng, p_max)[1:n_active])
    else
        active_groups = randperm(rng, n_groups)[1:(n_active ÷ group_size)]
        findall(g -> g in active_groups, groups)
    end
    covariance = Matrix{Float64}(I, p_max, p_max) .* (1 - rho)
    for group in 1:n_groups
        columns = findall(==(group), groups)
        covariance[columns, columns] .+= rho
    end
    beta_true = zeros(p_max)
    beta_true[support] .= 1.0
    beta_true .*= signal_std / sqrt(dot(beta_true, covariance * beta_true))
    y_train = X_train * beta_true + noise_train
    y_test = X_test * beta_true + noise_test
    return (; X_train, X_test, y_train, y_test, beta_true, covariance,
        support, groups, noise_std, signal_std, kind, rho)
end

# Exact test MSE conditional on a fitted coefficient vector, with omitted
# predictors padded by zero. This includes the irreducible outcome noise.
function population_mse(coefficients, data)
    delta = -copy(data.beta_true)
    delta[1:length(coefficients)] .+= coefficients
    return data.noise_std^2 + dot(delta, data.covariance * delta)
end
