using Random, Statistics, Plots, GLMNet
include("minnorm_svd.jl")
include("post_lasso.jl")

# Exercise 3: vary the number of predictors, keeping the data and outcome fixed.
# This is a teaching experiment, not yet a replication on FRED-MD.

function run_experiment(seed)
    rng = MersenneTwister(seed)
    n_train = 40
    n_test = 2000
    p_max = 160
    noise_std = 0.5
    train_errors = Float64[]
    test_errors = Float64[]

    # randn draws independent standard normal values; rows are observations.
    X_train = randn(rng, n_train, p_max)
    X_test = randn(rng, n_test, p_max)

    # Only the first five predictors have a true effect. Their combined signal
    # variance is one. Including signal first makes the initial descent visible.
    beta_true = zeros(p_max)
    beta_true[1:5] .= 1 / sqrt(5)
    y_train = X_train * beta_true + noise_std * randn(rng, n_train)
    y_test = X_test * beta_true + noise_std * randn(rng, n_test)

    # Both CV procedures see the same five folds and the same penalty grid.
    folds = shuffle(rng, repeat(1:5, inner = n_train ÷ 5))
    cv = glmnetcv(
        X_train,
        y_train;
        alpha = 1.0,
        intercept = false,
        nfolds = 5,
        folds = folds,
    )

    beta_lasso = coef(cv)
    lasso_selections = findall(b -> b != 0.0, beta_lasso)

    post = post_lasso_cv(X_train, y_train; folds = folds, lambda = cv.lambda)
    post_predictions = X_test[:, post.selected] * post.coefficients
    post_mse = mean((post_predictions .- y_test) .^ 2)
    lasso_mse = mean((X_test * beta_lasso .- y_test) .^ 2)
    post = merge(post, (test_mse = post_mse, lasso_test_mse = lasso_mse))
    println(
        "Seed $seed: lasso selected $(length(lasso_selections)), ",
        "post-lasso selected $(length(post.selected)); ",
        "test MSE: lasso=$lasso_mse, post-lasso=$post_mse",
    )

    # Sample densely around p = n_train, where interpolation first becomes possible
    # for this Gaussian design. A single seed gives a noisy illustration;
    # later we will repeat the experiment across seeds.
    p_values = [1, 2, 5, 10, 20, 30, 38, 39, 40, 41, 42, 50, 60, 80, 120, 160]
    println("Training observations: $n_train; test observations: $n_test")
    println("p\ttrain_mse\ttest_mse")

    for p in p_values
        # TODO 1: Select the first p columns of each matrix using [:, 1:p].
        X_train_fit = X_train[:, 1:p]
        X_test_fit = X_test[:, 1:p]
        # TODO 2: Fit minnorm_svd using only the training matrix and y_train.
        estimator = minnorm_svd(X_train_fit, y_train)
        # TODO 3: Predict the training and test outcomes by matrix multiplication.
        # ? Not sure what you're asking here. This is my best guess
        estimated_y = X_train_fit * estimator
        predicted_y = X_test_fit * estimator
        # TODO 4: Compute each MSE: mean((prediction .- outcome) .^ 2).
        train_MSE = mean((estimated_y .- y_train) .^ 2)
        test_MSE = mean((predicted_y .- y_test) .^ 2)
        # TODO 5: Print p and the two errors, separated by '\t'.
        push!(train_errors, train_MSE)
        push!(test_errors, test_MSE)
        println("p: $p \t train_MSE: $train_MSE \t test_MSE: $test_MSE")
    end
    return p_values, train_errors, test_errors, n_train, lasso_selections, post
end

