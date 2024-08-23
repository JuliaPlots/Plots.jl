
# NOTE: (0,0) is the top-left !!!

to_pixels(m::AbsoluteLength) = m.value / 0.254

const _cbar_width = 5mm
const DEFAULT_BBOX = Ref(BoundingBox(0mm, 0mm, 0mm, 0mm))
const DEFAULT_MINPAD = Ref((20mm, 5mm, 2mm, 10mm))

origin(bbox::BoundingBox) = left(bbox) + width(bbox) / 2, top(bbox) + height(bbox) / 2
left(bbox::BoundingBox) = bbox.x0[1]
top(bbox::BoundingBox) = bbox.x0[2]
right(bbox::BoundingBox) = left(bbox) + width(bbox)
bottom(bbox::BoundingBox) = top(bbox) + height(bbox)
Base.size(bbox::BoundingBox) = (width(bbox), height(bbox))

# Base.:*{T,N}(m1::Length{T,N}, m2::Length{T,N}) = Length{T,N}(m1.value * m2.value)
ispositive(m::Measure) = m.value > 0

# union together bounding boxes
function Base.:+(bb1::BoundingBox, bb2::BoundingBox)
    # empty boxes don't change the union
    ispositive(width(bb1)) || return bb2
    ispositive(height(bb1)) || return bb2
    ispositive(width(bb2)) || return bb1
    ispositive(height(bb2)) || return bb1

    l = min(left(bb1), left(bb2))
    t = min(top(bb1), top(bb2))
    r = max(right(bb1), right(bb2))
    b = max(bottom(bb1), bottom(bb2))
    BoundingBox(l, t, r - l, b - t)
end

# convert x,y coordinates from absolute coords to percentages...
# returns x_pct, y_pct
function xy_mm_to_pcts(x::AbsoluteLength, y::AbsoluteLength, figw, figh, flipy = true)
    xmm, ymm = x.value, y.value
    if flipy
        ymm = figh.value - ymm  # flip y when origin in bottom-left
    end
    xmm / figw.value, ymm / figh.value
end

# convert a bounding box from absolute coords to percentages...
# returns an array of percentages of figure size: [left, bottom, width, height]
function bbox_to_pcts(bb::BoundingBox, figw, figh, flipy = true)
    mms = Float64[f(bb).value for f in (left, bottom, width, height)]
    if flipy
        mms[2] = figh.value - mms[2]  # flip y when origin in bottom-left
    end
    mms ./ Float64[figw.value, figh.value, figw.value, figh.value]
end

Base.show(io::IO, bbox::BoundingBox) = print(
    io,
    "BBox{l,t,r,b,w,h = $(left(bbox)),$(top(bbox)), $(right(bbox)),$(bottom(bbox)), $(width(bbox)),$(height(bbox))}",
)

# -----------------------------------------------------------
# AbstractLayout

Base.show(io::IO, layout::AbstractLayout) = print(io, "$(typeof(layout))$(size(layout))")

make_measure_hor(n::Number) = n * w
make_measure_hor(m::Measure) = m

make_measure_vert(n::Number) = n * h
make_measure_vert(m::Measure) = m

"""
    bbox(x, y, w, h [,originargs...])
    bbox(layout)

Create a bounding box for plotting
"""
function bbox(x, y, w, h, oarg1::Symbol, originargs::Symbol...)
    oargs = vcat(oarg1, originargs...)
    orighor = :left
    origver = :top
    for oarg in oargs
        if oarg === :center
            orighor = origver = oarg
        elseif oarg in (:left, :right, :hcenter)
            orighor = oarg
        elseif oarg in (:top, :bottom, :vcenter)
            origver = oarg
        else
            @warn "Unused origin arg in bbox construction: $oarg"
        end
    end
    bbox(x, y, w, h; h_anchor = orighor, v_anchor = origver)
end

# create a new bbox
function bbox(x, y, width, height; h_anchor = :left, v_anchor = :top)
    x = make_measure_hor(x)
    y = make_measure_vert(y)
    width = make_measure_hor(width)
    height = make_measure_vert(height)
    left = if h_anchor === :left
        x
    elseif h_anchor in (:center, :hcenter)
        0.5w - 0.5width + x
    else
        1w - x - width
    end
    top = if v_anchor === :top
        y
    elseif v_anchor in (:center, :vcenter)
        0.5h - 0.5height + y
    else
        1h - y - height
    end
    BoundingBox(left, top, width, height)
