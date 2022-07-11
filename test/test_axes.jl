@testset "Axes" begin
    p = plot()
    axis = p.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5, 1.5)
    @test axis[:discrete_map] == Dict{Any,Any}(:yo => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i in 1:5])
    Plots.discrete_value!(axis, ["x$i" for i in 0:2])
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)
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
    p = plot(p1, p2)
    @test xticks(p) == yticks(p) == zticks(p) == [ticks1, ticks2]
    @test xticks(p[1]) == yticks(p[1]) == zticks(p[1]) == ticks1
end

@testset "Axis limits" begin
    pl = plot(1:5, xlims = :symmetric, widen = false)
    @test Plots.xlims(pl) == (-5, 5)

    pl = plot(1:3)
    @test Plots.xlims(pl) == Plots.widen(1, 3)

    pl = plot([1.05, 2.0, 2.95], ylims = :round)
    @test Plots.ylims(pl) == (1, 3)

    for x in (1:3, -10:10), xlims in ((1, 5), [1, 5])
        pl = plot(x; xlims)
        @test Plots.xlims(pl) == (1, 5)
        pl = plot(x; xlims, widen = true)
        @test Plots.xlims(pl) == Plots.widen(1, 5)
    end

    pl = plot(1:5, lims = :symmetric, widen = false)
    @test Plots.xlims(pl) == Plots.ylims(pl) == (-5, 5)

    for xlims in (0, 0.0, false, true, plot())
        pl = plot(1:5; xlims)
        @test Plots.xlims(pl) == Plots.widen(1, 5)
        @test_logs (:warn, r"Invalid limits for x axis") match_mode = :any display(pl)
    end
end

@testset "3D Axis" begin
    ql = quiver([1, 2], [2, 1], [3, 4], quiver = ([1, -1], [0, 0], [1, -0.5]), arrow = true)
    @test ql[1][:projection] == "3d"
end

@testset "Twinx" begin
    pl = plot(1:10, margin = 2Plots.cm)
    twpl = twinx(pl)
    pl! = plot!(twinx(), -(1:10))
    @test twpl[:right_margin] == 2Plots.cm
    @test twpl[:left_margin] == 2Plots.cm
    @test twpl[:top_margin] == 2Plots.cm
    @test twpl[:bottom_margin] == 2Plots.cm
end

@testset "Axis-aliases" begin
    @test haskey(Plots._keyAliases, :xguideposition)
    @test haskey(Plots._keyAliases, :x_guide_position)
    @test !haskey(Plots._keyAliases, :xguide_position)
    p = plot(1:2, xl = "x label")
    @test p[1][:xaxis][:guide] === "x label"
    p = plot(1:2, xrange = (0, 3))
    @test xlims(p) === (0, 3)
    p = plot(1:2, xtick = [1.25, 1.5, 1.75])
    @test p[1][:xaxis][:ticks] == [1.25, 1.5, 1.75]
    p = plot(1:2, xlabelfontsize = 4)
    @test p[1][:xaxis][:guidefontsize] == 4
    p = plot(1:2, xgα = 0.07)
    @test p[1][:xaxis][:gridalpha] ≈ 0.07
    p = plot(1:2, xgridls = :dashdot)
    @test p[1][:xaxis][:gridstyle] === :dashdot
    p = plot(1:2, xgridcolor = :red)
    @test p[1][:xaxis][:foreground_color_grid] === RGBA{Float64}(1.0, 0.0, 0.0, 1.0)
    p = plot(1:2, xminorgridcolor = :red)
    @test p[1][:xaxis][:foreground_color_minor_grid] === RGBA{Float64}(1.0, 0.0, 0.0, 1.0)
    p = plot(1:2, xgrid_lw = 0.01)
    @test p[1][:xaxis][:gridlinewidth] ≈ 0.01
    p = plot(1:2, xminorgrid_lw = 0.01)
    @test p[1][:xaxis][:minorgridlinewidth] ≈ 0.01
    p = plot(1:2, xtickor = :out)
    @test p[1][:xaxis][:tick_direction] === :out
end

@testset "Aliases" begin
    compare(p::Plot, s::Symbol, val, op) =
        op(p[1][:xaxis][s], val) && op(p[1][:yaxis][s], val) && op(p[1][:zaxis][s], val)
    p = plot(1:2, guide = "all labels")
    @test compare(p, :guide, "all labels", ===)
    p = plot(1:2, label = "test")
    @test compare(p, :guide, "", ===)
    p = plot(1:2, lim = (0, 3))
    @test xlims(p) === ylims(p) === zlims(p) === (0, 3)
    p = plot(1:2, tick = [1.25, 1.5, 1.75])
    @test compare(p, :ticks, [1.25, 1.5, 1.75], ==)
    p = plot(1:2, labelfontsize = 4)
    @test compare(p, :guidefontsize, 4, ==)
    p = plot(1:2, gα = 0.07)
    @test compare(p, :gridalpha, 0.07, ≈)
    p = plot(1:2, gridls = :dashdot)
    @test compare(p, :gridstyle, :dashdot, ===)
    p = plot(1:2, gridcolor = :red)
    @test compare(p, :foreground_color_grid, RGBA{Float64}(1.0, 0.0, 0.0, 1.0), ===)
    p = plot(1:2, minorgridcolor = :red)
    @test compare(p, :foreground_color_minor_grid, RGBA{Float64}(1.0, 0.0, 0.0, 1.0), ===)
    p = plot(1:2, grid_lw = 0.01)
    @test compare(p, :gridlinewidth, 0.01, ≈)
    p = plot(1:2, minorgrid_lw = 0.01)
    @test compare(p, :minorgridlinewidth, 0.01, ≈)
    p = plot(1:2, tickor = :out)
    @test compare(p, :tick_direction, :out, ===)
end
