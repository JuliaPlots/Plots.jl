@shorthands marginalscatter

@recipe function f(::Type{Val{:marginalscatter}}, plt::AbstractPlot; density = false)
    x, y = plotattributes[:x], plotattributes[:y]
    i = isfinite.(x) .& isfinite.(y)
    x, y = x[i], y[i]
    scale = get(plotattributes, :scale, :identity)
    xlims, ylims = map(
        x -> PlotsBase.Axes.scale_lims(
            PlotsBase.ignorenan_extrema(x)...,
            PlotsBase.Axes.default_widen_factor,
            scale,
        ),
        (x, y),
    )

    # set up the subplots
    legend --> false
    link := :both
    grid --> false
    layout --> @layout [
        topscatter _
        scatter2d{0.9w,0.9h} rightscatter
    ]

    # main scatter2d
    @series begin
        seriestype := :scatter
        right_margin --> 0mm
        top_margin --> 0mm
        subplot := 2
        xlims --> xlims
        ylims --> ylims
    end

    # these are common to both marginal scatter
    ticks := nothing
    xguide := ""
    yguide := ""
    fillcolor --> PlotsBase.fg_color(plotattributes)
    linecolor --> PlotsBase.fg_color(plotattributes)

    if density
        trim := true
        seriestype := :density
    else
        seriestype := :scatter
    end

    # upper scatter
    @series begin
        subplot := 1
        bottom_margin --> 0mm
        showaxis := :x
        x := x
        y := ones(y |> size)
        xlims --> xlims
        ylims --> (0.95, 1.05)
    end

    # right scatter
    @series begin
        orientation := :h
        showaxis := :y
        subplot := 3
        left_margin --> 0mm
        # bins := edges2
        y := y
        x := ones(x |> size)
    end
end

# # now you can plot like:
# marginalscatter(rand(1000), rand(1000))
