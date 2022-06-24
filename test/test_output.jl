macro test_save(fmt)
    quote
        let p = plot(1:10), fn = tempname()
            getfield(Plots, $fmt)(p, fn)
            getfield(Plots, $fmt)(fn)
            fn_ext = string(fn, '.', $fmt)
            savefig(p, fn_ext)
            savefig(fn_ext)
            @test isfile(fn_ext)
            @test_throws ErrorException savefig(string(fn, ".foo"))
        end
    end |> esc
end

@testset "GR" begin
    gr()

    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :svg
    @test_save :pdf
    @test_save :ps
end

@testset "PGFPlotsx" begin
    pgfplotsx()
    Sys.islinux() && @test_save :tex
end

@testset "UnicodePlots" begin
    unicodeplots()

    @test_save :txt
    @test_save :png
end

@testset "PlotlyJS" begin
    plotlyjs()

    # @test_save :html
    @test_save :json

    Sys.islinux() && @test_save :eps
end

gr()  # reset to default backend
