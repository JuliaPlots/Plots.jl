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

@testset "colorbar border and size" begin
    # the backends must keep their own defaults when nothing is requested
    @test PlotsBase.colorbar_border(heatmap(rand(10, 10))[1]) == (colorant"black", :auto)
    # setting the color alone is enough to request a border
    @test PlotsBase.colorbar_border(heatmap(rand(10, 10); colorbar_border_color = :red)[1]) ==
        (:red, 1)
    @test PlotsBase.colorbar_border(
        heatmap(rand(10, 10); colorbar_border_width = 3)[1],
    )[2] == 3
    # aliases
    @test PlotsBase.colorbar_border(heatmap(rand(10, 10); cbborder_width = 2)[1])[2] == 2
    @test heatmap(rand(10, 10); cbwidth = 0.1)[1][:colorbar_width] == 0.1
    @test heatmap(rand(10, 10); cbar_height = 0.5)[1][:colorbar_height] == 0.5

    # the styled colorbar must render for 2d, 3d and horizontal colorbars
    for be in (:gr, :pythonplot)
        be ∈ values(TEST_BACKENDS) || continue
        with(be) do
            io = IOContext(IOBuffer(), :color => true)
            for kw in (
                    (; colorbar_border_color = :red, colorbar_border_width = 2),
                    (; colorbar_width = 0.1, colorbar_height = 0.5),
                    (; colorbar_width = 0.1, colorbar_title = "cbar"),
                    (; colorbar = :top, colorbar_width = 0.5, colorbar_height = 0.05),
                )
                @test show(io, heatmap(rand(10, 10); kw...)) isa Nothing
                @test show(io, surface(1:10, 1:10, (x, y) -> x * y; kw...)) isa Nothing
            end
        end
    end
end
