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
    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    @test_save :png
    @test_save :pdf
    @test_save :svg
    @test_save :ps
end

with(:unicodeplots) do
    @test_save :txt
    @test_save :png
end

with(:plotlyjs) do
    @test_save :html
    @test_save :json
    @test_save :pdf
    @test_save :png
    @test_save :svg
    # @test_save :eps
end

if Sys.islinux()
    with(:pgfplotsx) do
        @test_save :tex
        @test_save :png
        @test_save :pdf
    end

    with(:pyplot) do
        @test_save :pdf
        @test_save :png
        @test_save :svg
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

with(:inspectdr) do
    @test_save :png
    @test_save :pdf
    @test_save :eps
    @test_save :svg
end
=#
