module Plots

_current_plots_version = v"0.24.0"

using Reexport

import GeometryTypes
using Dates, Printf, Statistics, Base64, LinearAlgebra, Random
import SparseArrays: findnz

@reexport using RecipesBase
import RecipesBase: plot, plot!, animate
using Base.Meta
@reexport using PlotUtils
@reexport using PlotThemes
import Showoff
import StatsBase
import JSON

using Requires

if isfile(joinpath(@__DIR__, "..", "deps", "deps.jl"))
    include(joinpath(@__DIR__, "..", "deps", "deps.jl"))
else
    # This is a bit dirty, but I don't really see why anyone should be forced
    # to build Plots, while it will just include exactly the below line
    # as long as `ENV["PLOTS_HOST_DEPENDENCY_LOCAL"] = "true"` is not set.
    # If the above env is set + `plotly_local_file_path == ""``,
    # it will warn in the __init__ function to run build
    const plotly_local_file_path = ""
end

export
    grid,
    bbox,
    plotarea,
    @layout,
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

    plotattr

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
import Measures: Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height, w, h
const BBox = Measures.Absolute2DBox

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct, Float64}(1.0)
export BBox, BoundingBox, mm, cm, inch, px, pct, pt, w, h
end

using .PlotMeasures
import .PlotMeasures: Length, AbsoluteLength, Measure, width, height
# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("components.jl")
include("axes.jl")
include("args.jl")
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("series.jl")
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

include("backends/plotly.jl")
include("backends/gr.jl")
include("backends/web.jl")

include("shorthands.jl")

let PlotOrSubplot = Union{Plot, Subplot}
    global title!(plt::PlotOrSubplot, s::AbstractString; kw...)                  = plot!(plt; title = s, kw...)
    global xlabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                 = plot!(plt; xlabel = s, kw...)
    global ylabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                 = plot!(plt; ylabel = s, kw...)
    global xlims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}  = plot!(plt; xlims = lims, kw...)
    global ylims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}  = plot!(plt; ylims = lims, kw...)
    global zlims!(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real}  = plot!(plt; zlims = lims, kw...)
    global xlims!(plt::PlotOrSubplot, xmin::Real, xmax::Real; kw...)             = plot!(plt; xlims = (xmin,xmax), kw...)
    global ylims!(plt::PlotOrSubplot, ymin::Real, ymax::Real; kw...)             = plot!(plt; ylims = (ymin,ymax), kw...)
    global zlims!(plt::PlotOrSubplot, zmin::Real, zmax::Real; kw...)             = plot!(plt; zlims = (zmin,zmax), kw...)
    global xticks!(plt::PlotOrSubplot, ticks::TicksArgs; kw...) where {T<:Real}           = plot!(plt; xticks = ticks, kw...)
    global yticks!(plt::PlotOrSubplot, ticks::TicksArgs; kw...) where {T<:Real}           = plot!(plt; yticks = ticks, kw...)
    global xticks!(plt::PlotOrSubplot,
   ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(plt; xticks = (ticks,labels), kw...)
    global yticks!(plt::PlotOrSubplot,
   ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(plt; yticks = (ticks,labels), kw...)
    global xgrid!(plt::PlotOrSubplot, args...; kw...)                  = plot!(plt; xgrid = args, kw...)
    global ygrid!(plt::PlotOrSubplot, args...; kw...)                  = plot!(plt; ygrid = args, kw...)
    global annotate!(plt::PlotOrSubplot, anns...; kw...)                         = plot!(plt; annotation = anns, kw...)
    global annotate!(plt::PlotOrSubplot, anns::AVec{T}; kw...) where {T<:Tuple}         = plot!(plt; annotation = anns, kw...)
    global xflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                  = plot!(plt; xflip = flip, kw...)
    global yflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                  = plot!(plt; yflip = flip, kw...)
    global xaxis!(plt::PlotOrSubplot, args...; kw...)                            = plot!(plt; xaxis = args, kw...)
    global yaxis!(plt::PlotOrSubplot, args...; kw...)                            = plot!(plt; yaxis = args, kw...)
end


# ---------------------------------------------------------

const CURRENT_BACKEND = CurrentBackend(:none)

end # module
