using Plots, Test

@testset "Adding attributes" begin
    pl = plot(rand(8,8), layout = 4)
    pl_all = plot!(deepcopy(pl); label = ["test" for _ in 1:8])
    pl_subplot = plot!(deepcopy(pl); label = ["test" for _ in 1:2], subplot = 2)
    pl_series = plot!(deepcopy(pl); label = "test", series = 5)
    for series in pl_all.series_list
        @test series[:label] == "test"
    end
    @test pl_subplot[1][1][:label] == "y1"
    for series in pl_subplot[2].series_list
        @test series[:label] == "test"
    end
    @test pl_series[1][1][:label] == "y1"
    @test pl_series.series_list[5][:label] == "test"
end
