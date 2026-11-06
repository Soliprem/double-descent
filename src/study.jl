const PREFIX_RATIOS = (0.1, 0.25, 0.5, 0.75, 0.9, 1.1, 1.25, 1.5, 2, 3, 5, 10, 20)
const DESIGN_FACTORS = (:n, :overparam, :spectrum, :signal, :signs, :n_active, :snr)
# `p` follows from `n` and `overparam`, and `rho` and `n_factors` from `spectrum`.
const SCENARIO_FIELDS = (DESIGN_FACTORS..., :p, :rho, :n_factors)
const OUTCOMES = (
    :signal_r2, :bias2, :variance,
    :coef_r2, :attenuation, :cosine, :sign_agreement, :top_precision, :factor_cosine,
    :type1_noise, :power_noise, :coverage_noise,
    :type1_total, :power_total, :coverage_total,
)
# `noise_inflation` is derived per scenario from min-norm's median `variance`, not per fit.
const SCENARIO_OUTCOMES = (OUTCOMES..., :noise_inflation)

"""
    study_grid(; n, overparam, spectra, signals, signs, snrs, n_active)

Full factorial grid. Each spectrum is `(rho, n_factors)`.
"""
function study_grid(; n=100, overparam=(2, 5, 20),
    spectra=((0.0, 1), (0.3, 5), (0.7, 5), (0.3, 50), (0.7, 50)),
    signals=SIGNALS, signs=SIGN_PATTERNS, snrs=(1.0, 4.0, 16.0), n_active=10)
    return [Scenario(; n, p=n * ratio, rho, n_factors, signal, signs=pattern, n_active, snr)
            for ratio in overparam
            for (rho, n_factors) in spectra
            for signal in signals
            for pattern in signs
            for snr in snrs]
end

spectrum_label(s::Scenario) = iszero(s.rho) ? "isotropic" : "rho=$(s.rho) K=$(s.n_factors)"

scenario_fields(s::Scenario) = (;
    n=s.n, p=s.p, overparam=s.p / s.n, spectrum=spectrum_label(s), rho=s.rho,
    n_factors=s.n_factors, signal=s.signal, signs=s.signs, n_active=s.n_active, snr=s.snr,
)

"""Prediction and coefficient quality, comparable across all estimators."""
fit_quality(coefficients, data) = merge((; signal_r2=signal_r2(coefficients, data)),
    coefficient_quality(coefficients, data))

"""Min-norm risk along nested feature prefixes, the double-descent curve."""
function descent_curve(data, run_fields)
    n, p = size(data.X)
    # Sample densely around the interpolation threshold, where risk can spike.
    sizes = [round.(Int, n .* PREFIX_RATIOS)..., (n - 2):(n + 2)..., p]
    prefixes = filter(k -> 1 <= k <= p, unique(sort(sizes)))
    return map(prefixes) do k
        X = data.X[:, 1:k]
        pseudoinverse = pinv(X)
        coefficients = pseudoinverse * data.y
        prefix_fit = (;
            k, train_mse=mean(abs2, X * coefficients - data.y),
            excess_risk=excess_risk(coefficients, data),
        )
        merge(run_fields, prefix_fit, risk_decomposition(pseudoinverse, data))
    end
end

"""Fit min-norm and every benchmark to one draw of one scenario."""
function fit_scenario(s::Scenario, seed)
    data = simulate(s, seed)
    share = signal_share(data.covariance, data.beta)
    run_fields = merge(scenario_fields(s), (; seed, signal_share=share))

    pseudoinverse = pinv(data.X)
    minnorm_coefficients = pseudoinverse * data.y
    minnorm_only = merge(risk_decomposition(pseudoinverse, data),
        coefficient_tests(pseudoinverse, minnorm_coefficients, data))
    not_applicable = map(_ -> NaN, minnorm_only)

    fit_row(estimator, coefficients, extras) =
        merge(run_fields, (; estimator), fit_quality(coefficients, data), extras)
    fits = [fit_row(:minnorm, minnorm_coefficients, minnorm_only)]
    for (name, coefficients) in pairs(benchmarks(data, seed))
        push!(fits, fit_row(name, coefficients, not_applicable))
    end
    return (; fits, curve=descent_curve(data, run_fields))
