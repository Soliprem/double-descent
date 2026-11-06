using GLMNet, LinearAlgebra, Statistics

# The caller supplies minnorm_svd, a shared penalty grid, and fold assignments.
# This version matches our synthetic model: no intercept and equally weighted rows.
function post_lasso_cv(X, y; folds, lambda)
    n = size(X, 1)
    @assert length(y) == length(folds) == n
    @assert sort(unique(folds)) == collect(1:maximum(folds))
    @assert maximum(folds) >= 2

    # Each column stores the validation MSE for one fold.
    # Inf also excludes penalties whose path fit did not converge.
    fold_losses = fill(Inf, length(lambda), maximum(folds))
    fold_sizes = zeros(Int, maximum(folds))

    for fold in 1:maximum(folds)
        training = folds .!= fold
        validation = folds .== fold
        X_fit, y_fit = X[training, :], y[training]
        X_valid, y_valid = X[validation, :], y[validation]
        fold_sizes[fold] = length(y_valid)

        path = glmnet(X_fit, y_fit;
            lambda=lambda, alpha=1.0, intercept=false,
        )

        for j in eachindex(path.lambda)
            selected = findall(b -> b != 0.0, path.betas[:, j])

            if isempty(selected)
                # With no intercept and no predictors, the prediction is zero.
                predictions = zeros(length(y_valid))
            else
                design = X_fit[:, selected]
                # Keep this benchmark as OLS with residual degrees of freedom.
                # We do not switch to interpolation for oversized selections.
                if length(selected) >= length(y_fit) || rank(design) < length(selected)
                    continue
                end
                coefficients = minnorm_svd(design, y_fit)
                predictions = X_valid[:, selected] * coefficients
            end

            fold_losses[j, fold] = mean((predictions .- y_valid) .^ 2)
        end
    end

    # Weight folds by their sizes, so every validation observation counts equally.
    meanloss = fold_losses * (fold_sizes ./ n)
    path = glmnet(X, y; lambda=lambda, alpha=1.0, intercept=false)

    # Check that the final fit can also be refitted by OLS.
    for j in eachindex(lambda)
        if j > length(path.lambda)
            meanloss[j] = Inf
            continue
        end
        selected = findall(b -> b != 0.0, path.betas[:, j])
        if !isempty(selected) &&
            (length(selected) >= n || rank(X[:, selected]) < length(selected))
            meanloss[j] = Inf
        end
    end

    best = argmin(meanloss)
    isfinite(meanloss[best]) || error("No penalty produced a valid post-lasso OLS model.")
    selected = findall(b -> b != 0.0, path.betas[:, best])
    coefficients = isempty(selected) ? Float64[] : minnorm_svd(X[:, selected], y)

    return (; selected, coefficients, lambda=lambda[best], meanloss, fold_losses)
end
