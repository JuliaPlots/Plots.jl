"Things that should be common to all backends and frontend modules"
module Commons

export AVec,
    AMat, KW, AKW, TicksArgs, PlotsBase, PLOTS_SEED, _haligns, _valigns, _cbar_width
# Functions
export get_subplot,
    coords,
    ispolar,
    expand_extrema!,
    series_list,
    axis_limits,
    get_size,
    get_thickness_scaling,
    get_clims
export fg_color, plot_color, single_color, alpha, isdark, color_or_nothing!
export get_attr_symbol,
    _cycle,
    _as_gradient,
    makevec,
    maketuple,
    unzip,
    get_aspect_ratio,
    ok,
    handle_surface,
    reverse_if,
    _debug
export _all_scales, _log_scales, _log_scale_bases, _scale_aliases
export _segmenting_array_attributes, _segmenting_vector_attributes
export anynan,
    allnan,
    round_base,
    floor_base,
    ceil_base,
    ignorenan_min_max,
    ignorenan_extrema,
    ignorenan_maximum,
    ignorenan_mean,
    ignorenan_minimum
#exports from args.jl
export default, wraptuple, merge_with_base_supported

using PlotsBase: PlotsBase, Printf, NaNMath, cgrad
import PlotsBase: RecipesPipeline
using PlotsBase.Colors: Colorant, @colorant_str
using PlotsBase.ColorTypes: alpha
using PlotsBase.Measures: mm, BoundingBox
using PlotsBase.PlotUtils: PlotUtils, ColorPalette, plot_color, isdark, ColorGradient
using PlotsBase.RecipesBase
using PlotsBase: DEFAULT_LINEWIDTH
using PlotsBase: Statistics

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
const _all_scales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
const _log_scales = [:ln, :log2, :log10]
const _log_scale_bases = Dict(:ln => ℯ, :log2 => 2.0, :log10 => 10.0)
const _scale_aliases = Dict{Symbol,Symbol}(:none => :identity, :log => :log10)
const _segmenting_vector_attributes = (
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linealpha,
    :linewidth,
    :linestyle,
    :fillcolor,
    :fillalpha,
    :fillstyle,
    :markercolor,
    :markeralpha,
    :markersize,
    :markerstrokecolor,
    :markerstrokealpha,
    :markerstrokewidth,
    :markershape,
)
const _segmenting_array_attributes = :line_z, :fill_z, :marker_z
const _debug = Ref(false)

function get_subplot end
function get_clims end
function series_list end
function coords end
function ispolar end
function expand_extrema! end
function axis_limits end
function preprocess_attributes! end
# ---------------------------------------------------------------
wraptuple(x::Tuple) = x
wraptuple(x) = (x,)

true_or_all_true(f::Function, x::AbstractArray) = all(f, x)
true_or_all_true(f::Function, x) = f(x)

all_lineLtypes(arg) =
    true_or_all_true(a -> get(Commons._typeAliases, a, a) in Commons._all_seriestypes, arg)
all_styles(arg) =
    true_or_all_true(a -> get(Commons._styleAliases, a, a) in Commons._all_styles, arg)
all_shapes(arg) = (true_or_all_true(
    a ->
        get(Commons._marker_aliases, a, a) in Commons._all_markers ||
            a isa PlotsBase.Shape,
    arg,
))
all_alphas(arg) = true_or_all_true(
    a ->
        (typeof(a) <: Real && a > 0 && a < 1) || (
            typeof(a) <: AbstractFloat && (a == zero(typeof(a)) || a == one(typeof(a)))
        ),
    arg,
)
all_reals(arg) = true_or_all_true(a -> typeof(a) <: Real, arg)
all_functionss(arg) = true_or_all_true(a -> isa(a, Function), arg)

# ---------------------------------------------------------------
include("attrs.jl")

