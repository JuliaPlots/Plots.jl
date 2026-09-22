# github.com/JuliaPlots/Plots.jl/issues/4900
@testset "getattr" begin
    pl = plot(
        repeat([1:5, 2:6], inner = 3);
        layout = @layout([a b; c]),
        this = :that,
        line = (5, :dash),
        title = ["A" "B"],
        xlims = [:auto (0, Inf)],
    )
    auto3 = (x = :auto, y = :auto, z = :auto)

    @testset "from a plot" begin
        @test getattr(pl, :size) == default(:size)
        @test getattr(pl, :title) == ["A" "B" "A"]
        @test getattr(pl, :xlims) == [:auto (0, Inf) :auto]
        @test getattr(pl, :lims) ==
            [auto3 (x = (0, Inf), y = :auto, z = :auto) auto3]
        @test getattr(pl, :linestyle) == permutedims(fill(:dash, 6))
        @test getattr(pl, :this) == permutedims(fill(:that, 6))
    end

    @testset "from a subplot" begin
        sp = pl[2]
        @test getattr(sp, :size) == default(:size)
        @test getattr(sp, :title) == "B"
        @test getattr(sp, :xlims) == (0, Inf)
        @test getattr(sp, :lims) == (x = (0, Inf), y = :auto, z = :auto)
        @test getattr(sp, :linestyle) == [:dash :dash]
        @test getattr(sp, :this) == [:that :that]
    end

    @testset "from an axis" begin
        axis = pl[3][:yaxis]
        @test getattr(axis, :size) == default(:size)
        @test getattr(axis, :title) == "A"
        # the letter is implied, and a mismatched one is a mistake rather than a fallback
        @test getattr(axis, :lims) ≡ getattr(axis, :ylims) ≡ :auto
        @test_throws ArgumentError getattr(axis, :xlims)
    end

    @testset "from a series" begin
        series = pl[1][1]
        @test getattr(series, :size) == default(:size)
        @test getattr(series, :title) == "A"
        @test getattr(series, :linestyle) ≡ :dash
        @test getattr(series, :lims) == auto3
        @test getattr(series, :this) ≡ :that
    end

    @testset "aliases and mistakes" begin
        @test getattr(pl, :c) == getattr(pl, :seriescolor)
        @test getattr(pl, :sizes) == getattr(pl, :size)
        @test getattr(pl[3][:xaxis], :xlabel) == getattr(pl[3][:xaxis], :guide)
        for magic in (:line, :tick_font, :xtick_font)
            @test_throws ArgumentError getattr(pl, magic)
        end
        @test_throws ArgumentError getattr(pl, :nothere)
        @test_throws ArgumentError getattr(pl[1], :nothere)
        @test_throws ArgumentError getattr(pl[1][1], :nothere)
    end

    # a linked axis belongs to several subplots, so it answers for all of them
    pl = plot(rand(4, 2); layout = 2, link = :y, title = ["A" "B"])
    @test getattr(pl[1][:yaxis], :title) == ["A" "B"]
end
