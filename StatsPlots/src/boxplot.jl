
# ---------------------------------------------------------------------------
# Box Plot

notch_width(q2, q4, N) = 1.58 * (q4 - q2) / sqrt(N)

@recipe function f(
    ::Type{Val{:boxplot}},
    x,
    y,
    z;
    notch = false,
    whisker_range = 1.5,
    outliers = true,
    whisker_width = :half,
    sort_labels_by = identity,
    xshift = 0.0,
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
    texts = String[]
    glabels = sort(collect(unique(x)))
    warning = false
    outliers_x, outliers_y = zeros(0), zeros(0)
    bw = plotattributes[:bar_width]
    isnothing(bw) && (bw = 0.8)
    @assert whisker_width === :match || whisker_width == :half || whisker_width >= 0 "whisker_width must be :match, :half, or a positive number"
    ww = whisker_width === :match ? bw : whisker_width == :half ? bw / 2 : whisker_width
    for (i, glabel) ∈ enumerate(sort(glabels; by = sort_labels_by))
        # filter y
        values = y[filter(i -> _cycle(x, i) == glabel, 1:length(y))]

        # compute quantiles
        q1, q2, q3, q4, q5 = quantile(values, range(0, stop = 1, length = 5))

        # notch
        n = notch_width(q2, q4, length(values))

        # warn on inverted notches?
        if notch && !warning && ((q2 > (q3 - n)) || (q4 < (q3 + n)))
            @warn("Boxplot's notch went outside hinges. Set notch to false.")
            warning = true # Show the warning only one time
        end

        # make the shape
        center = PlotsBase.discrete_value!(plotattributes, :x, glabel)[1] + xshift
        hw = 0.5_cycle(bw, i) # Box width
        HW = 0.5_cycle(ww, i) # Whisker width
        l, m, r = center - hw, center, center + hw
        lw, rw = center - HW, center + HW

        # internal nodes for notches
        L, R = center - 0.5 * hw, center + 0.5 * hw

        # outliers
        if Float64(whisker_range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
            limit = whisker_range * (q4 - q2)
            inside = Float64[]
            for value ∈ values
                if (value < (q2 - limit)) || (value > (q4 + limit))
                    if outliers
                        push!(outliers_y, value)
                        push!(outliers_x, center)
                    end
                else
                    push!(inside, value)
                end
            end
            # change q1 and q5 to show outliers
            # using maximum and minimum values inside the limits
            q1, q5 = PlotsBase.ignorenan_extrema(inside)
            q1, q5 = (min(q1, q2), max(q4, q5)) # whiskers cannot be inside the box
        end
        # Box
        push!(xsegs, m, lw, rw, m, m)       # lower T
        push!(ysegs, q1, q1, q1, q1, q2)    # lower T
        push!(
            texts,
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Q1: $q2",
            "",
        )

        if notch
            push!(xsegs, r, r, R, L, l, l, r, r) # lower box
            push!(xsegs, r, r, l, l, L, R, r, r) # upper box

            push!(ysegs, q2, q3 - n, q3, q3, q3 - n, q2, q2, q3 - n) # lower box
            push!(
                texts,
                "Q1: $q2",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Q1: $q2",
                "Q1: $q2",
                "Median: $q3 ± $n",
                "",
            )

            push!(ysegs, q3 + n, q4, q4, q3 + n, q3, q3, q3 + n, q4) # upper box
            push!(
                texts,
                "Median: $q3 ± $n",
                "Q3: $q4",
                "Q3: $q4",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Median: $q3 ± $n",
                "Q3: $q4",
                "",
            )
        else
            push!(xsegs, r, r, l, l, r, r)         # lower box
            push!(xsegs, r, l, l, r, r, m)         # upper box
            push!(ysegs, q2, q3, q3, q2, q2, q3)   # lower box
            push!(
                texts,
                "Q1: $q2",
                "Median: $q3",
                "Median: $q3",
                "Q1: $q2",
                "Q1: $q2",
                "Median: $q3",
                "",
            )
            push!(ysegs, q4, q4, q3, q3, q4, q4)   # upper box
            push!(
                texts,
                "Q3: $q4",
                "Q3: $q4",
                "Median: $q3",
                "Median: $q3",
                "Q3: $q4",
                "Q3: $q4",
                "",
            )
        end

        push!(xsegs, m, lw, rw, m, m)             # upper T
        push!(ysegs, q5, q5, q5, q5, q4)          # upper T
        push!(
            texts,
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Q3: $q4",
            "",
        )
    end

    if !isvertical(plotattributes)
        # We should draw the plot horizontally!
        xsegs, ysegs = ysegs, xsegs
        outliers_x, outliers_y = outliers_y, outliers_x

        # Now reset the orientation, so that the axes limits are set correctly.
        orientation := default(:orientation)
    end

    @series begin
        # To prevent linecolor equal to fillcolor (It makes the median visible)
        if plotattributes[:linecolor] == plotattributes[:fillcolor]
            plotattributes[:linecolor] = plotattributes[:markerstrokecolor]
        end
        primary := true
        seriestype := :shape
        x := xsegs.pts
        y := ysegs.pts
        ()
    end

    # Outliers
    if outliers && !isempty(outliers)
        @series begin
            primary := false
            seriestype := :scatter
            if get!(plotattributes, :markershape, :circle) === :none
                plotattributes[:markershape] = :circle
            end

            fillrange := nothing
            x := outliers_x
            y := outliers_y
            ()
        end
    end

    # Hover
    primary := false
    seriestype := :path
    marker := false
    if PlotsBase.is_attr_supported(PlotsBase.backend(), :hover)
        hover := texts
    end
    linewidth := 0
    x := xsegs.pts
    y := ysegs.pts
    ()
end

PlotsBase.@deps boxplot shape scatter

# ------------------------------------------------------------------------------
# Grouped Boxplot

@userplot GroupedBoxplot

recipetype(::Val{:groupedboxplot}, args...) = GroupedBoxplot(args)

@recipe function f(g::GroupedBoxplot; spacing = 0.1)
    x, y = grouped_xy(g.args...)

    # extract xnums and set default bar width.
    # might need to set xticks as well
    ux = unique(x)
    x = if eltype(x) <: Number
        bar_width --> (0.8 * mean(diff(sort(ux))))
        float.(x)
    else
        bar_width --> 0.8
        xnums = [findfirst(isequal(xi), ux) for xi ∈ x] .- 0.5
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
        for i ∈ 1:n
            groupinds = idxs[i]
            Δx = _cycle(bws, i) * (i - (n + 1) / 2)
            x[groupinds] .+= Δx
        end
    end

    seriestype := :boxplot
    x, y
end

PlotsBase.@deps groupedboxplot boxplot
