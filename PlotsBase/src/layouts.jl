
leftpad(pad)   = pad[1]
toppad(pad)    = pad[2]
rightpad(pad)  = pad[3]
bottompad(pad) = pad[4]

leftpad(layout::GridLayout)   = leftpad(layout.minpad)
toppad(layout::GridLayout)    = toppad(layout.minpad)
rightpad(layout::GridLayout)  = rightpad(layout.minpad)
bottompad(layout::GridLayout) = bottompad(layout.minpad)

# here's how this works... first we recursively "update the minimum padding" (which
# means to calculate the minimum size needed from the edge of the subplot to plot area)
# for the whole layout tree.  then we can compute the "padding borders" of this
# layout as the biggest padding of the children on the perimeter.  then we need to
# recursively pass those borders back down the tree, one side at a time, but ONLY
# to those perimeter children.

function paddings(args...)
    funcs = (leftpad, toppad, rightpad, bottompad)
    args = length(args) == 1 ? ntuple(i -> first(args), Val(4)) : args
    map(i -> map(funcs[i], args[i]), Tuple(1:4))
end

compute_minpad(args...) = map(maximum, paddings(args...))

_update_inset_padding!(layout::GridLayout) = map(_update_inset_padding!, layout.grid)
_update_inset_padding!(sp::Subplot) =
    for isp in sp.plt.inset_subplots
        parent(isp) == sp || continue
        _update_min_padding!(isp)
        sp.minpad = max.(sp.minpad, isp.minpad)
    end

# leftpad, toppad, rightpad, bottompad
function _update_min_padding!(layout::GridLayout)
    map(_update_min_padding!, layout.grid)
    map(_update_inset_padding!, layout.grid)
    layout.minpad = compute_minpad(
        layout.grid[:, 1],
        layout.grid[1, :],
        layout.grid[:, end],
        layout.grid[end, :],
    )
    layout.minpad
end

update_position!(layout::GridLayout) = map(update_position!, layout.grid)

# some lengths are fixed... we have to split up the free space among the list v
function recompute_lengths(v)
    # dump(v)
    tot = 0pct
    cnt = 0
    for vi in v
        if vi == 0pct
            cnt += 1
        else
            tot += vi
        end
    end
    leftover = 1.0pct - tot
    if cnt > 1 && leftover.value <= 0
        error(
            "Not enough length left over in layout!  v = $v, cnt = $cnt, leftover = $leftover",
        )
    end

    # now fill in the blanks
    map(x -> x == 0pct ? leftover / cnt : x, v)
end

