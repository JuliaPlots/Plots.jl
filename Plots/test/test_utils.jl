@testset "Utils" begin
    zipped = (
        [(1, 2)],
        [("a", "b")],
        [(1, "a"), (2, "b")],
        [(1, 2), (3, 4)],
        [(1, 2, 3), (3, 4, 5)],
        [(1, 2, 3, 4), (3, 4, 5, 6)],
        [(1, 2.0), (missing, missing)],
        [(1, missing), (missing, "a")],
        [(missing, missing)],
        [(missing, missing, missing), ("a", "b", "c")],
    )
    for z in zipped
        @test isequal(collect(zip(Plots.unzip(z)...)), z)
        @test isequal(collect(zip(Plots.unzip(GeometryBasics.Point.(z))...)), z)
    end
    op1 = Plots.process_clims((1.0, 2.0))
    op2 = Plots.process_clims((1, 2.0))
    data = randn(100, 100)
    @test op1(data) == op2(data)
    @test Plots.process_clims(nothing) ==
        Plots.process_clims(missing) ==
        Plots.process_clims(:auto)

    @test (==)(
        Plots.texmath2unicode(
            raw"Equation $y = \alpha \cdot x + \beta$ and eqn $y = \sin(x)^2$",
        ),
        raw"Equation y = α ⋅ x + β and eqn y = sin(x)²",
    )

    @test Plots.isvector([1, 2])
    @test !Plots.isvector(nothing)
    @test Plots.ismatrix([1 2; 3 4])
    @test !Plots.ismatrix(nothing)
    @test Plots.isscalar(1.0)
    @test !Plots.isscalar(nothing)
    @test Plots.anynan(1, 3, (1, NaN, 3))
    @test Plots.allnan(1, 2, (NaN, NaN, 1))
    @test Plots.makevec([]) isa AbstractVector
    @test Plots.makevec(1) isa AbstractVector
    @test Plots.maketuple(1) == (1, 1)
    @test Plots.maketuple((1, 1)) == (1, 1)
    @test Plots.ok(1, 2)
    @test !Plots.ok(1, 2, NaN)
    @test Plots.ok((1, 2, 3))
    @test !Plots.ok((1, 2, NaN))
    @test Plots.nansplit([1, 2, NaN, 3, 4]) == [[1.0, 2.0], [3.0, 4.0]]
    @test Plots.nanvcat([1, NaN]) |> length == 4

    @test Plots.inch2px(1) isa AbstractFloat
    @test Plots.px2inch(1) isa AbstractFloat
    @test Plots.inch2mm(1) isa AbstractFloat
    @test Plots.mm2inch(1) isa AbstractFloat
    @test Plots.px2mm(1) isa AbstractFloat
    @test Plots.mm2px(1) isa AbstractFloat

    pl = plot()
    @test xlims() isa Tuple
    @test ylims() isa Tuple
    @test zlims() isa Tuple

    @test_throws MethodError Plots.inline()
    @test_throws MethodError Plots._do_plot_show(plot(), :inline)

    @test plot(-1:10, xscale = :log10) isa Plots.Plot

    Plots.makekw(foo = 1, bar = 2) isa Dict

    ######################
    Plots.debug!(true)

    io = PipeBuffer()
    Plots.debugshow(io, nothing)
    Plots.debugshow(io, [1])

    pl = plot(1:2)
    Plots.dumpdict(devnull, first(pl.series_list).plotattributes)
    show(devnull, pl[1][:xaxis])

    # bounding boxes
    Plots.with(:gr) do
        show(devnull, plot(1:2))
    end

    Plots.debug!(false)
    ######################

    let pl = plot(1)
        push!(pl, 1.5)
        push!(pl, 1, 1.5)
        append!(pl, [1.0, 2.0])
        append!(pl, 1, 2.5, 2.5)
        push!(pl, (1.5, 2.5))
        push!(pl, 1, (1.5, 2.5))
        append!(pl, (1.5, 2.5))
        append!(pl, 1, (1.5, 2.5))
    end

    pl = scatter(1:2, 1:2)
    push!(pl, 2:3)
    pl = scatter(1:2, 1:2, 1:2)
    push!(pl, 1:2, 2:3, 3:4)

    pl = plot([1, 2, 3], [4, 5, 6])
    @test Plots.xmin(pl) == 1
    @test Plots.xmax(pl) == 3
    @test Plots.ignorenan_extrema(pl) == (1, 3)

    @test Plots.get_attr_symbol(:x, "lims") === :xlims
    @test Plots.get_attr_symbol(:x, :lims) === :xlims

    @test contains(Plots._document_argument(:bar_position), "bar_position")

    @test Plots.limsType((1, 1)) === :limits
    @test Plots.limsType(:undefined) === :invalid
    @test Plots.limsType(:auto) === :auto
    @test Plots.limsType(NaN) === :invalid

    @test Plots.ticksType([1, 2]) === :ticks
    @test Plots.ticksType(["1", "2"]) === :labels
    @test Plots.ticksType(([1, 2], ["1", "2"])) === :ticks_and_labels
    @test Plots.ticksType(((1, 2), ("1", "2"))) === :ticks_and_labels
    @test Plots.ticksType(:undefined) === :invalid

    pl = plot(1:2, 1:2, 1:2, proj_type = :ortho)
    @test Plots.isortho(first(pl.subplots))
    pl = plot(1:2, 1:2, 1:2, proj_type = :persp)
    @test Plots.ispersp(first(pl.subplots))

    let pl = plot(1:2)
        series = first(pl.series_list)
        label = "fancy label"
        attr!(series; label)
        @test series[:label] == label
        @test Plots.attr(series, :label) == label

        label = "another label"
        attr!(series, label, :label)
        @test Plots.attr(series, :label) == label

        sp = first(pl.subplots)
        title = "fancy title"
        attr!(sp; title)
        @test sp[:title] == title
    end
