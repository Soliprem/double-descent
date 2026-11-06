# Minimum-norm regression and double descent

Run the synthetic comparison with the Julia environment supplied by the flake:

```sh
nix develop
export GKSwstype=100 OPENBLAS_NUM_THREADS=1
julia --startup-file=no learning/synthetic_comparison.jl
```

The experiment crosses three coefficient structures with two feature designs:

| Signal | Nonzero coefficients | Locations |
| --- | --- | --- |
| Sparse | 10 out of 160 | Random individual features |
| Dense | 160 out of 160 | All features |
| Group-sparse | 10 out of 160 | Two random complete groups of five |

Features are Gaussian, with either independent columns (`rho=0`) or correlation
`rho=0.7` within each group of five and zero correlation between groups. All
nonzero effects are positive. In the correlated case this aligns grouped signals
with the common group factors; other sign patterns are a separate experiment.
Each signal is scaled using the **population covariance**, so its variance is
exactly 1 in every scenario. Outcome noise has standard deviation 0.5 (SNR = 4).

Each seed uses 40 training and 2,000 test observations. Minimum-norm regression
fits nested feature prefixes from 1 to 160 predictors, densely sampled around
`p=n=40`. The full data and outcomes stay fixed as predictors are added. Support
locations are random; active features are not placed first. Consequently an
initial descent is not guaranteed, even when a peak appears near interpolation.
The earlier signal-first teaching experiment remains in `learning/double_descent.jl`.

Lasso and post-lasso use all 160 predictors and training-only five-fold CV with
shared folds and penalty grids. They are fixed benchmarks rather than fits at
each point of the minimum-norm curve. This comparison does not fit group lasso.
Across scenarios, seeds pair the underlying Gaussian draws, noise, and CV folds.

Results are saved under `outputs/synthetic_comparison/`:

- `comparison.png`: six panels with median population test MSE and the 25–75%
  range over 20 seeds, plus median lasso and post-lasso benchmarks.
- `curves.csv`: every seed and predictor count, with training MSE, empirical test
  MSE, and exact population test MSE.
- `summary.csv`: means, medians, and quartiles of the minimum-norm risks.
- `benchmarks.csv`: per-seed lasso and post-lasso errors and selection counts.

Population test MSE is `noise_std^2 + (b - beta)' * covariance * (b - beta)`,
with omitted coefficients padded by zero. It averages over new features and
outcome noise conditional on the training fit, eliminating finite test-sample
noise. The empirical test MSE is retained for comparison. Medians and quartiles
make the typical curve visible; arithmetic means near `p=n` can be dominated by
rare nearly singular fits and should not be read as stable population averages.

For isotropic Gaussian features, full-model minimum-norm risk is invariant to
rotations of a fixed-norm signal. Sparsity alone therefore should not create a
systematic full-model difference in the independent-feature cases; finite-seed
curves and prefixes can still differ. Correlation changes that geometry. See
[Hastie et al., *Surprises in High-Dimensional Ridgeless Least Squares Interpolation*](https://arxiv.org/abs/1903.08560).

Parameters can be changed from Julia without editing the scripts:

```julia
include("learning/synthetic_comparison.jl")
result = run_synthetic_comparison(
    seeds=1:100,
    correlations=(0.0, 0.3, 0.7),
    n_train=60,
    p_values=[5, 10, 20, 40, 58, 59, 60, 61, 62, 80, 120, 160],
    n_active=20,
    group_size=5,
)
```

`p_max` must be divisible by `group_size`; `n_active` must also be divisible by
`group_size` for group-sparse signals. Change `p_values` when changing `p_max` or
when studying a different interpolation threshold. `rho` must be below 1 to keep
the covariance positive definite.
