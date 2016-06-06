
# TODO: I declare lots of types here because of the lacking ability to do forward declarations in current Julia
# I should move these to the relevant files when something like "extern" is implemented

typealias AVec AbstractVector
typealias AMat AbstractMatrix
typealias KW Dict{Symbol,Any}

immutable PlotsDisplay <: Display end

abstract AbstractBackend
abstract AbstractPlot{T<:AbstractBackend}
abstract AbstractLayout

# -----------------------------------------------------------

immutable InputWrapper{T}
    obj::T
end
wrap{T}(obj::T) = InputWrapper{T}(obj)
Base.isempty(wrapper::InputWrapper) = false


# -----------------------------------------------------------

# a single subplot
type Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox  # the canvas area which is available to this subplot
    plotarea::BoundingBox  # the part where the data goes
    attr::KW  # args specific to this subplot
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)
end

# -----------------------------------------------------------

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
type Axis
    sp::Subplot
    d::KW
end

type Extrema
    emin::Float64
    emax::Float64
end
Extrema() = Extrema(Inf, -Inf)

# -----------------------------------------------------------

typealias SubplotMap Dict{Any, Subplot}

# -----------------------------------------------------------

type Series
    d::KW
end

attr(series::Series, k::Symbol) = series.d[k]
attr!(series::Series, v, k::Symbol) = (series.d[k] = v)

# -----------------------------------------------------------

type Plot{T<:AbstractBackend} <: AbstractPlot{T}
    backend::T                   # the backend type
    n::Int                       # number of series
    attr::KW                     # arguments for the whole plot
    user_attr::KW                # raw arg inputs (after aliases).  these are used as the input dict in `_plot!`
    series_list::Vector{Series}  # arguments for each series
    o                            # the backend's plot object
    subplots::Vector{Subplot}
    spmap::SubplotMap            # provide any label as a map to a subplot
    layout::AbstractLayout
    init::Bool
end

function Plot()
    Plot(backend(), 0, KW(), KW(), Series[], nothing,
         Subplot[], SubplotMap(), EmptyLayout(), false)
end

# TODO: make a decision... should plt[1] return the first subplot or the first series??
# Base.getindex(plt::Plot, i::Integer) = plt.subplots[i]
Base.getindex(plt::Plot, s::Symbol) = plt.spmap[s]
Base.getindex(plt::Plot, r::Integer, c::Integer) = plt.layout[r,c]
attr(plt::Plot, k::Symbol) = plt.attr[k]
attr!(plt::Plot, v, k::Symbol) = (plt.attr[k] = v)


# -----------------------------------------------------------------------
