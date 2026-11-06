using Test
isdefined(@__MODULE__, :DoubleDescent) ||
    include(joinpath(@__DIR__, "..", "src", "DoubleDescent.jl"))
using .DoubleDescent

@testset "Study pipeline" begin
    n, p = 30, 90

    @testset "run_study writes every table and figure for a custom grid" begin
        # Deliberately not the default grid: two active counts, one SNR, no factors.
        # The curve-example scenarios are absent and factor totals are undefined throughout.
        grid = [Scenario(; n, p, signal, signs, n_active, snr=4.0)
                for signal in (:sparse, :dense),
                    signs in (:aligned, :contrast),
                    n_active in (4, 8)]
        n_seeds, n_estimators = 2, 5
        expected_files = (
            "fits.csv", "fit_summary.csv", "curves.csv", "scenarios.csv",
            "main_effects.csv", "factor_importance.csv",
            "prediction.png", "coefficients.png", "tradeoffs.png",
        )
        mktempdir() do output
            result = run_study(; seeds=1:n_seeds, grid=vec(grid), output)
            @test length(result.table) == length(grid)
            @test length(result.fits) == n_seeds * n_estimators * length(grid)
            @test all(row -> row.rho == 0 && row.p == p, result.table)
            for file in expected_files
                @test isfile(joinpath(output, file))
            end
            @test !isfile(joinpath(output, "curves.png"))
        end
    end

    @testset "the descent curve" begin
        fit = fit_scenario(Scenario(; n, p), 1)

        @testset "it interpolates from the threshold on, and not well below it" begin
            @test all(row.train_mse < 1e-20 for row in fit.curve if row.k >= n)
            @test all(row.train_mse > 1e-6 for row in fit.curve if row.k < n - 2)
        end

        @testset "risk peaks within two features of the threshold" begin
            peak = argmax(row -> row.excess_risk, fit.curve)
            @test abs(peak.k - n) <= 2
        end

        @testset "the final prefix uses every feature" begin
            @test last(fit.curve).k == p
        end
    end
end
