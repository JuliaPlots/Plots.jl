using VisualRegressionTests
using Plots
using Random
using BinaryProvider
using Test
using FileIO

include("imgcomp.jl")
# don't actually show the plots
Random.seed!(1234)
default(show=false, reuse=true)
img_tol = isinteractive() ? 1e-2 : 10e-2

@testset "GR" begin
    ENV["PLOTS_TEST"] = "true"
    ENV["GKSwstype"] = "100"
    @test gr() == Plots.GRBackend()
    @test backend() == Plots.GRBackend()

    @static if Sys.islinux()
        image_comparison_facts(:gr, tol=img_tol, skip = [25, 30])
    end
end


@testset "UnicodePlots" begin
    @test unicodeplots() == Plots.UnicodePlotsBackend()
    @test backend() == Plots.UnicodePlotsBackend()

    # lets just make sure it runs without error
    p = plot(rand(10))
    @test isa(p, Plots.Plot) == true
    @test isa(display(p), Nothing) == true
    p = bar(randn(10))
    @test isa(p, Plots.Plot) == true
    @test isa(display(p), Nothing) == true
end

@testset "Axes" begin
    p = plot()
    axis = p.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5,1.5)
    @test axis[:discrete_map] == Dict{Any,Any}(:yo  => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i=1:5])
    Plots.discrete_value!(axis, ["x$i" for i=0:2])
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)
end

@testset "NoFail" begin
    histogram([1, 0, 0, 0, 0, 0])
end
