@testset "Shapes" begin
    @testset "Type" begin
        square = Shape([(0, 0.0), (1, 0.0), (1, 1.0), (0, 1.0)])
        @test Plots.get_xs(square) == [0, 1, 1, 0]
        @test Plots.get_ys(square) == [0, 0, 1, 1]
        @test Plots.vertices(square) == [(0, 0), (1, 0), (1, 1), (0, 1)]
        @test isa(square, Shape{Int64,Float64})
        @test coords(square) isa Tuple{Vector{S},Vector{T}} where {T,S}
        @test Shape(:circle) isa Shape

        xs = view([0.0, 1.0, 2.0, 1.25], 1:3)
        ys = view([6 4 7; 9 9 9], 1, :)
        tri = Shape(xs, ys)
        @test isa(tri, Shape{Float64,Int64})
        @test Plots.vertices(tri) == [(0.0, 6), (1.0, 4), (2.0, 7)]
    end

    @testset "Copy" begin
        square = Shape([(0, 0), (1, 0), (1, 1), (0, 1)])
        square2 = Shape(square)
        @test square2.x == square.x
        @test square2.y == square.y
    end

    @testset "Center" begin
        square = Shape([(0, 0), (1, 0), (1, 1), (0, 1)])
        @test Plots.center(square) == (0.5, 0.5)
    end

    @testset "Translate" begin
        square = Shape([(0, 0), (1, 0), (1, 1), (0, 1)])
        squareUp = Shape([(0, 1), (1, 1), (1, 2), (0, 2)])
        squareUpRight = Shape([(1, 1), (2, 1), (2, 2), (1, 2)])

        @test Plots.translate(square, 0, 1).x == squareUp.x
        @test Plots.translate(square, 0, 1).y == squareUp.y

        @test Plots.center(translate!(square, 1)) == (1.5, 1.5)
    end

    @testset "Rotate" begin
        # 2 radians rotation matrix
        R2 = [cos(2) sin(2); -sin(2) cos(2)]
        coords = [0 0; 1 0; 1 1; 0 1]'
        coordsRotated2 = R2 * (coords .- 0.5) .+ 0.5

        square = Shape([(0, 0), (1, 0), (1, 1), (0, 1)])

        # make a new, rotated square
        square2 = Plots.rotate(square, -2)
        @test square2.x ≈ coordsRotated2[1, :]
        @test square2.y ≈ coordsRotated2[2, :]

        # unrotate the new square in place
        rotate!(square2, 2)
        @test square2.x ≈ coords[1, :]
        @test square2.y ≈ coords[2, :]
    end

    @testset "Plot" begin
        ang = range(0, 2π, length = 60)
        ellipse(x, y, w, h) = Shape(w * sin.(ang) .+ x, h * cos.(ang) .+ y)
        myshapes = [ellipse(x, rand(), rand(), rand()) for x in 1:4]
        @test coords(myshapes) isa Tuple{Vector{Vector{S}},Vector{Vector{T}}} where {T,S}
        local pl
        @test_nowarn pl = plot(myshapes)
        @test pl[1][1][:seriestype] === :shape
    end

    @testset "Misc" begin
        @test Plots.weave([1, 3], [2, 4]) == collect(1:4)
        @test Plots.makeshape(3) isa Plots.Shape
        @test Plots.makestar(3) isa Plots.Shape
        @test Plots.makecross() isa Plots.Shape
        @test Plots.makearrowhead(10.0) isa Plots.Shape

        @test Plots.rotate(1.0, 2.0, 5.0, (0, 0)) isa Tuple

        star = Plots.makestar(3)
        star_scaled = Plots.scale(star, 0.5)

        Plots.scale!(star, 0.5)
        @test Plots.get_xs(star) == Plots.get_xs(star_scaled)
        @test Plots.get_ys(star) == Plots.get_ys(star_scaled)

        @test Plots.extrema_plus_buffer([1, 2], 0.1) == (0.9, 2.1)
    end
end

