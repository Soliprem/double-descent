using LinearAlgebra

X = [1.0 0.0 1.0; 0.0 1.0 1.0]
y = [1.0, 2.0]
F = svd(X)
tolerance = minimum(size(X)) * eps(eltype(F.S)) * maximum(F.S)
size(F.U)
coords = F.U' * y
tolerable_coords = map((c, s) -> s > tolerance ? c / s : 0.0, coords, F.S)
coefficients = F.V * tolerable_coords

# Exercise 2: reconstruct the minimum-norm estimator without calling pinv.
# Work with nonempty Float64 matrices and vector outcomes in this exercise.
function minnorm_svd(X, y)
  F = svd(X)
  tolerance = minimum(size(X)) * eps(eltype(F.S)) * maximum(F.S)

  # 1. Project y into the left singular-vector coordinates using F.U.
  # 2. Divide each coordinate by its singular value in F.S when that value
  #    exceeds tolerance. Otherwise set that coordinate to zero.
  # 3. Map the resulting coordinates into coefficient space using F.V.
  coords = F.U' * y
  tolerable_coords = map((c, s) -> s > tolerance ? c / s : 0.0, coords, F.S)
  coefficients = F.V * tolerable_coords
  return coefficients
end

function check_minnorm_svd()
  cases = [
    ([1.0 0.0 1.0; 0.0 1.0 1.0], [1.0, 2.0]),
    ([1.0 0.0; 0.0 1.0; 1.0 1.0], [1.0, 2.0, 4.0]),
    ([1.0 1.0; 2.0 2.0], [1.0, 0.0]),
  ]
  for (X, y) in cases
    b = minnorm_svd(X, y)
    @assert size(b) == (size(X, 2),)
    @assert isapprox(b, pinv(X) * y; atol=1e-10, rtol=1e-10)
    @assert norm(X' * (X * b - y)) < 1e-10
  end
  println("SVD estimator matches pinv on all three cases.")

  # Predict the coefficient error before running this experiment.
  # Every matrix has full rank, but its second singular value gets smaller.
  truth = [1.0, 1.0]
  noise = [0.0, 1e-4]
  for delta in (1e-1, 1e-2, 1e-3)
    X = Matrix(Diagonal([1.0, delta]))
    y_noisy = X * truth + noise
    b = minnorm_svd(X, y_noisy)
    @assert norm(X * b - y_noisy) < 1e-10
    @assert isapprox(norm(b - truth), noise[2] / delta; atol=1e-10)
    println((delta=delta, training_residual=norm(X * b - y_noisy),
      coefficient_error=norm(b - truth)))
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  check_minnorm_svd()
end
