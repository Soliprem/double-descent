using Statistics, Plots, GLMNet
using Plots.PlotMeasures: mm
include("synthetic_data.jl")
include("minnorm_svd.jl")
include("post_lasso.jl")

"""Fit a nested minimum-norm curve and full-feature CV benchmarks on one dataset."""
function compare_synthetic(seed; p_values=[1, 2, 5, 10, 20, 30, 38, 39, 40, 41,
    42, 50, 60, 80, 120, 160], kwargs...)
    data = synthetic_data(seed; kwargs...)
    n_train, p_max = size(data.X_train)
    !isempty(p_values) && issorted(p_values) && all(p -> 1 <= p <= p_max, p_values) ||
        throw(ArgumentError("p_values must be nonempty, sorted, and within 1:p_max"))
    n_train >= 5 || throw(ArgumentError("Five-fold CV needs at least five observations"))
    curve = map(p_values) do p
        X = data.X_train[:, 1:p]
        coefficients = minnorm_svd(X, data.y_train)
        (; seed, kind=data.kind, rho=data.rho, p, n_train, p_max,
            n_active=length(data.support), group_size=count(==(1), data.groups),
            n_test=size(data.X_test, 1), signal_std=data.signal_std,
            noise_std=data.noise_std,
            train_mse=mean(abs2, X * coefficients - data.y_train),
            test_mse=mean(abs2, data.X_test[:, 1:p] * coefficients - data.y_test),
            population_mse=population_mse(coefficients, data))
    end
    # Pair the folds across scenarios and keep all model selection in training.
    folds = shuffle(MersenneTwister(seed), mod1.(1:n_train, 5))
    cv = glmnetcv(data.X_train, data.y_train;
        alpha=1.0, intercept=false, nfolds=5, folds=folds)
    lasso = coef(cv)
    post = post_lasso_cv(data.X_train, data.y_train; folds, lambda=cv.lambda)
    post_coefficients = zeros(p_max)
    post_coefficients[post.selected] = post.coefficients
    benchmarks = map((:lasso, :post_lasso), (lasso, post_coefficients)) do model, coefficients
        (; seed, kind=data.kind, rho=data.rho, model,
            n_selected=count(!iszero, coefficients),
            train_mse=mean(abs2, data.X_train * coefficients - data.y_train),
            test_mse=mean(abs2, data.X_test * coefficients - data.y_test),
            population_mse=population_mse(coefficients, data))
    end
    return (; curve, benchmarks)
end

# Rows contain numbers and fixed symbol labels, so no CSV dependency is needed.
function write_synthetic_csv(path, rows)
    open(path, "w") do io
        println(io, join(keys(first(rows)), ','))
        for row in rows
            println(io, join(values(row), ','))
        end
    end
end

"""
    run_synthetic_comparison(; seeds=2000:2019, correlations=(0.0, 0.7), ...)

Cross three coefficient structures with independent/block-correlated designs.
Save per-seed errors, summaries, full-feature CV benchmarks, and a panel plot.
The plot shows median population test MSE and its interquartile range; means
are retained in CSV because interpolation-threshold outliers can dominate them.
"""
function run_synthetic_comparison(; seeds=2000:2019, correlations=(0.0, 0.7),
    output=joinpath(dirname(@__DIR__), "outputs", "synthetic_comparison"), kwargs...)
    seeds, correlations = collect(seeds), collect(correlations)
    isempty(seeds) && throw(ArgumentError("Provide at least one seed"))
    isempty(correlations) && throw(ArgumentError("Provide at least one correlation"))
    kinds = (:sparse, :dense, :group_sparse)
    curves, benchmarks, summaries = NamedTuple[], NamedTuple[], NamedTuple[]
    panels = []
    for rho in correlations, kind in kinds
        runs = [compare_synthetic(seed; kind, rho, kwargs...) for seed in seeds]
        for run in runs
            append!(curves, run.curve)
            append!(benchmarks, run.benchmarks)
        end
        p_values = [row.p for row in first(runs).curve]
        scenario_summary = map(eachindex(p_values)) do j
            losses = [run.curve[j].population_mse for run in runs]
            (; kind, rho, p=p_values[j], n_seeds=length(seeds),
                mean_population_mse=mean(losses), median_population_mse=median(losses),
                q25_population_mse=quantile(losses, 0.25),
                q75_population_mse=quantile(losses, 0.75),
                mean_train_mse=mean(run.curve[j].train_mse for run in runs),
                mean_test_mse=mean(run.curve[j].test_mse for run in runs))
        end
        append!(summaries, scenario_summary)
        centers = [row.median_population_mse for row in scenario_summary]
        lower = centers - [row.q25_population_mse for row in scenario_summary]
        upper = [row.q75_population_mse for row in scenario_summary] - centers
        panel = plot(p_values, centers; ribbon=(lower, upper), fillalpha=0.2,
            label="Min norm (median + IQR)", yscale=:log10,
            xlabel="Number of predictors", ylabel="Population test MSE",
            title="$(replace(string(kind), '_' => ' ')); rho=$rho", legend=:topright)
        for (model, label) in ((:lasso, "Lasso CV"), (:post_lasso, "Post-lasso CV"))
            losses = [row.population_mse for run in runs for row in run.benchmarks if row.model == model]
            hline!(panel, [median(losses)]; label="$label (full p)", linestyle=:dash)
        end
        n_train = first(first(runs).curve).n_train
        noise_variance = first(first(runs).curve).noise_std^2
        vline!(panel, [n_train]; label="p = n", color=:gray, linestyle=:dot)
        if noise_variance > 0
            hline!(panel, [noise_variance]; label="Noise variance", color=:black, linestyle=:dot)
        end
        push!(panels, panel)
        println("$kind, rho=$rho: median min-norm MSE at p=$(last(p_values)) = $(last(centers))")
    end
    mkpath(output)
    positive_risks = [row.median_population_mse for row in summaries]
    append!(positive_risks, [row.population_mse for row in benchmarks])
    noise_variance = first(curves).noise_std^2
    noise_variance > 0 && push!(positive_risks, noise_variance)
    limits = (minimum(filter(>(0), positive_risks)) / 1.3,
        maximum(row.q75_population_mse for row in summaries) * 1.3)
    for panel in panels
        plot!(panel; ylims=limits, left_margin=5mm, right_margin=5mm,
            bottom_margin=8mm, top_margin=5mm)
    end
    figure = plot(panels...; layout=(length(correlations), length(kinds)),
        size=(1650, 520 * length(correlations)))
    savefig(figure, joinpath(output, "comparison.png"))
    write_synthetic_csv(joinpath(output, "curves.csv"), curves)
    write_synthetic_csv(joinpath(output, "summary.csv"), summaries)
    write_synthetic_csv(joinpath(output, "benchmarks.csv"), benchmarks)
    println("Saved synthetic comparison to $output")
    return (; figure, curves, summaries, benchmarks)
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_synthetic_comparison()
end