function _override_seriestype_check(plotattributes::AKW, st::Symbol)
    # do we want to override the series type?
    if !RecipesPipeline.is3d(st) && st ∉ (:contour, :contour3d, :quiver)
        if (z = plotattributes[:z]) ≢ nothing &&
           size(plotattributes[:x]) == size(plotattributes[:y]) == size(z)
            st = st ≡ :scatter ? :scatter3d : :path3d
            plotattributes[:seriestype] = st
        end
    end
    st
end

"These should only be needed in frontend modules"
PlotsBase.@ScopeModule(
    Frontend,
    Commons,
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
    if fg ≡ :auto
        bg = plot_color(get(plotattributes, :background_color, :white))
        fg = alpha(bg) > 0 && isdark(bg) ? colorant"white" : colorant"black"
    else
        plot_color(fg)
    end
end
function color_or_nothing!(plotattributes, k::Symbol)
    plotattributes[k] = (v = plotattributes[k]) ≡ :match ? v : plot_color(v)
    nothing
end

# cache joined symbols so they can be looked up instead of constructed each time
const _attrsymbolcache = Dict{Symbol,Dict{String,Symbol}}()

get_attr_symbol(letter::Symbol, keyword::String) = _attrsymbolcache[letter][keyword]
get_attr_symbol(letter::Symbol, keyword::Symbol) = get_attr_symbol(letter, string(keyword))

new_attr_dict!(letter::Symbol) = get!(_attrsymbolcache, letter, Dict{String,Symbol}())
set_attr_symbol!(letter::Symbol, keyword::String) =
    let letter_keyword = Symbol(letter, keyword)
        _attrsymbolcache[letter][keyword] = letter_keyword
    end

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

single_color(c, v = 0.5) = c
single_color(grad::ColorGradient, v = 0.5) = grad[v]

get_gradient(c) = cgrad()
get_gradient(cg::ColorGradient) = cg
get_gradient(cp::ColorPalette) = cgrad(cp, categorical = true)

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

"floor number x in base b, note this is different from using Base.round(...; base=b) !"
floor_base(x, b) = round_base(x, b, RoundDown)

"ceil number x in base b"
ceil_base(x, b) = round_base(x, b, RoundUp)

round_base(x::T, b, ::RoundingMode{:Down}) where {T} = T(b^floor(log(b, x)))
round_base(x::T, b, ::RoundingMode{:Up}) where {T} = T(b^ceil(log(b, x)))
# define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum(x::AbstractArray{<:AbstractFloat}) = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum(x::AbstractArray{<:AbstractFloat}) = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean(x::AbstractArray{<:AbstractFloat}) = NaNMath.mean(x)
ignorenan_mean(x) = Statistics.mean(x)
ignorenan_extrema(x::AbstractArray{<:AbstractFloat}) = NaNMath.extrema(x)
ignorenan_extrema(x) = Base.extrema(x)
ignorenan_min_max(::Any, ex) = ex
function ignorenan_min_max(x::AbstractArray{<:AbstractFloat}, ex::Tuple)
    mn, mx = ignorenan_extrema(x)
    NaNMath.min(ex[1], mn), NaNMath.max(ex[2], mx)
end

# helpers to figure out if there are NaN values in a list of array types
anynan(i::Int, args::Tuple) = any(a -> try
    isnan(_cycle(a, i))
catch MethodError
    false
end, args)
anynan(args::Tuple) = i -> anynan(i, args)
anynan(istart::Int, iend::Int, args::Tuple) = any(anynan(args), istart:iend)
allnan(istart::Int, iend::Int, args::Tuple) = all(anynan(args), istart:iend)

handle_surface(z) = z

reverse_if(x, cond) = cond ? reverse(x) : x

function get_aspect_ratio(sp)
    ar = sp[:aspect_ratio]
    check_aspect_ratio(ar)
    if ar ≡ :auto
        ar = :none
        for series in series_list(sp)
            if series[:seriestype] ≡ :image
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
include("postprocess_attrs.jl")

end
