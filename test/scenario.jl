using Test, LinearAlgebra, Statistics
isdefined(@__MODULE__, :DoubleDescent) ||
    include(joinpath(@__DIR__, "..", "src", "DoubleDescent.jl"))
using .DoubleDescent

@testset "Scenario" begin
    @testset "every spectrum, signal and sign pattern" begin
        for (rho, n_factors) in ((0.0, 1), (0.3, 5), (0.7, 20)),
            signal in (:sparse, :grouped, :dense),
            signs in (:aligned, :contrast)

            @testset "rho=$rho, K=$n_factors, $signal, $signs" begin
                s = Scenario(; n=30, p=120, rho, n_factors, signal, signs)
                data = simulate(s, 42)
                covariance = Matrix(data.covariance)

                @testset "unit-variance features with a positive definite covariance" begin
                    @test diag(covariance) ≈ ones(120)
                    @test isposdef(covariance)
                end

                @testset "the signal has unit variance" begin
                    @test dot(data.beta, covariance * data.beta) ≈ 1
                    @test quadratic(data.covariance, data.beta) ≈ 1
                end

                @testset "`n_active` features are active, or all of them if dense" begin
                    @test count(!iszero, data.beta) == (signal == :dense ? 120 : 10)
                end

                @testset "the same seed gives the same draw" begin
                    @test simulate(s, 42).y == data.y
                end
            end
        end
    end

    @testset "block covariance" begin
        s = Scenario(; n=100_000, p=20, rho=0.7, n_factors=4, signal=:grouped)
        data = simulate(s, 7)
        covariance = Matrix(data.covariance)
        v = randn(20)

        @testset "the sampled features have this covariance" begin
            @test maximum(abs, cov(data.X) - covariance) < 0.025
        end

        @testset "quadratic agrees with the full matrix" begin
            @test quadratic(data.covariance, v) ≈ dot(v, covariance, v)
        end

        @testset "quadratic pads a short vector with zeros" begin
            leading = v[1:5]
            @test quadratic(data.covariance, leading) ≈
                  quadratic(data.covariance, [leading; zeros(15)])
        end
    end

    @testset "spectrum matches the covariance" begin
        s = Scenario(; n=30, p=120, rho=0.7, n_factors=5)
        eigenvalues = sort(eigvals(Symmetric(Matrix(simulate(s, 1).covariance))); rev=true)
        (; spike, n_spikes, tail_rank) = spectrum(s)
        @test n_spikes + tail_rank == 120
        @test eigenvalues[1:n_spikes] ≈ fill(spike, n_spikes)
        @test eigenvalues[(n_spikes + 1):end] ≈ fill(1 - s.rho, tail_rank)
    end

    @testset "signs control the alignment with the spikes" begin
        function share(signal, signs)
            s = Scenario(; n=30, p=400, rho=0.7, n_factors=5, signal, signs)
            data = simulate(s, 3)
            return signal_share(data.covariance, data.beta)
        end
        @test share(:dense, :aligned) ≈ 1
        @test share(:dense, :contrast) < 1e-12
        @test share(:grouped, :contrast) < 1e-12
        @test share(:grouped, :aligned) > 0.9
    end

    @testset "grouped signals use as few factors as possible" begin
        s = Scenario(; n=30, p=120, rho=0.5, n_factors=30, signal=:grouped)
        data = simulate(s, 5)
        active = findall(!iszero, data.beta)
        fewest_factors = cld(s.n_active, s.p ÷ s.n_factors)
        @test length(unique(data.covariance.factor_of[active])) == fewest_factors
    end

    @testset "scenarios with the same seed are paired" begin
        sparse = simulate(Scenario(; n=30, p=120, signal=:sparse), 11)
        dense = simulate(Scenario(; n=30, p=120, signal=:dense), 11)
        @test sparse.X == dense.X
        noise(data) = (data.y - data.X * data.beta) / data.noise_std
        @test noise(sparse) ≈ noise(dense)
        correlated_scenario = Scenario(; n=30, p=120, rho=0.7, n_factors=5, signal=:sparse)
        correlated = simulate(correlated_scenario, 11)
        @test findall(!iszero, correlated.beta) == findall(!iszero, sparse.beta)
    end

    @testset "invalid scenarios are rejected" begin
        @test_throws ArgumentError Scenario(; rho=1.0)
        @test_throws ArgumentError Scenario(; signal=:unknown)
        @test_throws ArgumentError Scenario(; signs=:unknown)
        @test_throws ArgumentError Scenario(; n_factors=0)
        @test_throws ArgumentError Scenario(; n_active=0)
        @test_throws ArgumentError Scenario(; snr=0.0)
    end
end
