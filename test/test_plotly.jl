using Plots, Test
Sys.isunix() && Plots.with(:plotly) do
    @testset "Basic" begin
        @test backend() == Plots.PlotlyBackend()

        pl = plot(rand(10))
        @test pl isa Plots.Plot
        @test_nowarn Plots.plotly_series(plot())
        @test !haskey(Plots.plotly_series(pl)[1], :zmax)
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
                cont = contour(x, y, z, levels = 10)
                @test Plots.plotly_series(cont)[1][:ncontours] == 12
            end
        end

        @testset "Contour values" begin
            @testset "Range" begin
                levels = -1:0.5:1
                pl = contour(x, y, z, levels = levels)
                @test pl[1][1].plotattributes[:levels] == levels
                @test Plots.plotly_series(pl)[1][:contours][:start] == first(levels)
                @test Plots.plotly_series(pl)[1][:contours][:end] == last(levels)
                @test Plots.plotly_series(pl)[1][:contours][:size] == step(levels)
            end

            @testset "Set of contours" begin
                levels = [-1, -0.25, 0, 0.25, 1]
                levels_range =
                    range(first(levels), stop = last(levels), length = length(levels))
                pl = contour(x, y, z, levels = levels)
                @test pl[1][1].plotattributes[:levels] == levels
                series_dict = @test_logs (
                    :warn,
                    """
             setting arbitrary contour levels with Plotly backend is not supported;
             use a range to set equally-spaced contours or an integer to set the
             approximate number of contours with the keyword `levels`.
             Setting levels to -1.0:0.5:1.0
             """,
                ) Plots.plotly_series(pl)
                @test series_dict[1][:contours][:start] == first(levels_range)
                @test series_dict[1][:contours][:end] == last(levels_range)
                @test series_dict[1][:contours][:size] == step(levels_range)
            end
        end
    end

    @testset "Extra kwargs" begin
        pl = plot(1:5, test = "me")
        @test Plots.plotly_series(pl)[1][:test] == "me"
        pl = plot(1:5, test = "me", extra_kwargs = :plot)
        @test Plots.plotly_layout(pl)[:test] == "me"
    end
end
