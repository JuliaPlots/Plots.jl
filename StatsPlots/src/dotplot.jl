# ---------------------------------------------------------------------------
# Dot Plot (strip plot, beeswarm)

@recipe function f(::Type{Val{:dotplot}}, x, y, z; mode = :density, side = :both)
    # if only y is provided, then x will be UnitRange 1:size(y, 2)
    if typeof(x) <: AbstractRange
        if step(x) == first(x) == 1
            x = plotattributes[:series_plotindex]
        else
            x = [PlotsBase.Commons._getvalue(x, plotattributes[:series_plotindex])]
        end
    end

    grouplabels = sort(collect(unique(x)))
    barwidth = plotattributes[:bar_width]
    barwidth == nothing && (barwidth = 0.8)

    getoffsets(halfwidth, y) =
        mode ≡ :uniform ? (rand(length(y)) .* 2 .- 1) .* halfwidth :
        mode ≡ :density ? violinoffsets(halfwidth, y) : zeros(length(y))

    points_x, points_y = zeros(0), zeros(0)

    for (i, grouplabel) in enumerate(grouplabels)
        # filter y
        groupy = y[filter(i -> PlotsBase.Commons._getvalue(x, i) == grouplabel, 1:length(y))]

        center = PlotsBase.discrete_value!(plotattributes, :x, grouplabel)[1]
        halfwidth = 0.5PlotsBase.Commons._getvalue(barwidth, i)

        offsets = getoffsets(halfwidth, groupy)

        if side ≡ :left
            offsets = -abs.(offsets)
        elseif side ≡ :right
            offsets = abs.(offsets)
        end

        append!(points_y, groupy)
        append!(points_x, center .+ offsets)
    end

    seriestype := :scatter
    x := points_x
    y := points_y
    ()
end

PlotsBase.@deps dotplot scatter
PlotsBase.@shorthands dotplot

function violinoffsets(maxwidth, y)
    normalizewidths(maxwidth, widths) =
        maxwidth * widths / PlotsBase.ignorenan_maximum(widths)

    function getlocalwidths(widths, centers, y)
        upperbounds =
            [violincenters[violincenters .> yval] for yval in y] .|> findmin .|> first
        lowercenters = findmax.([violincenters[violincenters .≤ yval] for yval in y])
        lowerbounds, lowerindexes = first.(lowercenters), last.(lowercenters)
        δs = (y .- lowerbounds) ./ (upperbounds .- lowerbounds)

        itp = interpolate(widths, BSpline(Quadratic(Reflect(OnCell()))))
        return localwidths = itp.(lowerindexes .+ δs)
    end

    violinwidths, violincenters = violin_coords(y)
    violinwidths = normalizewidths(maxwidth, violinwidths)
    localwidths = getlocalwidths(violinwidths, violincenters, y)
    return offsets = (rand(length(y)) .* 2 .- 1) .* localwidths
end

# ------------------------------------------------------------------------------
# Grouped dotplot

@userplot GroupedDotplot

recipetype(::Val{:groupeddotplot}, args...) = GroupedDotplot(args)

@recipe function f(g::GroupedDotplot; spacing = 0.1)
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
        for i in 1:n
            groupinds = idxs[i]
            Δx = PlotsBase.Commons._getvalue(bws, i) * (i - (n + 1) / 2)
            x[groupinds] .+= Δx
        end
    end

    seriestype := :dotplot
    x, y
end

PlotsBase.@deps groupeddotplot dotplot
