# previously https://github.com/jw3126/UnitfulRecipes.jl
# authors: Benoit Pasquier (@briochemc) - David Gustavsson (@gustaphe) - Jan Weidner (@jw3126)

module UnitfulExt

import Plots: Plots, @ext_imp_use, @recipe, PlotText, Subplot, AVec, AMat, Axis
import RecipesBase
@ext_imp_use :import Unitful Quantity unit ustrip Unitful dimension Units NoUnits LogScaled logunit MixedUnits Level Gain uconvert
import LaTeXStrings: LaTeXString
import Latexify: latexify
using UnitfulLatexify

const MissingOrQuantity = Union{Missing, <:Quantity, <:LogScaled}

#==========
Main recipe
==========#

@recipe function f(::Type{T}, x::T) where {T <: AbstractArray{<:MissingOrQuantity}}  # COV_EXCL_LINE
    axisletter = plotattributes[:letter]   # x, y, or z
    clims_types = (:contour, :contourf, :heatmap, :surface)
    if axisletter === :z && get(plotattributes, :seriestype, :nothing) ∈ clims_types
        u = get(plotattributes, :zunit, _unit(eltype(x)))
        ustripattribute!(plotattributes, :clims, u)
        append_cbar_unit_if_needed!(plotattributes, u)
    end
    fixaxis!(plotattributes, x, axisletter)
end

function fixaxis!(attr, x, axisletter)
    # Attribute keys
    err = Symbol(axisletter, :error)       # xerror, yerror, zerror
    axisunit = Symbol(axisletter, :unit)   # xunit, yunit, zunit
    axis = Symbol(axisletter, :axis)       # xaxis, yaxis, zaxis
    # if the subplot already exists with data, use that unit
    sp = get(attr, :subplot, 1)
    if sp ≤ length(attr[:plot_object]) && attr[:plot_object].n > 0
        spu = getaxisunit(attr[:plot_object][sp][axis])
        u = if isnothing(spu)  # subplot exists but doesn't have a unit yet
            get!(attr, axisunit, _unit(eltype(x)))  # get the unit
        else
            spu
        end
    else # Subplot doesn't exist yet, so create it with given unit
        u = get!(attr, axisunit, _unit(eltype(x)))  # get the unit
    end
    # fix the attributes: labels, lims, ticks, marker/line stuff, etc.
    ustripattribute!(attr, err, u)
    if axisletter === :y
        ustripattribute!(attr, :ribbon, u)
        ustripattribute!(attr, :fillrange, u)
    end
    fixaspectratio!(attr, u, axisletter)
    fixseriescolor!(attr, :marker_z)
    fixseriescolor!(attr, :line_z)
    fixmarkersize!(attr)
    return _ustrip.(u, x)  # strip the unit
end

# Recipe for (x::AVec, y::AVec, z::Surface) types
@recipe function f(x::AVec, y::AVec, z::AMat{T}) where {T <: Quantity}  # COV_EXCL_LINE
    u = get(plotattributes, :zunit, _unit(eltype(z)))
    ustripattribute!(plotattributes, :clims, u)
    z = fixaxis!(plotattributes, z, :z)
    append_cbar_unit_if_needed!(plotattributes, u)
    x, y, z
end

# Recipe for vectors of vectors
@recipe function f(::Type{T}, x::T) where {T <: AVec{<:AVec{<:MissingOrQuantity}}}  # COV_EXCL_LINE
    axisletter = plotattributes[:letter]   # x, y, or z
    unitsymbol = Symbol(axisletter, :unit)
    axisunit = pop!(plotattributes, unitsymbol, _unit(eltype(first(x))))
    map(
        x -> (
            plotattributes[unitsymbol] = axisunit; fixaxis!(plotattributes, x, axisletter)
        ),
        x,
    )
end

# Recipe for bare units
@recipe function f(::Type{T}, x::T) where {T <: Units}  # COV_EXCL_LINE
    primary := false
    Float64[] * x
end

