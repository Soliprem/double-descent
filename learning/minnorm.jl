using LinearAlgebra

# Exercise 1: implement a minimum-norm least-squares fit.
# X has n observations (rows) and p predictors (columns); y has length n.
# Return a coefficient vector of length p. Start with LinearAlgebra.pinv.
# Later we will implement the same estimator using the SVD.
function minnorm(X, y)
  pinv(X) * y
end

# Run the checks after implementing minnorm:
#     julia --project=. src/minnorm.jl
# To explore without running them, start the REPL and use:
#     include("src/minnorm.jl")
if abspath(PROGRAM_FILE) == @__FILE__
    # Two observations and three predictors: infinitely many exact fits.
    X = [1.0 0.0 1.0; 0.0 1.0 1.0]
    y = [1.0, 2.0]
    v = [1.0, 1.0, -1.0]
    b = minnorm(X, y)
    @assert size(b) == (size(X, 2),)
    @assert norm(X * b - y) < 1e-10
    @assert norm(X * v) < 1e-10
    @assert abs(dot(b, v)) < 1e-10
    @assert norm(b) < norm(b + v)
    println("Underdetermined fit: b = $b, residual norm = $(norm(X * b - y))")

    # More observations than predictors, with an outcome that cannot be fitted exactly.
    X = [1.0 0.0; 0.0 1.0; 1.0 1.0]
    y = [1.0, 2.0, 4.0]
    b = minnorm(X, y)
    @assert size(b) == (2,)
    @assert norm(X * b - y) > 0.1
    @assert norm(X' * (X * b - y)) < 1e-10

    # A square matrix can also be rank deficient. Least squares still exists.
    X = [1.0 1.0; 2.0 2.0]
    y = [1.0, 0.0]
    b = minnorm(X, y)
    @assert norm(X' * (X * b - y)) < 1e-10
    @assert abs(dot(b, [1.0, -1.0])) < 1e-10
    println("All three checks passed.")
end
