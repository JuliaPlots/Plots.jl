using PlotsBase, Test
Sys.isunix() && with(:plotly) do
    @testset "Basic" begin
        @test backend() == PlotsBase.PlotlyBackend()

        pl = plot(rand(10))
        @test pl isa PlotsBase.Plot
        @test_nowarn PlotsBase.plotly_series(plot())
        @test !haskey(PlotsBase.plotly_series(pl)[1], :zmax)
    end

    @testset "Contours" begin
        x = (-2π):0.1:(2π)
        y = (-π):0.1:π
        z = cos.(y) .* sin.(x')

        @testset "Contour numbers" begin
            @testset "Default" begin
                @test PlotsBase.plotly_series(contour(x, y, z))[1][:ncontours] ==
                    PlotsBase._series_defaults[:levels] + 2
            end
            @testset "Specified number" begin
                cont = contour(x, y, z, levels = 10)
                @test PlotsBase.plotly_series(cont)[1][:ncontours] == 12
            end
        end

        @testset "Contour values" begin
            @testset "Range" begin
                levels = -1:0.5:1
                pl = contour(x, y, z, levels = levels)
                @test pl[1][1].plotattributes[:levels] == levels
                @test PlotsBase.plotly_series(pl)[1][:contours][:start] == first(levels)
                @test PlotsBase.plotly_series(pl)[1][:contours][:end] == last(levels)
                @test PlotsBase.plotly_series(pl)[1][:contours][:size] == step(levels)
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
                ) PlotsBase.plotly_series(pl)
                @test series_dict[1][:contours][:start] == first(levels_range)
                @test series_dict[1][:contours][:end] == last(levels_range)
                @test series_dict[1][:contours][:size] == step(levels_range)
            end
        end
    end

    @testset "Extra kwargs" begin
        pl = plot(1:5, test = "me")
        @test PlotsBase.plotly_series(pl)[1][:test] == "me"
        pl = plot(1:5, test = "me", extra_kwargs = :plot)
        @test PlotsBase.plotly_layout(pl)[:test] == "me"
    end

    @testset "Requirejs" begin
        pl = plot(sin, 0, 2pi)
        io = PipeBuffer()
        show(io, MIME("text/html"), pl)
        html = read(io, String)
        # FIXME: how can we write a test checking that the html correctly draw a plotly plot ?
    end

    @testset "Colorbar properties" begin
        pl = heatmap(
            reshape(1:9, 3, 3);
            colorbar_ticks = ([2, 5, 8], ["low", "mid", "high"]),
            colorbar_tickfont = (12, :red, 45.0),
            colorbar_tickcolor = :blue,
            colorbar_ticklinewidth = 2,
            colorbar_bordercolor = :green,
            colorbar_borderlinewidth = 3,
            colorbar_width = 0.05,
            colorbar_height = 0.75,
            colorbar_title = "Styled",
        )
        colorbar = PlotsBase.plotly_series(pl)[1][:colorbar]
        @test colorbar[:title][:text] == "Styled"
        @test colorbar[:tickfont][:size] == round(Int, 1.4 * 12)
        @test colorbar[:tickfont][:color] == "rgba(255, 0, 0, 1.000)"
        @test colorbar[:tickcolor] == "rgba(0, 0, 255, 1.000)"
        @test colorbar[:tickwidth] == 2
        @test colorbar[:outlinecolor] == "rgba(0, 128, 0, 1.000)"
        @test colorbar[:outlinewidth] == 3
        @test colorbar[:thicknessmode] == "fraction"
        @test colorbar[:thickness] == 0.05
        @test colorbar[:lenmode] == "fraction"
        @test colorbar[:len] == 0.75
        @test colorbar[:tickmode] == "array"
        @test colorbar[:tickvals] == [2, 5, 8]
        @test colorbar[:ticktext] == ["low", "mid", "high"]
    end
end
