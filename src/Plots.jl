module Plots

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end

const _current_plots_version = VersionNumber(
    split(
        first(
            filter(
                line -> occursin("version", line),
                readlines(normpath(@__DIR__, "..", "Project.toml")),
            ),
        ),
        "\"",
    )[2],
)

using Reexport

import GeometryBasics
using Dates, Printf, Statistics, Base64, LinearAlgebra, Random
using SparseArrays

using FFMPEG

@reexport using RecipesBase
import RecipesBase: plot, plot!, animate, is_explicit, grid
using Base.Meta
@reexport using PlotUtils
@reexport using PlotThemes
import UnicodeFun
import StatsBase
import Downloads
import Showoff
import JSON

using Requires

#! format: off
export
    grid,
    bbox,
    plotarea,
    KW,

    wrap,
    theme,

    plot,
    plot!,
    attr!,

    current,
    default,
    with,
    twinx,

    pie,
    pie!,
    plot3d,
    plot3d!,

    title!,
    xlabel!,
    ylabel!,
    xlims!,
    ylims!,
    zlims!,
    xticks!,
    yticks!,
    annotate!,
    xflip!,
    yflip!,
    xaxis!,
    yaxis!,
    xgrid!,
    ygrid!,

    xlims,
    ylims,
    zlims,

    savefig,
    png,
    gui,
    inline,
    closeall,

    backend,
    backends,
    backend_name,
    backend_object,
    aliases,

    Shape,
    text,
    font,
    stroke,
    brush,
    Surface,
    OHLC,
    arrow,
    Segments,
    Formatted,

    Animation,
    frame,
    gif,
    mov,
    mp4,
    webm,
    animate,
    @animate,
    @gif,

    test_examples,
    iter_segments,
    coords,

    translate,
    translate!,
    rotate,
    rotate!,
    center,
    BezierCurve,

    plotattr,
    scalefontsize,
    scalefontsizes,
    resetfontsizes
#! format: on
# ---------------------------------------------------------

import NaNMath # define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum(x::AbstractArray{F}) where {F<:AbstractFloat} = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum(x::AbstractArray{F}) where {F<:AbstractFloat} = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean(x::AbstractArray{F}) where {F<:AbstractFloat} = NaNMath.mean(x)
ignorenan_mean(x) = Statistics.mean(x)
ignorenan_extrema(x::AbstractArray{F}) where {F<:AbstractFloat} = NaNMath.extrema(x)
ignorenan_extrema(x) = Base.extrema(x)

# ---------------------------------------------------------

# to cater for block matrices, Base.transpose is recursive.
# This makes it impossible to create row vectors of String and Symbol with the transpose operator.
# This solves this issue, internally in Plots at least.

# commented out on the insistence of the METADATA maintainers

#Base.transpose(x::Symbol) = x
#Base.transpose(x::String) = x

# ---------------------------------------------------------

import Measures
module PlotMeasures
import Measures
import Measures:
    Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height, w, h
const BBox = Measures.Absolute2DBox

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct,Float64}(1.0)

Base.convert(::Type{<:Measure}, x::Float64) = x * pct

Base.:*(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.:*(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.:/(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.:/(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)

export BBox, BoundingBox, mm, cm, inch, px, pct, pt, w, h
end

using .PlotMeasures
import .PlotMeasures: Length, AbsoluteLength, Measure, width, height
# ---------------------------------------------------------

import RecipesPipeline
import RecipesPipeline:
    SliceIt,
    DefaultsDict,
    Formatted,
    AbstractSurface,
    Surface,
    Volume,
    is3d,
    is_surface,
    needs_3d_axes,
    group_as_matrix, # for StatsPlots
    reset_kw!,
    pop_kw!,
    scale_func,
    inverse_scale_func,
    unzip,
    dateformatter,
    datetimeformatter,
    timeformatter

# Use fixed version of Plotly instead of the latest one for stable dependency
# Ref: https://github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-1.57.1.min.js"

include("types.jl")
include("utils.jl")
include("colorbars.jl")
include("axes.jl")
include("args.jl")
include("components.jl")
include("consts.jl")
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("layouts.jl")
include("subplots.jl")
include("recipes.jl")
include("animation.jl")
include("examples.jl")
include("arg_desc.jl")
include("plotattr.jl")
include("backends.jl")
include("output.jl")
include("ijulia.jl")
include("fileio.jl")
include("init.jl")
include("legend.jl")

include("backends/plotly.jl")
include("backends/gr.jl")
include("backends/web.jl")

include("shorthands.jl")

let PlotOrSubplot = Union{Plot,Subplot}
    global title!(plt::PlotOrSubplot, s::AbstractString; kw...)                                                  = plot!(plt; title = s, kw...)
    global xlabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                                                 = plot!(plt; xlabel = s, kw...)
    global ylabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                                                 = plot!(plt; ylabel = s, kw...)
    global xlims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}                           = plot!(plt; xlims = lims, kw...)
    global ylims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}                           = plot!(plt; ylims = lims, kw...)
    global zlims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}                           = plot!(plt; zlims = lims, kw...)
    global xlims!(plt::PlotOrSubplot, xmin::Real, xmax::Real; kw...)                                             = plot!(plt; xlims = (xmin, xmax), kw...)
    global ylims!(plt::PlotOrSubplot, ymin::Real, ymax::Real; kw...)                                             = plot!(plt; ylims = (ymin, ymax), kw...)
    global zlims!(plt::PlotOrSubplot, zmin::Real, zmax::Real; kw...)                                             = plot!(plt; zlims = (zmin, zmax), kw...)
    global xticks!(plt::PlotOrSubplot, ticks::TicksArgs; kw...)                                                  = plot!(plt; xticks = ticks, kw...)
    global yticks!(plt::PlotOrSubplot, ticks::TicksArgs; kw...)                                                  = plot!(plt; yticks = ticks, kw...)
    global xticks!(plt::PlotOrSubplot, ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString} = plot!(plt; xticks = (ticks, labels), kw...)
    global yticks!(plt::PlotOrSubplot, ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString} = plot!(plt; yticks = (ticks, labels), kw...)
    global xgrid!(plt::PlotOrSubplot, args...; kw...)                                                            = plot!(plt; xgrid = args, kw...)
    global ygrid!(plt::PlotOrSubplot, args...; kw...)                                                            = plot!(plt; ygrid = args, kw...)
    global annotate!(plt::PlotOrSubplot, anns...; kw...)                                                         = plot!(plt; annotation = anns, kw...)
    global annotate!(plt::PlotOrSubplot, anns::AVec{T}; kw...) where {T<:Tuple}                                  = plot!(plt; annotation = anns, kw...)
    global xflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                                                  = plot!(plt; xflip = flip, kw...)
    global yflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                                                  = plot!(plt; yflip = flip, kw...)
    global xaxis!(plt::PlotOrSubplot, args...; kw...)                                                            = plot!(plt; xaxis = args, kw...)
    global yaxis!(plt::PlotOrSubplot, args...; kw...)                                                            = plot!(plt; yaxis = args, kw...)
end

# ---------------------------------------------------------

const CURRENT_BACKEND = CurrentBackend(:none)
const PLOTS_SEED = 1234

include("precompile_includer.jl")

end # module
