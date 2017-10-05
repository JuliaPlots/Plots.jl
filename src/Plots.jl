__precompile__(true)

module Plots

using Reexport

import StaticArrays
using StaticArrays.FixedSizeArrays

@reexport using RecipesBase
import RecipesBase: plot, plot!, animate
using Base.Meta
@reexport using PlotUtils
@reexport using PlotThemes
import Showoff
import StatsBase

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
    add_backend,
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
    P2,
    P3,
    BezierCurve,

    plotattr

# ---------------------------------------------------------

import NaNMath # define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum{F<:AbstractFloat}(x::AbstractArray{F}) = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum{F<:AbstractFloat}(x::AbstractArray{F}) = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean{F<:AbstractFloat}(x::AbstractArray{F}) = NaNMath.mean(x)
ignorenan_mean(x) = Base.mean(x)
ignorenan_extrema{F<:AbstractFloat}(x::AbstractArray{F}) = NaNMath.extrema(x)
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

# ---------------------------------------------------------

@shorthands scatter
@shorthands bar
@shorthands barh
@shorthands histogram
@shorthands barhist
@shorthands stephist
@shorthands scatterhist
@shorthands histogram2d
@shorthands density
@shorthands heatmap
@shorthands hexbin
@shorthands sticks
@shorthands hline
@shorthands vline
@shorthands ohlc
@shorthands contour
@shorthands contourf
@shorthands contour3d
@shorthands surface
@shorthands wireframe
@shorthands path3d
@shorthands scatter3d
@shorthands boxplot
@shorthands violin
@shorthands quiver
@shorthands curves

"Plot a pie diagram"
pie(args...; kw...)        = plot(args...; kw...,  seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
pie!(args...; kw...)       = plot!(args...; kw..., seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)

"Plot with seriestype :path3d"
plot3d(args...; kw...)     = plot(args...; kw...,  seriestype = :path3d)
plot3d!(args...; kw...)    = plot!(args...; kw..., seriestype = :path3d)

"Add title to an existing plot"
title!(s::AbstractString; kw...)                 = plot!(; title = s, kw...)

"Add xlabel to an existing plot"
xlabel!(s::AbstractString; kw...)                = plot!(; xlabel = s, kw...)

"Add ylabel to an existing plot"
ylabel!(s::AbstractString; kw...)                = plot!(; ylabel = s, kw...)

"Set xlims for an existing plot"
xlims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; xlims = lims, kw...)

"Set ylims for an existing plot"
ylims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; ylims = lims, kw...)

"Set zlims for an existing plot"
zlims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; zlims = lims, kw...)

xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
zlims!(zmin::Real, zmax::Real; kw...)                     = plot!(; zlims = (zmin,zmax), kw...)


"Set xticks for an existing plot"
xticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; xticks = v, kw...)

"Set yticks for an existing plot"
yticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; yticks = v, kw...)

xticks!{T<:Real,S<:AbstractString}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:AbstractString}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; yticks = (ticks,labels), kw...)

"Add annotations to an existing plot"
annotate!(anns...; kw...)                                 = plot!(; annotation = anns, kw...)
annotate!{T<:Tuple}(anns::AVec{T}; kw...)                 = plot!(; annotation = anns, kw...)

"Flip the current plots' x axis"
xflip!(flip::Bool = true; kw...)                          = plot!(; xflip = flip, kw...)

"Flip the current plots' y axis"
yflip!(flip::Bool = true; kw...)                          = plot!(; yflip = flip, kw...)

"Specify x axis attributes for an existing plot"
xaxis!(args...; kw...)                                    = plot!(; xaxis = args, kw...)

"Specify x axis attributes for an existing plot"
yaxis!(args...; kw...)                                    = plot!(; yaxis = args, kw...)
xgrid!(args...; kw...)                                    = plot!(; xgrid = args, kw...)
ygrid!(args...; kw...)                                    = plot!(; ygrid = args, kw...)

let PlotOrSubplot = Union{Plot, Subplot}
    title!(plt::PlotOrSubplot, s::AbstractString; kw...)                  = plot!(plt; title = s, kw...)
    xlabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                 = plot!(plt; xlabel = s, kw...)
    ylabel!(plt::PlotOrSubplot, s::AbstractString; kw...)                 = plot!(plt; ylabel = s, kw...)
    xlims!{T<:Real,S<:Real}(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...)  = plot!(plt; xlims = lims, kw...)
    ylims!{T<:Real,S<:Real}(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...)  = plot!(plt; ylims = lims, kw...)
    zlims!{T<:Real,S<:Real}(plt::PlotOrSubplot, lims::Tuple{T,S}; kw...)  = plot!(plt; zlims = lims, kw...)
    xlims!(plt::PlotOrSubplot, xmin::Real, xmax::Real; kw...)             = plot!(plt; xlims = (xmin,xmax), kw...)
    ylims!(plt::PlotOrSubplot, ymin::Real, ymax::Real; kw...)             = plot!(plt; ylims = (ymin,ymax), kw...)
    zlims!(plt::PlotOrSubplot, zmin::Real, zmax::Real; kw...)             = plot!(plt; zlims = (zmin,zmax), kw...)
    xticks!{T<:Real}(plt::PlotOrSubplot, ticks::AVec{T}; kw...)           = plot!(plt; xticks = ticks, kw...)
    yticks!{T<:Real}(plt::PlotOrSubplot, ticks::AVec{T}; kw...)           = plot!(plt; yticks = ticks, kw...)
    xticks!{T<:Real,S<:AbstractString}(plt::PlotOrSubplot,
                              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; xticks = (ticks,labels), kw...)
    yticks!{T<:Real,S<:AbstractString}(plt::PlotOrSubplot,
                              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; yticks = (ticks,labels), kw...)
    xgrid!(plt::PlotOrSubplot, args...; kw...)                  = plot!(plt; xgrid = args, kw...)
    ygrid!(plt::PlotOrSubplot, args...; kw...)                  = plot!(plt; ygrid = args, kw...)
    annotate!(plt::PlotOrSubplot, anns...; kw...)                         = plot!(plt; annotation = anns, kw...)
    annotate!{T<:Tuple}(plt::PlotOrSubplot, anns::AVec{T}; kw...)         = plot!(plt; annotation = anns, kw...)
    xflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                  = plot!(plt; xflip = flip, kw...)
    yflip!(plt::PlotOrSubplot, flip::Bool = true; kw...)                  = plot!(plt; yflip = flip, kw...)
    xaxis!(plt::PlotOrSubplot, args...; kw...)                            = plot!(plt; xaxis = args, kw...)
    yaxis!(plt::PlotOrSubplot, args...; kw...)                            = plot!(plt; yaxis = args, kw...)
end


# ---------------------------------------------------------

const CURRENT_BACKEND = CurrentBackend(:none)

# for compatibility with Requires.jl:
@init begin
    if isdefined(Main, :PLOTS_DEFAULTS)
        for (k,v) in Main.PLOTS_DEFAULTS
            default(k, v)
        end
    end
end

# ---------------------------------------------------------

end # module
