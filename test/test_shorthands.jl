using Plots, Test

@testset "Shorthands" begin
    @testset "Set Lims" begin
        p = plot(rand(10))

        xlims!((1, 20))
        @test xlims(p) == (1, 20)

        xlims!(p, (1, 21))
        @test xlims(p) == (1, 21)

        ylims!((-1, 1))
        @test ylims(p) == (-1, 1)

        ylims!(p, (-2, 2))
        @test ylims(p) == (-2, 2)

        zlims!((-1, 1))
        @test zlims(p) == (-1, 1)

        zlims!(p, (-2, 2))
        @test zlims(p) == (-2, 2)

        xlims!(-1, 11)
        @test xlims(p) == (-1, 11)

        xlims!(p, -2, 12)
        @test xlims(p) == (-2, 12)

        ylims!((-10, 10))
        @test ylims(p) == (-10, 10)

        ylims!(p, (-11, 9))
        @test ylims(p) == (-11, 9)

        zlims!((-10, 10))
        @test zlims(p) == (-10, 10)

        zlims!(p, (-9, 8))
        @test zlims(p) == (-9, 8)
    end

    @testset "Set Title / Labels" begin
        p = plot()
        title!(p, "Foo")
        sp = p[1]
        @test sp[:title] == "Foo"
        xlabel!(p, "xlabel")
        @test sp[:xaxis][:guide] == "xlabel"
        ylabel!(p, "ylabel")
        @test sp[:yaxis][:guide] == "ylabel"
    end

    @testset "Misc" begin
        p = plot()
        sp = p[1]

        xflip!(p)
        @test sp[:xaxis][:flip]

        xflip!(false)
        @test !sp[:xaxis][:flip]

        yflip!(p)
        @test sp[:yaxis][:flip]

        yflip!(false)
        @test !sp[:yaxis][:flip]

        xgrid!(p, true)
        @test sp[:xaxis][:grid]

        xgrid!(p, false)
        @test !sp[:xaxis][:grid]

        xgrid!(true)
        @test sp[:xaxis][:grid]

        ygrid!(p, true)
        @test sp[:yaxis][:grid]

        ygrid!(p, false)
        @test !sp[:yaxis][:grid]

        ygrid!(true)
        @test sp[:yaxis][:grid]

        ann = [(7, 3, "(7,3)"), (3, 7, text("hey", 14, :left, :top, :green))]
        annotate!(p, ann)
        annotate!(p, ann...)
        annotate!(ann...)

        xaxis!(p, true)
        @test sp[:xaxis][:showaxis]

        xaxis!(p, false)
        @test !sp[:xaxis][:showaxis]

        xaxis!(true)
        @test sp[:xaxis][:showaxis]

        yaxis!(p, true)
        @test sp[:yaxis][:showaxis]

        yaxis!(p, false)
        @test !sp[:yaxis][:showaxis]

        yaxis!(true)
        @test sp[:yaxis][:showaxis]

        p = plot3d([1, 2], [1, 2], [1, 2])
        plot3d!(p, [3, 4], [3, 4], [3, 4])
        @test Plots.series_list(p[1])[1][:seriestype] == :path3d
    end

    @testset "Set Ticks" begin
        p = plot([0, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        sp = p[1]

        xticks = 2:6
        xticks!(xticks)
        @test sp.attr[:xaxis][:ticks] == xticks

        xticks = 1:5
        xticks!(p, xticks)
        @test sp.attr[:xaxis][:ticks] == xticks

        yticks = 0.2:0.1:0.7
        yticks!(yticks)
        @test sp.attr[:yaxis][:ticks] == yticks

        yticks = 0.1:0.5
        yticks!(p, yticks)
        @test sp.attr[:yaxis][:ticks] == yticks

        xticks = [5, 6, 7.5]
        xlabels = ["a", "b", "c"]
        xticks!(xticks, xlabels)
        @test sp.attr[:xaxis][:ticks] == (xticks, xlabels)

        xticks = [5, 2]
        xlabels = ["b", "a"]
        xticks!(p, xticks, xlabels)
        @test sp.attr[:xaxis][:ticks] == (xticks, xlabels)

        yticks = [0.5, 0.6, 0.75]
        ylabels = ["z", "y", "x"]
        yticks!(yticks, ylabels)
        @test sp.attr[:yaxis][:ticks] == (yticks, ylabels)

        yticks = [0.5, 0.1]
        ylabels = ["z", "y"]
        yticks!(p, yticks, ylabels)
        @test sp.attr[:yaxis][:ticks] == (yticks, ylabels)
    end
end