end

@testset "NaN-separated Segments" begin
    segments(args...) = collect(iter_segments(args...))

    nan10 = fill(NaN, 10)
    @test segments(11:20) == [1:10]
    @test segments([NaN]) == []
    @test segments(nan10) == []
    @test segments([nan10; 1:5]) == [11:15]
    @test segments([1:5; nan10]) == [1:5]
    @test segments([nan10; 1:5; nan10; 1:5; nan10]) == [11:15, 26:30]
    @test segments([NaN; 1], 1:10) == [2:2, 4:4, 6:6, 8:8, 10:10]
    @test segments([nan10; 1:15], [1:15; nan10]) == [11:15]
end

@testset "Invalid scale values" begin
    @test_logs match_mode = :any (:warn, r"Invalid negative or zero value.*") png(
        plot([0, 1], yscale = :log10),
        tempname(),
    )
end

@testset "Triangulation" begin
    x = [0, 1, 2, 0]
    y = [0, 0, 1, 2]
    z = [0, 2, 0, 1]

    i = [0, 0, 0, 1]
    j = [1, 2, 3, 2]
    k = [2, 3, 1, 3]

    X, Y, Z = Plots.mesh3d_triangles(x, y, z, (i, j, k))
    @test length(X) == length(Y) == length(Z) == 4length(i)

    cns = [(1, 2, 3), (1, 3, 2), (1, 4, 2), (2, 3, 4)]

    X, Y, Z = Plots.mesh3d_triangles(x, y, z, cns)
    @test length(X) == length(Y) == length(Z) == 4length(i)
end

@testset "SentinelArrays - _cycle" begin
    # discourse.julialang.org/t/plots-borking-on-sentinelarrays-produced-by-csv-read/89505
    # `CSV` produces `SentinelArrays` data
    @test scatter(ChainedVector([[1, 2], [3, 4]]), 1:4) isa Plot
end

