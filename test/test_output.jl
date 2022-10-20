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

with(:gr) do
    @info backend()
    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :svg
    @test_save :pdf
    @test_save :ps
end

with(:pgfplotsx) do
    @info backend()
    if Sys.islinux()
        @test_save :tex
        @test_save :png
        @test_save :pdf
    end
end

with(:unicodeplots) do
    @info backend()
    @test_save :txt
    @test_save :png
end

with(:plotlyjs) do
    @info backend()
    @test_save :html
    @test_save :json
    @test_save :pdf
    @test_save :png
    @test_save :eps
    @test_save :svg
end

with(:pyplot) do
    @info backend()
    @test_save :pdf
    @test_save :png
    @test_save :svg
    if Sys.islinux()
        @test_save :eps
        @test_save :ps
    end
end

#=
with(:gaston) do
    @test_save :png
    @test_save :pdf
    @test_save :eps
    @test_save :svg
end
=#