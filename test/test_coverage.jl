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