# Recipes for functions
@recipe f(f::Function, x::T) where {T <: AVec{<:MissingOrQuantity}} = x, f.(x)
@recipe f(x::T, f::Function) where {T <: AVec{<:MissingOrQuantity}} = x, f.(x)
@recipe f(x::T, y::AVec, f::Function) where {T <: AVec{<:MissingOrQuantity}} = x, y, f.(x', y)
@recipe f(x::AVec, y::T, f::Function) where {T <: AVec{<:MissingOrQuantity}} = x, y, f.(x', y)
@recipe function f(  # COV_EXCL_LINE
        x::T1,
        y::T2,
        f::Function,
    ) where {T1 <: AVec{<:MissingOrQuantity}, T2 <: AVec{<:MissingOrQuantity}}
    x, y, f.(x', y)
end
@recipe function f(f::Function, u::Units)  # COV_EXCL_LINE
    uf = UnitFunction(f, [u])
    recipedata = RecipesBase.apply_recipe(plotattributes, uf)
    _, xmin, xmax = recipedata[1].args
    f, xmin * u, xmax * u
end

"""
```julia
UnitFunction
```
A function, bundled with the assumed units of each of its inputs.

```julia
f(x, y) = x^2 + y
uf = UnitFunction(f, u"m", u"m^2")
uf(3, 2) == f(3u"m", 2u"m"^2) == 7u"m^2"
```
"""
struct UnitFunction <: Function
    f::Function
    u::Vector{Units}
end
(f::UnitFunction)(args...) = f.f((args .* f.u)...)

#===============
Attribute fixing
===============#
# Aspect ratio
function fixaspectratio!(attr, u, axisletter)
    aspect_ratio = get(attr, :aspect_ratio, :auto)
    if aspect_ratio in (:auto, :none)
        # Keep the default behavior (let Plots figure it out)
        return
    end
    if aspect_ratio === :equal
        aspect_ratio = 1
    end
    #=======================================================================================
    Implementation example:

    Consider an x axis in `u"m"` and a y axis in `u"s"`, and an `aspect_ratio` in `u"m/s"`.
    On the first pass, `axisletter` is `:x`, so `aspect_ratio` is converted to `u"m/s"/u"m"
    = u"s^-1"`. On the second pass, `axisletter` is `:y`, so `aspect_ratio` becomes
    `u"s^-1"*u"s" = 1`. If at this point `aspect_ratio` is *not* unitless, an error has been
    made, and the default aspect ratio fixing of Plots throws a `DimensionError` as it tries
    to compare `0 < 1u"m"`.
    =======================================================================================#
    if axisletter === :y
        attr[:aspect_ratio] = aspect_ratio * u
    elseif axisletter === :x
        attr[:aspect_ratio] = aspect_ratio / u
    end
    return nothing
end

# Markers / lines
function fixseriescolor!(attr, key)
    sp = get(attr, :subplot, 1)
    # Precedence to user-passed zunit
    if haskey(attr, :zunit)
        u = attr[:zunit]
        ustripattribute!(attr, key, u)
        # Then to an existing subplot's colorbar title
    elseif sp ≤ length(attr[:plot_object]) && attr[:plot_object].n > 0
        cbar_title = get(attr[:plot_object][sp], :colorbar_title, nothing)
        spu = cbar_title isa UnitfulString ? cbar_title.unit : nothing
        u = if isnothing(spu)
            ustripattribute!(attr, key)
        else
            ustripattribute!(attr, key, spu)
        end
        # Otherwise, get from the attribute
    else
        u = ustripattribute!(attr, key)
    end
    ustripattribute!(attr, :clims, u)
    # fixseriescolor! is called for each axis, so after the first pass,
    # u will be NoUnits and we don't want to append unit again
    return u == NoUnits || append_cbar_unit_if_needed!(attr, u)
end
fixmarkersize!(attr) = ustripattribute!(attr, :markersize)

# strip unit from attribute[key]
ustripattribute!(attr, key) =
if haskey(attr, key)
    v = attr[key]
    u = _unit(eltype(v))
    attr[key] = _ustrip.(u, v)
    u
else
    NoUnits
end

# if supplied, use the unit (optional 3rd argument)
function ustripattribute!(attr, key, u)
    if haskey(attr, key)
        v = attr[key]
        if eltype(v) <: Quantity
            attr[key] = _ustrip.(u, v)
        elseif v isa Tuple
            attr[key] = Tuple([(eltype(vi) <: Quantity ? _ustrip.(u, vi) : vi) for vi in v])
        end
    end
    return u
end

#=======================================
Label string containing unit information
Used only for colorbars, etc., which don't
have a bettter place for storing units
=======================================#

const APS = Plots.AbstractProtectedString
struct UnitfulString{S, U} <: APS
    content::S
    unit::U
end

#=====================================
Append unit to labels when appropriate
This is needed for colorbars, etc., since axes have
distinct unit handling
=====================================#

append_cbar_unit_if_needed!(attr, u) =
    append_cbar_unit_if_needed!(attr, get(attr, :colorbar_title, nothing), u)
# dispatch on the type of `label`
append_cbar_unit_if_needed!(attr, label::UnitfulString, u) = nothing
function append_cbar_unit_if_needed!(attr, label::Nothing, u)
    unitformat = get(attr, Symbol(:z, :unitformat), :round)
    if unitformat ∈ [:nounit, :none, false, nothing]
        return attr[:colorbar_title] = UnitfulString("", u)
    end
    return attr[:colorbar_title] = if Plots.backend_name() === :pgfplotsx
        UnitfulString(LaTeXString(latexify(u)), u)
    else
        UnitfulString(string(u), u)
    end
end
function append_cbar_unit_if_needed!(attr, label::S, u) where {S <: AbstractString}
    isempty(label) && return attr[:colorbar_title] = UnitfulString(label, u)
    return attr[:colorbar_title] = if Plots.backend_name() ≡ :pgfplotsx
        UnitfulString(
            LaTeXString(
                Plots.format_unit_label(
                    label,
                    latexify(u),
                    get(attr, :zunitformat, :round),
                ),
            ),
            u,
        )
    else
        UnitfulString(
            S(
                Plots.format_unit_label(
                    label,
                    u,
                    get(attr, :zunitformat, :round),
                ),
            ),
            u,
        )
    end
end

getaxisunit(::Nothing) = nothing
getaxisunit(u) = u
getaxisunit(a::Axis) = getaxisunit(a[:unit])

#==============
Fix annotations
===============#
function Plots.locate_annotation(
        sp::Subplot,
        x::MissingOrQuantity,
        y::MissingOrQuantity,
        label::PlotText,
    )
    xunit = getaxisunit(sp.attr[:xaxis])
    yunit = getaxisunit(sp.attr[:yaxis])
    return (_ustrip(xunit, x), _ustrip(yunit, y), label)
end
function Plots.locate_annotation(
        sp::Subplot,
        x::MissingOrQuantity,
        y::MissingOrQuantity,
        z::MissingOrQuantity,
        label::PlotText,
    )
    xunit = getaxisunit(sp.attr[:xaxis])
    yunit = getaxisunit(sp.attr[:yaxis])
    zunit = getaxisunit(sp.attr[:zaxis])
    return (_ustrip(xunit, x), _ustrip(yunit, y), _ustrip(zunit, z), label)
end
function Plots.locate_annotation(
        sp::Subplot,
        rel::NTuple{N, <:MissingOrQuantity},
        label,
    ) where {N}
    units = getaxisunit(sp.attr[:xaxis]),
        getaxisunit(sp.attr[:yaxis]),
        getaxisunit(sp.attr[:zaxis])
    return PlotsBase.locate_annotation(sp, _ustrip.(zip(units, rel)), label)
end

#==================#
# ticks and limits #
#==================#
Plots._transform_ticks(ticks::AbstractArray{T}, axis) where {T <: Quantity} =
    _ustrip.(getaxisunit(axis), ticks)
Plots.process_limits(lims::AbstractArray{T}, axis) where {T <: Quantity} =
    _ustrip.(getaxisunit(axis), lims)
Plots.process_limits(lims::Tuple{S, T}, axis) where {S <: Quantity, T <: Quantity} =
    _ustrip.(getaxisunit(axis), lims)

function _ustrip(u, x)
    u isa MixedUnits && return ustrip(uconvert(u, x))
    return ustrip(u, x)
end

function _unit(x)
    (t = eltype(x)) <: LogScaled && return logunit(t)
    return unit(x)
end

function Plots.pgfx_sanitize_string(s::UnitfulString)
    return UnitfulString(Plots.pgfx_sanitize_string(s.content), s.unit)
end

end  # module
