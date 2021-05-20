using Plots, Test

@testset "Shapes" begin
    @testset "Type" begin
        square = Shape([(0,0.0),(1,0.0),(1,1.0),(0,1.0)])
        @test isa(square, Shape{Int64, Float64})
        @test coords(square) isa Tuple{Vector{S}, Vector{T}} where {T,S}
    end

    @testset "Copy" begin
        square = Shape([(0,0),(1,0),(1,1),(0,1)])
        square2 = Shape(square)
        @test square2.x == square.x
        @test square2.y == square.y
    end

    @testset "Center" begin
        square = Shape([(0,0),(1,0),(1,1),(0,1)])
        @test Plots.center(square) == (0.5,0.5)
    end

    @testset "Translate" begin
        square = Shape([(0,0),(1,0),(1,1),(0,1)])
        squareUp = Shape([(0,1),(1,1),(1,2),(0,2)])
        squareUpRight = Shape([(1,1),(2,1),(2,2),(1,2)])

        @test Plots.translate(square,0,1).x == squareUp.x
        @test Plots.translate(square,0,1).y == squareUp.y

        @test Plots.center(translate!(square,1)) == (1.5,1.5)
    end

    @testset "Rotate" begin
        # 2 radians rotation matrix
        R2 = [cos(2) sin(2); -sin(2) cos(2)]
        coords = [0 0; 1 0; 1 1; 0 1]'
        coordsRotated2 = R2*(coords.-0.5).+0.5

        square = Shape([(0,0),(1,0),(1,1),(0,1)])

        # make a new, rotated square
        square2 = Plots.rotate(square, -2)
        @test square2.x ≈ coordsRotated2[1,:]
        @test square2.y ≈ coordsRotated2[2,:]

        # unrotate the new square in place
        rotate!(square2, 2)
        @test square2.x ≈ coords[1,:]
        @test square2.y ≈ coords[2,:]
    end

    @testset "Plot" begin
        ang = range(0, 2π, length = 60)
        ellipse(x, y, w, h) = Shape(w*sin.(ang).+x, h*cos.(ang).+y)
        myshapes = [ellipse(x,rand(),rand(),rand()) for x = 1:4]
        @test coords(myshapes) isa Tuple{Vector{Vector{S}}, Vector{Vector{T}}} where {T,S}
        local p
        @test_nowarn p = plot(myshapes)
        @test p[1][1][:seriestype] == :shape
    end
end

@testset "Brush" begin
    @testset "Colors" begin
        baseline = brush(1, RGB(0,0,0))
        @test brush(:black) == baseline
        @test brush("black") == baseline
    end
    @testset "Weight" begin
        @test brush(10).size == 10
        @test brush(0.1).size == 1
    end
    @testset "Alpha" begin
        @test brush(0.4).alpha == 0.4
        @test brush(20).alpha == nothing
    end
    @testset "Bad Argument" begin
        # using test_logs because test_warn seems to not work anymore
        @test_logs (:warn,"Unused brush arg: nothing (Nothing)") begin
            brush(nothing)
        end
    end
end

@testset "Fonts" begin
    @testset "Scaling" begin
        sizesToCheck = [:titlefontsize, :legendfontsize, :legendtitlefontsize,
            :xtickfontsize, :ytickfontsize, :ztickfontsize,
            :xguidefontsize, :yguidefontsize, :zguidefontsize,]
        # get inital font sizes
        initialSizes = [Plots.default(s) for s in sizesToCheck ]

        #scale up font sizes
        scalefontsizes(2)

        # get inital font sizes
        doubledSizes = [Plots.default(s) for s in sizesToCheck ]

        @test doubledSizes == initialSizes*2

        # reset font sizes
        resetfontsizes()

        finalSizes = [Plots.default(s) for s in sizesToCheck ]

        @test finalSizes == initialSizes
    end
end

@testset "Series Annotations" begin
    square = Shape([(0,0),(1,0),(1,1),(0,1)])
    @test_logs (:warn,"Unused SeriesAnnotations arg: triangle (Symbol)") begin
        p = plot([1,2,3],
            series_annotations=(["a"],
                                 2,    # pass a scale factor
                                 (1,4), # pass two scale factors (overwrites first one)
                                 square, # pass a shape
                                 font(:courier), # pass an annotation font
                                 :triangle  # pass an incorrect argument
                            ))
        sa = p.series_list[1].plotattributes[:series_annotations]
        @test sa.strs == ["a"]
        @test sa.font.family == "courier"
        @test sa.baseshape == square
        @test sa.scalefactor == (1,4)
    end
end
