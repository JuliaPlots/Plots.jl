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
        @test getattr(pl[1], :legend_position) ≡ :best  # added to the defaults by `@add_attributes`
        # `link` is a plot attribute and an axis one, a letter picks the axis
        @test getattr(pl, :link) ≡ :none
        @test getattr(pl[1], :xlink) == getattr(pl[1][:xaxis], :link) == []
        @test_throws ArgumentError getattr(pl, :nothere)
        @test_throws ArgumentError getattr(pl[1], :nothere)
        @test_throws ArgumentError getattr(pl[1][1], :nothere)
    end

    @testset "magic attributes" begin
        # read back as the attributes they set
        series = pl[1][1]
        @test getattr(series, :line) == (
            linestyle = :dash,
            linewidth = 5,
            linecolor = series[:linecolor],
            linealpha = nothing,
            arrow = nothing,
        )
        @test getattr(pl, :line).linewidth == permutedims(fill(5, 6))
        @test getattr(pl[1][:xaxis], :tick_font) == getattr(pl[1], :xtick_font)
        @test getattr(pl[2], :xaxis).lims == (0, Inf)
        # `grid` is magic but also stored, so it is read as the stored value
        @test getattr(pl[1], :xgrid) ≡ true
        # built from its parts, the stored `legend_font` does not follow them
        @test getattr(plot(1:3; legend_font_size = 13), :legend_font).legend_font_size == 13

        # and a named tuple of them sets them
        sp = plot(1:3; line = (linewidth = 4, lc = :red), xaxis = (guide = "x", flip = true))[1]
        @test sp[1][:linewidth] == 4
        @test sp[1][:linecolor] == PlotsBase.RGBA(1, 0, 0, 1)
        @test sp[:xaxis][:guide] == "x"
        @test sp[:xaxis][:flip] && !sp[:yaxis][:flip]
        @test_logs (:warn, r"not one of the attributes `line` sets") plot(
            1:3;
            line = (markersize = 3,),
        )
    end

    @testset "an axis attribute per axis" begin
        # asked without a letter it is answered per axis, and it takes that back
        sp = plot(1:3; lims = (x = (0, 5), y = (1, 2)), grid = (x = false, y = true))[1]
        @test PlotsBase.xlims(sp) == (0, 5) && PlotsBase.ylims(sp) == (1, 2)
        @test !sp[:xaxis][:grid] && sp[:yaxis][:grid]
        @test getattr(sp, :grid) == (x = false, y = true, z = true)
        # an explicit letter still wins
        @test PlotsBase.xlims(plot(1:3; lims = (x = (0, 5),), xlims = (0, 9))) == (0, 9)
    end

    @testset "round trip" begin
        # what `getattr` returns is valid input for the same attribute and reads back the same
        C = PlotsBase.Commons
        same(a, b) = isequal(a, b)
        same(a::PlotsBase.Colorant, b::PlotsBase.Colorant) =
            PlotsBase.RGBA{Float64}(a) == PlotsBase.RGBA{Float64}(b)  # may come back as `RGBA`
        same(a::NamedTuple, b::NamedTuple) =
            keys(a) == keys(b) && all(k -> same(a[k], b[k]), keys(a))
        same(a::AbstractArray, b::AbstractArray) =
            size(a) == size(b) && all(splat(same), zip(a, b))
        function roundtrips(mk, attr)
            value = getattr(mk(), attr)
            logs, back = Test.collect_test_logs(min_level = Base.CoreLogging.Warn) do
                getattr(mk(; (attr => value,)...), attr)
            end
            return isempty(logs) && same(value, back)
        end

        attrs = union(
            keys(C._plot_defaults),
            keys(C._subplot_defaults),
            keys(C._series_defaults),
            keys(C._axis_defaults),
            C._lettered_all_axis_attrs,
            C._all_magic_attrs,
        )
        # the series' own subplot and its processed group are state rather than input
        attrs = setdiff(attrs, (:subplot, :group))
        # these do not take a row of values, one per series or per subplot, yet
        rows = (
            :arrow,
            :line,
            :levels,
            :smooth,
            :permute,
            :xerror,
            :yerror,
            :zerror,
            :series_annotations,
            :limits_modifiers,
            :xlimits_modifiers,
            :ylimits_modifiers,
            :zlimits_modifiers,
            :minorgrid,
            :xminorgrid,
            :yminorgrid,
            :zminorgrid,
        )
        one(; kw...) = plot([1.0, 3.0, 2.0]; kw...)
        two(; kw...) = plot([1.0 2.0; 3.0 1.0; 2.0 3.0]; layout = 2, title = ["A" "B"], kw...)
        for attr in attrs
            @test roundtrips(one, attr)
            if attr in rows
                @test_broken roundtrips(two, attr)
            else
                @test roundtrips(two, attr)
            end
        end
    end

    # a linked axis belongs to several subplots, so it answers for all of them
    pl = plot(rand(4, 2); layout = 2, link = :y, title = ["A" "B"])
    @test getattr(pl[1][:yaxis], :title) == ["A" "B"]
end
