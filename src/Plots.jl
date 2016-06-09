
 __precompile__()

module Plots

using Compat
using Reexport
@reexport using Colors
# using Requires
using FixedSizeArrays
@reexport using RecipesBase
using Base.Meta

export
    AbstractPlot,
    Plot,
    Subplot,
    AbstractLayout,
    GridLayout,
    grid,
    EmptyLayout,
    @layout,
    # RowsLayout,
    # FlexLayout,
    AVec,
    AMat,
    KW,
    # attr,
    # attr!,

    wrap,
    set_theme,
    add_theme,

    plot,
    plot!,
    # subplot,
    # subplot!,

    current,
    default,
    with,

    @userplot,
    @shorthands,
    # scatter,
    # scatter!,
    # bar,
    # bar!,
    # barh,
    # barh!,
    # histogram,
    # histogram!,
    # histogram2d,
    # histogram2d!,
    # density,
    # density!,
    # heatmap,
    # heatmap!,
    # hexbin,
    # hexbin!,
    # sticks,
    # sticks!,
    # hline,
    # hline!,
    # vline,
    # vline!,
    # ohlc,
    # ohlc!,
    pie,
    pie!,
    # contour,
    # contour!,
    # contour3d,
    # contour3d!,
    # surface,
    # surface!,
    # wireframe,
    # wireframe!,
    # path3d,
    # path3d!,
    plot3d,
    plot3d!,
    # scatter3d,
    # scatter3d!,
    # abline!,
    # boxplot,
    # boxplot!,
    # violin,
    # violin!,
    # quiver,
    # quiver!,

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
    aliases,
    dataframes,

    Shape,
    text,
    font,
    Axis,
    # xaxis,
    # yaxis,
    # zaxis,
    stroke,
    brush,
    Surface,
    OHLC,
    arrow,

    colorscheme,
    ColorScheme,
    ColorGradient,
    ColorVector,
    ColorWrapper,
    ColorFunction,
    ColorZFunction,
    getColor,
    getColorZ,

    debugplots,

    supportedArgs,
    supportedAxes,
    supportedTypes,
    supportedStyles,
    supportedMarkers,
    subplotSupported,

    Animation,
    frame,
    gif,
    @animate,
    @gif,

    PlotRecipe,
    spy,
    arcdiagram,
    chorddiagram,

    # @kw,
    # @recipe,
    # @plotrecipe,

    test_examples,

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
import Measures: Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height
typealias BBox Measures.Absolute2DBox
export BBox, BoundingBox, mm, cm, inch, pt, px, pct

# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("colors.jl")
include("components.jl")
include("axes.jl")
include("backends.jl")
include("args.jl")
include("themes.jl")
include("plot.jl")
include("series_args.jl")
include("series_new.jl")
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
    ret = esc(quote
        export $funcname, $funcname2
        $funcname(args...; kw...) = plot(args...; kw..., seriestype = $(quot(funcname)))
        $funcname2(args...; kw...) = plot!(args...; kw..., seriestype = $(quot(funcname)))
    end)
    # dump(ret,20)
    # @show ret
    ret
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
# @shorthands pie
@shorthands contour
@shorthands contour3d
@shorthands surface
@shorthands wireframe
@shorthands path3d
@shorthands scatter3d
@shorthands boxplot
@shorthands violin
@shorthands quiver

