using RecipesPipeline
using Test

makie_test_dir = joinpath(@__DIR__, "test_makie")
mkpath(makie_test_dir)

@testset "RecipesPipeline.jl" begin
    @testset "Makie integration" begin cd(makie_test_dir) do
        include("makie.jl")
    end end
end
