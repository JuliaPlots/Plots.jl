macro test_save(fmt)
    quote
        let pl = plot(1:2), fn = tempname(), fp = tmpname()  # fp is an AbstractPath from FilePathsBase.jl
            getfield(PlotsBase, $fmt)(pl, fn)
            getfield(PlotsBase, $fmt)(fn)
            getfield(PlotsBase, $fmt)(fp)

            fn_ext = string(fn, '.', $fmt)
            fp_ext = string(fp, '.', $fmt)

            savefig(fn_ext)
            savefig(fp_ext)

            savefig(pl, fn_ext)
            savefig(pl, fp_ext)

            @test isfile(fn_ext)
            @test isfile(fp_ext)

            @test_throws ErrorException savefig(string(fn, ".foo"))
            @test_throws ErrorException savefig(string(fp, ".foo"))
        end

        let pl = plot(1:2), io = PipeBuffer()
            getfield(PlotsBase, $fmt)(pl, io)
            getfield(PlotsBase, $fmt)(io)
            @test length(io.data) > 10
        end
    end |> esc
end

with(:gr) do
    @test PlotsBase.default_output_format(plot()) == "png"
    @test PlotsBase.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :pdf
    @test_save :svg
    @test_save :ps
end

with(:unicodeplots) do
    @test_save :txt
    UnicodePlots = Base.get_extension(PlotsBase, :UnicodePlotsExt).UnicodePlots
    if UnicodePlots.get_font_face() ≢ nothing
        @test_save :png
    end
end

if Sys.isunix()
    with(:plotlyjs) do
        @test_save :html
        @test_save :json
        @test_save :pdf
        @test_save :png
        @test_save :svg
        # @test_save :eps
    end

    with(:plotly) do
        @test_save :pdf
        @test_save :png
        @test_save :svg
        @test_save :html
    end
end

if Sys.islinux() && Sys.which("pdflatex") ≢ nothing
    with(:pgfplotsx) do
        @test_save :tex
        @test_save :png
        @test_save :pdf
    end

    with(:pythonplot) do
        @test_save :pdf
        @test_save :png
        @test_save :svg
        @test_save :eps
        @test_save :ps
    end
end

with(:gaston) do
    @test_save :png
    @test_save :pdf
    @test_save :eps
    @test_save :svg
end

@testset "html" begin
    with(:gr) do
        io = PipeBuffer()
        pl = plot(1:2)
        pl.attr[:html_output_format] = :auto
        PlotsBase._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :png
        PlotsBase._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :svg
        PlotsBase._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :txt
        PlotsBase._show(io, MIME("text/html"), pl)
    end
end

@testset "size error handling" begin
    plt = plot(size = ())
    @test_throws ArgumentError savefig(plt, tempname())
    plt = plot(size = (1))
    @test_throws ArgumentError savefig(plt, tempname())
    plt = plot(size = (1, 2, 3))
    @test_throws ArgumentError savefig(plt, tempname())
end
