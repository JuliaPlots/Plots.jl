using Distributions
using FileIO
using GeometryBasics
using ImageMagick
using Images
using OffsetArrays
using Plots
using Random
using RecipesPipeline
using RDatasets
using SparseArrays
using StaticArrays
using Statistics
using StatsPlots
using Test
using TestImages

# makie_test_dir = joinpath(@__DIR__, "test_makie")
# mkpath(makie_test_dir)

@testset "RecipesPipeline.jl" begin
    # @testset "Makie integration" begin cd(makie_test_dir) do
    #     include("makie.jl")
    # end end
    @testset "Plots tests" begin
    for i in eachindex(Plots._examples)
        if i ∉ Plots._backend_skips[:gr]
            @test Plots.test_examples(:gr, i, disp=false) isa Plots.Plot
        end
    end
    end
end
