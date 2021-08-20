using Plots, Test

@testset "Plotly" begin
    @testset "Basic" begin
        @test plotly() == Plots.PlotlyBackend()
        @test backend() == Plots.PlotlyBackend()

        p = plot(rand(10))
        @test isa(p, Plots.Plot) == true
    end

    @testset "Contours" begin
        x = (-2π):0.1:(2π)
        y = (-π):0.1:π
        z = cos.(y) .* sin.(x')

        @testset "Contour numbers" begin
            @testset "Default" begin
                @test Plots.plotly_series(contour(x, y, z))[1][:ncontours] ==
                      Plots._series_defaults[:levels] + 2
            end
            @testset "Specified number" begin
                @test Plots.plotly_series(contour(x, y, z, levels = 10))[1][:ncontours] ==
                      12
            end
        end

        @testset "Contour values" begin
            @testset "Range" begin
                levels = -1:0.5:1
                p = contour(x, y, z, levels = levels)
                @test p[1][1].plotattributes[:levels] == levels
                @test Plots.plotly_series(p)[1][:contours][:start] == first(levels)
                @test Plots.plotly_series(p)[1][:contours][:end] == last(levels)
                @test Plots.plotly_series(p)[1][:contours][:size] == step(levels)
            end

            @testset "Set of contours" begin
                levels = [-1, -0.25, 0, 0.25, 1]
                levels_range =
                    range(first(levels), stop = last(levels), length = length(levels))
                p = contour(x, y, z, levels = levels)
                @test p[1][1].plotattributes[:levels] == levels
                series_dict = @test_logs (
                    :warn,
                    "setting arbitrary contour levels with Plotly backend " *
                    "is not supported; use a range to set equally-spaced contours or an " *
                    "integer to set the approximate number of contours with the keyword " *
                    "`levels`. Using levels -1.0:0.5:1.0",
                ) Plots.plotly_series(p)
                @test series_dict[1][:contours][:start] == first(levels_range)
                @test series_dict[1][:contours][:end] == last(levels_range)
                @test series_dict[1][:contours][:size] == step(levels_range)
            end
        end
    end
end
