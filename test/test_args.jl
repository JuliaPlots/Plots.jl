using Plots, Test

@testset "Series Attributes" begin
    pl = plot([1,2,3], lw = 5)
    @test hline!(pl, [1.75]).series_list == hline!(pl, [1.75], z_order = :front).series_list
    @test hline!(pl, [1.75], z_order == :back)[1].series_list[1][:label] == "y3"
    @test hline!(pl, [1.75], z_order == 2)[1].series_list[2][:label] == "y3"
end
