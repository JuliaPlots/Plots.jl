# # Utilities

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol, Any}
const AKW = AbstractDict{Symbol, Any}

# --------------------------------
# ## DefaultsDict
# --------------------------------

struct DefaultsDict <: AbstractDict{Symbol, Any}
    explicit::KW
    defaults::KW
end

function Base.getindex(dd::DefaultsDict, k)
    return haskey(dd.explicit, k) ? dd.explicit[k] : dd.defaults[k]
end
Base.haskey(dd::DefaultsDict, k) = haskey(dd.explicit, k) || haskey(dd.defaults, k)
Base.get(dd::DefaultsDict, k, default) = haskey(dd, k) ? dd[k] : default
function Base.get!(dd::DefaultsDict, k, default)
    v = if haskey(dd, k)
        dd[k]
    else
        dd.defaults[k] = default
    end
    return v
end
function Base.delete!(dd::DefaultsDict, k)
    haskey(dd.explicit, k) && delete!(dd.explicit, k)
    haskey(dd.defaults, k) && delete!(dd.defaults, k)
end
Base.length(dd::DefaultsDict) = length(union(keys(dd.explicit), keys(dd.defaults)))
function Base.iterate(dd::DefaultsDict)
    exp_keys = keys(dd.explicit)
    def_keys = setdiff(keys(dd.defaults), exp_keys)
    key_list = collect(Iterators.flatten((exp_keys, def_keys)))
    iterate(dd, (key_list, 1))
end
function Base.iterate(dd::DefaultsDict, (key_list, i))
    i > length(key_list) && return nothing
    k = key_list[i]
    (k => dd[k], (key_list, i + 1))
end

Base.copy(dd::DefaultsDict) = DefaultsDict(copy(dd.explicit), dd.defaults)

RecipesBase.is_explicit(dd::DefaultsDict, k) = haskey(dd.explicit, k)
isdefault(dd::DefaultsDict, k) = !is_explicit(dd, k) && haskey(dd.defaults, k)

Base.setindex!(dd::DefaultsDict, v, k) = dd.explicit[k] = v

# Reset to default value and return dict
reset_kw!(dd::DefaultsDict, k) = is_explicit(dd, k) ? delete!(dd.explicit, k) : dd
# Reset to default value and return old value
pop_kw!(dd::DefaultsDict, k) = is_explicit(dd, k) ? pop!(dd.explicit, k) : dd.defaults[k]
pop_kw!(dd::DefaultsDict, k, default) =
    is_explicit(dd, k) ? pop!(dd.explicit, k) : get(dd.defaults, k, default)
# Fallbacks for dicts without defaults
reset_kw!(d::AKW, k) = delete!(d, k)
pop_kw!(d::AKW, k) = pop!(d, k)
pop_kw!(d::AKW, k, default) = pop!(d, k, default)


# --------------------------------
# ## 3D types
# --------------------------------

abstract type AbstractSurface end

"represents a contour or surface mesh"
struct Surface{M <: AMat} <: AbstractSurface
    surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi, yi) for yi in y, xi in x])

Base.Array(surf::Surface) = surf.surf

for f in (:length, :size, :axes)
    @eval Base.$f(surf::Surface, args...) = $f(surf.surf, args...)
end
Base.copy(surf::Surface) = Surface(copy(surf.surf))
Base.eltype(surf::Surface{T}) where {T} = eltype(T)


struct Volume{T}
    v::Array{T, 3}
    x_extents::Tuple{T, T}
    y_extents::Tuple{T, T}
    z_extents::Tuple{T, T}
end

default_extents(::Type{T}) where {T} = (zero(T), one(T))

function Volume(
    v::Array{T, 3},
    x_extents = default_extents(T),
    y_extents = default_extents(T),
    z_extents = default_extents(T),
) where {T}
    Volume(v, x_extents, y_extents, z_extents)
end

