module Measurements

export GridLayout, EmptyLayout, RootLayout
export leftpad, toppad, bottompad, rightpad
export origin, left, right, bottom, top
export bbox, bbox!, bbox_to_pcts, xy_mm_to_pcts
export Length, AbsoluteLength, Measure
export to_pixels, ispositive

import ..Measures
import ..Measures: Length, AbsoluteLength, Measure, BoundingBox
import ..Measures: mm, cm, inch, pt, width, height, w, h
using ..RecipesBase: AbstractLayout
using ..Commons

const BBox = Measures.Absolute2DBox
export BBox, BoundingBox, mm, cm, inch, px, pct, pt, w, h

to_pixels(m::AbsoluteLength) = m.value / 0.254

left(bbox::BoundingBox) = bbox.x0[1]
top(bbox::BoundingBox) = bbox.x0[2]
right(bbox::BoundingBox) = left(bbox) + width(bbox)
bottom(bbox::BoundingBox) = top(bbox) + height(bbox)
origin(bbox::BoundingBox) = left(bbox) + width(bbox) / 2, top(bbox) + height(bbox) / 2
Base.size(bbox::BoundingBox) = (width(bbox), height(bbox))

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
        if oarg ≡ :center
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
    left = if h_anchor ≡ :left
        x
    elseif h_anchor in (:center, :hcenter)
        0.5w - 0.5width + x
    else
        1w - x - width
    end
    top = if v_anchor ≡ :top
        y
    elseif v_anchor in (:center, :vcenter)
        0.5h - 0.5height + y
    else
        1h - y - height
    end
    BoundingBox(left, top, width, height)
end
# NOTE: (0,0) is the top-left !!!

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

left(layout::AbstractLayout) = left(bbox(layout))
top(layout::AbstractLayout) = top(bbox(layout))
right(layout::AbstractLayout) = right(bbox(layout))
bottom(layout::AbstractLayout) = bottom(bbox(layout))
width(layout::AbstractLayout) = width(bbox(layout))
height(layout::AbstractLayout) = height(bbox(layout))

leftpad(layout::AbstractLayout)   = 0mm
toppad(layout::AbstractLayout)    = 0mm
rightpad(layout::AbstractLayout)  = 0mm
bottompad(layout::AbstractLayout) = 0mm

leftpad(pad)   = pad[1]
toppad(pad)    = pad[2]
rightpad(pad)  = pad[3]
bottompad(pad) = pad[4]

Base.show(io::IO, layout::AbstractLayout) = print(io, "$(typeof(layout))$(size(layout))")

# this is the available area for drawing everything in this layout... as percentages of total canvas
bbox(layout::AbstractLayout) = layout.bbox
bbox!(layout::AbstractLayout, bb::BoundingBox) = (layout.bbox = bb)

# layouts are recursive, tree-like structures, and most will have a parent field
Base.parent(layout::AbstractLayout) = layout.parent
parent_bbox(layout::AbstractLayout) = bbox(parent(layout))

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

leftpad(layout::GridLayout)   = leftpad(layout.minpad)
toppad(layout::GridLayout)    = toppad(layout.minpad)
rightpad(layout::GridLayout)  = rightpad(layout.minpad)
bottompad(layout::GridLayout) = bottompad(layout.minpad)


function GridLayout(
    dims...;
    parent = RootLayout(),
    widths = zeros(dims[2]),
    heights = zeros(dims[1]),
    kw...,
)
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

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct,Float64}(1.0)

Base.convert(::Type{<:Measure}, x::Float64) = x * pct

Base.:*(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.:*(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.:/(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.:/(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)

inch2px(inches::Real) = float(inches * PX_PER_INCH)
px2inch(px::Real)     = float(px / PX_PER_INCH)
inch2mm(inches::Real) = float(inches * MM_PER_INCH)
mm2inch(mm::Real)     = float(mm / MM_PER_INCH)
px2mm(px::Real)       = float(px * MM_PER_PX)
mm2px(mm::Real)       = float(mm / MM_PER_PX)

end  # module
