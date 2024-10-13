
# ---------------------------------------------------------------------------
# Violin Plot

const _violin_warned = [false]

function violin_coords(
    y;
    wts = nothing,
    trim::Bool = false,
    bandwidth = KernelDensity.default_bandwidth(y),
)
    kd =
        wts === nothing ? KernelDensity.kde(y, npoints = 200, bandwidth = bandwidth) :
        KernelDensity.kde(y, weights = weights(wts), npoints = 200, bandwidth = bandwidth)
    if trim
        xmin, xmax = PlotsBase.ignorenan_extrema(y)
        inside = Bool[xmin <= x <= xmax for x in kd.x]
        return (kd.density[inside], kd.x[inside])
    end
    kd.density, kd.x
end

get_quantiles(quantiles::AbstractVector) = quantiles
get_quantiles(x::Real) = [x]
get_quantiles(b::Bool) = b ? [0.5] : Float64[]
get_quantiles(n::Int) = range(0, 1, length = n + 2)[2:(end - 1)]

@recipe function f(
    ::Type{Val{:violin}},
    x,
    y,
    z;
    trim = true,
    side = :both,
    show_mean = false,
    show_median = false,
    quantiles = Float64[],
    bandwidth = KernelDensity.default_bandwidth(y),
)
    # if only y is provided, then x will be UnitRange 1:size(y,2)
    if typeof(x) <: AbstractRange
        x = if step(x) == first(x) == 1
            plotattributes[:series_plotindex]
        else
            [getindex(x, plotattributes[:series_plotindex])]
        end
    end
    xsegs, ysegs = Plots.PlotsBase.Segments(), Plots.PlotsBase.Segments()
    qxsegs, qysegs = Plots.PlotsBase.Segments(), Plots.PlotsBase.Segments()
    mxsegs, mysegs = Plots.PlotsBase.Segments(), Plots.PlotsBase.Segments()
    glabels = sort(collect(unique(x)))
    bw = plotattributes[:bar_width]
    bw == nothing && (bw = 0.8)
    msc = plotattributes[:markerstrokecolor]
    for (i, glabel) in enumerate(glabels)
        fy = y[filter(i -> _cycle(x, i) == glabel, 1:length(y))]
        widths, centers = violin_coords(
            fy,
            trim = trim,
            wts = plotattributes[:weights],
            bandwidth = bandwidth,
        )
        isempty(widths) && continue

        # normalize
        hw = 0.5_cycle(bw, i)
        widths = hw * widths / PlotsBase.ignorenan_maximum(widths)

        # make the violin
        xcenter = PlotsBase.discrete_value!(plotattributes, :x, glabel)[1]
        xcoords = if (side === :right)
            vcat(widths, zeros(length(widths))) .+ xcenter
        elseif (side === :left)
            vcat(zeros(length(widths)), -reverse(widths)) .+ xcenter
        else
            vcat(widths, -reverse(widths)) .+ xcenter
        end
        ycoords = vcat(centers, reverse(centers))

        push!(xsegs, xcoords)
        push!(ysegs, ycoords)

        if show_mean
            mea = StatsBase.mean(fy)
            mw = maximum(widths)
            mx = xcenter .+ [-mw, mw] * 0.75
            my = [mea, mea]
            if side === :right
                mx[1] = xcenter
            elseif side === :left
                mx[2] = xcenter
            end

            push!(mxsegs, mx)
            push!(mysegs, my)
        end

        if show_median
            med = StatsBase.median(fy)
            mw = maximum(widths)
            mx = xcenter .+ [-mw, mw] / 2
            my = [med, med]
            if side === :right
                mx[1] = xcenter
            elseif side === :left
                mx[2] = xcenter
            end

            push!(qxsegs, mx)
            push!(qysegs, my)
        end

        quantiles = get_quantiles(quantiles)
        if !isempty(quantiles)
            qy = quantile(fy, quantiles)
            maxw = maximum(widths)

            for i in eachindex(qy)
                qxi = xcenter .+ [-maxw, maxw] * (0.5 - abs(0.5 - quantiles[i]))
                qyi = [qy[i], qy[i]]
                if side === :right
                    qxi[1] = xcenter
                elseif side === :left
                    qxi[2] = xcenter
                end

                push!(qxsegs, qxi)
                push!(qysegs, qyi)
            end

            push!(qxsegs, [xcenter, xcenter])
            push!(qysegs, [extrema(qy)...])
        end
    end

    @series begin
        seriestype := :shape
        x := xsegs.pts
        y := ysegs.pts
        ()
    end

    if !isempty(mxsegs.pts)
        @series begin
            primary := false
            seriestype := :shape
            linestyle := :dot
            x := mxsegs.pts
            y := mysegs.pts
            ()
        end
    end

    if !isempty(qxsegs.pts)
        @series begin
            primary := false
            seriestype := :shape
            x := qxsegs.pts
            y := qysegs.pts
            ()
        end
    end

    seriestype := :shape
    primary := false
    x := []
    y := []
    ()
end
PlotsBase.@deps violin shape

# ------------------------------------------------------------------------------
# Grouped Violin

@userplot GroupedViolin

recipetype(::Val{:groupedviolin}, args...) = GroupedViolin(args)

@recipe function f(g::GroupedViolin; spacing = 0.1)
    x, y = grouped_xy(g.args...)

    # extract xnums and set default bar width.
    # might need to set xticks as well
    ux = unique(x)
    x = if eltype(x) <: Number
        bar_width --> (0.8 * mean(diff(sort(ux))))
        float.(x)
    else
        bar_width --> 0.8
        xnums = [findfirst(isequal(xi), ux) for xi in x] .- 0.5
        xticks --> (eachindex(ux) .- 0.5, ux)
        xnums
    end

    # shift x values for each group
    group = get(plotattributes, :group, nothing)
    if group != nothing
        gb = RecipesPipeline._extract_group_attributes(group)
        labels, idxs = getfield(gb, 1), getfield(gb, 2)
        n = length(labels)
        bws = plotattributes[:bar_width] / n
        bar_width := bws * clamp(1 - spacing, 0, 1)
        for i = 1:n
            groupinds = idxs[i]
            Δx = _cycle(bws, i) * (i - (n + 1) / 2)
            x[groupinds] .+= Δx
        end
    end

    seriestype := :violin
    x, y
end

PlotsBase.@deps groupedviolin violin
