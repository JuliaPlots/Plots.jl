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

    @testset "Colorbar attributes" begin
        pl = heatmap(
            [1.0 10.0; 100.0 1000.0];
            colorbar_title = "Intensity",
            colorbar_scale = :log10,
            colorbar_ticks = ([1.0, 1000.0], ["low", "high"]),
            colorbar_tickfont = font(9, "Courier", :left, :top, 30.0),
            colorbar_titlefont = font(12, "Times"),
        )
        series_dict = PlotsBase.plotly_series(pl)[1]
        colorbar = series_dict[:colorbar]
        @test vec(series_dict[:z]) == [0.0, 1.0, 2.0, 3.0]
        @test series_dict[:zmin] == 0.0
        @test series_dict[:zmax] == 3.0
        @test colorbar[:title][:text] == "Intensity"
        @test colorbar[:title][:font][:family] == "Times"
        @test colorbar[:tickfont][:family] == "Courier"
        @test colorbar[:tickfont][:size] == round(Int, 1.4 * 9)
        @test colorbar[:tickangle] == -30.0
        @test colorbar[:tickmode] == "array"
        @test colorbar[:tickvals] == [0.0, 3.0]
        @test colorbar[:ticktext] == ["low", "high"]

        colorbar = PlotsBase.plotly_series(
            heatmap(rand(2, 2); colorbar_ticks = false),
        )[1][:colorbar]
        @test colorbar[:showticklabels] == false
        @test colorbar[:ticks] == ""
    end
end
