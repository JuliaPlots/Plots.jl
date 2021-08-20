using Plots, Test

@testset "Contours" begin
    x = (-2π):0.1:(2π)
    y = (-π):0.1:π
    z = cos.(y) .* sin.(x')

    @testset "Default number" begin
        @test contour(x, y, z)[1][1].plotattributes[:levels] ==
              Plots._series_defaults[:levels]
    end

    @testset "Number" begin
        @testset "$n contours" for n in (2, 5, 100)
            p = contour(x, y, z, levels = n)
            attr = p[1][1].plotattributes
            @test attr[:seriestype] == :contour
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
