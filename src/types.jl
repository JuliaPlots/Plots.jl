
# TODO: I declare lots of types here because of the lacking ability to do forward declarations in current Julia
# I should move these to the relevant files when something like "extern" is implemented

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const TicksArgs = Union{AVec{T}, Tuple{AVec{T}, AVec{S}}, Symbol} where {T<:Real, S<:AbstractString}

struct PlotsDisplay <: AbstractDisplay end

# -----------------------------------------------------------

struct InputWrapper{T}
    obj::T
end
wrap(obj::T) where {T} = InputWrapper{T}(obj)
Base.isempty(wrapper::InputWrapper) = false


# -----------------------------------------------------------

mutable struct Series
    plotattributes::KW
end

attr(series::Series, k::Symbol) = series.plotattributes[k]
attr!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)

# -----------------------------------------------------------

# a single subplot
mutable struct Subplot{T<:AbstractBackend} <: AbstractLayout
    parent
    series_list::Vector{Series}  # arguments for each series
    minpad::Tuple{AbsoluteLength,AbsoluteLength,AbsoluteLength,AbsoluteLength} # leftpad, toppad, rightpad, bottompad
    bbox#::BoundingBox  # the canvas area which is available to this subplot
    plotarea#::BoundingBox  # the part where the data goes
    attr::KW  # args specific to this subplot
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)
end

Base.show(io::IO, sp::Subplot) = print(io, "Subplot{$(sp[:subplot_index])}")

# -----------------------------------------------------------

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
mutable struct Axis
    sps::Vector{Subplot}
    plotattributes::KW
end

mutable struct Extrema
    emin::Float64
    emax::Float64
end
Extrema() = Extrema(Inf, -Inf)

# -----------------------------------------------------------


mutable struct Plot{T<:AbstractBackend} <: AbstractPlot{T}
    backend::T                   # the backend type
    n::Int                       # number of series
    attr::KW                     # arguments for the whole plot
    user_attr::KW                # raw arg inputs (after aliases).  these are used as the input dict in `_plot!`
    series_list::Vector{Series}  # arguments for each series
    o                            # the backend's plot object
    subplots::Vector{Subplot{T}}
    spmap::KW            # provide any label as a map to a subplot
    layout
    inset_subplots::Vector{Subplot{T}}  # list of inset subplots
    init::Bool
end

function Plot(_backend = CURRENT_BACKEND)
    Plot(_backend.pkg, 0, KW(), KW(), Series[], nothing,
         Subplot{typeof(_backend.pkg)}[], KW(), EmptyLayout(),
         Subplot{typeof(_backend.pkg)}[], false)
end

# -----------------------------------------------------------------------

Base.getindex(plt::Plot, i::Integer) = plt.subplots[i]
Base.length(plt::Plot) = length(plt.subplots)
Base.lastindex(plt::Plot) = length(plt)

Base.getindex(plt::Plot, r::Integer, c::Integer) = plt.layout[r,c]
Base.size(plt::Plot) = size(plt.layout)
Base.size(plt::Plot, i::Integer) = size(plt.layout)[i]
Base.ndims(plt::Plot) = 2

# attr(plt::Plot, k::Symbol) = plt.attr[k]
# attr!(plt::Plot, v, k::Symbol) = (plt.attr[k] = v)

Base.getindex(sp::Subplot, i::Integer) = series_list(sp)[i]
Base.lastindex(sp::Subplot) = length(series_list(sp))

# -----------------------------------------------------------------------