# recursively compute the bounding boxes for the layout and plotarea (relative to canvas!)
function update_child_bboxes!(layout::GridLayout, minimum_perimeter = [0mm, 0mm, 0mm, 0mm])
    nr, nc = size(layout)

    # create a matrix for each minimum padding direction
    minpad_left, minpad_top, minpad_right, minpad_bottom = paddings(layout.grid)

    # get the max horizontal (left and right) padding over columns,
    # and max vertical (bottom and top) padding over rows
    # TODO: add extra padding here
    pad_left   = maximum(minpad_left, dims = 1)
    pad_top    = maximum(minpad_top, dims = 2)
    pad_right  = maximum(minpad_right, dims = 1)
    pad_bottom = maximum(minpad_bottom, dims = 2)

    # make sure the perimeter match the parent
    pad_left[1]     = max(pad_left[1], leftpad(minimum_perimeter))
    pad_top[1]      = max(pad_top[1], toppad(minimum_perimeter))
    pad_right[end]  = max(pad_right[end], rightpad(minimum_perimeter))
    pad_bottom[end] = max(pad_bottom[end], bottompad(minimum_perimeter))

    # scale this up to the total padding in each direction, and limit padding to 95%
    total_pad_horizontal = min(0.95width(layout), sum(pad_left + pad_right))
    total_pad_vertical   = min(0.95height(layout), sum(pad_top + pad_bottom))

    # now we can compute the total plot area in each direction
    total_plotarea_horizontal = width(layout) - total_pad_horizontal
    total_plotarea_vertical   = height(layout) - total_pad_vertical

    @assert total_plotarea_horizontal > 0mm
    @assert total_plotarea_vertical > 0mm

    # recompute widths/heights
    layout.widths = recompute_lengths(layout.widths)
    layout.heights = recompute_lengths(layout.heights)

    # we have all the data we need... lets compute the plot areas and set the bounding boxes
    for r in 1:nr, c in 1:nc
        child = layout[r, c]

        # get the top-left corner of this child... the first one is top-left of the parent (i.e. layout)
        child_left = c == 1 ? left(layout.bbox) : right(layout[r, c - 1].bbox)
        child_top  = r == 1 ? top(layout.bbox) : bottom(layout[r - 1, c].bbox)

        # compute plot area
        plotarea_left   = child_left + pad_left[c]
        plotarea_top    = child_top + pad_top[r]
        plotarea_width  = total_plotarea_horizontal * layout.widths[c]
        plotarea_height = total_plotarea_vertical * layout.heights[r]

        bb = BoundingBox(plotarea_left, plotarea_top, plotarea_width, plotarea_height)
        plotarea!(child, bb)

        # compute child bbox
        child_width  = pad_left[c] + plotarea_width + pad_right[c]
        child_height = pad_top[r] + plotarea_height + pad_bottom[r]
        bbox!(child, BoundingBox(child_left, child_top, child_width, child_height))

        # this is the minimum perimeter as decided by this child's parent, so that
        # all children on this border have the same value
        min_child_perim = [
            c == 1 ? leftpad(layout) : pad_left[c],
            r == 1 ? toppad(layout) : pad_top[r],
            c == nc ? rightpad(layout) : pad_right[c],
            r == nr ? bottompad(layout) : pad_bottom[r],
        ]
        # recursively update the child's children
        update_child_bboxes!(child, min_child_perim)
    end
end

# for each inset (floating) subplot, resolve the relative position
# to absolute canvas coordinates, relative to the parent's plotarea
update_inset_bboxes!(plt::Plot) =
    for sp in plt.inset_subplots
        p_area = Measures.resolve(plotarea(sp.parent), sp[:relative_bbox])
        plotarea!(sp, p_area)
        # NOTE: `lens` example, `pgfplotsx` for non-regression
        bbox!(
            sp,
            bbox(
                left(p_area) - leftpad(sp),
                top(p_area) - toppad(sp),
                width(p_area) + leftpad(sp) + rightpad(sp),
                height(p_area) + toppad(sp) + bottompad(sp),
            ),
        )
    end
# ----------------------------------------------------------------------

calc_num_subplots(layout::AbstractLayout) = get(layout.attr, :blank, false) ? 0 : 1
calc_num_subplots(layout::GridLayout) = sum(map(l -> calc_num_subplots(l), layout.grid))

function compute_gridsize(numplts::Int, nr::Int, nc::Int)
    # figure out how many rows/columns we need
    if nr < 1
        if nc < 1
            nr = round(Int, sqrt(numplts))
            nc = ceil(Int, numplts / nr)
        else
            nr = ceil(Int, numplts / nc)
        end
    else
        nc = ceil(Int, numplts / nr)
    end
    nr, nc
end

# ----------------------------------------------------------------------
# constructors

# pass the layout arg through
layout_attrs(plotattributes::AKW) = layout_attrs(plotattributes[:layout])

function layout_attrs(plotattributes::AKW, n_override::Integer)
    layout, n = layout_attrs(n_override, get(plotattributes, :layout, n_override))
    if n < n_override
        error(
            "When doing layout, n ($n) < n_override ($(n_override)).  You're probably trying to force existing plots into a layout that doesn't fit them.",
        )
    end
    layout, n
end

function layout_attrs(n::Integer)
    nr, nc = compute_gridsize(n, -1, -1)
    GridLayout(nr, nc), n
