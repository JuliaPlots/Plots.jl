module Plots

using Reexport

import StaticArrays
using StaticArrays.FixedSizeArrays
using Dates, Printf, Statistics, Base64, LinearAlgebra
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
include("init.jl")

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
@shorthands plots_heatmap
@shorthands hexbin
@shorthands sticks
@shorthands hline
@shorthands vline
@shorthands hspan
@shorthands vspan
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
xlims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; xlims = lims, kw...)

"Set ylims for an existing plot"
ylims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; ylims = lims, kw...)

"Set zlims for an existing plot"
zlims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; zlims = lims, kw...)

xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
zlims!(zmin::Real, zmax::Real; kw...)                     = plot!(; zlims = (zmin,zmax), kw...)


"Set xticks for an existing plot"
xticks!(v::TicksArgs; kw...) where {T<:Real}                       = plot!(; xticks = v, kw...)

"Set yticks for an existing plot"
yticks!(v::TicksArgs; kw...) where {T<:Real}                       = plot!(; yticks = v, kw...)

xticks!(
ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(; xticks = (ticks,labels), kw...)
yticks!(
ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(; yticks = (ticks,labels), kw...)

"Add annotations to an existing plot"
annotate!(anns...; kw...)                                 = plot!(; annotation = anns, kw...)
annotate!(anns::AVec{T}; kw...) where {T<:Tuple}                 = plot!(; annotation = anns, kw...)

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
