using Plots, Test

@testset "Shape Copy" begin
    square = Shape([(0,0),(1,0),(1,1),(0,1)])
    square2 = Shape(square)
    @test square2.x == square.x
    @test square2.y == square.y
end

@testset "Shape Center" begin
    square = Shape([(0,0),(1,0),(1,1),(0,1)])
    @test Plots.center(square) == (0.5,0.5)
end

@testset "Shape Translate" begin
    square = Shape([(0,0),(1,0),(1,1),(0,1)])
    squareUp = Shape([(0,1),(1,1),(1,2),(0,2)])
    squareUpRight = Shape([(1,1),(2,1),(2,2),(1,2)])

    @test Plots.translate(square,0,1).x == squareUp.x
    @test Plots.translate(square,0,1).y == squareUp.y

    @test Plots.center(translate!(square,1)) == (1.5,1.5)
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
