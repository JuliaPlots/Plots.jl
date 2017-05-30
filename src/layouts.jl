
# NOTE: (0,0) is the top-left !!!

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct, Float64}(1.0)

to_pixels(m::AbsoluteLength) = m.value / 0.254

const _cbar_width = 5mm

Base.:.*(m::Measure, n::Number) = m * n
Base.:.*(n::Number, m::Measure) = m * n
Base.:-(m::Measure, a::AbstractArray) = map(ai -> m - ai, a)
Base.:-(a::AbstractArray, m::Measure) = map(ai -> ai - m, a)
Base.zero(::Type{typeof(mm)}) = 0mm
Base.one(::Type{typeof(mm)}) = 1mm
Base.typemin(::typeof(mm)) = -Inf*mm
Base.typemax(::typeof(mm)) = Inf*mm
Base.convert{F<:AbstractFloat}(::Type{F}, l::AbsoluteLength) = convert(F, l.value)

# TODO: these are unintuitive and may cause tricky bugs
# Base.:+(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 + m2.value))
# Base.:+(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (1 + m1.value))
# Base.:-(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 - m2.value))
# Base.:-(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (m1.value - 1))

Base.:*(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.:*(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.:/(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.:/(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)


Base.zero(::Type{typeof(pct)}) = 0pct
Base.one(::Type{typeof(pct)}) = 1pct
Base.typemin(::typeof(pct)) = 0pct
Base.typemax(::typeof(pct)) = 1pct

const defaultbox = BoundingBox(0mm, 0mm, 0mm, 0mm)

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
    ispositive(width(bb1))  || return bb2
    ispositive(height(bb1)) || return bb2
    ispositive(width(bb2))  || return bb1
    ispositive(height(bb2)) || return bb1

    l = min(left(bb1), left(bb2))
    t = min(top(bb1), top(bb2))
    r = max(right(bb1), right(bb2))
    b = max(bottom(bb1), bottom(bb2))
    BoundingBox(l, t, r-l, b-t)
end

# this creates a bounding box in the parent's scope, where the child bounding box
# is relative to the parent
function crop(parent::BoundingBox, child::BoundingBox)
    l = left(parent) + left(child)
    t = top(parent) + top(child)
    w = width(child)
    h = height(child)
    BoundingBox(l, t, w, h)
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
    mms = Float64[f(bb).value for f in (left,bottom,width,height)]
    if flipy
        mms[2] = figh.value - mms[2]  # flip y when origin in bottom-left
    end
    mms ./ Float64[figw.value, figh.value, figw.value, figh.value]
end

function Base.show(io::IO, bbox::BoundingBox)
    print(io, "BBox{l,t,r,b,w,h = $(left(bbox)),$(top(bbox)), $(right(bbox)),$(bottom(bbox)), $(width(bbox)),$(height(bbox))}")
end

# -----------------------------------------------------------

# points combined by x/y, pct, and length
type MixedMeasures
    xy::Float64
    pct::Float64
    len::AbsoluteLength
end

function resolve_mixed(mix::MixedMeasures, sp::Subplot, letter::Symbol)
    xy = mix.xy
    pct = mix.pct
    if mix.len != 0mm
        f = (letter == :x ? width : height)
        totlen = f(plotarea(sp))
        @show totlen
        pct += mix.len / totlen
    end
    if pct != 0
        amin, amax = axis_limits(sp[Symbol(letter,:axis)])
        xy += pct * (amax-amin)
    end
    xy
end


# -----------------------------------------------------------
# AbstractLayout

Base.show(io::IO, layout::AbstractLayout) = print(io, "$(typeof(layout))$(size(layout))")

make_measure_hor(n::Number) = n * w
make_measure_hor(m::Measure) = m

make_measure_vert(n::Number) = n * h
make_measure_vert(m::Measure) = m


function bbox(x, y, w, h, oarg1::Symbol, originargs::Symbol...)
    oargs = vcat(oarg1, originargs...)
    orighor = :left
    origver = :top
    for oarg in oargs
        if oarg == :center
            orighor = origver = oarg
        elseif oarg in (:left, :right, :hcenter)
            orighor = oarg
        elseif oarg in (:top, :bottom, :vcenter)
            origver = oarg
        else
            warn("Unused origin arg in bbox construction: $oarg")
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
    left = if h_anchor == :left
        x
    elseif h_anchor in (:center, :hcenter)
        0.5w - 0.5width + x
    else
        1w - x - width
    end
    top = if v_anchor == :top
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
update_child_bboxes!(layout::AbstractLayout, minimum_perimeter = [0mm,0mm,0mm,0mm]) = nothing

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
immutable RootLayout <: AbstractLayout end

Base.parent(::RootLayout) = nothing
parent_bbox(::RootLayout) = defaultbox
bbox(::RootLayout) = defaultbox

# -----------------------------------------------------------
# EmptyLayout

# contains blank space
type EmptyLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
    attr::KW  # store label, width, and height for initialization
    # label  # this is the label that the subplot will take (since we create a layout before initialization)
end
EmptyLayout(parent = RootLayout(); kw...) = EmptyLayout(parent, defaultbox, KW(kw))

Base.size(layout::EmptyLayout) = (0,0)
Base.length(layout::EmptyLayout) = 0
Base.getindex(layout::EmptyLayout, r::Int, c::Int) = nothing

_update_min_padding!(layout::EmptyLayout) = nothing

# -----------------------------------------------------------
# GridLayout

# nested, gridded layout with optional size percentages
type GridLayout <: AbstractLayout
    parent::AbstractLayout
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox
    grid::Matrix{AbstractLayout} # Nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    widths::Vector{Measure}
    heights::Vector{Measure}
    attr::KW
end

grid(args...; kw...) = GridLayout(args...; kw...)

function GridLayout(dims...;
                    parent = RootLayout(),
                    widths = zeros(dims[2]),
                    heights = zeros(dims[1]),
                    kw...)
    grid = Matrix{AbstractLayout}(dims...)
    layout = GridLayout(
        parent,
        (20mm, 5mm, 2mm, 10mm),
        defaultbox,
        grid,
        Measure[w*pct for w in widths],
        Measure[h*pct for h in heights],
        # convert(Vector{Float64}, widths),
        # convert(Vector{Float64}, heights),
        KW(kw))
    for i in eachindex(grid)
        grid[i] = EmptyLayout(layout)
    end
    layout
end

Base.size(layout::GridLayout) = size(layout.grid)
Base.length(layout::GridLayout) = length(layout.grid)
Base.getindex(layout::GridLayout, r::Int, c::Int) = layout.grid[r,c]
function Base.setindex!(layout::GridLayout, v, r::Int, c::Int)
    layout.grid[r,c] = v
end

leftpad(layout::GridLayout)   = layout.minpad[1]
toppad(layout::GridLayout)    = layout.minpad[2]
rightpad(layout::GridLayout)  = layout.minpad[3]
bottompad(layout::GridLayout) = layout.minpad[4]


# here's how this works... first we recursively "update the minimum padding" (which
# means to calculate the minimum size needed from the edge of the subplot to plot area)
# for the whole layout tree.  then we can compute the "padding borders" of this
# layout as the biggest padding of the children on the perimeter.  then we need to
# recursively pass those borders back down the tree, one side at a time, but ONLY
# to those perimeter children.

# leftpad, toppad, rightpad, bottompad
function _update_min_padding!(layout::GridLayout)
    map(_update_min_padding!, layout.grid)
    layout.minpad = (
        maximum(map(leftpad,   layout.grid[:,1])),
        maximum(map(toppad,    layout.grid[1,:])),
        maximum(map(rightpad,  layout.grid[:,end])),
        maximum(map(bottompad, layout.grid[end,:]))
    )
end


function update_position!(layout::GridLayout)
    map(update_position!, layout.grid)
end

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
        error("Not enough length left over in layout!  v = $v, cnt = $cnt, leftover = $leftover")
    end

    # now fill in the blanks
    Measure[(vi == 0pct ? leftover / cnt : vi) for vi in v]
end

# recursively compute the bounding boxes for the layout and plotarea (relative to canvas!)
function update_child_bboxes!(layout::GridLayout, minimum_perimeter = [0mm,0mm,0mm,0mm])
    nr, nc = size(layout)

    # # create a matrix for each minimum padding direction
    # _update_min_padding!(layout)

    minpad_left   = map(leftpad,   layout.grid)
    minpad_top    = map(toppad,    layout.grid)
    minpad_right  = map(rightpad,  layout.grid)
    minpad_bottom = map(bottompad, layout.grid)

    # get the max horizontal (left and right) padding over columns,
    # and max vertical (bottom and top) padding over rows
    # TODO: add extra padding here
    pad_left   = maximum(minpad_left,   1)
    pad_top    = maximum(minpad_top,    2)
    pad_right  = maximum(minpad_right,  1)
    pad_bottom = maximum(minpad_bottom, 2)

    # make sure the perimeter match the parent
    pad_left[1]     = max(pad_left[1], minimum_perimeter[1])
    pad_top[1]      = max(pad_top[1], minimum_perimeter[2])
    pad_right[end]  = max(pad_right[end], minimum_perimeter[3])
    pad_bottom[end] = max(pad_bottom[end], minimum_perimeter[4])

    # scale this up to the total padding in each direction
    total_pad_horizontal = sum(pad_left + pad_right)
    total_pad_vertical   = sum(pad_top + pad_bottom)

    # now we can compute the total plot area in each direction
    total_plotarea_horizontal = width(layout)  - total_pad_horizontal
    total_plotarea_vertical   = height(layout) - total_pad_vertical

    # recompute widths/heights
    layout.widths = recompute_lengths(layout.widths)
    layout.heights = recompute_lengths(layout.heights)

    # normalize widths/heights so they sum to 1
    # denom_w = sum(layout.widths)
    # denom_h = sum(layout.heights)

    # we have all the data we need... lets compute the plot areas and set the bounding boxes
    for r=1:nr, c=1:nc
        child = layout[r,c]

        # get the top-left corner of this child... the first one is top-left of the parent (i.e. layout)
        child_left = (c == 1 ? left(layout.bbox) : right(layout[r, c-1].bbox))
        child_top  = (r == 1 ? top(layout.bbox) : bottom(layout[r-1, c].bbox))

        # compute plot area
        plotarea_left   = child_left + pad_left[c]
        plotarea_top    = child_top + pad_top[r]
        plotarea_width  = total_plotarea_horizontal * layout.widths[c]
        plotarea_height = total_plotarea_vertical * layout.heights[r]
        plotarea!(child, BoundingBox(plotarea_left, plotarea_top, plotarea_width, plotarea_height))

        # compute child bbox
        child_width  = pad_left[c] + plotarea_width + pad_right[c]
        child_height = pad_top[r] + plotarea_height + pad_bottom[r]
        bbox!(child, BoundingBox(child_left, child_top, child_width, child_height))

        # this is the minimum perimeter as decided by this child's parent, so that
        # all children on this border have the same value
        min_child_perimeter = [
            c == 1  ? layout.minpad[1] : 0mm,
            r == 1  ? layout.minpad[2] : 0mm,
            c == nc ? layout.minpad[3] : 0mm,
            r == nr ? layout.minpad[4] : 0mm
        ]

        # recursively update the child's children
        update_child_bboxes!(child, min_child_perimeter)
    end
end

# for each inset (floating) subplot, resolve the relative position
# to absolute canvas coordinates, relative to the parent's plotarea
function update_inset_bboxes!(plt::Plot)
    for sp in plt.inset_subplots
        p_area = Measures.resolve(plotarea(sp.parent), sp[:relative_bbox])
        plotarea!(sp, p_area)

        bbox!(sp, bbox(
            left(p_area) - leftpad(sp),
            top(p_area) - toppad(sp),
            width(p_area) + leftpad(sp) + rightpad(sp),
            height(p_area) + toppad(sp) + bottompad(sp)
        ))
    end
end

# ----------------------------------------------------------------------

calc_num_subplots(layout::AbstractLayout) = 1
function calc_num_subplots(layout::GridLayout)
    tot = 0
    for l in layout.grid
        tot += calc_num_subplots(l)
    end
    tot
end

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
function layout_args(d::KW)
    layout_args(get(d, :layout, default(:layout)))
end

function layout_args(d::KW, n_override::Integer)
    layout, n = layout_args(get(d, :layout, n_override))
    if n != n_override
        error("When doing layout, n ($n) != n_override ($(n_override)).  You're probably trying to force existing plots into a layout that doesn't fit them.")
    end
    layout, n
end

function layout_args(n::Integer)
    nr, nc = compute_gridsize(n, -1, -1)
    GridLayout(nr, nc), n
end

function layout_args{I<:Integer}(sztup::NTuple{2,I})
    nr, nc = sztup
    GridLayout(nr, nc), nr*nc
end

function layout_args{I<:Integer}(sztup::NTuple{3,I})
    n, nr, nc = sztup
    nr, nc = compute_gridsize(n, nr, nc)
    GridLayout(nr, nc), n
end

# compute number of subplots
function layout_args(layout::GridLayout)
    # recursively get the size of the grid
    n = calc_num_subplots(layout)
    layout, n
end

layout_args(huh) = error("unhandled layout type $(typeof(huh)): $huh")


# ----------------------------------------------------------------------


function build_layout(args...)
    layout, n = layout_args(args...)
    build_layout(layout, n)
end

# # just a single subplot
# function build_layout(sp::Subplot, n::Integer)
#     sp, Subplot[sp], SubplotMap(gensym() => sp)
# end

# n is the number of subplots... build a grid and initialize the inner subplots recursively
function build_layout(layout::GridLayout, n::Integer)
    nr, nc = size(layout)
    subplots = Subplot[]
    spmap = SubplotMap()
    i = 0
    for r=1:nr, c=1:nc
        l = layout[r,c]
        if isa(l, EmptyLayout) && !get(l.attr, :blank, false)
            sp = Subplot(backend(), parent=layout)
            layout[r,c] = sp
            push!(subplots, sp)
            spmap[attr(l,:label,gensym())] = sp
            if get(l.attr, :width, :auto) != :auto
                layout.widths[c] = attr(l,:width)
            end
            if get(l.attr, :height, :auto) != :auto
                layout.heights[r] = attr(l,:height)
            end
            i += 1
        elseif isa(l, GridLayout)
            # sub-grid
            if get(l.attr, :width, :auto) != :auto
                layout.widths[c] = attr(l,:width)
            end
            if get(l.attr, :height, :auto) != :auto
                layout.heights[r] = attr(l,:height)
            end
            l, sps, m = build_layout(l, n-i)
            append!(subplots, sps)
            merge!(spmap, m)
            i += length(sps)
        elseif isa(l, Subplot)
            error("Subplot exists. Cannot re-use existing layout.  Please make a new one.")
        end
        i >= n && break  # only add n subplots
    end

    layout, subplots, spmap
end

# build a layout from a list of existing Plot objects
# TODO... much of the logic overlaps with the method above... can we merge?
function build_layout(layout::GridLayout, numsp::Integer, plts::AVec{Plot})
    nr, nc = size(layout)
    subplots = Subplot[]
    spmap = SubplotMap()
    i = 0
    for r=1:nr, c=1:nc
        l = layout[r,c]
        if isa(l, EmptyLayout) && !get(l.attr, :blank, false)
            plt = shift!(plts)  # grab the first plot out of the list
            layout[r,c] = plt.layout
            append!(subplots, plt.subplots)
            merge!(spmap, plt.spmap)
            if get(l.attr, :width, :auto) != :auto
                layout.widths[c] = attr(l,:width)
            end
            if get(l.attr, :height, :auto) != :auto
                layout.heights[r] = attr(l,:height)
            end
            i += length(plt.subplots)
        elseif isa(l, GridLayout)
            # sub-grid
            if get(l.attr, :width, :auto) != :auto
                layout.widths[c] = attr(l,:width)
            end
            if get(l.attr, :height, :auto) != :auto
                layout.heights[r] = attr(l,:height)
            end
            l, sps, m = build_layout(l, numsp-i, plts)
            append!(subplots, sps)
            merge!(spmap, m)
            i += length(sps)
        end
        i >= numsp && break  # only add n subplots
    end
    layout, subplots, spmap
end


# ----------------------------------------------------------------------
# @layout macro

function add_layout_pct!(kw::KW, v::Expr, idx::Integer, nidx::Integer)
    # dump(v)
    # something like {0.2w}?
    if v.head == :call && v.args[1] == :*
        num = v.args[2]
        if length(v.args) == 3 && isa(num, Number)
            units = v.args[3]
            if units == :h
                return kw[:h] = num*pct
            elseif units == :w
                return kw[:w] = num*pct
            elseif units in (:pct, :px, :mm, :cm, :inch)
                idx == 1 && (kw[:w] = v)
                (idx == 2 || nidx == 1) && (kw[:h] = v)
                # return kw[idx == 1 ? :w : :h] = v
            end
        end
    end
    error("Couldn't match layout curly (idx=$idx): $v")
end

function add_layout_pct!(kw::KW, v::Number, idx::Integer)
    # kw[idx == 1 ? :w : :h] = v*pct
    idx == 1 && (kw[:w] = v*pct)
    (idx == 2 || nidx == 1) && (kw[:h] = v*pct)
end

isrow(v) = isa(v, Expr) && v.head in (:hcat,:row)
iscol(v) = isa(v, Expr) && v.head == :vcat
rowsize(v) = isrow(v) ? length(v.args) : 1


function create_grid(expr::Expr)
    if iscol(expr)
        create_grid_vcat(expr)
    elseif isrow(expr)
        :(let cell = GridLayout(1, $(length(expr.args)))
            $([:(cell[1,$i] = $(create_grid(v))) for (i,v) in enumerate(expr.args)]...)
            cell
        end)

    elseif expr.head == :curly
        create_grid_curly(expr)
    else
        # if it's something else, just return that (might be an existing layout?)
        esc(expr)
    end
end

function create_grid_vcat(expr::Expr)
    rowsizes = map(rowsize, expr.args)
    rmin, rmax = _extrema(rowsizes)
    if rmin > 0 && rmin == rmax
        # we have a grid... build the whole thing
        # note: rmin is the number of columns
        nr = length(expr.args)
        nc = rmin
        body = Expr(:block)
        for r=1:nr
            arg = expr.args[r]
            if isrow(arg)
                for (c,item) in enumerate(arg.args)
                    push!(body.args, :(cell[$r,$c] = $(create_grid(item))))
                end
            else
                push!(body.args, :(cell[$r,1] = $(create_grid(arg))))
            end
        end
        :(let cell = GridLayout($nr, $nc)
            $body
            cell
        end)
    else
        # otherwise just build one row at a time
        :(let cell = GridLayout($(length(expr.args)), 1)
            $([:(cell[$i,1] = $(create_grid(v))) for (i,v) in enumerate(expr.args)]...)
            cell
        end)
    end
end

function create_grid_curly(expr::Expr)
    kw = KW()
    for (i,arg) in enumerate(expr.args[2:end])
        add_layout_pct!(kw, arg, i, length(expr.args)-1)
    end
    s = expr.args[1]
    if isa(s, Expr) && s.head == :call && s.args[1] == :grid
        create_grid(:(grid($(s.args[2:end]...), width = $(get(kw, :w, QuoteNode(:auto))), height = $(get(kw, :h, QuoteNode(:auto))))))
    elseif isa(s, Symbol)
        :(EmptyLayout(label = $(QuoteNode(s)), width = $(get(kw, :w, QuoteNode(:auto))), height = $(get(kw, :h, QuoteNode(:auto)))))
    else
        error("Unknown use of curly brackets: $expr")
    end
end

function create_grid(s::Symbol)
    :(EmptyLayout(label = $(QuoteNode(s)), blank = $(s == :_)))
end

macro layout(mat::Expr)
    create_grid(mat)
end


# -------------------------------------------------------------------------

# make all reference the same axis extrema/values.
# merge subplot lists.
function link_axes!(axes::Axis...)
    a1 = axes[1]
    for i=2:length(axes)
        a2 = axes[i]
        expand_extrema!(a1, _extrema(a2))
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
        elseif isa(l, GridLayout) && size(l) == (1,1)
            push!(subplots, l[1,1])
        end
    end
    subplots
end

# for some vector or matrix of layouts, filter only the Subplots and link those axes
function link_axes!(a::AbstractArray{AbstractLayout}, axissym::Symbol)
    subplots = link_subplots(a, axissym)
    axes = [sp.attr[axissym] for sp in subplots]
    if length(axes) > 0
        link_axes!(axes...)
    end
end

# don't do anything for most layout types
function link_axes!(l::AbstractLayout, link::Symbol)
end

# process a GridLayout, recursively linking axes according to the link symbol
function link_axes!(layout::GridLayout, link::Symbol)
    nr, nc = size(layout)
    if link in (:x, :both)
        for c=1:nc
            link_axes!(layout.grid[:,c], :xaxis)
        end
    end
    if link in (:y, :both)
        for r=1:nr
            link_axes!(layout.grid[r,:], :yaxis)
        end
    end
    if link == :square
        sps = filter(l -> isa(l, Subplot), layout.grid)
        if !isempty(sps)
            base_axis = sps[1][:xaxis]
            for sp in sps
                link_axes!(base_axis, sp[:xaxis])
                link_axes!(base_axis, sp[:yaxis])
            end
        end
    end
    if link == :all
        link_axes!(layout.grid, :xaxis)
        link_axes!(layout.grid, :yaxis)
    end
    for l in layout.grid
        link_axes!(l, link)
    end
end

# -------------------------------------------------------------------------

"Adds a new, empty subplot overlayed on top of `sp`, with a mirrored y-axis and linked x-axis."
function twinx(sp::Subplot)
    sp[:right_margin] = max(sp[:right_margin], 30px)
    plot!(sp.plt, inset = (sp[:subplot_index], bbox(0,0,1,1)))
    twinsp = sp.plt.subplots[end]
    twinsp[:yaxis][:mirror] = true
    twinsp[:background_color_inside] = RGBA{Float64}(0,0,0,0)
    link_axes!(sp[:xaxis], twinsp[:xaxis])
    twinsp
end

twinx(plt::Plot = current()) = twinx(plt[1])
