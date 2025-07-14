@testset "Axes" begin
    pl = plot()
    axis = pl.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5, 1.5)
    @test axis[:discrete_map] == Dict{Any, Any}(:yo => 2, "HI" => 1)

    Plots.discrete_value!(axis, map(i -> "x$i", 1:5))
    Plots.discrete_value!(axis, map(i -> "x$i", 0:2))
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)

    # github.com/JuliaPlots/Plots.jl/issues/4375
    for lab in ("foo", :foo)
        pl = plot(1:2, xlabel = lab, ylabel = lab, title = lab)
        show(devnull, pl)
    end

    @test Plots.labelfunc_tex(:log10)(1) == "10^{1}"
    @test Plots.labelfunc_tex(:log2)(1) == "2^{1}"
    @test Plots.labelfunc_tex(:ln)(1) == "e^{1}"

    @test Plots.get_labels(:auto, 1:3, :identity) == ["1", "2", "3"]
    @test Plots.get_labels(:scientific, float.(500:500:1500), :identity) ==
        ["5.00×10^{2}", "1.00×10^{3}", "1.50×10^{3}"]
    @test Plots.get_labels(:engineering, float.(500:500:1500), :identity) ==
        ["500.×10^{0}", "1.00×10^{3}", "1.50×10^{3}"]
    @test Plots.get_labels(:latex, 1:3, :identity) == ["\$1\$", "\$2\$", "\$3\$"]
    # GR is used during tests and it correctly overrides labelfunc(), but PGFPlotsX did not
    Plots.with(:pgfplotsx) do
        @test Plots.get_labels(:auto, 1:3, :log10) == ["10^{1}", "10^{2}", "10^{3}"]
    end
    @test Plots.get_labels(:auto, 1:3, :log10) == ["10^{1}", "10^{2}", "10^{3}"]
    @test Plots.get_labels(:auto, 1:3, :log2) == ["2^{1}", "2^{2}", "2^{3}"]
    @test Plots.get_labels(:auto, 1:3, :ln) == ["e^{1}", "e^{2}", "e^{3}"]
    @test Plots.get_labels(:latex, 1:3, :log10) ==
        ["\$10^{1}\$", "\$10^{2}\$", "\$10^{3}\$"]
    @test Plots.get_labels(:latex, 1:3, :log2) == ["\$2^{1}\$", "\$2^{2}\$", "\$2^{3}\$"]
    @test Plots.get_labels(:latex, 1:3, :ln) == ["\$e^{1}\$", "\$e^{2}\$", "\$e^{3}\$"]

    @test Plots.get_labels(x -> 1.0e3x, 1:3, :identity) == ["1000", "2000", "3000"]
    @test Plots.get_labels(x -> 1.0e3x, 1:3, :log10) == ["10^{4}", "10^{5}", "10^{6}"]
    @test Plots.get_labels(x -> 8x, 1:3, :log2) == ["2^{4}", "2^{5}", "2^{6}"]
    @test Plots.get_labels(x -> ℯ * x, 1:3, :ln) == ["e^{2}", "e^{3}", "e^{4}"]
    @test Plots.get_labels(x -> string(x, " MB"), 1:3, :identity) ==
        ["1.0 MB", "2.0 MB", "3.0 MB"]
    @test Plots.get_labels(x -> string(x, " MB"), 1:3, :log10) ==
        ["10.0 MB", "100.0 MB", "1000.0 MB"]
end

@testset "Showaxis" begin
    for value in Plots._allShowaxisArgs
        @test plot(1:5, showaxis = value)[1][:yaxis][:showaxis] isa Bool
    end
    @test plot(1:5, showaxis = :y)[1][:yaxis][:showaxis]
    @test !plot(1:5, showaxis = :y)[1][:xaxis][:showaxis]
end

@testset "Magic axis" begin
    @test isempty(plot(1, axis = nothing)[1][:xaxis][:ticks])
    @test isempty(plot(1, axis = nothing)[1][:yaxis][:ticks])
end

@testset "Categorical ticks" begin
    p1 = plot('A':'M', 1:13)
    p2 = plot('A':'Z', 1:26)
    p3 = plot('A':'Z', 1:26, ticks = :all)
    @test Plots.get_ticks(p1[1], p1[1][:xaxis])[2] == string.('A':'M')
    @test Plots.get_ticks(p2[1], p2[1][:xaxis])[2] == string.('C':3:'Z')
    @test Plots.get_ticks(p3[1], p3[1][:xaxis])[2] == string.('A':'Z')
end

@testset "Ticks getter functions" begin
    ticks1 = ([1, 2, 3], ("a", "b", "c"))
    ticks2 = ([4, 5], ("e", "f"))
    p1 = plot(1:5, 1:5, 1:5, xticks = ticks1, yticks = ticks1, zticks = ticks1)
    p2 = plot(1:5, 1:5, 1:5, xticks = ticks2, yticks = ticks2, zticks = ticks2)
    pl = plot(p1, p2)
    @test xticks(pl) == yticks(pl) == zticks(pl) == [ticks1, ticks2]
    @test xticks(pl[1]) == yticks(pl[1]) == zticks(pl[1]) == ticks1
