"""
When does minimum-norm interpolation overfit benignly, and when can its
coefficients be read? See the README for the design and the metrics.
"""
module DoubleDescent

using GLMNet, LinearAlgebra, Plots, Random, Statistics

export Scenario, BlockCovariance, simulate, quadratic, signal_share, spectrum
export minnorm, ridge_cv, post_lasso_cv, benchmarks
export excess_risk, signal_r2, risk_decomposition, coefficient_quality, coefficient_tests
export study_grid, fit_scenario, run_study

include("scenario.jl")
include("estimators.jl")
include("metrics.jl")
include("study.jl")
include("figures.jl")

end