end

"""Rows that agree on the fields `by`, as a vector of groups in first-seen order."""
function group_rows(rows, by)
    groups = Dict{Any,Vector{eltype(rows)}}()
    order = []
    for row in rows
        key = row[by]
        haskey(groups, key) || push!(order, key)
        push!(get!(groups, key, eltype(rows)[]), row)
    end
    return [groups[key] for key in order]
end

"""Finite values of a field; undefined metrics are NaN and dropped from summaries."""
finite_values(rows, field) = filter(isfinite, [Float64(row[field]) for row in rows])

function quartiles(rows, field)
    values = finite_values(rows, field)
    isempty(values) && return (NaN, NaN, NaN)
    return (quantile(values, 0.25), median(values), quantile(values, 0.75))
end

median_of(rows, field) = quartiles(rows, field)[2]

"""Median of each outcome per scenario and estimator, and quartiles of the headline two."""
function summarise_fits(fits)
    group_fields = (SCENARIO_FIELDS..., :estimator)
    return map(group_rows(fits, group_fields)) do rows
        share = (; signal_share=median_of(rows, :signal_share))
        medians = NamedTuple{OUTCOMES}(map(field -> median_of(rows, field), OUTCOMES))
        low_r2, _, high_r2 = quartiles(rows, :signal_r2)
        low_cosine, _, high_cosine = quartiles(rows, :cosine)
        headline_quartiles = (;
            signal_r2_q25=low_r2, signal_r2_q75=high_r2,
            cosine_q25=low_cosine, cosine_q75=high_cosine,
        )
        merge(first(rows)[group_fields], share, medians, headline_quartiles)
    end
end

"""Median risk per scenario and prefix size."""
function summarise_curves(curves)
    group_fields = (SCENARIO_FIELDS..., :k)
    return map(group_rows(curves, group_fields)) do rows
        low, middle, high = quartiles(rows, :excess_risk)
        risks = (;
            excess_risk=middle, excess_risk_q25=low, excess_risk_q75=high,
            bias2=median_of(rows, :bias2), variance=median_of(rows, :variance),
            train_mse=median_of(rows, :train_mse),
        )
        merge(first(rows)[group_fields], risks)
    end
end

"""
The shape of one double-descent curve. `second_descent` is true when the fully
overparameterised fit beats the best underparameterised prefix; prefixes omit part
of a randomly placed signal, so this also reflects misspecification, not only
interpolation.
"""
function curve_shape(curve)
    best_underparameterised = minimum(row.excess_risk for row in curve if row.k < row.n)
    peak = maximum(row.excess_risk for row in curve if abs(row.k - row.n) <= 2)
    final = only(row.excess_risk for row in curve if row.k == row.p)
    return (;
        best_underparameterised, peak, final,
        second_descent=final < best_underparameterised,
    )
end

"""One row per scenario: min-norm outcomes, the benchmarks, and the curve's shape."""
function scenario_table(fit_summary, curve_summary)
    curves_by_scenario = Dict(first(rows)[SCENARIO_FIELDS] => rows
                              for rows in group_rows(curve_summary, SCENARIO_FIELDS))
    return map(group_rows(fit_summary, SCENARIO_FIELDS)) do rows
        fit_of(name) = only(filter(row -> row.estimator == name, rows))
        minnorm_fit = fit_of(:minnorm)
        ridge, lasso, post_lasso = fit_of(:ridge), fit_of(:lasso), fit_of(:post_lasso)
        benchmark_fields = (;
            ridge_r2=ridge.signal_r2, lasso_r2=lasso.signal_r2,
            post_lasso_r2=post_lasso.signal_r2, oracle_r2=fit_of(:oracle).signal_r2,
            ridge_cosine=ridge.cosine, lasso_cosine=lasso.cosine,
            post_lasso_cosine=post_lasso.cosine,
            ridge_top_precision=ridge.top_precision,
            lasso_top_precision=lasso.top_precision,
        )
        scenario = minnorm_fit[SCENARIO_FIELDS]
        merge(scenario, (; signal_share=minnorm_fit.signal_share), minnorm_fit[OUTCOMES],
            (; noise_inflation=minnorm_fit.variance * minnorm_fit.snr),
            benchmark_fields, curve_shape(curves_by_scenario[scenario]))
    end
