using Plots, Test

@testset "Plotting plots" begin
    pl = @test_nowarn plot(plot(1:2), plot(1:2, size = (1200, 400)))
    @test pl[:size] == (1200, 400)
    pl = @test_nowarn plot(plot(1:2), plot(1:2), size = (1200, 400))
    @test pl[:size] == (1200, 400)
end

@testset "Subplot sclicing" begin
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
    pl = plot(rand(4, 8), layout = 4, plot_title = "My title")
    @test pl[:plot_title] == "My title"
    @test pl[:plot_titleindex] == 5

    plot!(pl)
    @test pl[:plot_title] == "My title"
    @test pl[:plot_titleindex] == 5

    plot!(pl, plot_title = "My new title")
    @test pl[:plot_title] == "My new title"
    @test pl[:plot_titleindex] == 5
end

@testset "Plots.jl/issues/4083" begin
    p = plot(plot(1:2), plot(1:2); border = :grid, plot_title = "abc")
    @test p[1][:framestyle] === :grid
    @test p[2][:framestyle] === :grid
    @test p[3][:framestyle] === :none
end

@testset "Allowed subplot counts" begin
    p = plot(plot(1:2); layout = grid(2, 2))
    @test length(p) == 1

    p = plot((plot(1:2) for _ in 1:2)...; layout = grid(2, 2))
    @test length(p) == 2

    p = plot((plot(1:2) for _ in 1:3)...; layout = grid(2, 2))
    @test length(p) == 3
    @test length(plot!(p, plot(1:2))) == 4

    p = plot((plot(1:2) for _ in 1:4)...; layout = grid(2, 2))
    @test length(p) == 4

    @test_throws ErrorException plot((plot(1:2) for _ in 1:5)...; layout = grid(2, 2))
end

@testset "Coverage" begin
    p = plot((plot(i) for i in 1:4)..., layout = (2, 2))

    sp = p[end]
    @test sp isa Plots.Subplot
    @test size(sp) == (1, 1)
    @test length(sp) == 1
    @test sp[1, 1] == sp
    @test Plots.get_subplot(p, UInt32(4)) == sp
    @test Plots.series_list(sp) |> first |> Plots.get_subplot isa Plots.Subplot
    @test Plots.get_subplot(p, keys(p.spmap) |> first) isa Plots.Subplot

    gl = p[2, 2]
    @test gl isa Plots.GridLayout
    @test length(gl) == 1
    @test size(gl) == (1, 1)
    @test Plots.layout_args(gl) == (gl, 1)

    @test size(p, 1) == 2
    @test size(p, 2) == 2
    @test size(p) == (2, 2)
    @test ndims(p) == 2

    @test p[1][end] isa Plots.Series
    io = devnull
    show(io, p[1])

    @test Plots.getplot(p) == p
    @test Plots.getattr(p) == p.attr
    @test Plots.backend_object(p) == p.o
    @test occursin("Plot", string(p))
    print(io, p)

    @test Plots.to_pixels(1Plots.mm) isa AbstractFloat
    @test Plots.ispositive(1Plots.mm)
    @test size(Plots.defaultbox) == (0Plots.mm, 0Plots.mm)
    show(io, Plots.defaultbox)
    show(io, p.layout)

    @test Plots.make_measure_hor(1Plots.mm) == 1Plots.mm
    @test Plots.make_measure_vert(1Plots.mm) == 1Plots.mm

    @test Plots.parent(p.layout) isa Plots.RootLayout
    show(io, Plots.parent_bbox(p.layout))

    rl = Plots.RootLayout()
    show(io, rl)
    @test parent(rl) === nothing
    @test Plots.parent_bbox(rl) == Plots.defaultbox
    @test Plots.bbox(rl) == Plots.defaultbox

    el = Plots.EmptyLayout()
    @test Plots.update_position!(el) === nothing
    @test size(el) == (0, 0)
    @test length(el) == 0
    @test el[1, 1] === nothing

    @test Plots.left(el) == 0Plots.mm
    @test Plots.top(el) == 0Plots.mm
    @test Plots.right(el) == 0Plots.mm
    @test Plots.bottom(el) == 0Plots.mm

    @test_throws ErrorException Plots.layout_args(nothing)
end