@testset "Brush" begin
    @testset "Colors" begin
        baseline = brush(1, RGB(0, 0, 0))
        @test brush(:black) == baseline
        @test brush("black") == baseline
    end
    @testset "Weight" begin
        @test brush(10).size == 10
        @test brush(0.1).size == 1
    end
    @testset "Alpha" begin
        @test brush(0.4).alpha == 0.4
        @test brush(20).alpha === nothing
    end
    @testset "Bad Argument" begin
        # using test_logs because test_warn seems to not work anymore
        @test_logs (:warn, "Unused brush arg: nothing (Nothing)") begin
            brush(nothing)
        end
    end
end

@testset "Text" begin
    t = Plots.PlotText("foo")
    @test length(t) == 3

    f = Plots.font()
    @test Plots.PlotText(nothing).str == "nothing"
    @test text(t).str == "foo"
    @test text(t, f).str == "foo"
    @test text("bar", f).str == "bar"
    @test text(true).str == "true"

    for rotation in -180:5:180
        t = text("foo"; rotation)
        if abs(rotation) ≤ 45 || abs(rotation) ≥ 135
            @test Plots.is_horizontal(t)
        else
            @test !Plots.is_horizontal(t)
        end
    end
end

@testset "Annotations" begin
    ann = Plots.series_annotations(missing)

    @test Plots.series_annotations(["1" "2"; "3" "4"]) isa AbstractMatrix
    @test Plots.series_annotations(10).strs[1].str == "10"
    @test Plots.series_annotations(nothing) === nothing
    @test Plots.series_annotations(ann) == ann

    @test Plots.annotations(["1" "2"; "3" "4"]) isa AbstractMatrix
    @test Plots.annotations(ann) == ann
    @test Plots.annotations([ann]) == [ann]
    @test Plots.annotations(nothing) == []

    t = Plots.text("foo")
    sp = plot(1)[1]
    @test Plots.locate_annotation(sp, 1, 2, t) == (1, 2, t)
    @test Plots.locate_annotation(sp, 1, 2, 3, t) == (1, 2, 3, t)
    @test Plots.locate_annotation(sp, (0.1, 0.2), t) isa Tuple
    @test Plots.locate_annotation(sp, (0.1, 0.2, 0.3), t) isa Tuple

    # see github.com/JuliaPlots/Plots.jl/issues/4073
    anns = [(["x", "y"], [10, 20], :hexagon) (["a", "b"], [3, 4], :circle)]
    pl = plot(rand(2, 2), layout = 2, series_annotations = anns)

    # github.com/JuliaPlots/Plots.jl/pull/3634#issue-940055478
    let p = plot(
            plot(rand(10) .* 15, aspect_ratio = :equal),
            plot(rand(10) .* 10, aspect_ratio = :equal),
            legend = false,
            layout = grid(1, 2),
            frame = :box,
        )
        annotate!(sp = 1, (0.03, 0.95), text("Cats&Dogs", :left))
        annotate!(sp = 2, (0.03, 0.95), text("Cats&Dogs", :left))
    end

    for scale in Plots._logScales
        pl = plot(xlim = (1, 10), xscale = scale)
        annotate!(pl, (0.5, 0.5), "hello")
    end

    let pl = plot(1:2)
        for loc in
            (:topleft, :topcenter, :topright, :bottomleft, :bottomcenter, :bottomright)
            annotate!(pl, loc, string(loc))
        end
    end
    let pl = plot(1:2)
        for loc in (:N, :NE, :E, :SE, :S, :SW, :W, :NW, :N)
            annotate!(pl, loc, string(loc))
        end
    end
end

@testset "Fonts" begin
    @testset "Scaling" begin
        sizesToCheck = [
            :titlefontsize,
            :legendfontsize,
            :legendtitlefontsize,
            :xtickfontsize,
            :ytickfontsize,
            :ztickfontsize,
            :xguidefontsize,
            :yguidefontsize,
            :zguidefontsize,
        ]
        # get initial font sizes
        initialSizes = [Plots.default(s) for s in sizesToCheck]

        #scale up font sizes
        scalefontsizes(2)

        # get initial font sizes
        doubledSizes = [Plots.default(s) for s in sizesToCheck]

        @test doubledSizes == initialSizes * 2

        # reset font sizes
        resetfontsizes()

        finalSizes = [Plots.default(s) for s in sizesToCheck]

        @test finalSizes == initialSizes
    end
