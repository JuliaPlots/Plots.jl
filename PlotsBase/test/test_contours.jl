@testset "check_contour_levels" begin
    let check_contour_levels = PlotsBase.Commons.check_contour_levels
        @test check_contour_levels(2) ≡ nothing
        @test check_contour_levels(-1.0:0.2:10.0) ≡ nothing
        @test check_contour_levels([-100, -2, -1, 0, 1, 2, 100]) ≡ nothing
        @test_throws ArgumentError check_contour_levels(1.0)
        @test_throws ArgumentError check_contour_levels((1, 2, 3))
        @test_throws ArgumentError check_contour_levels(-3)
    end
end

@testset "Commons.preprocess_attributes!" begin
    function equal_after_pipeline(kw)
        kw′ = deepcopy(kw)
        PlotsBase.Commons.preprocess_attributes!(kw′)
        kw == kw′
    end

    @test equal_after_pipeline(KW(:levels => 1))
    @test equal_after_pipeline(KW(:levels => 1:10))
    @test equal_after_pipeline(KW(:levels => [1.0, 3.0, 5.0]))
    @test_throws ArgumentError PlotsBase.Commons.preprocess_attributes!(KW(:levels => 1.0))
    @test_throws ArgumentError PlotsBase.Commons.preprocess_attributes!(
        KW(:levels => (1, 2, 3)),
    )
    @test_throws ArgumentError PlotsBase.Commons.preprocess_attributes!(KW(:levels => -3))
end

@testset "contour[f]" begin
    x = (-2π):0.1:(2π)
    y = (-π):0.1:π
    z = cos.(y) .* sin.(x')

    @testset "Incorrect input" begin
        @test_throws ArgumentError contour(x, y, z, levels = 1.0)
        @test_throws ArgumentError contour(x, y, z, levels = (1, 2, 3))
        @test_throws ArgumentError contour(x, y, z, levels = -3)
    end

    @testset "Default number" begin
        @test contour(x, y, z)[1][1].plotattributes[:levels] ==
            PlotsBase._series_defaults[:levels]
    end

    @testset "Number" begin
        @testset "$n contours" for n in (2, 5, 100)
            p = contour(x, y, z, levels = n)
            attr = p[1][1].plotattributes
            @test attr[:seriestype] ≡ :contour
            @test attr[:levels] == n
        end
    end

    @testset "Range" begin
        levels = -1:0.5:1
        @test contour(x, y, z, levels = levels)[1][1].plotattributes[:levels] == levels
    end

    @testset "Set of levels" begin
        levels = [-1, 0.25, 0, 0.25, 1]
        @test contour(x, y, z, levels = levels)[1][1].plotattributes[:levels] == levels
    end
end

@testset "contour levels given as a range" begin
    # github.com/JuliaPlots/Plots.jl/issues/4806
    z = [x^2 + y^2 for x in -5:5, y in -5:5]  # `maximum(z)` is 50, above every level below
    with(:gr) do
        for levels in (5:5:40, range(5, 40, length = 8), collect(5:5:40))
            @test png(contourf(-5:5, -5:5, z; levels), tempname()) isa AbstractString
        end
    end
end

@testset "drawing does not mutate the given levels" begin
    given = collect(5:5:40)
    pl = contourf(-5:5, -5:5, [x^2 + y^2 for x in -5:5, y in -5:5]; levels = given)
    with(:gr) do
        png(pl, tempname())
    end
    @test given == 5:5:40
    @test pl.series_list[1][:levels] == 5:5:40
end
