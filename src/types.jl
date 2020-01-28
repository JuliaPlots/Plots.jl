
# TODO: I declare lots of types here because of the lacking ability to do forward declarations in current Julia
# I should move these to the relevant files when something like "extern" is implemented

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}
const TicksArgs = Union{AVec{T}, Tuple{AVec{T}, AVec{S}}, Symbol} where {T<:Real, S<:AbstractString}

struct PlotsDisplay <: AbstractDisplay end

# -----------------------------------------------------------

struct InputWrapper{T}
    obj::T
end
wrap(obj::T) where {T} = InputWrapper{T}(obj)
Base.isempty(wrapper::InputWrapper) = false


# -----------------------------------------------------------

struct Attr <: AbstractDict{Symbol,Any}
    explicit::KW
    defaults::KW
end

Base.getindex(attr::Attr, k) = haskey(attr.explicit,k) ?
                                     attr.explicit[k] : attr.defaults[k]
Base.haskey(attr::Attr, k) = haskey(attr.explicit,k) || haskey(attr.defaults,k)
Base.get(attr::Attr, k, default) = haskey(attr, k) ? attr[k] : default
Base.length(attr::Attr) = length(union(keys(attr.explicit), keys(attr.defaults)))
function Base.iterate(attr::Attr)
    exp_keys = keys(attr.explicit)
    def_keys = setdiff(keys(attr.defaults), exp_keys)
    key_list = collect(Iterators.flatten((exp_keys, def_keys)))
    iterate(attr, (key_list, 1))
end
function Base.iterate(attr::Attr, (key_list, i))
    i > length(key_list) && return nothing
    k = key_list[i]
    (k=>attr[k], (key_list, i+1))
end

Base.copy(attr::Attr) = Attr(copy(attr.explicit), attr.defaults)

RecipesBase.is_explicit(attr::Attr, k) = haskey(attr.explicit,k)
isdefault(attr::Attr, k) = !is_explicit(attr,k) && haskey(attr.defaults,k)

Base.setindex!(attr::Attr, v, k) = attr.explicit[k] = v

# Reset to default value and return dict
reset_kw!(attr::Attr, k) = is_explicit(attr, k) ? delete!(attr.explicit, k) : attr
# Reset to default value and return old value
pop_kw!(attr::Attr, k) = is_explicit(attr, k) ? pop!(attr.explicit, k) : attr.defaults[k]
pop_kw!(attr::Attr, k, default) = is_explicit(attr, k) ? pop!(attr.explicit, k) : get(attr.defaults, k, default)
# Fallbacks for dicts without defaults
reset_kw!(d::AKW, k) = delete!(d, k)
pop_kw!(d::AKW, k) = pop!(d, k)
pop_kw!(d::AKW, k, default) = pop!(d, k, default)

# -----------------------------------------------------------

mutable struct Series
    plotattributes::Attr
end

attr(series::Series, k::Symbol) = series.plotattributes[k]
attr!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)

# -----------------------------------------------------------

# a single subplot
mutable struct Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    series_list::Vector{Series}  # arguments for each series
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox  # the canvas area which is available to this subplot
    plotarea::BoundingBox  # the part where the data goes
    attr::Attr  # args specific to this subplot
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)
end

Base.show(io::IO, sp::Subplot) = print(io, "Subplot{$(sp[:subplot_index])}")

# -----------------------------------------------------------

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
mutable struct Axis
    sps::Vector{Subplot}
    plotattributes::Attr
end

mutable struct Extrema
    emin::Float64
    emax::Float64
end
Extrema() = Extrema(Inf, -Inf)

# -----------------------------------------------------------

const SubplotMap = Dict{Any, Subplot}

# -----------------------------------------------------------


mutable struct Plot{T<:AbstractBackend} <: AbstractPlot{T}
    backend::T                   # the backend type
    n::Int                       # number of series
    attr::Attr            # arguments for the whole plot
    series_list::Vector{Series}  # arguments for each series
    o                            # the backend's plot object
    subplots::Vector{Subplot}
    spmap::SubplotMap            # provide any label as a map to a subplot
    layout::AbstractLayout
    inset_subplots::Vector{Subplot}  # list of inset subplots
    init::Bool
end

function Plot()
    Plot(backend(), 0, Attr(KW(), _plot_defaults), Series[], nothing,
         Subplot[], SubplotMap(), EmptyLayout(),
         Subplot[], false)
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
