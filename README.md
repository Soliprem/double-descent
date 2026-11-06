# Minimum-norm regression and benign overfitting

A model can interpolate noisy data and still predict well. What has to be true
for this to happen, and how much can we then read into its coefficients?

This is a Julia simulation study of those two questions. It varies the number of
features, their correlation structure, and the placement and signs of the
signal, comparing minimum-norm regression with ridge, lasso, post-lasso and OLS
on the true support. Prediction risk is computed from the population covariance.

## What comes out of it

Overparameterisation makes the contribution of noise small, but bias remains.

Prediction (as expected) works best when the signal lies along a few strong
factors: at `p/n=20` and SNR 4, a dense signal aligned with five strongly
correlated factors recovers 97.5% of the signal. A sparse signal with
independent features recovers 3.6%. Both interpolate.

The coefficients tell a different story: minimum-norm spreads an effect across
correlated features, so good prediction can coexist with poor identification of
the active ones. Factor totals remain readable in these cases; individual
coefficients are more useful when effects actually spread over whole factors.
For sparse individual effects, lasso remains the better tool in this study.

Inference needs its own care. Scaling tests by the true noise ignores signal
leakage and gives too many false rejections. Scaling by the spread of the
outcome controls the per-test error rate in these simulations, though interval
coverage and false discoveries remain problems.

(The study fixes `n=100`, with equal factor sizes and equal effect sizes. These
results do not establish what happens outside that design.)

The [full study notes](src/README.md) contain the design, metrics, numerical
comparisons and references. Earlier teaching experiments are in
[learning/](learning/README.md).

## Run it

From the repository root, using the Julia environment supplied by the Nix flake:

```sh
nix develop
export GKSwstype=100
julia --startup-file=no -t auto src/run_study.jl
julia --startup-file=no -t auto test/runtests.jl
```

The default grid runs 270 scenarios over 20 seeds and writes to
`outputs/benign_overfitting/`. It takes about five minutes on 24 threads. For a
smaller run, change the grid from Julia:

```julia
include("src/DoubleDescent.jl"); using .DoubleDescent
run_study(; seeds=1:5, grid=study_grid(; n=50, overparam=(2, 10), snrs=(4.0,)))
```