end

function layout_attrs(sztup::NTuple{2,Integer})
    nr, nc = sztup
    GridLayout(nr, nc), nr * nc
end

layout_attrs(n_override::Integer, n::Integer) = layout_attrs(n)
layout_attrs(n, sztup::NTuple{2,Integer}) = layout_attrs(sztup)

function layout_attrs(n, sztup::Tuple{Colon,Integer})
    nc = sztup[2]
    nr = ceil(Int, n / nc)
    GridLayout(nr, nc), n
end

function layout_attrs(n, sztup::Tuple{Integer,Colon})
    nr = sztup[1]
    nc = ceil(Int, n / nr)
    GridLayout(nr, nc), n
end

function layout_attrs(sztup::NTuple{3,Integer})
    n, nr, nc = sztup
    nr, nc = compute_gridsize(n, nr, nc)
    GridLayout(nr, nc), n
end

layout_attrs(nt::NamedTuple) = EmptyLayout(; nt...), 1

function layout_attrs(m::AbstractVecOrMat)
    sz = size(m)
    nr = first(sz)
    nc = get(sz, 2, 1)
    gl = GridLayout(nr, nc)
    for ci in CartesianIndices(m)
        gl[ci] = layout_attrs(m[ci])[1]
    end
    layout_attrs(gl)
end

# recursively get the size of the grid
layout_attrs(layout::GridLayout) = layout, calc_num_subplots(layout)

layout_attrs(n_override::Integer, layout::Union{AbstractVecOrMat,GridLayout}) =
    layout_attrs(layout)

# ----------------------------------------------------------------------

function build_layout(args...)
    layout, n = layout_attrs(args...)
    build_layout(layout, n, Array{Plot}(undef, 0))
end

# n is the number of subplots...
function build_layout(layout::GridLayout, n::Integer, plts::AVec{Plot})
    nr, nc = size(layout)
    subplots = Subplot[]
    spmap = Plots.SubplotMap()
    empty = isempty(plts)
    i = 0
    for r in 1:nr, c in 1:nc
        l = layout[r, c]
        if isa(l, EmptyLayout) && !get(l.attr, :blank, false)
            if empty
                # initialize the inner subplots recursively
                sp = Subplot(backend(), parent = layout)
                layout[r, c] = sp
                push!(subplots, sp)
                spmap[attr(l, :label, gensym())] = sp
                inc = 1
            else
                # build a layout from a list of existing Plot objects
                plt = popfirst!(plts)  # grab the first plot out of the list
                layout[r, c] = plt.layout
                append!(subplots, plt.subplots)
                merge!(spmap, plt.spmap)
                inc = length(plt.subplots)
            end
            if get(l.attr, :width, :auto) ≢ :auto
                layout.widths[c] = attr(l, :width)
            end
            if get(l.attr, :height, :auto) ≢ :auto
                layout.heights[r] = attr(l, :height)
            end
            i += inc
        elseif isa(l, GridLayout)
            # sub-grid
            if get(l.attr, :width, :auto) ≢ :auto
                layout.widths[c] = attr(l, :width)
            end
            if get(l.attr, :height, :auto) ≢ :auto
                layout.heights[r] = attr(l, :height)
            end
            l, sps, m = build_layout(l, n - i, plts)
            append!(subplots, sps)
            merge!(spmap, m)
            i += length(sps)
        elseif isa(l, Subplot) && empty
            error("Subplot exists. Cannot re-use existing layout.  Please make a new one.")
        end
        i ≥ n && break  # only add n subplots
    end

    layout, subplots, spmap
end

# -------------------------------------------------------------------------

# make all reference the same axis extrema/values.
# merge subplot lists.
function link_axes!(axes::Axis...)
    a1 = axes[1]
    for i in 2:length(axes)
        a2 = axes[i]
        expand_extrema!(a1, Axes.ignorenan_extrema(a2))
        for k in (:extrema, :discrete_values, :continuous_values, :discrete_map)
            a2[k] = a1[k]
        end

        # make a2's subplot list refer to a1's and add any missing values
        sps2 = a2.sps
        for sp in sps2
            sp in a1.sps || push!(a1.sps, sp)
        end
        a2.sps = a1.sps
    end