@testset "Best legend position" begin
    x = 0:0.01:2
    pl = plot(x, x, label = "linear")
    pl = plot!(x, x .^ 2, label = "quadratic")
    pl = plot!(x, x .^ 3, label = "cubic")
    @test Plots._guess_best_legend_position(:best, pl) === :topleft

    x = OffsetArrays.OffsetArray(0:0.01:2, OffsetArrays.Origin(-3))
    pl = plot(x, x, label = "linear")
    pl = plot!(x, x .^ 2, label = "quadratic")
    pl = plot!(x, x .^ 3, label = "cubic")
    @test Plots._guess_best_legend_position(:best, pl) === :topleft

    x = OffsetArrays.OffsetArray(0:0.01:2, OffsetArrays.Origin(+3))
    pl = plot(x, x, label = "linear")
    pl = plot!(x, x .^ 2, label = "quadratic")
    pl = plot!(x, x .^ 3, label = "cubic")
    @test Plots._guess_best_legend_position(:best, pl) === :topleft

    x = 0:0.01:2
    pl = plot(x, -x, label = "linear")
    pl = plot!(x, -x .^ 2, label = "quadratic")
    pl = plot!(x, -x .^ 3, label = "cubic")
    @test Plots._guess_best_legend_position(:best, pl) === :bottomleft

    x = OffsetArrays.OffsetArray(0:0.01:2, OffsetArrays.Origin(-3))
    pl = plot(x, -x, label = "linear")
    pl = plot!(x, -x .^ 2, label = "quadratic")
    pl = plot!(x, -x .^ 3, label = "cubic")
    @test Plots._guess_best_legend_position(:best, pl) === :bottomleft

    x = [0, 1, 0, 1]
    y = [0, 0, 1, 1]
    pl = scatter(x, y, xlims = [0.0, 1.3], ylims = [0.0, 1.3], label = "test")
    @test Plots._guess_best_legend_position(:best, pl) === :topright

    pl = scatter(x, y, xlims = [-0.3, 1.0], ylims = [-0.3, 1.0], label = "test")
    @test Plots._guess_best_legend_position(:best, pl) === :bottomleft

    pl = scatter(x, y, xlims = [0.0, 1.3], ylims = [-0.3, 1.0], label = "test")
    @test Plots._guess_best_legend_position(:best, pl) === :bottomright

    pl = scatter(x, y, xlims = [-0.3, 1.0], ylims = [0.0, 1.3], label = "test")
    @test Plots._guess_best_legend_position(:best, pl) === :topleft

    y1 = [
        0.6640202072697099,
        0.04435946459047402,
        0.4819421561655691,
        0.7812872333045798,
        0.9468591660437995,
        0.5530071466041402,
        0.22969207890925003,
        0.48741164266779236,
        0.0546763558355734,
        0.1432072797975329,
    ]
    y2 = [0.40089741940615464, 0.6687326060649715, 0.6844117863127116]
    pl = plot(1:10, y1)
    pl = plot!(1:3, y2, xlims = (0, 10), ylims = (0, 1))
    @test Plots._guess_best_legend_position(:best, pl) === :topright

    # test empty plot
    pl = plot([])
    @test Plots._guess_best_legend_position(:best, pl) === :topright

    # test that we didn't overlap other placements
    @test Plots._guess_best_legend_position(:bottomleft, pl) === :bottomleft

    # test singleton
    pl = plot(1:1)
    @test Plots._guess_best_legend_position(:best, pl) === :topright

    # test cycling indexes
    x = 0.0:0.1:1
    y = [1, 2, 3]
    pl = scatter(x, y)
    @test Plots._guess_best_legend_position(:best, pl) === :topright

    # Test step plot with variable limits
    x = 0:0.001:1
    y = vcat([0.0 for _ in 1:100], [1.0 for _ in 101:200], [0.5 for _ in 201:1001])
    pl = scatter(x, y)
    @test Plots._guess_best_legend_position(:best, pl) === :topright
    pl = scatter(x, y, xlims = [0, 0.25])
    @test Plots._guess_best_legend_position(:best, pl) === :topleft
    pl = scatter(x, y, xlims = [0.1, 0.25])
    @test Plots._guess_best_legend_position(:best, pl) === :topright
    pl = scatter(x, y, xlims = [0.18, 0.25])
    @test Plots._guess_best_legend_position(:best, pl) === :topright
    pl = scatter(x, y, ylims = [-1, 0.75])
    @test Plots._guess_best_legend_position(:best, pl) === :bottomright
    pl = scatter(x, y, ylims = [0.25, 0.75])
    @test Plots._guess_best_legend_position(:best, pl) === :topright
    pl = scatter(-x, y, ylims = [0.25, 0.75])
    @test Plots._guess_best_legend_position(:best, pl) === :topright
    pl = scatter(-x, y)
    @test Plots._guess_best_legend_position(:best, pl) === :topleft
    pl = scatter(-x, -y)
    @test Plots._guess_best_legend_position(:best, pl) === :topleft
    pl = scatter(x, -y)
    @test Plots._guess_best_legend_position(:best, pl) === :topright
end

@testset "dispatch" begin
    Plots.with(:gr) do
        pl = heatmap(rand(10, 10); xscale = :log10, yscale = :log10)
        @test show(devnull, pl) isa Nothing

        pl = plot(Shape([(1, 1), (2, 1), (2, 2), (1, 2)]); xscale = :log10)
        @test show(devnull, pl) isa Nothing
    end
end
