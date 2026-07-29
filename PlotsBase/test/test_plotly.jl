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

    @testset "Colorbar" begin
        cbar(pl) = (PlotsBase.prepare_output(pl); PlotsBase.plotly_series(pl)[1][:colorbar])

        pl = heatmap(rand(10, 10); colorbar_title = "cbar")
        cb = cbar(pl)
        @test cb[:title][:text] == "cbar"
        # backend defaults are kept when nothing is requested
        @test !haskey(cb, :outlinewidth)
        @test !haskey(cb, :thickness)

        len, thickness =
            cb[:len], PlotsBase.Plotly.plotly_domain(pl[1])[1] |> diff |> first
        cb = cbar(
            heatmap(
                rand(10, 10);
                colorbar_width = 0.1,
                colorbar_height = 0.5,
                colorbar_border_color = :red,
                colorbar_border_width = 2,
                colorbar_tickfontcolor = :blue,
            ),
        )
        @test cb[:len] ≈ 0.5len
        @test cb[:thicknessmode] == "fraction"
        @test cb[:thickness] ≈ 0.1thickness
        @test cb[:outlinewidth] == 2
        @test cb[:outlinecolor] == PlotsBase.rgba_string(PlotsBase.plot_color(:red))
        @test cb[:tickfont][:color] == PlotsBase.rgba_string(PlotsBase.plot_color(:blue))

        # setting the border color alone is enough to request a border
        @test cbar(heatmap(rand(10, 10); colorbar_border_color = :red))[:outlinewidth] == 1

        cb = cbar(heatmap(rand(10, 10); colorbar_ticks = ([0.2, 0.8], ["lo", "hi"])))
        @test cb[:tickmode] == "array"
        @test cb[:tickvals] == [0.2, 0.8]
        @test cb[:ticktext] == ["lo", "hi"]

        @test cbar(heatmap(rand(10, 10); colorbar_ticks = :none))[:showticklabels] == false
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
end
