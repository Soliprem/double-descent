using Test, Random, LinearAlgebra, Statistics
include(joinpath(@__DIR__, "..", "src", "minnorm_svd.jl"))
include(joinpath(@__DIR__, "..", "src", "post_lasso.jl"))

@testset "Post-lasso cross-validation" begin
    rng = MersenneTwister(42)
    X = randn(rng, 12, 3)
    truth = [2.0, -1.0, 0.0]
    y = X * truth
    # Unequal folds check that losses are weighted by observation count.
    folds = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3]

    empty_model = post_lasso_cv(X, y; folds=folds, lambda=[1e6])
    @test isempty(empty_model.selected)
    @test isempty(empty_model.coefficients)
    @test empty_model.meanloss[1] ≈ mean(y .^ 2)

    fit = post_lasso_cv(X, y; folds=folds, lambda=[10.0, 1.0, 0.1, 0.01])
    coefficients = zeros(3)
    coefficients[fit.selected] = fit.coefficients
    @test coefficients ≈ truth atol=1e-8
    @test minimum(fit.meanloss) < 1e-16
    @test size(fit.fold_losses) == (4, 3)

    # At lambda=0, the identity design needs one coefficient per training row
    # to interpolate a nonconstant outcome. That refit has no residual degrees
    # of freedom. A constant outcome is a degenerate case for glmnet's scaling.
    identity_design = Matrix{Float64}(I, 12, 12)
    identity_outcome = collect(1.0:12.0)
    fit = post_lasso_cv(identity_design, identity_outcome;
        folds=repeat(1:3, inner=4), lambda=[1e6, 0.0],
    )
    @test fit.meanloss[1] ≈ mean(identity_outcome .^ 2)
    @test isinf(fit.meanloss[2])
    @test isempty(fit.selected)
end
