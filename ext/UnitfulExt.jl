# previously https://github.com/jw3126/UnitfulRecipes.jl
# authors: Benoit Pasquier (@briochemc) - David Gustavsson (@gustaphe) - Jan Weidner (@jw3126)

module UnitfulExt

import Plots: Plots, @ext_imp_use, @recipe, PlotText, Subplot, AVec, AMat, Axis
import RecipesBase
@ext_imp_use :import Unitful Quantity unit ustrip Unitful dimension Units NoUnits LogScaled logunit MixedUnits Level Gain uconvert
import LaTeXStrings: LaTeXString
import Latexify: latexify
using UnitfulLatexify

const MissingOrQuantity = Union{Missing,<:Quantity,<:LogScaled}

#==========
Main recipe
==========#

@recipe function f(::Type{T}, x::T) where {T<:AbstractArray{<:MissingOrQuantity}}  # COV_EXCL_LINE
    axisletter = plotattributes[:letter]   # x, y, or z
    clims_types = (:contour, :contourf, :heatmap, :surface)
    if axisletter === :z && get(plotattributes, :seriestype, :nothing) ∈ clims_types
        u = get(plotattributes, :zunit, _unit(eltype(x)))
        ustripattribute!(plotattributes, :clims, u)
        append_unit_if_needed!(plotattributes, :colorbar_title, u)
    end
    fixaxis!(plotattributes, x, axisletter)
end

function fixaxis!(attr, x, axisletter)
    # Attribute keys
    axislabel = Symbol(axisletter, :guide) # xguide, yguide, zguide
    axislims = Symbol(axisletter, :lims)   # xlims, ylims, zlims
    axisticks = Symbol(axisletter, :ticks) # xticks, yticks, zticks
    err = Symbol(axisletter, :error)       # xerror, yerror, zerror
    axisunit = Symbol(axisletter, :unit)   # xunit, yunit, zunit
    axis = Symbol(axisletter, :axis)       # xaxis, yaxis, zaxis
    u = pop!(attr, axisunit, _unit(eltype(x)))  # get the unit
    # if the subplot already exists with data, get its unit
    sp = get(attr, :subplot, 1)
    if sp ≤ length(attr[:plot_object]) && attr[:plot_object].n > 0
        label = attr[:plot_object][sp][axis][:guide]
        u = getaxisunit(label)
        get!(attr, axislabel, label)  # if label was not given as an argument, reuse
    end
    # fix the attributes: labels, lims, ticks, marker/line stuff, etc.
    append_unit_if_needed!(attr, axislabel, u)
    ustripattribute!(attr, err, u)
    if axisletter === :y
        ustripattribute!(attr, :ribbon, u)
        ustripattribute!(attr, :fillrange, u)
    end
    fixaspectratio!(attr, u, axisletter)
    fixmarkercolor!(attr)
    fixmarkersize!(attr)
    fixlinecolor!(attr)
    _ustrip.(u, x)  # strip the unit
end

# Recipe for (x::AVec, y::AVec, z::Surface) types
@recipe function f(x::AVec, y::AVec, z::AMat{T}) where {T<:Quantity}  # COV_EXCL_LINE
    u = get(plotattributes, :zunit, _unit(eltype(z)))
    ustripattribute!(plotattributes, :clims, u)
    z = fixaxis!(plotattributes, z, :z)
    append_unit_if_needed!(plotattributes, :colorbar_title, u)
    x, y, z
end

# Recipe for vectors of vectors
@recipe function f(::Type{T}, x::T) where {T<:AVec{<:AVec{<:MissingOrQuantity}}}  # COV_EXCL_LINE
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
@recipe function f(::Type{T}, x::T) where {T<:Units}  # COV_EXCL_LINE
    primary := false
    Float64[] * x
end