end

@testset "Series Annotations" begin
    square = Shape([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
    @test_logs (:warn, "Unused SeriesAnnotations arg: triangle (Symbol)") begin
        pl = plot(
            [1, 2, 3],
            series_annotations = (
                ["a"],
                2,    # pass a scale factor
                (1, 4), # pass two scale factors (overwrites first one)
                square, # pass a shape
                font(:courier), # pass an annotation font
                :triangle,  # pass an incorrect argument
            ),
        )
        sa = pl.series_list[1].plotattributes[:series_annotations]
        @test only(sa.strs).str == "a"
        @test sa.font.family == "courier"
        @test sa.baseshape == square
        @test sa.scalefactor == (1, 4)
    end
    spl = scatter(
        4.53 .* [1 / 1 1 / 2 1 / 3 1 / 4 1 / 5],
        [0 0 0 0 0],
        layout = (5, 1),
        ylims = (-1.1, 1.1),
        xlims = (0, 5),
        series_annotations = permutedims([["1/1"], ["1/2"], ["1/3"], ["1/4"], ["1/5"]]),
    )
    for i in 1:5
        @test only(spl.series_list[i].plotattributes[:series_annotations].strs).str ==
              "1/$i"
    end

    series_anns(pl, series) = pl.series_list[series].plotattributes[:series_annotations]
    ann_strings(ann) = [s.str for s in ann.strs]
    ann_pointsizes(ann) = [s.font.pointsize for s in ann.strs]

    let pl = plot(ones(3, 2), series_annotations = ["a" "d"; "b" "e"; "c" "f"])
        ann1 = series_anns(pl, 1)
        @test ann_strings(ann1) == ["a", "b", "c"]

        ann2 = series_anns(pl, 2)
        @test ann_strings(ann2) == ["d", "e", "f"]
    end

    let pl = plot(ones(2, 2), series_annotations = (["a" "c"; "b" "d"], square))
        ann1 = series_anns(pl, 1)
        @test ann_strings(ann1) == ["a", "b"]

        ann2 = series_anns(pl, 2)
        @test ann_strings(ann2) == ["c", "d"]

        @test ann1.baseshape == ann2.baseshape == square
    end

    let pl = plot(
            ones(3, 2),
            series_annotations = (
                permutedims([
                    (["x", "y", "z"], [10, 20, 30], (14, 15), square),
                    [("a", 42), "b", "c"],
                ]),
                (12, 13),
            ),
        )
        ann1 = series_anns(pl, 1)
        @test ann1.baseshape == square
        @test ann1.scalefactor == (14, 15)
        @test ann_strings(ann1) == ["x", "y", "z"]
        @test ann_pointsizes(ann1) == [10, 20, 30]

        ann2 = series_anns(pl, 2)
        @test ann2.scalefactor == (12, 13)
        @test ann_strings(ann2) == ["a", "b", "c"]
        @test ann2.strs[1].font.pointsize == 42
    end

    @test_throws ArgumentError plot(ones(2, 2), series_annotations = [([1],) 2; 3 4])

    pl = plot([1, 2], annotations = (1.5, 2, text("foo", :left)))
    x, y, txt = only(pl.subplots[end][:annotations])
    @test (x, y) == (1.5, 2)
    @test txt.str == "foo"

    pl = plot([1, 2], annotations = ((0.1, 0.5), :auto))
    pos, txt = only(pl.subplots[end][:annotations])
    @test pos == (0.1, 0.5)
    @test txt.str == "(a)"
end

@testset "Bezier" begin
    curve = Plots.BezierCurve([(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)])
    @test curve(0.75) == (0.75, 0.375)
    @test length(coords(curve, 10)) == 10
end
