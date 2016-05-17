
typealias AVec AbstractVector
typealias AMat AbstractMatrix

immutable PlotsDisplay <: Display end

abstract AbstractBackend
abstract AbstractPlot{T<:AbstractBackend}

typealias KW Dict{Symbol,Any}

immutable InputWrapper{T}
    obj::T
end

wrap{T}(obj::T) = InputWrapper{T}(obj)
Base.isempty(wrapper::InputWrapper) = false

# -----------------------------------------------------------
# Axes
# -----------------------------------------------------------

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
type Axis #<: Associative{Symbol,Any}
    d::KW
end

type AxisView
    label::UTF8String
    axis::Axis
end


# -----------------------------------------------------------
# Layouts
# -----------------------------------------------------------

# NOTE: (0,0) is the top-left !!!

import Measures
import Measures: Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height
export BBox, BoundingBox, mm, cm, inch, pt, px, pct

typealias BBox Measures.Absolute2DBox

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct, Float64}(1.0)

Base.(:+)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 + m2.value))
Base.(:+)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (1 + m1.value))
Base.(:-)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * (1 - m2.value))
Base.(:-)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * (m1.value - 1))
Base.(:*)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.(:*)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.(:/)(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.(:/)(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)

const defaultbox = BoundingBox(0mm, 0mm, 0mm, 0mm)

# left(bbox::BoundingBox) = bbox.left
# bottom(bbox::BoundingBox) = bbox.bottom
# right(bbox::BoundingBox) = bbox.right
# top(bbox::BoundingBox) = bbox.top
# width(bbox::BoundingBox) = bbox.right - bbox.left
# height(bbox::BoundingBox) = bbox.top - bbox.bottom



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

    # if width(bb1) <= 0mm || height(bb1) <= 0mm
    #     return bb2
    # elseif width(bb2) <= 0mm || height(bb2) <= 0mm
    #     return bb1
    # end
    l = min(left(bb1), left(bb2))
    b = min(bottom(bb1), bottom(bb2))
    r = max(right(bb1), right(bb2))
    t = max(top(bb1), top(bb2))
    BoundingBox(l, t, r-l, t-b)
end

# this creates a bounding box in the parent's scope, where the child bounding box
# is relative to the parent
function crop(parent::BoundingBox, child::BoundingBox)
    # l = left(parent) + width(parent) * left(child)
    # b = bottom(parent) + height(parent) * bottom(child)
    # w = width(parent) * width(child)
    # h = height(parent) * height(child)
    l = left(parent) + left(child)
    t = top(parent) + top(child)
    w = width(child)
    h = height(child)
    BoundingBox(l, t, w, h)
end

function Base.show(io::IO, bbox::BoundingBox)
    print(io, "BBox{l,t,r,b,w,h = $(left(bbox)),$(top(bbox)), $(right(bbox)),$(bottom(bbox)), $(width(bbox)),$(height(bbox))}")
end

# -----------------------------------------------------------

abstract AbstractLayout

width(layout::AbstractLayout) = width(layout.bbox)
height(layout::AbstractLayout) = height(layout.bbox)

# -----------------------------------------------------------

# contains blank space
type EmptyLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
end
EmptyLayout(parent = RootLayout()) = EmptyLayout(parent, defaultbox)

# this is the parent of the top-level layout
immutable RootLayout <: AbstractLayout
    # child::AbstractLayout
end

# -----------------------------------------------------------

# a single subplot
type Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox  # the canvas area which is available to this subplot
    plotarea::BoundingBox  # the part where the data goes
    subplotargs::KW  # args specific to this subplot
    # axisviews::Vector{AxisView}
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)

    # Subplot(parent = RootLayout(); attr = KW())
end

function Subplot{T<:AbstractBackend}(::T; parent = RootLayout())
    Subplot{T}(parent, defaultbox, KW(), nothing)
end

# -----------------------------------------------------------

# TODO: i'll want a plotarea! method to set the plotarea only if the field exists

# nested, gridded layout with optional size percentages
type GridLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
    grid::Matrix{AbstractLayout} # Nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    widths::Vector{Measure}
    heights::Vector{Measure}
    attr::KW
end

function GridLayout(dims...;
                    parent = RootLayout(),
                    widths = ones(dims[2]),
                    heights = ones(dims[1]),
                    kw...)
    grid = Matrix{AbstractLayout}(dims...)
    layout = GridLayout(
        parent,
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


# -----------------------------------------------------------

typealias SubplotMap Dict{Any, Subplot}

# -----------------------------------------------------------
# Plot
# -----------------------------------------------------------

type Series
    d::KW
end

type Plot{T<:AbstractBackend} <: AbstractPlot{T}
    backend::T               # the backend type
    n::Int                   # number of series
    plotargs::KW             # arguments for the whole plot
    series_list::Vector{Series}   # arguments for each series
    o  # the backend's plot object
    subplots::Vector{Subplot}
    spmap::SubplotMap  # provide any label as a map to a subplot
    layout::AbstractLayout
end

function Plot()
    Plot(backend(), 0, KW(), Series[], nothing,
         Subplot[], SubplotMap(), EmptyLayout())
end

# -----------------------------------------------------------
# Subplot
# -----------------------------------------------------------

# type Subplot{T<:AbstractBackend, L<:AbstractLayout} <: AbstractPlot{T}
#     o                           # the underlying object
#     plts::Vector{Plot{T}}       # the individual plots
#     backend::T
#     p::Int                      # number of plots
#     n::Int                      # number of series
#     layout::L
#     plotargs::KW
#     initialized::Bool
#     linkx::Bool
#     linky::Bool
#     linkfunc::Function # maps (row,column) -> (BoolOrNothing, BoolOrNothing)... if xlink/ylink are nothing, then use subplt.linkx/y
# end

# -----------------------------------------------------------------------