function plot_experiments()
    p_values, train_errors, test_errors, n_train, lasso_selections, post =
        run_experiment(2000)
    # Keep the raw MSEs for comparisons; logarithms are only for plotting.
    rows = [(
        seed = 2000,
        post = post.test_mse,
        lasso = post.lasso_test_mse,
        minnorm = last(test_errors),
        oracle = test_errors[findfirst(==(5), p_values)],
    )]
    curve_sum = copy(test_errors)
    fig = plot(
        p_values,
        log.(test_errors);
        label = "Test (seed 2000)",
        xlabel = "Number of Predictors",
        ylabel = "Log test mean squared error",
    )
    lasso = scatter(
        [2000],
        [length(lasso_selections)];
        label = "Lasso CV",
        color = :steelblue,
        xlabel = "Seed",
        ylabel = "Number of selected predictors",
    )
    scatter!(
        lasso,
        [2000],
        [length(post.selected)];
        label = "Post-lasso CV",
        color = :orange,
    )

    for seed = 2001:2019
        p_values, train_errors, test_errors, n_train, lasso_selections, post =
            run_experiment(seed)
        push!(
            rows,
            (
                seed = seed,
                post = post.test_mse,
                lasso = post.lasso_test_mse,
                minnorm = last(test_errors),
                oracle = test_errors[findfirst(==(5), p_values)],
            ),
        )
        curve_sum .+= test_errors
        @assert length(train_errors) == length(test_errors) == length(p_values)
        plot!(
            fig,
            p_values,
            log.(test_errors);
            label = false,
            linealpha = 0.5,
            linewidth = 0.5,
        )
        scatter!(
            lasso,
            [seed],
            [length(lasso_selections)];
            label = false,
            color = :steelblue,
        )
        scatter!(lasso, [seed], [length(post.selected)]; label = false, color = :orange)
    end

    vline!(fig, [n_train]; label = "p = n", linestyle = :dash, linewidth = 0.2)
    hline!(lasso, [5]; label = "True count", linestyle = :dash)
    output = joinpath(dirname(@__DIR__), "outputs")
    mkpath(output)
    savefig(fig, joinpath(output, "synthetic_double_descent.png"))
    savefig(lasso, joinpath(output, "lasso_selection_counts.png"))

    # Every seed compares models fitted on the same training and test data.
    # p=160 is a fixed benchmark; we do not choose p by minimizing test MSE.
    @assert last(p_values) == 160
    comparison = plot(
        p_values,
        curve_sum ./ length(rows);
        label = "Minimum-norm regression",
        marker = :circle,
        xlabel = "Number of predictors",
        ylabel = "Mean test MSE (log scale)",
        yscale = :log10,
        title = "Average over $(length(rows)) seeds",
    )
    hline!(
        comparison,
        [mean(r.post for r in rows)];
        label = "Post-lasso CV",
        color = :orange,
    )
    hline!(comparison, [mean(r.lasso for r in rows)]; label = "Lasso CV", linestyle = :dash)
    vline!(comparison, [n_train]; label = "p = n", color = :gray, linestyle = :dot)
    savefig(comparison, joinpath(output, "mse_comparison.png"))

    open(joinpath(output, "mse_comparison.csv"), "w") do io
        println(io, "seed,post_lasso_mse,lasso_mse,minnorm_p160_mse,oracle_p5_mse")
        for row in rows
            println(io, join(values(row), ','))
        end
    end
    println("\nMean test MSE over $(length(rows)) seeds:")
    println("Post-lasso CV: ", mean(r.post for r in rows))
    println("Lasso CV: ", mean(r.lasso for r in rows))
    println("Minimum norm (p=160): ", mean(r.minnorm for r in rows))
    println("Oracle OLS (p=5): ", mean(r.oracle for r in rows))
    println(
        "Post-lasso beats p=160 in ",
        count(r -> r.post < r.minnorm, rows),
        " of $(length(rows)) seeds.",
    )
    return fig, lasso, comparison
end

fig, lasso, comparison = plot_experiments()
display(fig)
display(lasso)
display(comparison)


# Run after completing the loop:
# nix develop -c julia --startup-file=no src/double_descent.jl
# Before running: predict how training error changes when p reaches 40.
# The noisy test curve need not decrease at every step beyond that point.
