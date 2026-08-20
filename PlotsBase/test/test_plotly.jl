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
                colorbar_tick_font_color = :blue,
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

        # tick marks
        cb = cbar(heatmap(rand(10, 10)))
        @test !haskey(cb, :tickwidth)
        cb = cbar(
            heatmap(rand(10, 10); colorbar_tick_color = :blue, colorbar_tick_line_width = 2),
        )
        @test cb[:tickwidth] == 2
        @test cb[:tickcolor] == PlotsBase.rgba_string(PlotsBase.plot_color(:blue))

        # a custom formatter must reach the labels
        cb = cbar(heatmap(rand(10, 10); colorbar_formatter = x -> "test"))
        @test cb[:tickmode] == "array"
        @test all(==("test"), cb[:ticktext])

        # a log colorbar scale maps the colors, not only the labels
        z = reshape(collect(0.01:0.01:1), 10, 10)
        series(pl) = (PlotsBase.prepare_output(pl); PlotsBase.plotly_series(pl)[1])
        linear, logged = series(heatmap(z)), series(heatmap(z; colorbar_scale = :log10))
        @test linear[:zmin] ≈ 0.01 && linear[:zmax] ≈ 1
        @test logged[:zmin] ≈ -2 && logged[:zmax] ≈ 0
        @test logged[:z] ≈ log10.(linear[:z])
        @test logged[:colorbar][:tickvals] ≈ [-2, -1, 0]
    end

    @testset "Extra kwargs" begin
        pl = plot(1:5, test = "me")
        @test PlotsBase.plotly_series(pl)[1][:test] == "me"
        pl = plot(1:5, test = "me", extra_kwargs = :plot)
        @test PlotsBase.plotly_layout(pl)[:test] == "me"
    end

    @testset "3D scene aspect" begin
        scene(pl) = PlotsBase.plotly_layout(pl)[:scene]

        @testset "#5044 - default is data independent" begin
            # `plotly.js` defaults `scene.aspectmode` to `"auto"`, which proportions the box
            # to the data ranges but flips to `"cube"` once one axis spans more than 4x the
            # two others - so the same code produced different boxes for different data
            for zmax in (1, 2, 5, 100)  # crosses the `"auto"` 4x threshold
                pl = plot(1:3, 1:3, range(0, zmax, length = 3))
                @test scene(pl)[:aspectmode] == "cube"  # as `GR` and `PythonPlot` do
            end
        end

        @testset "`aspect_ratio = :equal`" begin
            # the box must follow the *axis limits*, so that one data unit is the same
            # length on each axis. `"data"` cannot express this: `plotly` computes it from
            # the traces and ignores these limits
            for ar in (:equal, 1, 1 // 1, true)
                sc = scene(
                    plot(
                        1:3, 1:3, 1:3;
                        aspect_ratio = ar, xlims = (0, 10), ylims = (0, 5), zlims = (0, 1),
                    ),
                )
                @test sc[:aspectmode] == "manual"
                @test sc[:aspectratio][:x] ≈ 1
                @test sc[:aspectratio][:y] ≈ 0.5
                @test sc[:aspectratio][:z] ≈ 0.1
            end
            # equal limits collapse to a cube, matching `GR`
            sc = scene(
                plot(
                    1:3, 1:3, 1:3;
                    aspect_ratio = :equal, xlims = (0, 4), ylims = (1, 5), zlims = (-2, 2),
                ),
            )
            @test sc[:aspectratio][:x] ≈ sc[:aspectratio][:y] ≈ sc[:aspectratio][:z] ≈ 1

            @testset "log scales are measured in decades" begin
                # `plotly_axis` reports a `:log10` range already scaled, so the box has to
                # be sized the same way - a raw data span would stretch it by orders of
                # magnitude (x here spans 3 decades, not 999 units)
                sc = scene(
                    plot(
                        [1, 1000], [0, 1], [0, 1];
                        seriestype = :surface, xscale = :log10, aspect_ratio = :equal,
                    ),
                )
                @test collect(sc[:xaxis][:range]) ≈ [0, 3]
                @test sc[:aspectratio][:x] / sc[:aspectratio][:y] ≈ 3
            end
        end

        @testset "explicit `aspect_ratio`" begin
            @test scene(plot(1:3, 1:3, 1:3, aspect_ratio = :none))[:aspectmode] == "cube"

            sc = scene(plot(1:3, 1:3, 1:3, aspect_ratio = [1, 2, 3]))
            @test sc[:aspectmode] == "manual"
            @test sc[:aspectratio][:x] == 1
            @test sc[:aspectratio][:y] == 2
            @test sc[:aspectratio][:z] == 3
        end

        # 2D subplots have no `scene`
        @test !haskey(PlotsBase.plotly_layout(plot(1:3, aspect_ratio = :equal)), :scene)
    end

    @testset "Requirejs" begin
        pl = plot(sin, 0, 2pi)
        io = PipeBuffer()
        show(io, MIME("text/html"), pl)
        html = read(io, String)
        # FIXME: how can we write a test checking that the html correctly draw a plotly plot ?
    end
end
