# Minimum-norm regression and benign overfitting

If we parametrise the data-generating process, which characteristics let the
minimum-norm interpolator predict well, and which also let its coefficients be
read for inference?

```sh
nix develop
export GKSwstype=100
julia --startup-file=no -t auto src/run_study.jl
julia --startup-file=no -t auto test/runtests.jl
```

The study takes about five minutes on 24 threads and writes to
`outputs/benign_overfitting/`. Grids can be changed from Julia:

```julia
include("src/DoubleDescent.jl"); using .DoubleDescent
run_study(; seeds=1:5, grid=study_grid(; n=50, overparam=(2, 10), snrs=(4.0,)))
```

(The earlier teaching experiments, and their README, are in `learning/`.)

## Design

A full factorial of 270 scenarios over 20 seeds, with `n=100` and 10 active features
unless the signal is dense. Features have unit variance and load on one of `K`
factors with within-factor correlation `rho`, which gives `K` spikes over a flat tail.
Signal variance is always one.

| Factor | Levels |
| --- | --- |
| Overparameterisation `p/n` | 2, 5, 20 |
| Spectrum `(rho, K)` | isotropic, (0.3, 5), (0.7, 5), (0.3, 50), (0.7, 50) |
| Support | `sparse` (scattered), `grouped` (as few factors as possible), `dense` |
| Signs | `aligned` (all positive, loads on the spikes), `contrast` (alternating within factors, cancels that loading) |
| SNR | 1, 4, 16 |

Risk is computed exactly from the population covariance, so there is no test set.
Benchmarks are ridge, lasso and post-lasso (all five-fold CV) and OLS on the true
support. The ridge grid reaches the min-norm limit, so that comparison is nested.

| Metric | Meaning |
| --- | --- |
| `signal_r2` | Share of the signal recovered: one is perfect, zero matches predicting zero |
| `bias2`, `variance` | Expected excess risk given the features; benign overfitting means `variance` vanishes |
| `signal_share` | Share of the signal variance lying along the spikes |
| `cosine`, `attenuation`, `sign_agreement` | Direction, scale and signs of the coefficients against the truth |
| `top_precision` | Share of the largest `s` coefficients that are truly active |
| `factor_cosine` | `cosine` of the within-factor totals, what correlated features can still identify |
| `type1_*`, `power_*`, `coverage_*` | 95% tests and intervals, scaled by the true noise (`noise`) or the spread of `y` (`total`) |

## Results

All values are medians over seeds. `scenarios.csv` has one row per scenario,
`factor_importance.csv` the share of variance each factor explains.

### Prediction

Benign and useful are separate conditions. Variance disappears almost everywhere
as `p/n` grows: it inflates noise by 1.01 at `p/n=2` and 0.05 at `p/n=20` under
isotropy, and tracks Bartlett et al.'s `k/n + n/R_k` where the spikes are clearly
separated (0.104 against 0.10 at `rho=0.7, K=5, p/n=20`). What remains is bias, and
bias depends on where the signal sits, because min-norm only learns what lies on the
spikes. At `p/n=20` and SNR 4, `signal_r2` correlates 0.94 with `signal_share`.

| `p/n=20`, SNR 4 | `signal_r2` | Lasso | Why |
| --- | --- | --- | --- |
| `rho=0.7, K=5`, dense, aligned | 0.975 | 0.922 | All signal on few strong spikes |
| `rho=0.7, K=5`, grouped, aligned | 0.932 | 0.919 | |
| `rho=0.7, K=5`, sparse, aligned | 0.830 | 0.818 | |
| `rho=0.7, K=5`, sparse, contrast | 0.309 | 0.504 | About a third of the signal on the spikes |
| Isotropic, sparse | 0.036 | 0.396 | Variance is harmless, but so is the fit: it finds about `n/p` of the signal |
| `rho=0.7, K=5`, dense, contrast | -0.010 | 0.000 | All signal in the tail |
| `rho=0.7, K=50`, dense, contrast | -0.440 | 0.000 | All signal in the tail, and bias exceeds one |

