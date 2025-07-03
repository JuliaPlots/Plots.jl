using VisualRegressionTests
using AbstractTrees
using LinearAlgebra
using GraphRecipes.AbstractTrees
using GraphRecipes.Colors
using GraphRecipes
using SparseArrays
using ImageMagick
using StableRNGs
using PlotsBase
using Logging
using Graphs
using Test
using Gtk  # for popup

import GR
gr()

isci() = get(ENV, "CI", "false") == "true"
itol(tol = nothing) = something(tol, isci() ? 1.0e-3 : 1.0e-5)

include("functions.jl")
include("parse_readme.jl")

default(show = false, reuse = true)

@testset "functions" begin
    rng = StableRNG(1)
    for method in keys(GraphRecipes._graph_funcs)
        method ≡ :spectral && continue  # FIXME
        dat = if (inp = GraphRecipes._graph_inputs[method]) ≡ :adjmat
            [
                0 1 1
                1 0 1
                1 1 0
            ]
        elseif inp ≡ :sourcedestiny
            Symmetric(sparse(rand(rng, 0:1, 8, 8)))
        elseif inp ≡ :adjlist
            dat = [
                0 1 1 0 0 0 0 0 0 0
                0 0 0 0 1 1 0 0 0 0
                0 0 0 1 0 0 1 0 1 0
                0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 1 0 1
                0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0
            ]
        else
            @error "wrong input $inp"
        end
        pl = graphplot(dat; method)
        @test pl isa PlotsBase.Plot
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
        graphplot(mat; method = :arcdiagram, rng)
    end
end

@testset "utils.jl" begin
    rng = StableRNG(1)
    @test GraphRecipes.directed_curve(0.0, 1.0, 0.0, 1.0; rng) ==
        GraphRecipes.directed_curve(0, 1, 0, 1; rng)

    @test GraphRecipes.isnothing(nothing) == PlotsBase.isnothing(nothing)
    @test GraphRecipes.isnothing(missing) == PlotsBase.isnothing(missing)
    @test GraphRecipes.isnothing(NaN) == PlotsBase.isnothing(NaN)
    @test GraphRecipes.isnothing(0) == PlotsBase.isnothing(0)
    @test GraphRecipes.isnothing(1) == PlotsBase.isnothing(1)
    @test GraphRecipes.isnothing(0.0) == PlotsBase.isnothing(0.0)
    @test GraphRecipes.isnothing(1.0) == PlotsBase.isnothing(1.0)

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
        graphplot(A; markercolor = :red, markershape = :rect, markersize = 0.5, rng)
        graphplot(A; nodeweights = 1:4, rng)
        graphplot(A; curvaturescalar = 0, rng)
        graphplot(A; el = Dict((1, 2) => ""), elb = true, rng)
        graphplot(A; ew = (s, d, w) -> 3, rng)
        graphplot(A; ses = 0.5, rng)
    end
end

cd(joinpath(@__DIR__, "..", "assets")) do
    @testset "FIGURES" begin
        @plottest random_labelled_graph() "random_labelled_graph.png" popup = !isci() tol =
            itol()

        @plottest random_3d_graph() "random_3d_graph.png" popup = !isci() tol = itol()

        @plottest light_graphs() "light_graphs.png" popup = !isci() tol = itol()

        @plottest directed() "directed.png" popup = !isci() tol = itol()

        @plottest marker_properties() "marker_properties.png" popup = !isci() tol = itol()

        @plottest edgelabel() "edgelabel.png" popup = !isci() tol = itol()

        @plottest selfedges() "selfedges.png" popup = !isci() tol = itol()

        @plottest multigraphs() "multigraphs.png" popup = !isci() tol = itol()

        @plottest arc_chord_diagrams() "arc_chord_diagrams.png" popup = !isci() tol = itol()

        @plottest ast_example() "ast_example.png" popup = !isci() tol = itol()

        @plottest julia_type_tree() "julia_type_tree.png" popup = !isci() tol = itol(2.0e-2)
        @plottest julia_dict_tree() "julia_dict_tree.png" popup = !isci() tol = itol()

        @plottest funky_edge_and_marker_args() "funky_edge_and_marker_args.png" popup =
            !isci() tol = itol()

        @plottest custom_nodeshapes_single() "custom_nodeshapes_single.png" popup = !isci() tol =
            itol()

        @plottest custom_nodeshapes_various() "custom_nodeshapes_various.png" popup =
            !isci() tol = itol()
    end

    @testset "README" begin
        @plottest julia_logo_pun() "readme_julia_logo_pun.png" popup = !isci() tol = itol()
    end
end
