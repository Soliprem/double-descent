using Test, Statistics
include(joinpath(@__DIR__, "..", "src", "synthetic_data.jl"))
include(joinpath(@__DIR__, "..", "src", "minnorm_svd.jl"))

@testset "Synthetic signal structures and scaling" begin
    for rho in (0.0, 0.7), kind in (:sparse, :dense, :group_sparse)
        data = synthetic_data(42; kind, rho)
        @test length(data.support) == (kind == :dense ? 160 : 10)
        @test findall(!iszero, data.beta_true) == data.support
        @test dot(data.beta_true, data.covariance * data.beta_true) ≈ 1.0
        @test diag(data.covariance) ≈ ones(160)
        @test isposdef(data.covariance)
        @test population_mse(data.beta_true, data) ≈ 0.25
        @test population_mse(zeros(160), data) ≈ 1.25
        @test synthetic_data(42; kind, rho).y_train == data.y_train
        if kind == :group_sparse
            for group in unique(data.groups)
                @test count(!iszero, data.beta_true[data.groups .== group]) in (0, 5)
            end
        end
        # Nested least squares should interpolate once the design has full row rank.
        coefficients = minnorm_svd(data.X_train, data.y_train)
        @test data.X_train * coefficients ≈ data.y_train atol=1e-10
        @test population_mse(coefficients, data) >= 0.25
    end
    sparse = synthetic_data(42)
    dense = synthetic_data(42; kind=:dense)
    @test sparse.X_train == dense.X_train
    @test sparse.X_test == dense.X_test
    @test sparse.y_train - sparse.X_train * sparse.beta_true ≈
        dense.y_train - dense.X_train * dense.beta_true
    @test synthetic_data(42; rho=0.7).support == sparse.support
    @test_throws ArgumentError synthetic_data(42; kind=:unknown)
    @test_throws ArgumentError synthetic_data(42; rho=1.0)
    @test_throws ArgumentError synthetic_data(42; kind=:group_sparse, n_active=7)
    @test_throws ArgumentError synthetic_data(42; p_max=161)

    # Verify the generator's covariance and the population-risk calculation
    # against independent Monte Carlo outcomes, including omitted predictors.
    data = synthetic_data(123; kind=:group_sparse, rho=0.7, n_test=100_000,
        p_max=20, n_active=5)
    @test maximum(abs, cov(data.X_test) - data.covariance) < 0.025
    coefficients = [0.2, -0.1, 0.3]
    empirical = mean(abs2, data.X_test[:, 1:3] * coefficients - data.y_test)
    @test empirical ≈ population_mse(coefficients, data) rtol=0.02
end