end

# this is the available area for drawing everything in this layout... as percentages of total canvas
bbox(layout::AbstractLayout) = layout.bbox
bbox!(layout::AbstractLayout, bb::BoundingBox) = (layout.bbox = bb)

# layouts are recursive, tree-like structures, and most will have a parent field
Base.parent(layout::AbstractLayout) = layout.parent
parent_bbox(layout::AbstractLayout) = bbox(parent(layout))

# padding_w(layout::AbstractLayout) = left_padding(layout) + right_padding(layout)
# padding_h(layout::AbstractLayout) = bottom_padding(layout) + top_padding(layout)
# padding(layout::AbstractLayout) = (padding_w(layout), padding_h(layout))

update_position!(layout::AbstractLayout) = nothing
update_child_bboxes!(
    layout::AbstractLayout,
    minimum_perimeter = [0mm, 0mm, 0mm, 0mm];
    kw...,
) = nothing

left(layout::AbstractLayout) = left(bbox(layout))
top(layout::AbstractLayout) = top(bbox(layout))
right(layout::AbstractLayout) = right(bbox(layout))
bottom(layout::AbstractLayout) = bottom(bbox(layout))
width(layout::AbstractLayout) = width(bbox(layout))
height(layout::AbstractLayout) = height(bbox(layout))

# pass these through to the bbox methods if there's no plotarea
plotarea(layout::AbstractLayout) = bbox(layout)
plotarea!(layout::AbstractLayout, bb::BoundingBox) = bbox!(layout, bb)

attr(layout::AbstractLayout, k::Symbol) = layout.attr[k]
attr(layout::AbstractLayout, k::Symbol, v) = get(layout.attr, k, v)
attr!(layout::AbstractLayout, v, k::Symbol) = (layout.attr[k] = v)
hasattr(layout::AbstractLayout, k::Symbol) = haskey(layout.attr, k)

leftpad(layout::AbstractLayout)   = 0mm
toppad(layout::AbstractLayout)    = 0mm
rightpad(layout::AbstractLayout)  = 0mm
bottompad(layout::AbstractLayout) = 0mm

# -----------------------------------------------------------
# RootLayout

# this is the parent of the top-level layout
struct RootLayout <: AbstractLayout end

Base.show(io::IO, layout::RootLayout) = Base.show_default(io, layout)
Base.parent(::RootLayout) = nothing
parent_bbox(::RootLayout) = DEFAULT_BBOX[]
bbox(::RootLayout) = DEFAULT_BBOX[]

# -----------------------------------------------------------
# EmptyLayout

# contains blank space
mutable struct EmptyLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
    attr::KW  # store label, width, and height for initialization
    # label  # this is the label that the subplot will take (since we create a layout before initialization)
end
EmptyLayout(parent = RootLayout(); kw...) = EmptyLayout(parent, DEFAULT_BBOX[], KW(kw))

Base.size(layout::EmptyLayout) = (0, 0)
Base.length(layout::EmptyLayout) = 0
Base.getindex(layout::EmptyLayout, r::Int, c::Int) = nothing

_update_min_padding!(layout::EmptyLayout) = nothing
_update_inset_padding!(layout::EmptyLayout) = nothing

# -----------------------------------------------------------
# GridLayout

# nested, gridded layout with optional size percentages
mutable struct GridLayout <: AbstractLayout
    parent::AbstractLayout
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox
    grid::Matrix{AbstractLayout} # Nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    widths::Vector{Measure}
    heights::Vector{Measure}
    attr::KW
end

"""
    grid(args...; kw...)

Create a grid layout for subplots. `args` specify the dimensions, e.g.
`grid(3,2, widths = (0.6,0.4))` creates a grid with three rows and two
columns of different width.
"""
grid(args...; kw...) = GridLayout(args...; kw...)

