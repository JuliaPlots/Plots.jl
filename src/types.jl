
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

# wraps bounding box coords (percent of parent area)
# NOTE: (0,0) is the bottom-left, and (1,1) is the top-right!
immutable BoundingBox
    left::Float64
    bottom::Float64
    right::Float64
    top::Float64
end
BoundingBox() = BoundingBox(0,0,0,0)

# -----------------------------------------------------------

abstract AbstractLayout

# -----------------------------------------------------------

# contains blank space
type EmptyLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
end
EmptyLayout(parent = RootLayout()) = EmptyLayout(parent, BoundingBox(0,0,1,1))

# this is the parent of the top-level layout
immutable RootLayout <: AbstractLayout
    # child::AbstractLayout
end

# -----------------------------------------------------------

# a single subplot
type Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox  # the canvas area which is available to this subplot
    subplotargs::KW  # args specific to this subplot
    # axisviews::Vector{AxisView}
    o  # can store backend-specific data... like a pyplot ax

    # Subplot(parent = RootLayout(); attr = KW())
end

function Subplot{T<:AbstractBackend}(::T; parent = RootLayout())
    Subplot{T}(parent, BoundingBox(0,0,1,1), KW(), nothing)
end

# -----------------------------------------------------------

# nested, gridded layout with optional size percentages
type GridLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
    grid::Matrix{AbstractLayout} # Nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    widths::Vector{Float64}
    heights::Vector{Float64}
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
        BoundingBox(0,0,1,1),
        grid,
        convert(Vector{Float64}, widths),
        convert(Vector{Float64}, heights),
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
