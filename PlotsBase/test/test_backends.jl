@testset "UnicodePlots" begin
    with(:unicodeplots) do
        @test backend() == PlotsBase.backend_instance(:unicodeplots)

        io = IOContext(IOBuffer(), :color => true)

        # lets just make sure it runs without error
        pl = plot(rand(10))
        @test show(io, pl) isa Nothing

        pl = bar(randn(10))
        @test show(io, pl) isa Nothing

        pl = plot([1, 2], [3, 4])
        annotate!(pl, [(1.5, 3.2, PlotsBase.text("Test", :red, :center))])
        hline!(pl, [3.1])
        @test show(io, pl) isa Nothing

        pl = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        hline!(pl, [3.1])
        annotate!(
            pl,
            [(Dates.Date(2019, 1, 15), 3.2, PlotsBase.text("Test", :red, :center))],
        )
        @test show(io, pl) isa Nothing

        pl = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        annotate!(pl, [(Dates.Date(2019, 1, 15), 3.2, :auto)])
        hline!(pl, [3.1])
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:4)..., layout = (2, 2))
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:3)..., layout = (2, 2))
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:2)..., layout = @layout([° _; _ °]))
        @test show(io, pl) isa Nothing

        redirect_stdout(devnull) do
            show(plot(1:2))
        end
    end
end

is_pkgeval() || @testset "PlotlyJS" begin
    with(:plotlyjs) do
        PlotlyJSExt = Base.get_extension(PlotsBase, :PlotlyJSExt)
        @test backend() == PlotlyJSExt.PlotlyJSBackend()
        @test PlotsBase.is_attr_supported(backend(), :colorbar_tickcolor)
        @test PlotsBase.is_attr_supported(backend(), :colorbar_borderlinewidth)
        @test PlotsBase.is_attr_supported(backend(), :colorbar_width)
        pl = plot(rand(10))
        @test pl isa Plot
        if Sys.iswindows() && is_ci()
            # Blink's Electron process can fail to open its local socket on headless
            # Windows runners. Exercise PlotlyJS rendering without launching a window.
            @test occursin("plotly", lowercase(repr(MIME("text/html"), pl)))
        else
            display(pl)
        end
    end
end

is_pkgeval() || @testset "Backends $be" for be in TEST_BACKENDS
    callback(mod, pkgname, i) = begin
        save_func = (; pgfplotsx = mod.PlotsBase.pdf, unicodeplots = mod.PlotsBase.txt)  # fastest `savefig` for each backend
        pl = mod.PlotsBase.current()
        fn = Base.invokelatest(
            get(save_func, pkgname, mod.PlotsBase.png),
            pl,
            tempname() * PlotsBase.ref_name(i),
        )
        @test filesize(fn) > 1_000
    end
    !(Sys.islinux() && is_latest("release")) && continue
    skip = vcat(PlotsBase._backend_skips[be], skipped_examples, broken_examples)
    PlotsBase.test_examples(be; skip, callback, disp = is_ci(), strict = true)  # `ci` display for coverage
    closeall()
end

@testset "GR colorbar_ticks horizontal" begin
    with(:gr) do
        p = heatmap(rand(10, 10); colorbar = :top, colorbar_ticks = [0.3, 0.6, 0.9])
        io = IOContext(IOBuffer(), :color => true)
        @test show(io, p) isa Nothing
    end
end

@testset "GR colorbar properties" begin
    with(:gr) do
        GRExt = Base.get_extension(PlotsBase, :GRExt)
        @test GRExt.gr_colorbar_dimension(:auto, 0.03, "colorbar_width") == 0.03
        @test GRExt.gr_colorbar_dimension(-0.5, 0.03, "colorbar_width") == 0.0
        @test_throws ArgumentError GRExt.gr_colorbar_dimension(
            :bad,
            0.03,
            "colorbar_width",
        )

        for attr in (
                :colorbar_tickfont,
                :colorbar_tickfontfamily,
                :colorbar_tickfontsize,
                :colorbar_tickfontcolor,
                :colorbar_tickcolor,
                :colorbar_ticklinewidth,
                :colorbar_bordercolor,
                :colorbar_borderlinewidth,
                :colorbar_width,
                :colorbar_height,
            )
            @test PlotsBase.is_attr_supported(backend(), attr)
        end

        p = heatmap(
            reshape(1:100, 10, 10);
            colorbar_ticks = [20, 50, 80],
            colorbar_tickfont = (12, :red, 45.0),
            colorbar_tickcolor = :blue,
            colorbar_ticklinewidth = 2,
            colorbar_bordercolor = :green,
            colorbar_borderlinewidth = 3,
            colorbar_width = 0.05,
            colorbar_height = 0.75,
        )

        sp = p[1]
        @test sp[:colorbar_tickfontsize] == 12
        @test sp[:colorbar_tickfontrotation] == 45.0
        @test sp[:colorbar_ticklinewidth] == 2
        @test sp[:colorbar_borderlinewidth] == 3
        @test sp[:colorbar_width] == 0.05
        @test sp[:colorbar_height] == 0.75

        fn = tempname() * ".png"
        @test png(p, fn) == fn
        @test filesize(fn) > 1_000
    end
end

@testset "PythonPlot colorbar properties" begin
    if haskey(TEST_BACKENDS, :PythonPlot)
        with(:pythonplot) do
            PythonPlotExt = Base.get_extension(PlotsBase, :PythonPlotExt)
            @test PythonPlotExt._py_colorbar_dimension(
                :auto,
                0.05,
                "colorbar_width",
            ) == 0.05
            @test PythonPlotExt._py_colorbar_dimension(-0.5, 0.05, "colorbar_width") == 0.0
            @test_throws ArgumentError PythonPlotExt._py_colorbar_dimension(
                :bad,
                0.05,
                "colorbar_width",
            )

            for attr in (
                    :colorbar_titlefont,
                    :colorbar_tickfont,
                    :colorbar_tickcolor,
                    :colorbar_ticklinewidth,
                    :colorbar_bordercolor,
                    :colorbar_borderlinewidth,
                    :colorbar_width,
                    :colorbar_height,
                )
                @test PlotsBase.is_attr_supported(backend(), attr)
            end

            p = heatmap(
                reshape(1:100, 10, 10);
                colorbar_title = "Styled",
                colorbar_titlefont = (12, :green, 0.0),
                colorbar_ticks = ([20, 50, 80], ["low", "mid", "high"]),
                colorbar_tickfont = (10, :red, 45.0),
                colorbar_tickcolor = :blue,
                colorbar_ticklinewidth = 2,
                colorbar_bordercolor = :green,
                colorbar_borderlinewidth = 3,
                colorbar_width = 0.08,
                colorbar_height = 0.75,
            )

            sp = p[1]
            @test sp[:colorbar_titlefontsize] == 12
            @test sp[:colorbar_tickfontsize] == 10
            @test sp[:colorbar_tickfontrotation] == 45.0
            @test sp[:colorbar_ticklinewidth] == 2
            @test sp[:colorbar_borderlinewidth] == 3
            @test sp[:colorbar_width] == 0.08
            @test sp[:colorbar_height] == 0.75

            fn = tempname() * ".png"
            @test png(p, fn) == fn
            @test filesize(fn) > 1_000
            axis_width = PythonPlot.pyconvert(Float64, p[1].o.get_position().width)
            colorbar_width = PythonPlot.pyconvert(
                Float64,
                p[1][:cbar_ax].get_position().width,
            )
            # Width is a fraction of the parent axes width (AxesX reference).
            @test isapprox(colorbar_width / axis_width, 0.08; atol = 0.02)
        end
    end
end