# scatter(args...; kw...)    = plot(args...; kw...,  seriestype = :scatter)
# scatter!(args...; kw...)   = plot!(args...; kw..., seriestype = :scatter)
# bar(args...; kw...)        = plot(args...; kw...,  seriestype = :bar)
# bar!(args...; kw...)       = plot!(args...; kw..., seriestype = :bar)
# barh(args...; kw...)        = plot(args...; kw...,  seriestype = :barh, orientation = :h)
# barh!(args...; kw...)       = plot!(args...; kw..., seriestype = :barh, orientation = :h)
# histogram(args...; kw...)  = plot(args...; kw...,  seriestype = :histogram)
# histogram!(args...; kw...) = plot!(args...; kw..., seriestype = :histogram)
# histogram2d(args...; kw...)  = plot(args...; kw...,  seriestype = :histogram2d)
# histogram2d!(args...; kw...) = plot!(args...; kw..., seriestype = :histogram2d)
# density(args...; kw...)    = plot(args...; kw...,  seriestype = :density)
# density!(args...; kw...)   = plot!(args...; kw..., seriestype = :density)
# heatmap(args...; kw...)    = plot(args...; kw...,  seriestype = :heatmap)
# heatmap!(args...; kw...)   = plot!(args...; kw..., seriestype = :heatmap)
# hexbin(args...; kw...)     = plot(args...; kw...,  seriestype = :hexbin)
# hexbin!(args...; kw...)    = plot!(args...; kw..., seriestype = :hexbin)
# sticks(args...; kw...)     = plot(args...; kw...,  seriestype = :sticks, marker = :ellipse)
# sticks!(args...; kw...)    = plot!(args...; kw..., seriestype = :sticks, marker = :ellipse)
# hline(args...; kw...)      = plot(args...; kw...,  seriestype = :hline)
# hline!(args...; kw...)     = plot!(args...; kw..., seriestype = :hline)
# vline(args...; kw...)      = plot(args...; kw...,  seriestype = :vline)
# vline!(args...; kw...)     = plot!(args...; kw..., seriestype = :vline)
# ohlc(args...; kw...)       = plot(args...; kw...,  seriestype = :ohlc)
# ohlc!(args...; kw...)      = plot!(args...; kw..., seriestype = :ohlc)
pie(args...; kw...)        = plot(args...; kw...,  seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
pie!(args...; kw...)       = plot!(args...; kw..., seriestype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
# contour(args...; kw...)    = plot(args...; kw...,  seriestype = :contour)
# contour!(args...; kw...)   = plot!(args...; kw..., seriestype = :contour)
# contour3d(args...; kw...)  = plot(args...; kw...,  seriestype = :contour3d)
# contour3d!(args...; kw...) = plot!(args...; kw..., seriestype = :contour3d)
# surface(args...; kw...)    = plot(args...; kw...,  seriestype = :surface)
# surface!(args...; kw...)   = plot!(args...; kw..., seriestype = :surface)
# wireframe(args...; kw...)  = plot(args...; kw...,  seriestype = :wireframe)
# wireframe!(args...; kw...) = plot!(args...; kw..., seriestype = :wireframe)
# path3d(args...; kw...)     = plot(args...; kw...,  seriestype = :path3d)
# path3d!(args...; kw...)    = plot!(args...; kw..., seriestype = :path3d)
plot3d(args...; kw...)     = plot(args...; kw...,  seriestype = :path3d)
plot3d!(args...; kw...)    = plot!(args...; kw..., seriestype = :path3d)
# scatter3d(args...; kw...)  = plot(args...; kw...,  seriestype = :scatter3d)
# scatter3d!(args...; kw...) = plot!(args...; kw..., seriestype = :scatter3d)
# boxplot(args...; kw...)    = plot(args...; kw...,  seriestype = :boxplot)
# boxplot!(args...; kw...)   = plot!(args...; kw..., seriestype = :boxplot)
# violin(args...; kw...)     = plot(args...; kw...,  seriestype = :violin)
# violin!(args...; kw...)    = plot!(args...; kw..., seriestype = :violin)
# quiver(args...; kw...)     = plot(args...; kw...,  seriestype = :quiver)
# quiver!(args...; kw...)    = plot!(args...; kw..., seriestype = :quiver)


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

# setup_dataframes()

function __init__()
    setup_ijulia()
    # setup_dataframes()
    setup_atom()
    # add_axis_letter_defaults()
end

# ---------------------------------------------------------

end # module
