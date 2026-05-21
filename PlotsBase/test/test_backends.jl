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
        pl = plot(rand(10))
        @test pl isa Plot
        display(pl)
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

haskey(TEST_BACKENDS, :PythonPlot) && @testset "PythonPlot colorbar font controls" begin
    with(:pythonplot) do
        p = heatmap(
            [1.0 10.0; 100.0 1000.0];
            colorbar_title = "Intensity",
            colorbar_scale = :log10,
            colorbar_ticks = ([1.0, 1000.0], ["low", "high"]),
            colorbar_tickfont = font(9, "DejaVu Sans", :right, :top, 30.0),
            colorbar_titlefont = font(12, "DejaVu Sans", :left, :bottom, 45.0),
        )
        fn = tempname() * ".png"
        png(p, fn)
        @test filesize(fn) > 1_000
        rm(fn; force = true)

        pyconvert = PythonPlot.PythonCall.pyconvert
        pystr(x) = pyconvert(String, x)
        pyfloat(x) = pyconvert(Float64, x)
        cbar = p[1].attr[:cbar_handle]
        cbar_label = cbar.ax.yaxis.label
        @test pyconvert(Vector{String}, cbar_label.get_family()) == ["DejaVu Sans"]
        @test pyfloat(cbar_label.get_fontsize()) == 12.0
        @test pyfloat(cbar_label.get_rotation()) == 45.0
        @test pystr(cbar_label.get_horizontalalignment()) == "left"
        @test pystr(cbar_label.get_verticalalignment()) == "bottom"

        ticklabels = cbar.ax.yaxis.get_ticklabels()
        @test map(tick -> pystr(tick.get_text()), ticklabels) == ["low", "high"]
        @test all(
            tick -> pyconvert(Vector{String}, tick.get_family()) == ["DejaVu Sans"],
            ticklabels,
        )
        @test all(tick -> pyfloat(tick.get_fontsize()) == 9.0, ticklabels)
        @test all(tick -> pyfloat(tick.get_rotation()) == 30.0, ticklabels)
        @test all(tick -> pystr(tick.get_horizontalalignment()) == "right", ticklabels)
        @test all(tick -> pystr(tick.get_verticalalignment()) == "top", ticklabels)
    end
end
