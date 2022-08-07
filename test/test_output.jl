macro test_save(fmt)
    quote
        let pl = plot(1:10), fn = tempname()
            getfield(Plots, $fmt)(pl, fn)
            getfield(Plots, $fmt)(fn)
            fn_ext = string(fn, '.', $fmt)
            savefig(pl, fn_ext)
            savefig(fn_ext)
            @test isfile(fn_ext)
            @test_throws ErrorException savefig(string(fn, ".foo"))
        end

        let pl = plot(1:10), io = PipeBuffer()
            getfield(Plots, $fmt)(pl, io)
            getfield(Plots, $fmt)(io)
            @test length(io.data) > 10
        end
    end |> esc
end

with(:gr) do
    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :svg
    @test_save :pdf
    @test_save :ps
end

with(:pgfplotsx) do
    Sys.islinux() && @test_save :tex
end

with(:unicodeplots) do
    @test_save :txt
    @test_save :png
end

with(:plotlyjs) do
    # @test_save :html
    @test_save :json

    # Sys.islinux() && @test_save :eps
end
