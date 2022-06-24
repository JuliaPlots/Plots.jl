# miscellaneous tests (not fitting into other test files)

@testset "Infrastructure" begin
    @test_nowarn JSON.Parser.parse(
        String(read(joinpath(dirname(pathof(Plots)), "..", ".zenodo.json"))),
    )
end

@testset "Plotly standalone" begin
    @test_nowarn Plots._init_ijulia_plotting()
    @test Plots.plotly_local_file_path[] === nothing
    temp = Plots.use_local_dependencies[]
    withenv("PLOTS_HOST_DEPENDENCY_LOCAL" => true) do
        Plots.__init__()
        @test Plots.plotly_local_file_path[] isa String
        @test isfile(Plots.plotly_local_file_path[])
        @test Plots.use_local_dependencies[] = true
        @test_nowarn Plots._init_ijulia_plotting()
    end
    Plots.plotly_local_file_path[] = nothing
    Plots.use_local_dependencies[] = temp
end

@testset "NoFail" begin
    # ensure backend with tested display
    @test unicodeplots() == Plots.UnicodePlotsBackend()
    @test backend() == Plots.UnicodePlotsBackend()

    dsp = TextDisplay(IOContext(IOBuffer(), :color => true))

    @testset "plot" begin
        for plt in [
            histogram([1, 0, 0, 0, 0, 0]),
            plot([missing]),
            plot([missing, missing]),
            plot(fill(missing, 10)),
            plot([missing; 1:4]),
            plot([fill(missing, 10); 1:4]),
            plot([1 1; 1 missing]),
            plot(["a" "b"; missing "d"], [1 2; 3 4]),
        ]
            display(dsp, plt)
        end
        @test_nowarn plot(x -> x^2, 0, 2)
    end

    @testset "bar" begin
        p = bar([3, 2, 1], [1, 2, 3])
        @test p isa Plots.Plot
        @test display(dsp, p) isa Nothing
    end

    @testset "gui" begin
        open(tempname(), "w") do io
            redirect_stdout(io) do
                gui(plot())
            end
        end
    end

    gr()  # reset to default backend
end

@testset "themes" begin
    p = showtheme(:dark)
    @test p isa Plots.Plot
end

@testset "plotattr" begin
    tmp = tempname()
    open(tmp, "w") do io
        redirect_stdout(io) do
            plotattr("seriestype")
            plotattr(:Plot)
            plotattr()
        end
    end
    str = join(readlines(tmp), "")
    @test occursin("seriestype", str)
    @test occursin("Plot attributes", str)
end

@testset "legend" begin
    @test isa(
        Plots.legend_pos_from_angle(20, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0),
        NTuple{2,<:AbstractFloat},
    )
    @test Plots.legend_anchor_index(-1) == 1
    @test Plots.legend_anchor_index(+0) == 2
    @test Plots.legend_anchor_index(+1) == 3

    @test Plots.legend_angle(:foo_bar) == (45, :inner)
    @test Plots.legend_angle(20.0) == Plots.legend_angle((20.0, :inner)) == (20.0, :inner)
    @test Plots.legend_angle((20.0, 10.0)) == (20.0, 10.0)
end

@testset "Axis scales" begin
    unicodeplots()

    pl = plot(1:5, xscale = :log2, yscale = :ln)
    @test pl[1][:xaxis][:scale] === :log2
    @test pl[1][:yaxis][:scale] === :ln

    gr()
end
