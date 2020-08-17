using Plots, Test
@testset "lens!" begin
    pl = plot(1:5)
    lens!(pl, [1,2], [1,2], inset = (1, bbox(0.0,0.0,0.2,0.2)))
    @test length(pl.series_list) == 4
end # testset
