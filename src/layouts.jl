
# NOTE: (0,0) is the top-left !!!

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct, Float64}(1.0)

const _cbar_width = 5mm

Base.(:.*)(m::Measure, n::Number) = m * n
Base.(:.*)(n::Number, m::Measure) = m * n
Base.(:-)(m::Measure, a::AbstractArray) = map(ai -> m - ai, a)
Base.(:-)(a::AbstractArray, m::Measure) = map(ai -> ai - m, a)
Base.zero(::Type{typeof(mm)}) = 0mm
Base.one(::Type{typeof(mm)}) = 1mm
Base.typemin(::typeof(mm)) = -Inf*mm
Base.typemax(::typeof(mm)) = Inf*mm
Base.convert{F<:AbstractFloat}(::Type{F}, l::AbsoluteLength) = convert(F, l.value)

Base.(:+)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 + m2.value))
Base.(:+)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (1 + m1.value))
Base.(:-)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 - m2.value))
Base.(:-)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (m1.value - 1))
Base.(:*)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.(:*)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.(:/)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.(:/)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)


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

# Base.(:*){T,N}(m1::Length{T,N}, m2::Length{T,N}) = Length{T,N}(m1.value * m2.value)
ispositive(m::Measure) = m.value > 0

# union together bounding boxes
function Base.(:+)(bb1::BoundingBox, bb2::BoundingBox)
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
# AbstractLayout

Base.show(io::IO, layout::AbstractLayout) = print(io, "$(typeof(layout))$(size(layout))")

# this is the available area for drawing everything in this layout... as percentages of total canvas
bbox(layout::AbstractLayout) = layout.bbox
bbox!(layout::AbstractLayout, bb::BoundingBox) = (layout.bbox = bb)

# layouts are recursive, tree-like structures, and most will have a parent field
Base.parent(layout::AbstractLayout) = layout.parent
parent_bbox(layout::AbstractLayout) = bbox(parent(layout))

# NOTE: these should be implemented for subplots in each backend!
# they represent the minimum size of the axes and guides
min_padding_left(layout::AbstractLayout)   = 0mm
min_padding_top(layout::AbstractLayout)    = 0mm
min_padding_right(layout::AbstractLayout)  = 0mm
min_padding_bottom(layout::AbstractLayout) = 0mm

padding_w(layout::AbstractLayout) = left_padding(layout) + right_padding(layout)
padding_h(layout::AbstractLayout) = bottom_padding(layout) + top_padding(layout)
padding(layout::AbstractLayout) = (padding_w(layout), padding_h(layout))

_update_position!(layout::AbstractLayout) = nothing
update_child_bboxes!(layout::AbstractLayout) = nothing

width(layout::AbstractLayout) = width(layout.bbox)
height(layout::AbstractLayout) = height(layout.bbox)

plotarea(layout::AbstractLayout) = defaultbox
plotarea!(layout::AbstractLayout, bbox::BoundingBox) = nothing

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
                    widths = ones(dims[2]),
                    heights = ones(dims[1]),
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
    fill!(grid, EmptyLayout(layout))
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


function _update_position!(layout::GridLayout)
    map(_update_position!, layout.grid)
end


