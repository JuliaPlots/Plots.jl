@userplot GroupedBar

recipetype(::Val{:groupedbar}, args...) = GroupedBar(args)

PlotsBase.group_as_matrix(g::GroupedBar) = true

grouped_xy(x::AbstractVector, y::AbstractArray) = x, y
grouped_xy(y::AbstractArray) = 1:size(y, 1), y

@recipe function f(g::GroupedBar; spacing = 0)
    x, y = grouped_xy(g.args...)

    nr, nc = size(y)
    isstack = pop!(plotattributes, :bar_position, :dodge) === :stack
    isylog = pop!(plotattributes, :yscale, :identity) ∈ (:log10, :log)
    the_ylims = pop!(plotattributes, :ylims, (-Inf, Inf))

    # extract xnums and set default bar width.
    # might need to set xticks as well
    xnums = if eltype(x) <: Number
        xdiff = length(x) > 1 ? mean(diff(x)) : 1
        bar_width --> 0.8 * xdiff
        x
    else
        bar_width --> 0.8
        ux = unique(x)
        xnums = (1:length(ux)) .- 0.5
        xticks --> (xnums, ux)
        xnums
    end
    @assert length(xnums) == nr

    # compute the x centers.  for dodge, make a matrix for each column
    x = if isstack
        x
    else
        bws = plotattributes[:bar_width] / nc
        bar_width := bws * clamp(1 - spacing, 0, 1)
        xmat = zeros(nr, nc)
        for r = 1:nr
            bw = _cycle(bws, r)
            farleft = xnums[r] - 0.5 * (bw * nc)
            for c = 1:nc
                xmat[r, c] = farleft + 0.5bw + (c - 1) * bw
            end
        end
        xmat
    end

    fill_bottom = if isylog
        if isfinite(the_ylims[1])
            min(minimum(y) / 100, the_ylims[1])
        else
            minimum(y) / 100
        end
    else
        0
    end
    # compute fillrange
    y, fr =
        isstack ? groupedbar_fillrange(y) :
        (y, get(plotattributes, :fillrange, [fill_bottom]))
    if isylog
        replace!(fr, 0 => fill_bottom)
    end
    fillrange := fr

    seriestype := :bar
    x, y
end

function groupedbar_fillrange(y)
    nr, nc = size(y)
    # bar series fills from y[nr, nc] to fr[nr, nc], y .>= fr
    fr = zeros(nr, nc)
    y = copy(y)
    y[.!isfinite.(y)] .= 0
    for r = 1:nr
        y_neg = 0
        # upper & lower bounds for positive bar
        y_pos = sum([e for e in y[r, :] if e > 0])
        # division subtract towards 0
        for c = 1:nc
            el = y[r, c]
            if el >= 0
                y[r, c] = y_pos
                y_pos -= el
                fr[r, c] = y_pos
            else
                fr[r, c] = y_neg
                y_neg += el
                y[r, c] = y_neg
            end
        end
    end
    y, fr
end
