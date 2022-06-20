using Plots, Test

@testset "Subplot Attributes" begin
    let pl = plot(rand(4, 4), layout = 2)
        @test pl[1][:max_series_index] == 2
    end
end

@testset "Series Attributes" begin
    pl = plot([[1, 2, 3], [2, 3, 4]], lw = 5)
    @test hline!(deepcopy(pl), [1.75])[1].series_list[3][:label] ==
          hline!(deepcopy(pl), [1.75], z_order = :front)[1].series_list[3][:label] ==
          "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = :back)[1].series_list[1][:label] == "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = 2)[1].series_list[2][:label] == "y3"
    @test isempty(pl[1][1][:extra_kwargs])
    @test pl[1][2][:series_index] == 2
    @test pl[1][1][:seriescolor] == cgrad(default(:palette))[1]
    @test pl[1][2][:seriescolor] == cgrad(default(:palette))[2]
end

@testset "Axis Attributes" begin
    pl = @test_nowarn plot(; tickfont = font(10, "Times"))
    for axis in (:xaxis, :yaxis, :zaxis)
        @test pl[1][axis][:tickfontsize] == 10
        @test pl[1][axis][:tickfontfamily] == "Times"
    end
end

@testset "Permute recipes" begin
    pl = bar(["a", "b", "c"], [1, 2, 3])
    ppl = bar(["a", "b", "c"], [1, 2, 3], permute = (:x, :y))
    @test xticks(ppl) == yticks(pl)
    @test yticks(ppl) == xticks(pl)
    @test filter(isfinite, pl[1][1][:x]) == filter(isfinite, ppl[1][1][:y])
    @test filter(isfinite, pl[1][1][:y]) == filter(isfinite, ppl[1][1][:x])
end
