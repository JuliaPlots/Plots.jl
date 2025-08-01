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

is_pkgeval() || @testset "Backends" begin
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
    (Sys.islinux() && is_latest("release")) && for be in TEST_BACKENDS
        skip = vcat(PlotsBase._backend_skips[be], skipped_examples, broken_examples)
        PlotsBase.test_examples(be; skip, callback, disp = is_ci(), strict = true)  # `ci` display for coverage
        closeall()
    end
end