end

@testset "Axis limits" begin
    default_widen(from, to) = Plots.scale_lims(from, to, Plots.default_widen_factor)

    pl = plot(1:5, xlims = :symmetric, widen = false)
    @test Plots.xlims(pl) == (-5, 5)

    pl = plot(1:3)
    @test Plots.xlims(pl) == default_widen(1, 3)

    pl = plot([1.05, 2.0, 2.95], ylims = :round)
    @test Plots.ylims(pl) == (1, 3)

    for x in (1:3, -10:10), xlims in ((1, 5), [1, 5])
        pl = plot(x; xlims)
        @test Plots.xlims(pl) == (1, 5)
        pl = plot(x; xlims, widen = true)
        @test Plots.xlims(pl) == default_widen(1, 5)
    end

    pl = plot(1:5, lims = :symmetric, widen = false)
    @test Plots.xlims(pl) == Plots.ylims(pl) == (-5, 5)

    for xlims in (0, 0.0, false, true, plot())
        pl = plot(1:5; xlims)
        plims =
            @test_logs (:warn, r"Invalid limits for x axis") match_mode = :any Plots.xlims(
            pl,
        )
        @test plims == default_widen(1, 5)
    end

    @testset "#4379" begin
        for ylims in ((-5, :auto), [-5, :auto])
            pl = plot([-2, 3], ylims = ylims, widen = false)
            @test Plots.ylims(pl) == (-5.0, 3.0)
        end
        for ylims in ((:auto, 4), [:auto, 4])
            pl = plot([-2, 3], ylims = ylims, widen = false)
            @test Plots.ylims(pl) == (-2.0, 4.0)
        end

        for xlims in ((-3, :auto), [-3, :auto])
            pl = plot([-2, 3], [-1, 1], xlims = xlims, widen = false)
            @test Plots.xlims(pl) == (-3.0, 3.0)
        end
        for xlims in ((:auto, 4), [:auto, 4])
            pl = plot([-2, 3], [-1, 1], xlims = xlims, widen = false)
            @test Plots.xlims(pl) == (-2.0, 4.0)
        end
    end
end

@testset "3D Axis" begin
    ql = quiver([1, 2], [2, 1], [3, 4], quiver = ([1, -1], [0, 0], [1, -0.5]), arrow = true)
    @test ql[1][:projection] == "3d"
end

@testset "Twinx" begin
    pl = plot(1:10, margin = 2Plots.cm)
    twpl = twinx(pl)
    pl! = plot!(twpl, -(1:10))
    @test twpl[:right_margin] == 2Plots.cm
    @test twpl[:left_margin] == 2Plots.cm
    @test twpl[:top_margin] == 2Plots.cm
    @test twpl[:bottom_margin] == 2Plots.cm
end

@testset "Axis-aliases" begin
    @test haskey(Plots._keyAliases, :xguideposition)
    @test haskey(Plots._keyAliases, :x_guide_position)
    @test !haskey(Plots._keyAliases, :xguide_position)
    pl = plot(1:2, xl = "x label")
    @test Plots.get_guide(pl[1][:xaxis]) === "x label"
    pl = plot(1:2, xrange = (0, 3))
    @test xlims(pl) === (0, 3)
    pl = plot(1:2, xtick = [1.25, 1.5, 1.75])
    @test pl[1][:xaxis][:ticks] == [1.25, 1.5, 1.75]
    pl = plot(1:2, xlabelfontsize = 4)
    @test pl[1][:xaxis][:guidefontsize] == 4
    pl = plot(1:2, xgα = 0.07)
    @test pl[1][:xaxis][:gridalpha] ≈ 0.07
    pl = plot(1:2, xgridls = :dashdot)
    @test pl[1][:xaxis][:gridstyle] === :dashdot
    pl = plot(1:2, xgridcolor = :red)
    @test pl[1][:xaxis][:foreground_color_grid] === RGBA{Float64}(1.0, 0.0, 0.0, 1.0)
    pl = plot(1:2, xminorgridcolor = :red)
    @test pl[1][:xaxis][:foreground_color_minor_grid] === RGBA{Float64}(1.0, 0.0, 0.0, 1.0)
    pl = plot(1:2, xgrid_lw = 0.01)
    @test pl[1][:xaxis][:gridlinewidth] ≈ 0.01
    pl = plot(1:2, xminorgrid_lw = 0.01)
    @test pl[1][:xaxis][:minorgridlinewidth] ≈ 0.01
    pl = plot(1:2, xtickor = :out)
    @test pl[1][:xaxis][:tick_direction] === :out
end

