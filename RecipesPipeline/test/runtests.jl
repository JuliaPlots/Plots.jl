using RecipesPipeline
using Test

@testset "RecipesPipeline.jl" begin
    @testset "Makie integration" begin include("makie.jl") end
end