So the recipe is few factors (`K` well below `n`), signal aligned with them, and `p`
well above `n`. Interpolation itself then costs almost nothing: at `p/n=20`, 78% of
scenarios are within 0.05 of tuned ridge and none beats it by more. It does cost at
low `p/n` and low SNR (a median of 0.70 at `p/n=2`, SNR 1), and when the signal is in
the tail of a correlated design, where ridge shrinks to zero and min-norm cannot. 23
of the 90 scenarios at `p/n=20` are worse than predicting zero.

The second descent beats the best underparameterised prefix in over 90% of scenarios
at `p/n=20`. Prefixes omit part of a randomly placed signal, so this reflects
misspecification as much as any merit of interpolation.

### Coefficients

Good prediction does not imply readable coefficients, and the conditions pull apart.
Where prediction is best, individual coefficients are worst: `rho=0.7, K=5`, grouped,
aligned has `signal_r2=0.932`, `cosine=0.115` and only 10% of its top coefficients are
active. Under isotropy `cosine` follows `sqrt((n/p) * SNR / (1 + SNR))` (0.20 at
`p/n=20`, SNR 4), so the overparameterisation that removes variance also removes
coefficient direction. Min-norm spreads an effect evenly over correlated features,
and that is the mechanism: 10 active features out of a factor of 400 become 400 small
coefficients.

Three things are readable anyway.

- **Factor totals.** `factor_cosine` is 0.95 to 0.995 at `rho=0.7, K=5` and SNR 4,
  including where individual coefficients fail. It is weaker at `K=50` (0.58 to 0.91).
- **Effects spread over whole factors.** There min-norm's even spreading is correct.
  At `rho=0.7, K=50`, `p/n=5`, grouped, aligned, the 10 active features are exactly one
  factor: `signal_r2=0.771`, `cosine=0.594`, `top_precision=1` at SNR 4. At `p/n=20` they
  are 10 of 40 and `cosine` falls to 0.334. All 18 scenarios with `signal_r2 >= 0.7` and
  `cosine >= 0.5` have aligned signs.
- **Signs, on sparse signals.** `sign_agreement` averages 0.99, against 0.68 on dense
  ones. Min-norm never sets an effect to zero, while lasso's 0.75 at `rho=0.7, K=5` counts
  every effect it dropped as wrong.

Naive inference fails. Scaling by the true noise ignores leakage from other effects:
under isotropy at `p/n=20`, false rejection at a nominal 0.05 is 0.37 at SNR 4 and 0.63 at
SNR 16, matching `P(|N(0, 1 + SNR)| > 1.96)` (0.38 and 0.64). Scaling by the spread of `y`
needs no noise estimate, which matters since interpolation leaves no residuals to estimate
it from, and it holds the level in every scenario (at most 0.047). It is conservative, and
power is highest where prediction is worst: on average at `p/n=20`, 0.76 under isotropy
against 0.35 at `rho=0.7, K=5`. Intervals are less reliable: average coverage at `p/n=20` falls
to 0.76 at `rho=0.7, K=50`, and to 0.5 in the whole-factor case above even though its tests
reject correctly. Per-test control does not mean few false discoveries either: under isotropy
at `p/n=20`, 0.04 of 1,990 nulls is about 80 false rejections, against about 8 true ones.

For individual coefficients on sparse signals, lasso remains the better tool (`cosine`
0.87 against 0.40 under isotropy at SNR 4, median over `p/n`). I would read min-norm at
the level of factors, and at the level of features only when effects plausibly spread
over whole factors.

(These hold for `n=100`, equal factor sizes and equal effect sizes. `n` and the number of
active features are parameters of the grid, but are not varied here. Outside isotropy, the
`total` scale is supported by this simulation only.)

## References

- [Bartlett et al., *Benign Overfitting in Linear Regression*](https://arxiv.org/abs/1906.11300)
- [Hastie et al., *Surprises in High-Dimensional Ridgeless Least Squares Interpolation*](https://arxiv.org/abs/1903.08560)