@testset "Aliases" begin
    compare(pl::Plot, s::Symbol, val, op) =
        op(pl[1][:xaxis][s], val) && op(pl[1][:yaxis][s], val) && op(pl[1][:zaxis][s], val)
    pl = plot(1:2, guide = "all labels")
    @test compare(pl, :guide, "all labels", ===)
    pl = plot(1:2, label = "test")
    @test compare(pl, :guide, "", ===)
    pl = plot(1:2, lim = (0, 3))
    @test xlims(pl) === ylims(pl) === zlims(pl) === (0, 3)
    pl = plot(1:2, tick = [1.25, 1.5, 1.75])
    @test compare(pl, :ticks, [1.25, 1.5, 1.75], ==)
    pl = plot(1:2, labelfontsize = 4)
    @test compare(pl, :guidefontsize, 4, ==)
    pl = plot(1:2, gα = 0.07)
    @test compare(pl, :gridalpha, 0.07, ≈)
    pl = plot(1:2, gridls = :dashdot)
    @test compare(pl, :gridstyle, :dashdot, ===)
    pl = plot(1:2, gridcolor = :red)
    @test compare(pl, :foreground_color_grid, RGBA{Float64}(1.0, 0.0, 0.0, 1.0), ===)
    pl = plot(1:2, minorgridcolor = :red)
    @test compare(pl, :foreground_color_minor_grid, RGBA{Float64}(1.0, 0.0, 0.0, 1.0), ===)
    pl = plot(1:2, grid_lw = 0.01)
    @test compare(pl, :gridlinewidth, 0.01, ≈)
    pl = plot(1:2, minorgrid_lw = 0.01)
    @test compare(pl, :minorgridlinewidth, 0.01, ≈)
    pl = plot(1:2, tickor = :out)
    @test compare(pl, :tick_direction, :out, ===)
end

@testset "scale_lims!" begin
    let pl = plot(1:2)
        xl, yl = xlims(pl), ylims(pl)
        Plots.scale_lims!(:x, 1.1)
        @test first(xlims(pl)) < first(xl)
        @test last(xlims(pl)) > last(xl)
        @test ylims(pl) == yl
    end

    let pl = plot(1:2)
        xl, yl = xlims(pl), ylims(pl)
        Plots.scale_lims!(pl, 1.1)
        @test first(xlims(pl)) < first(xl)
        @test last(xlims(pl)) > last(xl)
        @test first(ylims(pl)) < first(yl)
        @test last(ylims(pl)) > last(yl)
    end
end

@testset "reset_extrema!" begin
    pl = plot(1:2)
    Plots.reset_extrema!(pl[1])
    ax = pl[1][:xaxis]
    @test Plots.expand_extrema!(ax, nothing) == ax[:extrema]
    @test Plots.expand_extrema!(ax, true) == ax[:extrema]
end

@testset "no labels" begin
    # github.com/JuliaPlots/Plots.jl/issues/4475
    pl = plot(100:100:300, hcat([1, 2, 4], [-1, -2, -4]); yformatter = :none)
    @test pl[1][:yaxis][:formatter] === :none
end

@testset "minor ticks" begin
    # FIXME in 2.0: this is awful to read, because `minorticks` represent the number of `intervals`
    for minor_intervals in (:auto, :none, nothing, false, true, 0, 1, 2, 3, 4, 5)
        n_minor_ticks_per_major = if minor_intervals isa Bool
            minor_intervals ? Plots.DEFAULT_MINOR_INTERVALS[] - 1 : 0
        elseif minor_intervals === :auto
            Plots.DEFAULT_MINOR_INTERVALS[] - 1
        elseif minor_intervals === :none || minor_intervals isa Nothing
            0
        else
            max(0, minor_intervals - 1)
        end
        pl = plot(1:4; minorgrid = true, minorticks = minor_intervals)
        sp = first(pl)
        for axis in (:xaxis, :yaxis)
            ticks = Plots.get_ticks(sp, sp[axis], update = false)
            n_expected_minor_ticks = (length(first(ticks)) - 1) * n_minor_ticks_per_major
            minor_ticks = Plots.get_minor_ticks(sp, sp[axis], ticks)
            n_minor_ticks = if minor_intervals isa Bool
                if minor_intervals
                    length(minor_ticks)
                else
                    @test minor_ticks isa Nothing
                    0
                end
            elseif minor_intervals === :auto
                length(minor_ticks)
            elseif minor_intervals === :none || minor_intervals isa Nothing
                @test minor_ticks isa Nothing
                0
            else
                length(minor_ticks)
            end
            show(devnull, pl)
            @test n_minor_ticks == n_expected_minor_ticks
        end
    end
end

@testset "axis guides (labels)" begin
    yguide(pl, idx = length(pl.subplots)) = Plots.get_guide(pl.subplots[idx].attr[:yaxis])

    @test yguide(plot(1:3, ylabel = "hello")) == "hello"
    @test yguide(plot(1:3, ylabel = L"hello")) == L"hello"
    @test yguide(plot(1:3, ylabel = :hello)) == :hello

    @test yguide(plot(1:3, yunit = 1)) == "1"
    @test yguide(plot(1:3, yunit = 1, ylabel = :hello)) == "hello (1)"
    @test yguide(plot(1:3, yunit = 1, ylabel = :hello, unitformat = :square)) == "hello [1]"
    @test yguide(plot(1:3, yunit = 1, ylabel = L"hello")) == L"hello" * " (1)"

    uf = (l, u) -> Symbol(l, "_symb_", u)
    @test yguide(plot(1:3, yunit = 1, ylabel = :hello, unitformat = uf)) == :hello_symb_1

end
