using Plots, Test

@testset "plot" begin
    pl = plot(1:5)
    pl2 = plot(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == false
    @test pl2[:tex_output_standalone] == true
    plot!(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == true
end
