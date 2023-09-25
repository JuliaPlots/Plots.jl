"Things that should be common to all backends and frontend modules"
module Commons

export AVec, AMat, KW, AKW, TicksArgs
export PLOTS_SEED, PX_PER_INCH, DPI, MM_PER_INCH, MM_PER_PX, DEFAULT_BBOX, DEFAULT_MINPAD, DEFAULT_LINEWIDTH
export _haligns, _valigns, _cbar_width
# Functions
export get_subplot, coords, ispolar, expand_extrema!, series_list, axis_limits, get_size, get_thickness_scaling
export fg_color, plot_color, alpha, isdark, color_or_nothing!
export get_attr_symbol, _cycle, _as_gradient, makevec, maketuple, unzip, get_aspect_ratio, ok, handle_surface, reverse_if, _debug
export _allScales, _logScales, _logScaleBases, _scaleAliases
#exports from args.jl
export default, wraptuple

using Plots: Plots, Printf
import Plots: RecipesPipeline
using Plots.Colors: Colorant, @colorant_str
using Plots.ColorTypes: alpha
using Plots.Measures: mm, BoundingBox
using Plots.PlotUtils: PlotUtils, ColorPalette, plot_color, isdark
using Plots.RecipesBase

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}
const TicksArgs =
    Union{AVec{T},Tuple{AVec{T},AVec{S}},Symbol} where {T<:Real,S<:AbstractString}
const PLOTS_SEED = 1234
const PX_PER_INCH = 100
const DPI = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX = MM_PER_INCH / PX_PER_INCH
const _haligns = :hcenter, :left, :right
const _valigns = :vcenter, :top, :bottom
const _cbar_width = 5mm
const DEFAULT_BBOX = Ref(BoundingBox(0mm, 0mm, 0mm, 0mm))
const DEFAULT_MINPAD = Ref((20mm, 5mm, 2mm, 10mm))
const DEFAULT_LINEWIDTH = Ref(1)
const _allScales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
const _logScales = [:ln, :log2, :log10]
const _logScaleBases = Dict(:ln => ℯ, :log2 => 2.0, :log10 => 10.0)
const _scaleAliases = Dict{Symbol,Symbol}(:none => :identity, :log => :log10)
const _debug = Ref(false)

function get_subplot end
function series_list end
function coords end
function ispolar end
function expand_extrema! end
function axis_limits end
function preprocess_attributes! end
# ---------------------------------------------------------------
wraptuple(x::Tuple) = x
wraptuple(x) = (x,)

trueOrAllTrue(f::Function, x::AbstractArray) = all(f, x)
trueOrAllTrue(f::Function, x) = f(x)

allLineTypes(arg) = trueOrAllTrue(a -> get(Commons._typeAliases, a, a) in Commons._allTypes, arg)
allStyles(arg) = trueOrAllTrue(a -> get(Commons._styleAliases, a, a) in Commons._allStyles, arg)
allShapes(arg) =
    (trueOrAllTrue(a -> get(Commons._markerAliases, a, a) in Commons._allMarkers || a isa Shape, arg))
allAlphas(arg) = trueOrAllTrue(
    a ->
        (typeof(a) <: Real && a > 0 && a < 1) || (
            typeof(a) <: AbstractFloat && (a == zero(typeof(a)) || a == one(typeof(a)))
        ),
    arg,
)
allReals(arg) = trueOrAllTrue(a -> typeof(a) <: Real, arg)
allFunctions(arg) = trueOrAllTrue(a -> isa(a, Function), arg)

# ---------------------------------------------------------------
include("args.jl")

function _override_seriestype_check(plotattributes::AKW, st::Symbol)
    # do we want to override the series type?
    if !RecipesPipeline.is3d(st) && st ∉ (:contour, :contour3d, :quiver)
        if (z = plotattributes[:z]) !== nothing &&
           size(plotattributes[:x]) == size(plotattributes[:y]) == size(z)
            st = st === :scatter ? :scatter3d : :path3d
            plotattributes[:seriestype] = st
        end
    end
    st
end

"These should only be needed in frontend modules"
Plots.@ScopeModule(Frontend, Commons,
    _subplot_defaults,
    _axis_defaults,
    _plot_defaults,
    _series_defaults,
    _match_map,
    _match_map2,
    @add_attributes,
    preprocess_attributes!,
    _override_seriestype_check
)

