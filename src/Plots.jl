
__precompile__()

module Plots

# using Compat
using Reexport
# @reexport using Colors
# using Requires
using FixedSizeArrays
@reexport using RecipesBase
using Base.Meta
@reexport using PlotUtils
import Showoff

export
    AbstractPlot,
    Plot,
    Subplot,
    AbstractLayout,
    GridLayout,
    grid,
    EmptyLayout,
    bbox,
    plotarea,
    @layout,
    AVec,
    AMat,
    KW,

    wrap,
    set_theme,
    add_theme,

    plot,
    plot!,
    update!,

    current,
    default,
    with,
    twinx,

    @userplot,
    @shorthands,

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

    savefig,
    png,
    gui,

    backend,
    backends,
    backend_name,
    backend_object,
    add_backend,
    aliases,
    # dataframes,

    Shape,
    text,
    font,
    Axis,
    stroke,
    brush,
    Surface,
    OHLC,
    arrow,
    Segments,

    Animation,
    frame,
    gif,
    @animate,
    @gif,

    spy,

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
    curve_points,
    directed_curve

# ---------------------------------------------------------

import Measures
import Measures: Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height, w, h
typealias BBox Measures.Absolute2DBox
export BBox, BoundingBox, mm, cm, inch, pt, px, pct, w, h

# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("components.jl")
include("axes.jl")
include("args.jl")
include("backends.jl")
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("series.jl")
include("layouts.jl")
include("subplots.jl")
include("recipes.jl")
include("animation.jl")
include("output.jl")
include("examples.jl")
include("arg_desc.jl")


# ---------------------------------------------------------

# define and export shorthand plotting method definitions
macro shorthands(funcname::Symbol)
    funcname2 = Symbol(funcname, "!")
    esc(quote
        export $funcname, $funcname2
        $funcname(args...; kw...) = plot(args...; kw..., seriestype = $(quot(funcname)))
        $funcname2(args...; kw...) = plot!(args...; kw..., seriestype = $(quot(funcname)))
    end)
end

@shorthands scatter
@shorthands bar
@shorthands barh
@shorthands histogram
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

pie(args...; kw...)        = plot(args...; kw...,  seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
pie!(args...; kw...)       = plot!(args...; kw..., seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
plot3d(args...; kw...)     = plot(args...; kw...,  seriestype = :path3d)
plot3d!(args...; kw...)    = plot!(args...; kw..., seriestype = :path3d)


title!(s::AbstractString; kw...)                 = plot!(; title = s, kw...)
xlabel!(s::AbstractString; kw...)                = plot!(; xlabel = s, kw...)
ylabel!(s::AbstractString; kw...)                = plot!(; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; ylims = lims, kw...)
zlims!{T<:Real,S<:Real}(lims::Tuple{T,S}; kw...) = plot!(; zlims = lims, kw...)
xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
zlims!(zmin::Real, zmax::Real; kw...)                     = plot!(; zlims = (zmin,zmax), kw...)
xticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; xticks = v, kw...)
yticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; yticks = v, kw...)
xticks!{T<:Real,S<:AbstractString}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:AbstractString}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; yticks = (ticks,labels), kw...)
annotate!(anns...; kw...)                                 = plot!(; annotation = anns, kw...)
annotate!{T<:Tuple}(anns::AVec{T}; kw...)                 = plot!(; annotation = anns, kw...)
xflip!(flip::Bool = true; kw...)                          = plot!(; xflip = flip, kw...)
yflip!(flip::Bool = true; kw...)                          = plot!(; yflip = flip, kw...)
xaxis!(args...; kw...)                                    = plot!(; xaxis = args, kw...)
yaxis!(args...; kw...)                                    = plot!(; yaxis = args, kw...)

title!(plt::Plot, s::AbstractString; kw...)                  = plot!(plt; title = s, kw...)
xlabel!(plt::Plot, s::AbstractString; kw...)                 = plot!(plt; xlabel = s, kw...)
ylabel!(plt::Plot, s::AbstractString; kw...)                 = plot!(plt; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(plt::Plot, lims::Tuple{T,S}; kw...)  = plot!(plt; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(plt::Plot, lims::Tuple{T,S}; kw...)  = plot!(plt; ylims = lims, kw...)
zlims!{T<:Real,S<:Real}(plt::Plot, lims::Tuple{T,S}; kw...)  = plot!(plt; zlims = lims, kw...)
xlims!(plt::Plot, xmin::Real, xmax::Real; kw...)                      = plot!(plt; xlims = (xmin,xmax), kw...)
ylims!(plt::Plot, ymin::Real, ymax::Real; kw...)                      = plot!(plt; ylims = (ymin,ymax), kw...)
zlims!(plt::Plot, zmin::Real, zmax::Real; kw...)                      = plot!(plt; zlims = (zmin,zmax), kw...)
xticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; xticks = ticks, kw...)
yticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; yticks = ticks, kw...)
xticks!{T<:Real,S<:AbstractString}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:AbstractString}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; yticks = (ticks,labels), kw...)
annotate!(plt::Plot, anns...; kw...)                                  = plot!(plt; annotation = anns, kw...)
annotate!{T<:Tuple}(plt::Plot, anns::AVec{T}; kw...)                  = plot!(plt; annotation = anns, kw...)
xflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; xflip = flip, kw...)
yflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; yflip = flip, kw...)
xaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; xaxis = args, kw...)
yaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; yaxis = args, kw...)



# ---------------------------------------------------------

const CURRENT_BACKEND = CurrentBackend(:none)

function __init__()
    setup_ijulia()
    setup_atom()

    if isdefined(Main, :PLOTS_DEFAULTS)
        for (k,v) in Main.PLOTS_DEFAULTS
            default(k, v)
        end
    end
end

# ---------------------------------------------------------

# if VERSION >= v"0.4.0-dev+5512"
#     include("precompile.jl")
#     _precompile_()
# end

# ---------------------------------------------------------

end # module
