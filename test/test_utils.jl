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
        @test isequal(collect(zip(Plots.RecipesPipeline.unzip(z)...)), z)
        @test isequal(
            collect(zip(Plots.RecipesPipeline.unzip(GeometryBasics.Point.(z))...)),
            z,
        )
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
    @test Plots.tovec([]) isa AbstractVector
    @test Plots.tovec(nothing) isa AbstractVector
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

    @test Plots.nop() === nothing
    @test_throws ErrorException Plots.notimpl()

    @test Plots.inch2px(1) isa AbstractFloat
    @test Plots.px2inch(1) isa AbstractFloat
    @test Plots.inch2mm(1) isa AbstractFloat
    @test Plots.mm2inch(1) isa AbstractFloat
    @test Plots.px2mm(1) isa AbstractFloat
    @test Plots.mm2px(1) isa AbstractFloat

    p = plot()
    @test xlims() isa Tuple
    @test ylims() isa Tuple
    @test zlims() isa Tuple

    @test_throws ErrorException Plots.inline()
    @test_throws ErrorException Plots._do_plot_show(plot(), :inline)
    @test_throws ErrorException Plots.dumpcallstack()

    @test plot(-1:10, xscale = :log10) isa Plot

    Plots.makekw(foo = 1, bar = 2) isa Dict

    Plots.debugplots(true)
    Plots.debugplots(false)

    io = PipeBuffer()
    Plots.debugshow(io, nothing)
    Plots.debugshow(io, [1])

    p = plot(1)
    push!(p, 1.5)
    push!(p, 1, 1.5)
    # append!(p, [1., 2.])
    append!(p, 1, 2.5, 2.5)
    push!(p, (1.5, 2.5))
    push!(p, 1, (1.5, 2.5))
    append!(p, (1.5, 2.5))
    append!(p, 1, (1.5, 2.5))

    p = plot([1, 2, 3], [4, 5, 6])
    @test Plots.xmin(p) == 1
    @test Plots.xmax(p) == 3
    @test Plots.ignorenan_extrema(p) == (1, 3)

    @test Plots.get_attr_symbol(:x, "lims") === :xlims
    @test Plots.get_attr_symbol(:x, :lims) === :xlims

    @test contains(Plots._document_argument("bar_position"), "bar_position")
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
