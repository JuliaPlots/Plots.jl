
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

type AxisView
    label::UTF8String
    axis::Axis
end

type Subplot
    axisviews::Vector{AxisView}
    subplotargs::KW  # args specific to this subplot
    obj  # can store backend-specific data... like a pyplot ax
end

type Series
    d::KW
    x
    y
    z
    # subplots::Vector{Subplot}
end

function Series(d::KW)
    x = pop!(d, :x)
    y = pop!(d, :y)
    z = pop!(d, :z)
    Series(d, x, y, z)
end

# -----------------------------------------------------------
# Plot
# -----------------------------------------------------------

type Plot{T<:AbstractBackend} <: AbstractPlot{T}
    o                        # the backend's plot object
    backend::T               # the backend type
    n::Int                   # number of series
    plotargs::KW             # arguments for the whole plot
    # seriesargs::Vector{KW}   # arguments for each series
    series_list::Vector{Series}   # arguments for each series
    subplots::Vector{Subplot}
end

# -----------------------------------------------------------
# Layout
# -----------------------------------------------------------

abstract SubplotLayout

# -----------------------------------------------------------
# Subplot
# -----------------------------------------------------------

# type Subplot{T<:AbstractBackend, L<:SubplotLayout} <: AbstractPlot{T}
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
