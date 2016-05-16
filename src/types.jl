
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

abstract AbstractLayout

# -----------------------------------------------------------

# contains blank space
immutable EmptyLayout <: AbstractLayout end

# this is the parent of the top-level layout
immutable RootLayout <: AbstractLayout
    # child::AbstractLayout
end

# -----------------------------------------------------------

# a single subplot
type Subplot <: AbstractLayout
    parent::AbstractLayout
    attr::KW  # args specific to this subplot
    # axisviews::Vector{AxisView}
    o  # can store backend-specific data... like a pyplot ax

    # Subplot(parent = RootLayout(); attr = KW())
end

Subplot() = Subplot(RootLayout(), KW(), nothing)

# -----------------------------------------------------------

# nested, gridded layout with optional size percentages
immutable GridLayout <: AbstractLayout
    parent::AbstractLayout
    grid::Matrix{AbstractLayout} # Nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    # widths::Vector{Float64}
    # heights::Vector{Float64}
    attr::KW
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
    o                        # the backend's plot object
    backend::T               # the backend type
    n::Int                   # number of series
    plotargs::KW             # arguments for the whole plot
    # seriesargs::Vector{KW}   # arguments for each series
    series_list::Vector{Series}   # arguments for each series
    subplots::Vector{Subplot}
    subplot_map::SubplotMap  # provide any label as a map to a subplot
    layout::AbstractLayout
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