Base.Array(vol::Volume) = vol.v
for f in (:length, :size)
    @eval Base.$f(vol::Volume, args...) = $f(vol.v, args...)
end
Base.copy(vol::Volume{T}) where {T} =
    Volume{T}(copy(vol.v), vol.x_extents, vol.y_extents, vol.z_extents)
Base.eltype(vol::Volume{T}) where {T} = T


# --------------------------------
# ## Formatting
# --------------------------------

"Represents data values with formatting that should apply to the tick labels."
struct Formatted{T}
    data::T
    formatter::Function
end

# -------------------------------
# ## 3D seriestypes
# -------------------------------

# TODO: Move to RecipesBase?
"""
    is3d(::Type{Val{:myseriestype}})

Returns `true` if `myseriestype` represents a 3D series, `false` otherwise.
"""
is3d(st) = false
for st in (
    :contour,
    :contourf,
    :contour3d,
    :heatmap,
    :image,
    :path3d,
    :scatter3d,
    :surface,
    :volume,
    :wireframe,
)
    @eval is3d(::Type{Val{Symbol($(string(st)))}}) = true
end
is3d(st::Symbol) = is3d(Val{st})
is3d(plt, stv::AbstractArray) = all(st -> is3d(plt, st), stv)
is3d(plotattributes::AbstractDict) = is3d(get(plotattributes, :seriestype, :path))


"""
    is_surface(::Type{Val{:myseriestype}})

Returns `true` if `myseriestype` represents a surface series, `false` otherwise.
"""
is_surface(st) = false
for st in (:contour, :contourf, :contour3d, :image, :heatmap, :surface, :wireframe)
    @eval is_surface(::Type{Val{Symbol($(string(st)))}}) = true
end
is_surface(st::Symbol) = is_surface(Val{st})
is_surface(plt, stv::AbstractArray) = all(st -> is_surface(plt, st), stv)
is_surface(plotattributes::AbstractDict) =
    is_surface(get(plotattributes, :seriestype, :path))


"""
    needs_3d_axes(::Type{Val{:myseriestype}})

Returns `true` if `myseriestype` needs 3d axes, `false` otherwise.
"""
needs_3d_axes(st) = false
for st in (
    :contour3d,
    :path3d,
    :scatter3d,
    :surface,
    :volume,
    :wireframe,
)
    @eval needs_3d_axes(::Type{Val{Symbol($(string(st)))}}) = true
end
needs_3d_axes(st::Symbol) = needs_3d_axes(Val{st})
needs_3d_axes(plt, stv::AbstractArray) = all(st -> needs_3d_axes(plt, st), stv)
needs_3d_axes(plotattributes::AbstractDict) =
    needs_3d_axes(get(plotattributes, :seriestype, :path))


# --------------------------------
# ## Scales
# --------------------------------

const SCALE_FUNCTIONS = Dict{Symbol, Function}(:log10 => log10, :log2 => log2, :ln => log)
const INVERSE_SCALE_FUNCTIONS =
    Dict{Symbol, Function}(:log10 => exp10, :log2 => exp2, :ln => exp)

scale_func(scale::Symbol) = x -> get(SCALE_FUNCTIONS, scale, identity)(Float64(x))
inverse_scale_func(scale::Symbol) =
    x -> get(INVERSE_SCALE_FUNCTIONS, scale, identity)(Float64(x))


# --------------------------------
# ## Unzip
# --------------------------------

for i in 2:4
    @eval begin
        unzip(v::AVec{<:Tuple{Vararg{T, $i} where T}}) =
            $(Expr(:tuple, (:([t[$j] for t in v]) for j in 1:i)...))
    end
end


# --------------------------------
# ## Map functions on vectors
# --------------------------------

_map_funcs(f::Function, u::AVec) = map(f, u)
_map_funcs(fs::AVec{F}, u::AVec) where {F <: Function} = [map(f, u) for f in fs]
