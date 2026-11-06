"""Minimum-norm least squares. It interpolates once `X` has full row rank."""
minnorm(X, y) = pinv(X) * y

"""Ridge coefficients `(X'X + penalty * I)⁻¹ X'y` for each penalty, from one SVD."""
function ridge_path(X, y, penalties)
    F = svd(X)
    projected = F.U' * y
    return [F.V * (F.S ./ (F.S .^ 2 .+ penalty) .* projected) for penalty in penalties]
end

"""
    ridge_cv(X, y; folds)

Ridge tuned by cross-validation over a grid that reaches down to the min-norm
limit, so tuning can choose to interpolate and the comparison with min-norm is
nested. glmnet's default ridge grid stops far above that limit.
"""
function ridge_cv(X, y; folds)
    penalties = first(svdvals(X))^2 .* exp10.(range(-10, 1; length=60))
    losses = zeros(length(penalties))
    for fold in unique(folds)
        fitting, validation = folds .!= fold, folds .== fold
        for (j, coefficients) in enumerate(ridge_path(X[fitting, :], y[fitting], penalties))
            losses[j] += sum(abs2, X[validation, :] * coefficients - y[validation])
        end
    end
    return only(ridge_path(X, y, [penalties[argmin(losses)]]))
end

"""
Lasso (glmnet's `alpha=1.0`) fits for each penalty. glmnet can end the path early,
leaving the smallest penalties without a fit, so `betas` can have fewer columns.
"""
lasso_path(X, y, penalties) = glmnet(X, y; lambda=penalties, alpha=1.0, intercept=false)

"""
OLS on the nonzero set of `penalised`, or `nothing` if that set is rank deficient
or leaves no residual degrees of freedom.
"""
function refit_ols(X, y, penalised)
    selected = findall(!iszero, penalised)
    isempty(selected) && return (; selected, coefficients=Float64[])
    X_selected = X[:, selected]
    identified = length(selected) < size(X, 1) && rank(X_selected) == length(selected)
    return identified ? (; selected, coefficients=X_selected \ y) : nothing
end

"""Validation loss per penalty and fold, `Inf` where a penalty has no identified refit."""
function refit_fold_losses(X, y, folds, penalties)
    n_folds = maximum(folds)
    fold_losses = fill(Inf, length(penalties), n_folds)
    for fold in 1:n_folds
        fitting, validation = folds .!= fold, folds .== fold
        X_fit, y_fit = X[fitting, :], y[fitting]
        path = lasso_path(X_fit, y_fit, penalties)
        for j in axes(path.betas, 2)
            model = refit_ols(X_fit, y_fit, path.betas[:, j])
            isnothing(model) && continue
            predictions = X[validation, model.selected] * model.coefficients
            fold_losses[j, fold] = mean(abs2, predictions - y[validation])
        end
    end
    return fold_losses
end

"""
    post_lasso_cv(X, y; folds, penalties)

Pick the lasso penalty by the validation loss of the OLS refit on its selected
set. A penalty is excluded if its refit is unidentified in any fold or on the full
data: rank deficient, or with no residual degrees of freedom, where it would
interpolate.

Returns a named tuple:

- `selected`, `coefficients`: the chosen refit's features and their OLS coefficients.
- `penalty`: the chosen penalty.
- `mean_losses`: validation loss per penalty, `Inf` for an excluded one.
- `fold_losses`: validation loss per penalty (rows) and fold (columns).
"""
function post_lasso_cv(X, y; folds, penalties)
    n_folds = maximum(folds)
    length(y) == length(folds) == size(X, 1) ||
        throw(DimensionMismatch("folds must match X and y"))
    n_folds >= 2 && sort(unique(folds)) == 1:n_folds ||
        throw(ArgumentError("folds must be 1:k with k >= 2"))

    fold_losses = refit_fold_losses(X, y, folds, penalties)

    # Weight folds by size so that every validation observation counts equally.
    weights = [count(==(fold), folds) for fold in 1:n_folds] ./ length(folds)
    mean_losses = fold_losses * weights

    path = lasso_path(X, y, penalties)
    models = [j <= size(path.betas, 2) ? refit_ols(X, y, path.betas[:, j]) : nothing
              for j in eachindex(penalties)]
    mean_losses[isnothing.(models)] .= Inf

    best = argmin(mean_losses)
    isfinite(mean_losses[best]) || error("no penalty gives an identified post-lasso refit")
    return (; models[best]..., penalty=penalties[best], mean_losses, fold_losses)
end

"""
Tuned and oracle benchmarks, as a named tuple of coefficients on the whole feature
set. Ridge says what interpolation costs against optimal shrinkage; lasso and
post-lasso against selection; oracle is OLS on the true active set, the attainable
best when that set is smaller than `n`.
"""
function benchmarks(data, seed)
    X, y = data.X, data.y
    n, p = size(X)
    n_folds = 5
    folds = shuffle(Xoshiro(seed), mod1.(1:n, n_folds))

    lasso = glmnetcv(X, y; alpha=1.0, intercept=false, nfolds=n_folds, folds)
    post = post_lasso_cv(X, y; folds, penalties=lasso.lambda)
    post_coefficients = zeros(p)
    post_coefficients[post.selected] = post.coefficients

    active = findall(!iszero, data.beta)
    oracle = zeros(p)
    oracle[active] = minnorm(X[:, active], y)

    return (;
        ridge=ridge_cv(X, y; folds), lasso=coef(lasso),
        post_lasso=post_coefficients, oracle,
    )
end