function fg_color(plotattributes::AKW)
    fg = get(plotattributes, :foreground_color, :auto)
    if fg === :auto
        bg = plot_color(get(plotattributes, :background_color, :white))
        fg = alpha(bg) > 0 && isdark(bg) ? colorant"white" : colorant"black"
    else
        plot_color(fg)
    end
end
function color_or_nothing!(plotattributes, k::Symbol)
    plotattributes[k] = (v = plotattributes[k]) === :match ? v : plot_color(v)
    nothing
end

# cache joined symbols so they can be looked up instead of constructed each time
const _attrsymbolcache = Dict{Symbol,Dict{Symbol,Symbol}}()

get_attr_symbol(letter::Symbol, keyword::String) = get_attr_symbol(letter, Symbol(keyword))
get_attr_symbol(letter::Symbol, keyword::Symbol) = _attrsymbolcache[letter][keyword]
# ------------------------------------------------------------------------------------
_cycle(v::AVec, idx::Int) = v[mod(idx, axes(v, 1))]
_cycle(v::AMat, idx::Int) = size(v, 1) == 1 ? v[end, mod(idx, axes(v, 2))] : v[:, mod(idx, axes(v, 2))]
_cycle(v, idx::Int)       = v

_cycle(v::AVec, indices::AVec{Int}) = map(i -> _cycle(v, i), indices)
_cycle(v::AMat, indices::AVec{Int}) = map(i -> _cycle(v, i), indices)
_cycle(v, indices::AVec{Int})       = fill(v, length(indices))

_cycle(cl::PlotUtils.AbstractColorList, idx::Int) = cl[mod1(idx, end)]
_cycle(cl::PlotUtils.AbstractColorList, idx::AVec{Int}) = cl[mod1.(idx, end)]

_as_gradient(grad) = grad
_as_gradient(v::AbstractVector{<:Colorant}) = cgrad(v)
_as_gradient(cp::ColorPalette) = cgrad(cp, categorical = true)
_as_gradient(c::Colorant) = cgrad([c, c])

makevec(v::AVec) = v
makevec(v::T) where {T} = T[v]

"duplicate a single value, or pass the 2-tuple through"
maketuple(x::Real) = (x, x)
maketuple(x::Tuple) = x

RecipesPipeline.unzip(v) = Unzip.unzip(v)  # COV_EXCL_LINE

"collect into columns (convenience for `unzip` from `Unzip.jl`)"
unzip(v) = RecipesPipeline.unzip(v)

check_aspect_ratio(ar::AbstractVector) = nothing  # for PyPlot
check_aspect_ratio(ar::Number) = nothing
check_aspect_ratio(ar::Symbol) =
    ar in (:none, :equal, :auto) || throw(ArgumentError("Invalid `aspect_ratio` = $ar"))
check_aspect_ratio(ar::T) where {T} =
    throw(ArgumentError("Invalid `aspect_ratio`::$T = $ar "))

ok(x::Number, y::Number, z::Number = 0) = isfinite(x) && isfinite(y) && isfinite(z)
ok(tup::Tuple) = ok(tup...)

handle_surface(z) = z

reverse_if(x, cond) = cond ? reverse(x) : x

function get_aspect_ratio(sp)
    ar = sp[:aspect_ratio]
    check_aspect_ratio(ar)
    if ar === :auto
        ar = :none
        for series in series_list(sp)
            if series[:seriestype] === :image
                ar = :equal
            end
        end
    end
    ar isa Bool && (ar = Int(ar))  # NOTE: Bool <: ... <: Number
    ar
end

get_size(kw) = get(kw, :size, default(:size))
get_thickness_scaling(kw) = get(kw, :thickness_scaling, default(:thickness_scaling))

debug!(on = true) = _debug[] = on
debugshow(io, x) = show(io, x)
debugshow(io, x::AbstractArray) = print(io, summary(x))

function dumpdict(io::IO, plotattributes::AKW, prefix = "")
    _debug[] || return
    println(io)
    prefix == "" || println(io, prefix, ":")
    for k in sort(collect(keys(plotattributes)))
        Printf.@printf(io, "%14s: ", k)
        debugshow(io, plotattributes[k])
        println(io)
    end
    println(io)
end
include("postprocess_args.jl")

end
