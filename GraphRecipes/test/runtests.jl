using VisualRegressionTests
using AbstractTrees
using LinearAlgebra
using Logging
using GraphRecipes
using SparseArrays
using ImageMagick
using StableRNGs
using Graphs
using Plots
using Plots.PlotsBase
using Test
using Gtk  # for popup

isci() = get(ENV, "CI", "false") == "true"
itol(tol = nothing) = something(tol, isci() ? 1.0e-3 : 1.0e-5)

include("functions.jl")
include("parse_readme.jl")

default(show = false, reuse = true)

cd(joinpath(@__DIR__, "..", "assets")) do
    @testset "TestImages" begin
        figure_files = readdir()
        @testset "$figure_file" for figure_file in figure_files
            figure = splitext(figure_file)[1]
            if figure == "julia_type_tree"
                if VERSION >= v"1.11" # julia 1.11 introduced Core.BFloat16
                    @plottest julia_type_tree() "julia_type_tree.png" popup = !isci() tol = itol()
                end
            else
                @plottest getproperty(@__MODULE__, Symbol(figure))() figure_file popup = !isci() tol =
                    itol()
            end
        end
    end
end

@testset "issues" begin
    @testset "143" begin
        g = SimpleGraph(7)

        add_edge!(g, 2, 3)
        add_edge!(g, 3, 4)
        @test g.ne == 2
        al = GraphRecipes.get_adjacency_list(g)
        @test isempty(al[1])
        @test al[2] == [3]
        @test al[3] == [2, 4]
        @test al[4] == [3]
        @test isempty(al[5])
        @test isempty(al[6])
        @test isempty(al[7])
        s, d, w = GraphRecipes.get_source_destiny_weight(al)
        @test s == [2, 3, 3, 4]
        @test d == [3, 2, 4, 3]
        @test all(w .≈ 1)

        with_logger(ConsoleLogger(stderr, Logging.Debug)) do
            pl = graphplot(g)
            @test first(pl.series_list)[:extra_kwargs][:num_edges_nodes] == (2, 7)

            add_edge!(g, 6, 7)
            @test g.ne == 3
            pl = graphplot(g)
            @test first(pl.series_list)[:extra_kwargs][:num_edges_nodes] == (3, 7)

            # old behavior (see issue), can be recovered using `trim=true`
            g = SimpleGraph(7)
            add_edge!(g, 2, 3)
            add_edge!(g, 3, 4)
            pl = graphplot(g; trim = true)
            @test first(pl.series_list)[:extra_kwargs][:num_edges_nodes] == (2, 4)
        end
    end

    @testset "180" begin
        rng = StableRNG(1)
        mat = Symmetric(sparse(rand(rng, 0:1, 8, 8)))
        graphplot(mat, method = :arcdiagram, rng = rng)
    end
end

@testset "utils.jl" begin
    rng = StableRNG(1)
    @test GraphRecipes.directed_curve(0.0, 1.0, 0.0, 1.0, rng = rng) ==
        GraphRecipes.directed_curve(0, 1, 0, 1, rng = rng)

    @test GraphRecipes.isnothing(nothing) == Plots.isnothing(nothing)
    @test GraphRecipes.isnothing(missing) == Plots.isnothing(missing)
    @test GraphRecipes.isnothing(NaN) == Plots.isnothing(NaN)
    @test GraphRecipes.isnothing(0) == Plots.isnothing(0)
    @test GraphRecipes.isnothing(1) == Plots.isnothing(1)
    @test GraphRecipes.isnothing(0.0) == Plots.isnothing(0.0)
    @test GraphRecipes.isnothing(1.0) == Plots.isnothing(1.0)

    for (s, e) in [(rand(rng), rand(rng)) for i in 1:100]
        @test GraphRecipes.partialcircle(s, e) == PlotsBase.partialcircle(s, e)
    end

    @testset "nearest_intersection" begin
        @test GraphRecipes.nearest_intersection(0, 0, 3, 3, [(1, 0), (0, 1)]) ==
            (0, 0, 0.5, 0.5)
        @test GraphRecipes.nearest_intersection(1, 2, 1, 2, []) == (1, 2, 1, 2)
    end

    @testset "unoccupied_angle" begin
        @test GraphRecipes.unoccupied_angle(1, 1, [1, 1, 1, 1], [2, 0, 3, -1]) == 2pi
    end

    @testset "islabel" begin
        @test GraphRecipes.islabel("hi")
        @test GraphRecipes.islabel(1)
        @test !GraphRecipes.islabel(missing)
        @test !GraphRecipes.islabel(NaN)
        @test !GraphRecipes.islabel(false)
        @test !GraphRecipes.islabel("")
    end

    @testset "control_point" begin
        @test GraphRecipes.control_point(0, 0, 6, 0, 4) == (4, 3)
    end

    # TODO: Actually test that the aliases produce the same plots, rather than just
    # checking that they don't error. Also, test all of the different aliases.
    @testset "Aliases" begin
        A = [1 0 1 0; 0 0 1 1; 1 1 1 1; 0 0 1 1]
        graphplot(A, markercolor = :red, markershape = :rect, markersize = 0.5, rng = rng)
        graphplot(A, nodeweights = 1:4, rng = rng)
        graphplot(A, curvaturescalar = 0, rng = rng)
        graphplot(A, el = Dict((1, 2) => ""), elb = true, rng = rng)
        graphplot(A, ew = (s, d, w) -> 3, rng = rng)
        graphplot(A, ses = 0.5, rng = rng)
    end
end

# -----------------------------------------
# marginalhist

# using Distributions
# n = 1000
# x = rand(RNG, Gamma(2), n)
# y = -0.5x + randn(RNG, n)
# marginalhist(x, y)

# -----------------------------------------
# portfolio composition map

# # fake data
# tickers = ["IBM", "Google", "Apple", "Intel"]
# N = 10
# D = length(tickers)
# weights = rand(RNG, N, D)
# weights ./= sum(weights, 2)
# returns = sort!((1:N) + D*randn(RNG, N))

# # plot it
# portfoliocomposition(weights, returns, labels = tickers')

# -----------------------------------------
#