# Recipes for functions
@recipe f(f::Function, x::T) where {T<:AVec{<:MissingOrQuantity}} = x, f.(x)
@recipe f(x::T, f::Function) where {T<:AVec{<:MissingOrQuantity}} = x, f.(x)
@recipe f(x::T, y::AVec, f::Function) where {T<:AVec{<:MissingOrQuantity}} = x, y, f.(x', y)
@recipe f(x::AVec, y::T, f::Function) where {T<:AVec{<:MissingOrQuantity}} = x, y, f.(x', y)
@recipe function f(  # COV_EXCL_LINE
    x::T1,
    y::T2,
    f::Function,
) where {T1<:AVec{<:MissingOrQuantity},T2<:AVec{<:MissingOrQuantity}}
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
    nothing
end

# Markers / lines
function fixmarkercolor!(attr)
    u = ustripattribute!(attr, :marker_z)
    ustripattribute!(attr, :clims, u)
    u == NoUnits || append_unit_if_needed!(attr, :colorbar_title, u)
end
fixmarkersize!(attr) = ustripattribute!(attr, :markersize)
fixlinecolor!(attr) = ustripattribute!(attr, :line_z)

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
        end
    end
    u
end

#=======================================
Label string containing unit information
=======================================#

abstract type AbstractProtectedString <: AbstractString end
struct ProtectedString{S} <: AbstractProtectedString
    content::S
end
struct UnitfulString{S,U} <: AbstractProtectedString
    content::S
    unit::U
end
# Minimum required AbstractString interface to work with Plots
const S = AbstractProtectedString
Base.iterate(n::S) = iterate(n.content)
Base.iterate(n::S, i::Integer) = iterate(n.content, i)
Base.codeunit(n::S) = codeunit(n.content)
Base.ncodeunits(n::S) = ncodeunits(n.content)
Base.isvalid(n::S, i::Integer) = isvalid(n.content, i)
Base.pointer(n::S) = pointer(n.content)
Base.pointer(n::S, i::Integer) = pointer(n.content, i)

Plots.protectedstring(s) = ProtectedString(s)

#=====================================
Append unit to labels when appropriate
=====================================#

append_unit_if_needed!(attr, key, u) =
    append_unit_if_needed!(attr, key, get(attr, key, nothing), u)
# dispatch on the type of `label`
append_unit_if_needed!(attr, key, label::ProtectedString, u) = nothing
append_unit_if_needed!(attr, key, label::UnitfulString, u) = nothing
function append_unit_if_needed!(attr, key, label::Nothing, u)
    attr[key] = if attr[:plot_object].backend == Plots.PGFPlotsXBackend()
        UnitfulString(LaTeXString(latexify(u)), u)
    else
        UnitfulString(string(u), u)
    end
end
function append_unit_if_needed!(attr, key, label::S, u) where {S<:AbstractString}
    isempty(label) && return attr[key] = UnitfulString(label, u)
    if attr[:plot_object].backend == Plots.PGFPlotsXBackend()
        attr[key] = UnitfulString(
            LaTeXString(
                format_unit_label(
                    label,
                    latexify(u),
                    get(attr, Symbol(get(attr, :letter, ""), :unitformat), :round),
                ),
            ),
            u,
        )
    else
        attr[key] = UnitfulString(
            S(
                format_unit_label(
                    label,
                    u,
                    get(attr, Symbol(get(attr, :letter, ""), :unitformat), :round),
                ),
            ),
            u,
        )
    end
end

#=============================================
Surround unit string with specified delimiters
=============================================#

const UNIT_FORMATS = Dict(
    :round => ('(', ')'),
    :square => ('[', ']'),
    :curly => ('{', '}'),
    :angle => ('<', '>'),
    :slash => '/',
    :slashround => (" / (", ")"),
    :slashsquare => (" / [", "]"),
    :slashcurly => (" / {", "}"),
    :slashangle => (" / <", ">"),
    :verbose => " in units of ",
    :none => nothing,
)

format_unit_label(l, u, f::Nothing)                    = string(l, ' ', u)
format_unit_label(l, u, f::Function)                   = f(l, u)
format_unit_label(l, u, f::AbstractString)             = string(l, f, u)
format_unit_label(l, u, f::NTuple{2,<:AbstractString}) = string(l, f[1], u, f[2])
format_unit_label(l, u, f::NTuple{3,<:AbstractString}) = string(f[1], l, f[2], u, f[3])
format_unit_label(l, u, f::Char)                       = string(l, ' ', f, ' ', u)
format_unit_label(l, u, f::NTuple{2,Char})             = string(l, ' ', f[1], u, f[2])
format_unit_label(l, u, f::NTuple{3,Char})             = string(f[1], l, ' ', f[2], u, f[3])
format_unit_label(l, u, f::Bool)                       = f ? format_unit_label(l, u, :round) : format_unit_label(l, u, nothing)
format_unit_label(l, u, f::Symbol)                     = format_unit_label(l, u, UNIT_FORMATS[f])

getaxisunit(::AbstractString) = NoUnits
getaxisunit(s::UnitfulString) = s.unit
getaxisunit(a::Axis) = getaxisunit(a[:guide])

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
    (_ustrip(xunit, x), _ustrip(yunit, y), label)
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
    (_ustrip(xunit, x), _ustrip(yunit, y), _ustrip(zunit, z), label)
end
function Plots.locate_annotation(
    sp::Subplot,
    rel::NTuple{N,<:MissingOrQuantity},
    label,
) where {N}
    units = getaxisunit(sp.attr[:xaxis], sp.attr[:yaxis], sp.attr[:zaxis])
    Plots.locate_annotation(sp, _ustrip.(zip(units, rel)), label)
end

#==================#
# ticks and limits #
#==================#
Plots._transform_ticks(ticks::AbstractArray{T}, axis) where {T<:Quantity} =
    _ustrip.(getaxisunit(axis), ticks)
Plots.process_limits(lims::AbstractArray{T}, axis) where {T<:Quantity} =
    _ustrip.(getaxisunit(axis), lims)
Plots.process_limits(lims::Tuple{S,T}, axis) where {S<:Quantity,T<:Quantity} =
    _ustrip.(getaxisunit(axis), lims)

function _ustrip(u, x)
    u isa MixedUnits && return ustrip(uconvert(u, x))
    ustrip(u, x)
end

function _unit(x)
    (t = eltype(x)) <: LogScaled && return logunit(t)
    unit(x)
end

function Plots.pgfx_sanitize_string(s::UnitfulString)
    UnitfulString(Plots.pgfx_sanitize_string(s.content), s.unit)
end

end  # module