end

# figure out which subplots to link
function link_subplots(a::AbstractArray{AbstractLayout}, axissym::Symbol)
    subplots = []
    for l in a
        if isa(l, Subplot)
            push!(subplots, l)
        elseif isa(l, GridLayout) && size(l) == (1, 1)
            push!(subplots, l[1, 1])
        end
    end
    subplots
end

# for some vector or matrix of layouts, filter only the Subplots and link those axes
function link_axes!(a::AbstractArray{AbstractLayout}, axissym::Symbol)
    subplots = link_subplots(a, axissym)
    axes = [sp.attr[axissym] for sp in subplots]
    length(axes) > 0 && link_axes!(axes...)
end

# don't do anything for most layout types
function link_axes!(l::AbstractLayout, link::Symbol) end

# process a GridLayout, recursively linking axes according to the link symbol
function link_axes!(layout::GridLayout, link::Symbol)
    nr, nc = size(layout)
    if link in (:x, :both)
        for c in 1:nc
            link_axes!(layout.grid[:, c], :xaxis)
        end
    end
    if link in (:y, :both)
        for r in 1:nr
            link_axes!(layout.grid[r, :], :yaxis)
        end
    end
    if link ≡ :square
        if (sps = filter(l -> isa(l, Subplot), layout.grid)) |> !isempty
            base_axis = sps[1][:xaxis]
            for sp in sps
                link_axes!(base_axis, sp[:xaxis])
                link_axes!(base_axis, sp[:yaxis])
            end
        end
    end
    if link ≡ :all
        link_axes!(layout.grid, :xaxis)
        link_axes!(layout.grid, :yaxis)
    end
    foreach(l -> link_axes!(l, link), layout.grid)
end

# -------------------------------------------------------------------------

function twin(sp, letter)
    plt = sp.plt
    orig_sp = first(plt.subplots)
    for letter in filter(!=(letter), axes_letters(orig_sp, letter))
        ax = orig_sp[get_attr_symbol(letter, :axis)]
        ax[:grid] = false  # disable the grid (overlaps with twin axis)
    end
    if orig_sp[:framestyle] ≡ :box
        # incompatible with shared axes (see github.com/JuliaPlots/Plots.jl/issues/2894)
        orig_sp[:framestyle] = :axes
    end
    plot!(
        plt;
        inset = (sp[:subplot_index], bbox(0, 0, 1, 1)),
        left_margin = orig_sp[:left_margin],
        top_margin = orig_sp[:top_margin],
        right_margin = orig_sp[:right_margin],
        bottom_margin = orig_sp[:bottom_margin],
    )
    twin_sp = last(plt.subplots)
    letters = axes_letters(twin_sp, letter)
    tax, oax = map(l -> twin_sp[get_attr_symbol(l, :axis)], letters)
    tax[:grid] = false
    tax[:showaxis] = false
    tax[:ticks] = :none
    oax[:grid] = false
    oax[:mirror] = true
    twin_sp[:background_color_inside] = RGBA{Float64}(0, 0, 0, 0)
    link_axes!(sp[get_attr_symbol(letter, :axis)], tax)
    twin_sp
end

"""
    twinx(sp)

Adds a new, empty subplot overlaid on top of `sp`, with a mirrored y-axis and linked x-axis.
"""
twinx(sp::Subplot) = twin(sp, :x)
twinx(plt::Plot = current()) = twinx(first(plt))

"""
    twiny(sp)

Adds a new, empty subplot overlaid on top of `sp`, with a mirrored x-axis and linked y-axis.
"""
twiny(sp::Subplot) = twin(sp, :y)
twiny(plt::Plot = current()) = twiny(first(plt))