end

mean_or_nan(values) = isempty(values) ? NaN : mean(values)

"""Mean of each outcome over the scenarios at each level of each design factor."""
function main_effects(table, outcomes=SCENARIO_OUTCOMES)
    return [(;
                factor=design_factor, level=first(rows)[design_factor], outcome,
                mean=mean_or_nan(finite_values(rows, outcome)),
            )
            for design_factor in DESIGN_FACTORS
            for rows in group_rows(table, (design_factor,))
            for outcome in outcomes]
end

function eta_squared(table, outcome, design_factor)
    usable = filter(row -> isfinite(row[outcome]), table)
    isempty(usable) && return NaN
    grand = mean(row[outcome] for row in usable)
    total = sum((row[outcome] - grand)^2 for row in usable)
    between = sum(length(rows) * (mean(row[outcome] for row in rows) - grand)^2
                  for rows in group_rows(usable, (design_factor,)))
    return between / total
end

"""
Share of the between-scenario variance in each outcome explained by each design
factor's main effect (eta squared). Each score treats one factor at a time; the
remainder includes other factors' main effects and interactions.
"""
function factor_importance(table, outcomes=SCENARIO_OUTCOMES)
    return [(;
                outcome, factor=design_factor,
                eta_squared=eta_squared(table, outcome, design_factor),
            )
            for design_factor in DESIGN_FACTORS
            for outcome in outcomes]
end

"""Rows hold numbers and plain labels with no commas, so no CSV dependency is needed."""
function write_csv(path, rows)
    open(path, "w") do io
        println(io, join(keys(first(rows)), ','))
        foreach(row -> println(io, join(values(row), ',')), rows)
    end
end

"""
    run_study(; seeds, grid, output)

Run every scenario of `grid` (by default `study_grid()`) on every one of `seeds` (by
default `1:20`), then write the results and figures to `output` (by default
`outputs/benign_overfitting/` in the repository). Parallel over the Julia threads, so
start Julia with `-t auto`.
"""
function run_study(; seeds=1:20, grid=study_grid(),
    output=joinpath(dirname(@__DIR__), "outputs", "benign_overfitting"))
    # Each thread runs whole fits, so BLAS threads would only compete with them.
    BLAS.set_num_threads(1)
    runs = vec(collect(Iterators.product(grid, seeds)))
    println("Fitting $(length(grid)) scenarios on $(length(seeds)) seeds ",
        "with $(Threads.nthreads()) threads")
    results = Vector{Any}(undef, length(runs))
    Threads.@threads for i in eachindex(runs)
        results[i] = fit_scenario(runs[i]...)
    end

    fits = reduce(vcat, [result.fits for result in results])
    curves = reduce(vcat, [result.curve for result in results])
    fit_summary = summarise_fits(fits)
    curve_summary = summarise_curves(curves)
    table = scenario_table(fit_summary, curve_summary)

    mkpath(output)
    write_csv(joinpath(output, "fits.csv"), fits)
    write_csv(joinpath(output, "fit_summary.csv"), fit_summary)
    write_csv(joinpath(output, "curves.csv"), curve_summary)
    write_csv(joinpath(output, "scenarios.csv"), table)
    write_csv(joinpath(output, "main_effects.csv"), main_effects(table))
    write_csv(joinpath(output, "factor_importance.csv"), factor_importance(table))
    save_figures(output, table, curve_summary)
    println("Saved results to $output")
    return (; fits, curves, fit_summary, curve_summary, table)
end
