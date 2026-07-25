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
        @test PlotsBase.Plotly.plotly_colorbar_dimension(
            :auto,
            PlotsBase.Plotly._plotly_colorbar_width_default,
            "colorbar_width",
        ) == PlotsBase.Plotly._plotly_colorbar_width_default
        @test PlotsBase.Plotly.plotly_colorbar_dimension(
            -0.5,
            PlotsBase.Plotly._plotly_colorbar_width_default,
            "colorbar_width",
        ) == 0.0
        @test_throws ArgumentError PlotsBase.Plotly.plotly_colorbar_dimension(
            :bad,
            PlotsBase.Plotly._plotly_colorbar_width_default,
            "colorbar_width",
        )

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
        repr(MIME("text/html"), pl) # update the subplot layout before checking fractions
        colorbar = PlotsBase.plotly_series(pl)[1][:colorbar]
        @test colorbar[:title][:text] == "Styled"
        @test colorbar[:tickfont][:size] == round(Int, 1.4 * 12)
        @test colorbar[:tickfont][:color] == "rgba(255, 0, 0, 1.000)"
        @test colorbar[:tickcolor] == "rgba(0, 0, 255, 1.000)"
        @test colorbar[:tickwidth] == 2
        @test colorbar[:outlinecolor] == "rgba(0, 128, 0, 1.000)"
        @test colorbar[:outlinewidth] == 3
        @test colorbar[:thicknessmode] == "fraction"
        @test colorbar[:thickness] > 0
        @test colorbar[:thickness] < 0.05
        x_domain, y_domain = PlotsBase.Plotly.plotly_domain(pl[1])
        @test isapprox(
            colorbar[:thickness] / (colorbar[:thickness] + only(diff(x_domain))),
            0.05,
        )
        @test colorbar[:lenmode] == "fraction"
        # colorbar_height is a fraction of the subplot y-domain, not the figure
        @test isapprox(colorbar[:len] / only(diff(y_domain)), 0.75)
        @test colorbar[:ticks] == "outside"
        @test colorbar[:tickmode] == "array"
        @test colorbar[:tickvals] == [2, 5, 8]
        @test colorbar[:ticktext] == ["low", "mid", "high"]

        pl = heatmap(reshape(1:9, 3, 3); colorbar_ticks = false)
        colorbar = PlotsBase.plotly_series(pl)[1][:colorbar]
        @test colorbar[:showticklabels] == false
        @test colorbar[:ticks] == ""

        # `:auto` width must still pin thickness (not leave Plotly's pixel default) and
        # use the compact default so dual-panel heatmaps are not squished.
        pl = heatmap(reshape(1:9, 3, 3))
        repr(MIME("text/html"), pl)
        colorbar = PlotsBase.plotly_series(pl)[1][:colorbar]
        x_domain, _ = PlotsBase.Plotly.plotly_domain(pl[1])
        @test colorbar[:thicknessmode] == "fraction"
        @test isapprox(
            colorbar[:thickness] / (colorbar[:thickness] + only(diff(x_domain))),
            PlotsBase.Plotly._plotly_colorbar_width_default;
            atol = 1.0e-6,
        )
    end

    @testset "Colorbar dual-panel layout" begin
        # Mirrors the maintainer review script: explicit width on one panel, `:auto` on
        # the other. Both plot domains must stay comparable (no 25%-width collapse).
        pl = plot(
            heatmap(
                reshape(1:100, 10, 10);
                colorbar_width = 0.06,
                colorbar_height = 0.8,
                colorbar_ticks = [0.2, 0.5, 0.8],
            ),
            heatmap(
                reshape(1:100, 10, 10);
                colorbar_ticks = ([0.2, 0.5, 0.8], ["low", "mid", "high"]),
                colorbar_title = "level",
            );
            layout = (1, 2),
            size = (900, 500),
        )
        repr(MIME("text/html"), pl)
        widths = map(1:2) do i
            xd, _ = PlotsBase.Plotly.plotly_domain(pl[i])
            only(diff(xd))
        end
        @test all(w -> w > 0.3, widths)
        @test isapprox(widths[1], widths[2]; rtol = 0.25)
        for i in 1:2
            cb = PlotsBase.plotly_series(pl)[i][:colorbar]
            @test cb[:thicknessmode] == "fraction"
            @test cb[:thickness] > 0
            @test cb[:ticks] == "outside"
            @test cb[:len] < 1
        end
    end

    @testset "Colorbar log scale" begin
        pl = heatmap(
            reshape(1:9, 3, 3);
            colorbar_scale = :log10,
            colorbar_ticks = ([1, 3, 9], ["one", "three", "nine"]),
            colorbar_width = 0.25,
        )
        repr(MIME("text/html"), pl)
        series = PlotsBase.plotly_series(pl)[1]
        colorbar = series[:colorbar]
        @test isapprox(series[:z], log10.(Float64[1 2 3; 4 5 6; 7 8 9]))
        @test isapprox(colorbar[:tickvals], log10.([1.0, 3.0, 9.0]))
        @test colorbar[:ticktext] == ["one", "three", "nine"]
        @test colorbar[:len] < 1
        @test colorbar[:thickness] < 0.25
        x_domain, _ = PlotsBase.Plotly.plotly_domain(pl[1])
        @test isapprox(
            colorbar[:thickness] / (colorbar[:thickness] + only(diff(x_domain))),
            0.25,
        )
    end
end
