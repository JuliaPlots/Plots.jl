using Plots, Test

@testset "Shorthands" begin
    @testset "Set Lims" begin
        p = plot(rand(10))

        xlims!((1,20))
        @test xlims(p) == (1,20)

        ylims!((-1,1))
        @test ylims(p) == (-1,1)

        zlims!((-1,1))
        @test zlims(p) == (-1,1)

        xlims!(-1,11)
        @test xlims(p) == (-1,11)

        ylims!((-10,10))
        @test ylims(p) == (-10,10)

        zlims!((-10,10))
        @test zlims(p) == (-10,10)
    end

    @testset "Set Ticks" begin
        p = plot([0,2,3,4,5,6,7,8,9,10])

        xticks = 2:6
        xticks!(xticks)
        @test Plots.get_subplot(current(),1).attr[:xaxis][:ticks] == xticks

        yticks = 0.2:0.1:0.7
        yticks!(yticks)
        @test Plots.get_subplot(current(),1).attr[:yaxis][:ticks] == yticks

        xticks = [5,6,7.5]
        xlabels = ["a","b","c"]

        xticks!(xticks, xlabels)
        @test Plots.get_subplot(current(),1).attr[:xaxis][:ticks] == (xticks, xlabels)

        yticks = [.5,.6,.75]
        ylabels = ["z","y","x"]
        yticks!(yticks, ylabels)
        @test Plots.get_subplot(current(),1).attr[:yaxis][:ticks] == (yticks, ylabels)
    end
end
