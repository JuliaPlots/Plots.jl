using Plots, Test
using RecipesPipeline

@testset "plot" begin
    pl = plot(1:5)
    pl2 = plot(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == false
    @test pl2[:tex_output_standalone] == true
    plot!(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == true
end

@testset "get_axis_limits" begin
    x = [.1, 5]
    p1 = plot(x, [5, .1], yscale=:log10)
    p2 = plot!(identity)
    @test all(RecipesPipeline.get_axis_limits(p1, :x) .== x)
    @test all(RecipesPipeline.get_axis_limits(p2, :x) .== x)
end
