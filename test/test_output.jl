@testset "GR" begin
    gr()

    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    let p = plot(), fn = tempname()
        Plots.png(p, fn)
        Plots.png(fn)
        savefig(p, "$fn.png")
        savefig("$fn.png")
        @test isfile("$fn.png")

        Plots.pdf(p, fn)
        Plots.pdf(fn)
        savefig(p, "$fn.pdf")
        savefig("$fn.pdf")
        @test isfile("$fn.pdf")

        Plots.ps(p, fn)
        Plots.ps(fn)
        savefig(p, "$fn.ps")
        savefig("$fn.ps")
        @test isfile("$fn.ps")

        Plots.svg(p, fn)
        Plots.svg(fn)
        savefig(p, "$fn.svg")
        savefig("$fn.svg")
        @test isfile("$fn.svg")
    end
end

@testset "PGFPlotsx" begin
    pgfplotsx()
    if Sys.islinux()
        let p = plot(), fn = tempname()
            Plots.tex(p, fn)
            Plots.tex(fn)
            savefig(p, "$fn.tex")
            savefig("$fn.tex")
            @test isfile("$fn.tex")
        end
    end
end

@testset "UnicodePlots" begin
    unicodeplots()
    let p = plot(), fn = tempname()
        Plots.txt(p, fn)
        Plots.txt(fn)
        savefig(p, "$fn.txt")
        savefig("$fn.txt")
        @test isfile("$fn.txt")
    end
end

@testset "PlotlyJS" begin
    plotlyjs()
    let p = plot(), fn = tempname()
        Plots.html(p, fn)
        Plots.html(fn)
        savefig(p, "$fn.html")
        savefig("$fn.html")
        @test isfile("$fn.html")

        if Sys.islinux()
            Plots.eps(p, fn)
            Plots.eps(fn)
            savefig(p, "$fn.eps")
            savefig("$fn.eps")
            @test isfile("$fn.eps")
        end

        @test_throws ErrorException savefig("$fn.foo")
    end
end

gr()  # reset to default backend
