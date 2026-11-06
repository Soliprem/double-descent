using Test, LinearAlgebra, Random, Statistics
isdefined(@__MODULE__, :DoubleDescent) ||
    include(joinpath(@__DIR__, "..", "src", "DoubleDescent.jl"))
using .DoubleDescent

@testset "Estimators" begin
    @testset "minnorm interpolates and has the smallest norm" begin
        data = simulate(Scenario(; n=30, p=120), 1)
        coefficients = minnorm(data.X, data.y)
        @test data.X * coefficients ≈ data.y
        null_direction = nullspace(data.X)[:, 1]
        @test norm(coefficients) < norm(coefficients + null_direction)
    end

    @testset "Ridge" begin
        s = Scenario(; n=40, p=200, rho=0.5, n_factors=5, signal=:dense, snr=1e8)
        data = simulate(s, 9)
        X, y = data.X, data.y
        folds = mod1.(1:40, 5)
        ridge_at(penalty) = only(DoubleDescent.ridge_path(X, y, [penalty]))

        @testset "the closed form agrees with the definition" begin
            for penalty in (1e-2, 1.0, 100.0)
                direct = (X' * X + penalty * I) \ (X' * y)
                @test ridge_at(penalty) ≈ direct rtol = 1e-6
            end
        end

        @testset "tiny penalties reach min-norm, huge ones shrink to zero" begin
            @test ridge_at(1e-10) ≈ minnorm(X, y) rtol = 1e-6
            @test norm(ridge_at(1e12)) < 1e-6 * norm(minnorm(X, y))
        end

        @testset "with almost no noise, tuning does at least as well as interpolating" begin
            tuned = signal_r2(ridge_cv(X, y; folds), data)
            @test tuned >= signal_r2(minnorm(X, y), data) - 1e-3
        end

        @testset "on pure noise, tuning shrinks far below the interpolating norm" begin
            noise = randn(Xoshiro(10), 40)
            @test norm(ridge_cv(X, noise; folds)) < 0.5 * norm(minnorm(X, noise))
        end
    end

    @testset "Post-lasso cross-validation" begin
        rng = Xoshiro(42)
        X = randn(rng, 12, 3)
        truth = [2.0, -1.0, 0.0]
        y = X * truth
        # Unequal folds check that losses are weighted by observation count.
        folds = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3]

        @testset "a penalty that selects nothing gives the empty model" begin
            empty_model = post_lasso_cv(X, y; folds, penalties=[1e6])
            @test isempty(empty_model.selected)
            @test isempty(empty_model.coefficients)
            @test empty_model.mean_losses[1] ≈ mean(abs2, y)
        end

        @testset "the refit recovers a noiseless signal" begin
            fit = post_lasso_cv(X, y; folds, penalties=[10.0, 1.0, 0.1, 0.01])
            coefficients = zeros(3)
            coefficients[fit.selected] = fit.coefficients
            @test coefficients ≈ truth atol = 1e-8
            @test minimum(fit.mean_losses) < 1e-16
            @test size(fit.fold_losses) == (4, 3)
        end

        @testset "a penalty whose refit would interpolate is excluded" begin
            # The identity design needs one coefficient per row to interpolate, which
            # leaves no residual degrees of freedom.
            identity_design = Matrix{Float64}(I, 12, 12)
            outcome = collect(1.0:12.0)
            balanced_folds = repeat(1:3; inner=4)
            fit = post_lasso_cv(identity_design, outcome;
                folds=balanced_folds, penalties=[1e6, 0.0])
            @test fit.mean_losses[1] ≈ mean(abs2, outcome)
            @test isinf(fit.mean_losses[2])
            @test isempty(fit.selected)
        end
    end

    @testset "Benchmarks" begin
        s = Scenario(; n=60, p=120, rho=0.3, n_factors=5, signal=:sparse, snr=16.0)
        data = simulate(s, 8)
        fits = benchmarks(data, 8)

        @testset "every benchmark covers the whole feature set" begin
            @test keys(fits) == (:ridge, :lasso, :post_lasso, :oracle)
            @test all(length(coefficients) == 120 for coefficients in fits)
        end

        @testset "the oracle fits the true active set" begin
            @test count(!iszero, fits.oracle) == 10
            @test findall(!iszero, fits.oracle) == findall(!iszero, data.beta)
            @test signal_r2(fits.oracle, data) > 0.8
        end

        @testset "the same seed gives the same fits" begin
            @test fits == benchmarks(data, 8)
        end
    end
end
