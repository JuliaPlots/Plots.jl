@testset "Set Lims" begin
    pl = plot(rand(10))

    xlims!((1, 20))
    @test xlims(pl) == (1, 20)
    xlims!(pl, (1, 21))
    @test xlims(pl) == (1, 21)
    ylims!((-1, 1))
    @test ylims(pl) == (-1, 1)
    ylims!(pl, (-2, 2))
    @test ylims(pl) == (-2, 2)
    zlims!((-1, 1))
    @test zlims(pl) == (-1, 1)
    zlims!(pl, (-2, 2))
    @test zlims(pl) == (-2, 2)
    xlims!(-1, 11)
    @test xlims(pl) == (-1, 11)
    xlims!(pl, -2, 12)
    @test xlims(pl) == (-2, 12)
    ylims!((-10, 10))
    @test ylims(pl) == (-10, 10)
    ylims!(pl, (-11, 9))
    @test ylims(pl) == (-11, 9)
    zlims!((-10, 10))
    @test zlims(pl) == (-10, 10)
    zlims!(pl, (-9, 8))
    @test zlims(pl) == (-9, 8)
end

@testset "Set Title / Labels" begin
    pl = plot()
    title!(pl, "Foo")
    sp = pl[1]
    @test sp[:title] == "Foo"
    xlabel!(pl, "xlabel")
    @test sp[:xaxis][:guide] == "xlabel"
    ylabel!(pl, "ylabel")
    @test sp[:yaxis][:guide] == "ylabel"
    zlabel!(pl, "zlabel")
    @test sp[:zaxis][:guide] == "zlabel"
end

@testset "Misc" begin
    pl = plot()
    sp = pl[1]

    xflip!(pl)
    @test sp[:xaxis][:flip]
    xflip!(false)
    @test !sp[:xaxis][:flip]
    yflip!(pl)
    @test sp[:yaxis][:flip]
    yflip!(false)
    @test !sp[:yaxis][:flip]
    xgrid!(pl, true)
    @test sp[:xaxis][:grid]
    xgrid!(pl, false)
    @test !sp[:xaxis][:grid]
    xgrid!(true)
    @test sp[:xaxis][:grid]
    ygrid!(pl, true)
    @test sp[:yaxis][:grid]
    ygrid!(pl, false)
    @test !sp[:yaxis][:grid]
    ygrid!(true)
    @test sp[:yaxis][:grid]

    # multiple annotations
    ann = [(7, 3, "(7,3)"), (3, 7, text("hey", 14, :left, :top, :green))]
    annotate!(pl, ann)
    show(devnull, pl)
    annotate!(pl, ann...)
    show(devnull, pl)
    annotate!(ann...)
    show(devnull, pl)

    # single annotation
    ann = (3, 7, text("hey", 14, :left, :top, :green))
    annotate!(pl, ann)
    show(devnull, pl)
    annotate!(pl, ann...)
    show(devnull, pl)
    annotate!(ann...)

    xaxis!(pl, true)
    @test sp[:xaxis][:showaxis]
    xaxis!(pl, false)
    @test !sp[:xaxis][:showaxis]
    xaxis!(true)
    @test sp[:xaxis][:showaxis]
    yaxis!(pl, true)
    @test sp[:yaxis][:showaxis]
    yaxis!(pl, false)
    @test !sp[:yaxis][:showaxis]
    yaxis!(true)
    @test sp[:yaxis][:showaxis]

    pl = plot3d([1, 2], [1, 2], [1, 2])
    plot3d!(pl, [3, 4], [3, 4], [3, 4])
    @test Plots.series_list(pl[1])[1][:seriestype] === :path3d
end

@testset "Set Ticks" begin
    pl = plot([0, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    sp = pl[1]

    xticks = 2:6
    xticks!(xticks)
    @test sp.attr[:xaxis][:ticks] == xticks

    xticks = 1:5
    xticks!(pl, xticks)
    @test sp.attr[:xaxis][:ticks] == xticks

    yticks = 0.2:0.1:0.7
    yticks!(yticks)
    @test sp.attr[:yaxis][:ticks] == yticks

    yticks = 0.1:0.5
    yticks!(pl, yticks)
    @test sp.attr[:yaxis][:ticks] == yticks

    xticks = [5, 6, 7.5]
    xlabels = ["a", "b", "c"]
    xticks!(xticks, xlabels)
    @test sp.attr[:xaxis][:ticks] == (xticks, xlabels)

    xticks = [5, 2]
    xlabels = ["b", "a"]
    xticks!(pl, xticks, xlabels)
    @test sp.attr[:xaxis][:ticks] == (xticks, xlabels)

    yticks = [0.5, 0.6, 0.75]
    ylabels = ["z", "y", "x"]
    yticks!(yticks, ylabels)
    @test sp.attr[:yaxis][:ticks] == (yticks, ylabels)

    yticks = [0.5, 0.1]
    ylabels = ["z", "y"]
    yticks!(pl, yticks, ylabels)
    @test sp.attr[:yaxis][:ticks] == (yticks, ylabels)
end