function GridLayout(
    dims...;
    parent = RootLayout(),
    widths = nothing,
    heights = nothing,
    kw...,
)
    # Check the values for heights and widths if values are provided
    all_between_one(xs) = all(x -> 0 < x < 1, xs)
    if heights !== nothing
        sum(heights) ≈ 1 || error("The heights provided ($(heights)) must sum to 1.")
        all_between_one(heights) ||
            error("The heights provided ($(heights)) must be in the range (0, 1).")
    else
        heights = zeros(dims[1])
    end
    if widths !== nothing
        sum(widths) ≈ 1 || error("The widths provided ($(widths)) must sum to 1.")
        all_between_one(widths) ||
            error("The widths provided ($(widths)) must be in the range (0, 1).")
    else
        widths = zeros(dims[2])
    end

    grid = Matrix{AbstractLayout}(undef, dims...)
    layout = GridLayout(
        parent,
        DEFAULT_MINPAD[],
        DEFAULT_BBOX[],
        grid,
        Measure[w * pct for w in widths],
        Measure[h * pct for h in heights],
        # convert(Vector{Float64}, widths),
        # convert(Vector{Float64}, heights),
        KW(kw),
    )
    for i in eachindex(grid)
        grid[i] = EmptyLayout(layout)
    end
    layout
end

Base.size(layout::GridLayout) = size(layout.grid)
Base.length(layout::GridLayout) = length(layout.grid)
Base.getindex(layout::GridLayout, r::Int, c::Int) = layout.grid[r, c]
Base.setindex!(layout::GridLayout, v, r::Int, c::Int) = layout.grid[r, c] = v
Base.setindex!(layout::GridLayout, v, ci::CartesianIndex) = layout.grid[ci] = v

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
layout_args(plotattributes::AKW) = layout_args(plotattributes[:layout])

function layout_args(plotattributes::AKW, n_override::Integer)
    layout, n = layout_args(n_override, get(plotattributes, :layout, n_override))
    if n < n_override
        error(
            "When doing layout, n ($n) < n_override ($(n_override)).  You're probably trying to force existing plots into a layout that doesn't fit them.",
        )
    end
    layout, n
end

function layout_args(n::Integer)
    nr, nc = compute_gridsize(n, -1, -1)
    GridLayout(nr, nc), n
end

function layout_args(sztup::NTuple{2,Integer})
    nr, nc = sztup
    GridLayout(nr, nc), nr * nc
end

layout_args(n_override::Integer, n::Integer) = layout_args(n)
layout_args(n, sztup::NTuple{2,Integer}) = layout_args(sztup)

function layout_args(n, sztup::Tuple{Colon,Integer})
    nc = sztup[2]
    nr = ceil(Int, n / nc)
    GridLayout(nr, nc), n
end

function layout_args(n, sztup::Tuple{Integer,Colon})
    nr = sztup[1]
    nc = ceil(Int, n / nr)
    GridLayout(nr, nc), n
end

function layout_args(sztup::NTuple{3,Integer})
    n, nr, nc = sztup
    nr, nc = compute_gridsize(n, nr, nc)
    GridLayout(nr, nc), n
end

layout_args(nt::NamedTuple) = EmptyLayout(; nt...), 1

function layout_args(m::AbstractVecOrMat)
    sz = size(m)
    nr = first(sz)
    nc = get(sz, 2, 1)
    gl = GridLayout(nr, nc)
    for ci in CartesianIndices(m)
        gl[ci] = layout_args(m[ci])[1]
    end
    layout_args(gl)
end

# recursively get the size of the grid
layout_args(layout::GridLayout) = layout, calc_num_subplots(layout)

layout_args(n_override::Integer, layout::Union{AbstractVecOrMat,GridLayout}) =
    layout_args(layout)

# ----------------------------------------------------------------------

function build_layout(args...)
    layout, n = layout_args(args...)
    build_layout(layout, n, Array{Plot}(undef, 0))
end

# n is the number of subplots...
function build_layout(layout::GridLayout, n::Integer, plts::AVec{Plot})
    nr, nc = size(layout)
    subplots = Subplot[]
    spmap = SubplotMap()
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
            if get(l.attr, :width, :auto) !== :auto
                layout.widths[c] = attr(l, :width)
            end
            if get(l.attr, :height, :auto) !== :auto
                layout.heights[r] = attr(l, :height)
            end
            i += inc
        elseif isa(l, GridLayout)
            # sub-grid
            if get(l.attr, :width, :auto) !== :auto
                layout.widths[c] = attr(l, :width)
            end
            if get(l.attr, :height, :auto) !== :auto
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
        expand_extrema!(a1, ignorenan_extrema(a2))
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
    if link === :square
        if (sps = filter(l -> isa(l, Subplot), layout.grid)) |> !isempty
            base_axis = sps[1][:xaxis]
            for sp in sps
                link_axes!(base_axis, sp[:xaxis])
                link_axes!(base_axis, sp[:yaxis])
            end
        end
    end
    if link === :all
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
    if orig_sp[:framestyle] === :box
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
