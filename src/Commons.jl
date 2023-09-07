"Things that should be common to all backends"
module Commons

export AVec, AMat, KW, AKW, TicksArgs
export PLOTS_SEED, PX_PER_INCH, DPI, MM_PER_INCH, MM_PER_PX, DEFAULT_BBOX, DEFAULT_MINPAD
export _haligns, _valigns, _cbar_width
# Functions
export get_subplot, coords, ispolar, expand_extrema!, series_list, axis_limits
export fg_color, plot_color, alpha, isdark, color_or_nothing!
export get_attr_symbol, _cycle, _as_gradient, makevec, maketuple, unzip, get_aspect_ratio
export _allScales, _logScales, _logScaleBases, _scaleAliases

import Plots: RecipesPipeline
using Plots.Colors: Colorant, @colorant_str
using Plots.PlotUtils: PlotUtils, ColorPalette, plot_color, isdark
using Plots.ColorTypes: alpha
using Plots.Measures: mm, BoundingBox

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}
const TicksArgs =
    Union{AVec{T},Tuple{AVec{T},AVec{S}},Symbol} where {T<:Real,S<:AbstractString}
const PLOTS_SEED  = 1234
const PX_PER_INCH = 100
const DPI         = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX   = MM_PER_INCH / PX_PER_INCH
const _haligns = :hcenter, :left, :right
const _valigns = :vcenter, :top, :bottom
const _cbar_width = 5mm
const DEFAULT_BBOX = Ref(BoundingBox(0mm, 0mm, 0mm, 0mm))
const DEFAULT_MINPAD = Ref((20mm, 5mm, 2mm, 10mm))
const _allScales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
const _logScales = [:ln, :log2, :log10]
const _logScaleBases = Dict(:ln => ℯ, :log2 => 2.0, :log10 => 10.0)
const _scaleAliases = Dict{Symbol,Symbol}(:none => :identity, :log => :log10)


function get_subplot end
function series_list end
function coords end
function ispolar end
function expand_extrema! end
function axis_limits end
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

end
