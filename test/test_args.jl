using Plots, Test

@testset "Series Attributes" begin
    pl = plot([[1, 2, 3], [2, 3, 4]], lw = 5)
    @test hline!(deepcopy(pl), [1.75])[1].series_list[3][:label] ==
          hline!(deepcopy(pl), [1.75], z_order = :front)[1].series_list[3][:label] ==
          "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = :back)[1].series_list[1][:label] == "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = 2)[1].series_list[2][:label] == "y3"
end
