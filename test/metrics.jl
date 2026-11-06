using Test, LinearAlgebra, Random, Statistics
isdefined(@__MODULE__, :DoubleDescent) ||
    include(joinpath(@__DIR__, "..", "src", "DoubleDescent.jl"))
using .DoubleDescent

# Fresh features from the scenario's population, for Monte Carlo checks.
function fresh_features(s, data, n_new, rng)
    factors = randn(rng, n_new, s.n_factors)
    idiosyncratic = randn(rng, n_new, s.p)
    shared = factors[:, data.covariance.factor_of]
    return sqrt(1 - s.rho) .* idiosyncratic .+ sqrt(s.rho) .* shared
end

@testset "Metrics" begin
    @testset "exact coefficients have no risk, and predicting zero has zero signal_r2" begin
        s = Scenario(; n=30, p=60, rho=0.7, n_factors=5, signal=:grouped)
        data = simulate(s, 2)
        @test excess_risk(data.beta, data) ≈ 0 atol = 1e-12
        @test signal_r2(zeros(60), data) ≈ 0 atol = 1e-12
    end

    @testset "excess risk matches a Monte Carlo test set, with omitted features" begin
        s = Scenario(; n=30, p=60, rho=0.7, n_factors=5, signal=:grouped)
        data = simulate(s, 2)
        rng = Xoshiro(3)
        X_new = fresh_features(s, data, 200_000, rng)
        for coefficients in (minnorm(data.X, data.y), [0.2, -0.1, 0.3])
            delta = X_new[:, eachindex(coefficients)] * coefficients - X_new * data.beta
            @test mean(abs2, delta) ≈ excess_risk(coefficients, data) rtol = 0.02
        end
    end

    @testset "bias and variance sum to the expected excess risk" begin
        for k in (10, 60)
            s = Scenario(; n=30, p=60, rho=0.5, n_factors=5, signal=:sparse)
            data = simulate(s, 4)
            pseudoinverse = pinv(data.X[:, 1:k])
            noiseless_y = data.X * data.beta
            rng = Xoshiro(5)
            risks = map(1:20_000) do _
                y = noiseless_y + data.noise_std * randn(rng, 30)
                excess_risk(pseudoinverse * y, data)
            end
            (; bias2, variance) = risk_decomposition(pseudoinverse, data)
            @test mean(risks) ≈ bias2 + variance rtol = 0.02
        end
    end

    @testset "isotropic min-norm matches its closed forms" begin
        n, p, snr = 100, 2000, 4.0
        rows = map(1:20) do seed
            data = simulate(Scenario(; n, p, snr), seed)
            pseudoinverse = pinv(data.X)
            coefficients = pseudoinverse * data.y
            merge(risk_decomposition(pseudoinverse, data),
                coefficient_quality(coefficients, data),
                coefficient_tests(pseudoinverse, coefficients, data))
        end
        average(field) = mean(row[field] for row in rows)
        @test average(:variance) ≈ (1 / snr) * n / (p - n - 1) rtol = 0.05
        @test average(:bias2) ≈ 1 - n / p rtol = 0.05
        @test average(:attenuation) ≈ n / p rtol = 0.2
        # Leakage from the other effects acts as noise: naive tests see variance
        # 1 + snr, while scaling by the outcome's own spread restores the level.
        @test average(:type1_noise) ≈ 2 * (1 - 0.8096) rtol = 0.1 # Φ(1.96/√(1 + snr))
        @test average(:type1_total) ≈ 0.05 atol = 0.015
    end

    @testset "coefficient quality on known inputs" begin
        data = simulate(Scenario(; n=30, p=120, rho=0.5, n_factors=5, signal=:sparse), 6)

        @testset "the true effects score perfectly" begin
            perfect = coefficient_quality(data.beta, data)
            @test perfect.coef_r2 ≈ 1
            @test perfect.attenuation ≈ 1
            @test perfect.cosine ≈ 1
            @test perfect.sign_agreement == 1
            @test perfect.top_precision == 1
            @test perfect.factor_cosine ≈ 1
        end

        @testset "an all-zero fit scores zero" begin
            zero_fit = coefficient_quality(zeros(120), data)
            @test zero_fit.coef_r2 ≈ 0
            @test zero_fit.cosine == 0
            @test zero_fit.factor_cosine == 0
        end

        @testset "metrics a dense uncorrelated signal cannot define are NaN" begin
            dense = simulate(Scenario(; n=30, p=120, signal=:dense), 6)
            quality = coefficient_quality(dense.beta, dense)
            tests = coefficient_tests(pinv(dense.X), minnorm(dense.X, dense.y), dense)
            @test isnan(quality.top_precision)
            @test isnan(quality.factor_cosine)
            @test isnan(tests.type1_total)
        end
    end
end
