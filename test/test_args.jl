@testset "Subplot Attributes" begin
    let pl = plot(rand(4, 4), layout = 2)
        @test pl[1].primary_series_count == 2
    end
end

@testset "Series Attributes" begin
    pl = plot([[1, 2, 3], [2, 3, 4]], lw = 5)
    @test hline!(deepcopy(pl), [1.75])[1].series_list[3][:label] ==
          hline!(deepcopy(pl), [1.75], z_order = :front)[1].series_list[3][:label] ==
          "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = :back)[1].series_list[1][:label] == "y3"
    @test hline!(deepcopy(pl), [1.75], z_order = 2)[1].series_list[2][:label] == "y3"
    sp = pl[1]
    @test isempty(sp[1][:extra_kwargs])
    @test sp[2][:series_index] == 2
    @test sp[1][:seriescolor] == cgrad(default(:palette))[1]
    @test sp[2][:seriescolor] == cgrad(default(:palette))[2]
end

@testset "Axis Attributes" begin
    pl = @test_nowarn plot(; tickfont = font(10, "Times"))
    for axis in (:xaxis, :yaxis, :zaxis)
        @test pl[1][axis][:tickfontsize] == 10
        @test pl[1][axis][:tickfontfamily] == "Times"
    end
end

@testset "Permute recipes" begin
    pl1 = bar(["a", "b", "c"], [1, 2, 3])
    pl2 = bar(["a", "b", "c"], [1, 2, 3], permute = (:x, :y))
    @test xticks(pl2) == yticks(pl1)
    @test yticks(pl2) == xticks(pl1)
    @test filter(isfinite, pl1[1][1][:x]) == filter(isfinite, pl2[1][1][:y])
    @test filter(isfinite, pl1[1][1][:y]) == filter(isfinite, pl2[1][1][:x])
end

@testset "@add_attributes" begin
    Font = Plots.Font
    Plots.@add_attributes subplot struct Legend
        background_color = :match
        foreground_color = :match
        position = :best
        title = nothing
        font::Font = font(8)
        title_font::Font = font(11)
        column = 1
    end :match = (
        :legend_font_family,
        :legend_font_color,
        :legend_title_font_family,
        :legend_title_font_color,
    )
    @test true
end

@testset "aspect_ratio" begin
    fn = tempname()
    for aspect_ratio in (1, 1.0, 1 // 10, :auto, :none, true)
        @test_nowarn png(plot(1:2; aspect_ratio), fn)
    end
    @test_throws ArgumentError png(plot(1:2; aspect_ratio = :invalid_ar), fn)
end

@testset "aliases" begin
    @test :legend in aliases(:legend_position)
    Plots.add_non_underscore_aliases!(Plots._typeAliases)
    Plots.add_axes_aliases(:ticks, :tick)
end
