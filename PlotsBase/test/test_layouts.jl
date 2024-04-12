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
    @test pl[1][:yaxis][:scale] ≡ :identity
    @test pl[2][:yaxis][:scale] ≡ :identity
    @test pl[3][:yaxis][:scale] ≡ :log10
    @test pl[4][:yaxis][:scale] ≡ :log10
end

@testset "Plot title" begin
    pl = plot(
        rand(4, 8),
        layout = 4,
        plot_title = "My title",
        background_color = :darkgray,
        background_color_inside = :lightgray,
    )
    @test pl.layout.heights == [0.05PlotsBase.pct, 0.95PlotsBase.pct]
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
    @test pl[1][:framestyle] ≡ :grid
    @test pl[2][:framestyle] ≡ :grid
    @test pl[3][:framestyle] ≡ :none
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

@testset "Invalid viewport" begin
    # github.com/JuliaPlots/Plots.jl/issues/2804
    pl = plot(1, layout = (10, 2))
    show(devnull, pl)
end

@testset "Coverage" begin
    pl = plot(map(plot, 1:4)..., layout = (2, 2))

    sp = pl[end]
    @test sp isa PlotsBase.Subplot
    @test size(sp) == (1, 1)
    @test length(sp) == 1
    @test sp[1, 1] == sp
    @test PlotsBase.get_subplot(pl, UInt32(4)) == sp
    @test PlotsBase.series_list(sp) |> first |> PlotsBase.get_subplot isa PlotsBase.Subplot
    @test PlotsBase.get_subplot(pl, keys(pl.spmap) |> first) isa PlotsBase.Subplot

    gl = pl[2, 2]
    @test gl isa PlotsBase.GridLayout
    @test length(gl) == 1
    @test size(gl) == (1, 1)
    @test PlotsBase.layout_attrs(gl) == (gl, 1)

    @test size(pl, 1) == 2
    @test size(pl, 2) == 2
    @test size(pl) == (2, 2)
    @test ndims(pl) == 2

    @test pl[1][end] isa PlotsBase.Series
    io = devnull
    show(io, pl[1])

    @test PlotsBase.getplot(pl) == pl
    @test PlotsBase.getattr(pl) == pl.attr
    @test PlotsBase.backend_object(pl) == pl.o
    @test occursin("Plot", string(pl))
    print(io, pl)

    @test PlotsBase.to_pixels(1PlotsBase.mm) isa AbstractFloat
    @test PlotsBase.ispositive(1PlotsBase.mm)
    @test size(PlotsBase.DEFAULT_BBOX[]) == (0PlotsBase.mm, 0PlotsBase.mm)
    show(io, PlotsBase.DEFAULT_BBOX[])
    show(io, pl.layout)

    @test PlotsBase.Commons.make_measure_hor(1PlotsBase.mm) == 1PlotsBase.mm
    @test PlotsBase.Commons.make_measure_vert(1PlotsBase.mm) == 1PlotsBase.mm

    @test PlotsBase.parent(pl.layout) isa PlotsBase.RootLayout
    show(io, PlotsBase.Commons.parent_bbox(pl.layout))

    rl = PlotsBase.RootLayout()
    show(io, rl)
    @test parent(rl) ≡ nothing
    @test PlotsBase.Commons.parent_bbox(rl) == PlotsBase.DEFAULT_BBOX[]
    @test PlotsBase.bbox(rl) == PlotsBase.DEFAULT_BBOX[]
    @test PlotsBase.origin(PlotsBase.DEFAULT_BBOX[]) == (0PlotsBase.mm, 0PlotsBase.mm)
    for h_anchor in (:left, :right, :hcenter), v_anchor in (:top, :bottom, :vcenter)
        @test PlotsBase.bbox(0, 0, 1, 1, h_anchor, v_anchor) isa PlotsBase.BoundingBox
    end

    el = PlotsBase.EmptyLayout()
    @test PlotsBase.update_position!(el) ≡ nothing
    @test size(el) == (0, 0)
    @test length(el) == 0
    @test el[1, 1] ≡ nothing

    @test PlotsBase.left(el) == 0PlotsBase.mm
    @test PlotsBase.top(el) == 0PlotsBase.mm
    @test PlotsBase.right(el) == 0PlotsBase.mm
    @test PlotsBase.bottom(el) == 0PlotsBase.mm

    plot(map(plot, 1:4)..., layout = (2, :))
    plot(map(plot, 1:4)..., layout = (:, 2))
end

@testset "Link" begin
    plot(map(plot, 1:4)..., link = :all)
    plot(map(plot, 1:4)..., link = :square)
end
