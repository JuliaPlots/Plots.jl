using Plots, Test
@testset "Plotting plots" begin
    pl = @test_nowarn plot(plot(1:2), plot(1:2, size = (1_200, 400)))
    @test pl[:size] == (1_200, 400)
    pl = @test_nowarn plot(plot(1:2), plot(1:2), size = (1_200, 400))
    @test pl[:size] == (1_200, 400)
end

@testset "Subplot slicing" begin
    pl = @test_nowarn plot(
        rand(4, 8),
        layout = 4,
        yscale = [:identity :identity :log10 :log10],
    )
    @test pl[1][:yaxis][:scale] === :identity
    @test pl[2][:yaxis][:scale] === :identity
    @test pl[3][:yaxis][:scale] === :log10
    @test pl[4][:yaxis][:scale] === :log10
end

@testset "Plot title" begin
    pl = plot(
        rand(4, 8),
        layout = 4,
        plot_title = "My title",
        background_color = :darkgray,
        background_color_inside = :lightgray,
    )
    @test pl.layout.heights == [0.05Plots.pct, 0.95Plots.pct]
    @test pl[:plot_title] == "My title"
    @test pl[:plot_titleindex] == 5

    @test pl[5][:background_color_inside] == RGBA(colorant"darkgray")

    plot!(pl)
    @test pl[:plot_title] == "My title"
    @test pl[:plot_titleindex] == 5

    plot!(pl, plot_title = "My new title")
    @test pl[:plot_title] == "My new title"
    @test pl[:plot_titleindex] == 5
end

@testset "Plots.jl/issues/4083" begin
    pl = plot(plot(1:2), plot(1:2); border = :grid, plot_title = "abc")
    @test pl[1][:framestyle] === :grid
    @test pl[2][:framestyle] === :grid
    @test pl[3][:framestyle] === :none
end

@testset "Allowed subplot counts" begin
    pl = plot(plot(1:2); layout = grid(2, 2))
    @test length(pl) == 1

    pl = plot(map(_ -> plot(1:2), 1:2)...; layout = grid(2, 2))
    @test length(pl) == 2

    pl = plot(map(_ -> plot(1:2), 1:3)...; layout = grid(2, 2))
    @test length(pl) == 3
    @test length(plot!(pl, plot(1:2))) == 4

    pl = plot(map(_ -> plot(1:2), 1:4)...; layout = grid(2, 2))
    @test length(pl) == 4

    @test_throws ErrorException plot(map(_ -> plot(1:2), 1:5)...; layout = grid(2, 2))
end

@testset "Allowed grid widths/heights" begin
    @test_nowarn grid(2, 1, heights = [0.5, 0.5])
    @test_nowarn grid(4, 1, heights = [0.3, 0.3, 0.3, 0.1])
    @test_nowarn grid(1, 2, widths = [0.5, 0.5])
    @test_nowarn grid(1, 4, widths = [0.3, 0.3, 0.3, 0.1])
    @test_throws ErrorException grid(2, 1, heights = [0.5, 0.4])
    @test_throws ErrorException grid(4, 1, heights = [1.5, -0.5])
    @test_throws ErrorException grid(1, 2, widths = [0.5, 0.4])
    @test_throws ErrorException grid(1, 4, widths = [1.5, -0.5])
end

@testset "Invalid viewport" begin
    # github.com/JuliaPlots/Plots.jl/issues/2804
    pl = plot(1, layout = (10, 2))
    show(devnull, pl)
end

@testset "Coverage" begin
    pl = plot(map(plot, 1:4)..., layout = (2, 2))

    sp = pl[end]
    @test sp isa Plots.Subplot
    @test size(sp) == (1, 1)
    @test length(sp) == 1
    @test sp[1, 1] == sp
    @test Plots.get_subplot(pl, UInt32(4)) == sp
    @test Plots.series_list(sp) |> first |> Plots.get_subplot isa Plots.Subplot
    @test Plots.get_subplot(pl, keys(pl.spmap) |> first) isa Plots.Subplot

    gl = pl[2, 2]
    @test gl isa Plots.GridLayout
    @test length(gl) == 1
    @test size(gl) == (1, 1)
    @test Plots.layout_args(gl) == (gl, 1)

    @test size(pl, 1) == 2
    @test size(pl, 2) == 2
    @test size(pl) == (2, 2)
    @test ndims(pl) == 2

    @test pl[1][end] isa Plots.Series
    io = devnull
    show(io, pl[1])

    @test Plots.getplot(pl) == pl
    @test Plots.getattr(pl) == pl.attr
    @test Plots.backend_object(pl) == pl.o
    @test occursin("Plot", string(pl))
    print(io, pl)

    @test Plots.to_pixels(1Plots.mm) isa AbstractFloat
    @test Plots.ispositive(1Plots.mm)
    @test size(Plots.DEFAULT_BBOX[]) == (0Plots.mm, 0Plots.mm)
    show(io, Plots.DEFAULT_BBOX[])
    show(io, pl.layout)

    @test Plots.make_measure_hor(1Plots.mm) == 1Plots.mm
    @test Plots.make_measure_vert(1Plots.mm) == 1Plots.mm

    @test Plots.parent(pl.layout) isa Plots.RootLayout
    show(io, Plots.parent_bbox(pl.layout))

    rl = Plots.RootLayout()
    show(io, rl)
    @test parent(rl) === nothing
    @test Plots.parent_bbox(rl) == Plots.DEFAULT_BBOX[]
    @test Plots.bbox(rl) == Plots.DEFAULT_BBOX[]
    @test Plots.origin(Plots.DEFAULT_BBOX[]) == (0Plots.mm, 0Plots.mm)
    for h_anchor in (:left, :right, :hcenter), v_anchor in (:top, :bottom, :vcenter)
        @test Plots.bbox(0, 0, 1, 1, h_anchor, v_anchor) isa Plots.BoundingBox
    end

    el = Plots.EmptyLayout()
    @test Plots.update_position!(el) === nothing
    @test size(el) == (0, 0)
    @test length(el) == 0
    @test el[1, 1] === nothing

    @test Plots.left(el) == 0Plots.mm
    @test Plots.top(el) == 0Plots.mm
    @test Plots.right(el) == 0Plots.mm
    @test Plots.bottom(el) == 0Plots.mm

    plot(map(plot, 1:4)..., layout = (2, :))
    plot(map(plot, 1:4)..., layout = (:, 2))
end

@testset "Link" begin
    plot(map(plot, 1:4)..., link = :all)
    plot(map(plot, 1:4)..., link = :square)
end
