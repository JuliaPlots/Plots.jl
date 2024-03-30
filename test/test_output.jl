macro test_save(fmt)
    quote
        let pl = plot(1:2), fn = tempname(), fp = tmpname()  # fp is an AbstractPath from FilePathsBase.jl
            getfield(Plots, $fmt)(pl, fn)
            getfield(Plots, $fmt)(fn)
            getfield(Plots, $fmt)(fp)

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
            getfield(Plots, $fmt)(pl, io)
            getfield(Plots, $fmt)(io)
            @test length(io.data) > 10
        end
    end |> esc
end

Plots.with(:gr) do
    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :pdf
    @test_save :svg
    @test_save :ps
end

Plots.with(:unicodeplots) do
    @test_save :txt
    if Plots.UnicodePlots.get_font_face() ≢ nothing
        @test_save :png
    end
end

if Sys.isunix()
    Plots.with(:plotlyjs) do
        @test_save :html
        @test_save :json
        @test_save :pdf
        @test_save :png
        @test_save :svg
        # @test_save :eps
    end

    Plots.with(:plotly) do
        @test_save :pdf
        @test_save :png
        @test_save :svg
        @test_save :html
    end
end

if Sys.islinux() && Sys.which("pdflatex") ≢ nothing
    Plots.with(:pgfplotsx) do
        @test_save :tex
        @test_save :png
        @test_save :pdf
    end

    Plots.with(:pythonplot) do
        @test_save :pdf
        @test_save :png
        @test_save :svg
        @test_save :eps
        @test_save :ps
    end
end

#=
Plots.with(:gaston) do
    @test_save :png
    @test_save :pdf
    @test_save :eps
    @test_save :svg
end

Plots.with(:inspectdr) do
    @test_save :png
    @test_save :pdf
    @test_save :eps
    @test_save :svg
end
=#

@testset "html" begin
    Plots.with(:gr) do
        io = PipeBuffer()
        pl = plot(1:2)
        pl.attr[:html_output_format] = :auto
        Plots._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :png
        Plots._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :svg
        Plots._show(io, MIME("text/html"), pl)
        pl.attr[:html_output_format] = :txt
        Plots._show(io, MIME("text/html"), pl)
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