# recursively compute the bounding boxes for the layout and plotarea (relative to canvas!)
function update_child_bboxes!(layout::GridLayout)
    nr, nc = size(layout)

    # create a matrix for each minimum padding direction
    _update_min_padding!(layout)

    minpad_left   = map(leftpad,   layout.grid)
    minpad_top    = map(toppad,    layout.grid)
    minpad_right  = map(rightpad,  layout.grid)
    minpad_bottom = map(bottompad, layout.grid)
    # @show minpad_left minpad_top minpad_right minpad_bottom

    # get the max horizontal (left and right) padding over columns,
    # and max vertical (bottom and top) padding over rows
    # TODO: add extra padding here
    pad_left   = maximum(minpad_left,   1)
    pad_top    = maximum(minpad_top,    2)
    pad_right  = maximum(minpad_right,  1)
    pad_bottom = maximum(minpad_bottom, 2)
    # @show pad_left pad_top pad_right pad_bottom

    # scale this up to the total padding in each direction
    total_pad_horizontal = sum(pad_left + pad_right)
    total_pad_vertical   = sum(pad_top + pad_bottom)
    # @show total_pad_horizontal total_pad_vertical

    # now we can compute the total plot area in each direction
    total_plotarea_horizontal = width(layout)  - total_pad_horizontal
    total_plotarea_vertical   = height(layout) - total_pad_vertical
    # @show total_plotarea_horizontal total_plotarea_vertical

    # normalize widths/heights so they sum to 1
    denom_w = sum(layout.widths)
    denom_h = sum(layout.heights)
    # @show layout.widths layout.heights denom_w, denom_h

    # we have all the data we need... lets compute the plot areas and set the bounding boxes
    for r=1:nr, c=1:nc
        child = layout[r,c]

        # get the top-left corner of this child... the first one is top-left of the parent (i.e. layout)
        child_left = (c == 1 ? left(layout.bbox) : right(layout[r, c-1].bbox))
        child_top  = (r == 1 ? top(layout.bbox) : bottom(layout[r-1, c].bbox))

        # compute plot area
        plotarea_left   = child_left + pad_left[c]
        plotarea_top    = child_top + pad_top[r]
        plotarea_width  = total_plotarea_horizontal * layout.widths[c] / denom_w
        plotarea_height = total_plotarea_vertical * layout.heights[r] / denom_h
        plotarea!(child, BoundingBox(plotarea_left, plotarea_top, plotarea_width, plotarea_height))

        # compute child bbox
        child_width  = pad_left[c] + plotarea_width + pad_right[c]
        child_height = pad_top[r] + plotarea_height + pad_bottom[r]
        bbox!(child, BoundingBox(child_left, child_top, child_width, child_height))

        # recursively update the child's children
        update_child_bboxes!(child)
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
function build_layout(d::KW)
    build_layout(get(d, :layout, default(:layout)))
end

function build_layout(n::Integer)
    nr, nc = compute_gridsize(n, -1, -1)
    build_layout(GridLayout(nr, nc), n)
end

function build_layout{I<:Integer}(sztup::NTuple{2,I})
    nr, nc = sztup
    build_layout(GridLayout(nr, nc))
end

function build_layout{I<:Integer}(sztup::NTuple{3,I})
    n, nr, nc = sztup
    nr, nc = compute_gridsize(n, nr, nc)
    build_layout(GridLayout(nr, nc), n)
end

# compute number of subplots
function build_layout(layout::GridLayout)
    # nr, nc = size(layout)
    # build_layout(layout, nr*nc)

    # recursively get the size of the grid
    n = calc_num_subplots(layout)
    build_layout(layout, n)
end

# n is the number of subplots
function build_layout(layout::GridLayout, n::Integer)
    nr, nc = size(layout)
    subplots = Subplot[]
    spmap = SubplotMap()
    i = 0
    for r=1:nr, c=1:nc
        l = layout[r,c]
        if isa(l, EmptyLayout)
            sp = Subplot(backend(), parent=layout)
            layout[r,c] = sp
            push!(subplots, sp)
            spmap[attr(l,:label,gensym())] = sp
            if hasattr(l,:width)
                layout.widths[c] = attr(l,:width)
            end
            if hasattr(l,:height)
                layout.heights[r] = attr(l,:height)
            end
            i += 1
        elseif isa(l, GridLayout)
            # sub-grid
            l, sps, m = build_layout(l, n-i)
            append!(subplots, sps)
            merge!(spmap, m)
            i += length(sps)
        end
        i >= n && break  # only add n subplots
    end
    layout, subplots, spmap
end

build_layout(huh) = error("unhandled layout type $(typeof(huh)): $huh")

# ----------------------------------------------------------------------
# @layout macro

function create_grid(expr::Expr)
    cellsym = gensym(:cell)
    constructor = if expr.head == :vcat
        :(let
            $cellsym = GridLayout($(length(expr.args)), 1)
            $([:($cellsym[$i,1] = $(create_grid(expr.args[i]))) for i=1:length(expr.args)]...)
            $cellsym
        end)
    elseif expr.head in (:hcat,:row)
        :(let
            $cellsym = GridLayout(1, $(length(expr.args)))
            $([:($cellsym[1,$i] = $(create_grid(expr.args[i]))) for i=1:length(expr.args)]...)
            $cellsym
        end)

    elseif expr.head == :curly
        length(expr.args) == 3 || error("Should be width and height in curly. Got: ", expr.args)
        s,w,h = expr.args
        :(EmptyLayout(label = $(QuoteNode(s)), width = $w, height = $h))

    else
        # if it's something else, just return that (might be an existing layout?)
        expr
    end
end

function create_grid(s::Symbol)
    :(EmptyLayout(label = $(QuoteNode(s))))
end

macro layout(mat::Expr)
    create_grid(mat)
end
