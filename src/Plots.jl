
 __precompile__()

module Plots

using Compat
using Reexport
@reexport using Colors
using Requires
using FixedSizeArrays

export
    AbstractPlot,
    Plot,
    Subplot,
    SubplotLayout,
    GridLayout,
    RowsLayout,
    FlexLayout,
    AVec,
    AMat,
    KW,

    wrap,
    set_theme,
    add_theme,

    plot,
    plot!,
    subplot,
    subplot!,

    current,
    default,
    with,

    scatter,
    scatter!,
    bar,
    bar!,
    barh,
    barh!,
    histogram,
    histogram!,
    histogram2d,
    histogram2d!,
    density,
    density!,
    heatmap,
    heatmap!,
    hexbin,
    hexbin!,
    sticks,
    sticks!,
    hline,
    hline!,
    vline,
    vline!,
    ohlc,
    ohlc!,
    pie,
    pie!,
    contour,
    contour!,
    contour3d,
    contour3d!,
    surface,
    surface!,
    wireframe,
    wireframe!,
    path3d,
    path3d!,
    plot3d,
    plot3d!,
    scatter3d,
    scatter3d!,
    abline!,
    boxplot,
    boxplot!,
    violin,
    violin!,
    quiver,
    quiver!,

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
    stroke,
    brush,
    Surface,
    OHLC,

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

    # recipes
    PlotRecipe,
    # EllipseRecipe,
    spy,
    arcdiagram,
    chorddiagram
    # corrplot


# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("colors.jl")
include("components.jl")
include("backends.jl")
include("args.jl")
include("plot.jl")
include("series_args.jl")
include("subplot.jl")
include("layouts.jl")
include("recipes.jl")
include("animation.jl")
include("output.jl")


# ---------------------------------------------------------

scatter(args...; kw...)    = plot(args...; kw...,  linetype = :scatter)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :scatter)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
barh(args...; kw...)        = plot(args...; kw...,  linetype = :barh, orientation = :h)
barh!(args...; kw...)       = plot!(args...; kw..., linetype = :barh, orientation = :h)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
histogram2d(args...; kw...)  = plot(args...; kw...,  linetype = :hist2d)
histogram2d!(args...; kw...) = plot!(args...; kw..., linetype = :hist2d)
density(args...; kw...)    = plot(args...; kw...,  linetype = :density)
density!(args...; kw...)   = plot!(args...; kw..., linetype = :density)
heatmap(args...; kw...)    = plot(args...; kw...,  linetype = :heatmap)
heatmap!(args...; kw...)   = plot!(args...; kw..., linetype = :heatmap)
hexbin(args...; kw...)     = plot(args...; kw...,  linetype = :hexbin)
hexbin!(args...; kw...)    = plot!(args...; kw..., linetype = :hexbin)
sticks(args...; kw...)     = plot(args...; kw...,  linetype = :sticks, marker = :ellipse)
sticks!(args...; kw...)    = plot!(args...; kw..., linetype = :sticks, marker = :ellipse)
hline(args...; kw...)      = plot(args...; kw...,  linetype = :hline)
hline!(args...; kw...)     = plot!(args...; kw..., linetype = :hline)
vline(args...; kw...)      = plot(args...; kw...,  linetype = :vline)
vline!(args...; kw...)     = plot!(args...; kw..., linetype = :vline)
ohlc(args...; kw...)       = plot(args...; kw...,  linetype = :ohlc)
ohlc!(args...; kw...)      = plot!(args...; kw..., linetype = :ohlc)
pie(args...; kw...)        = plot(args...; kw...,  linetype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
pie!(args...; kw...)       = plot!(args...; kw..., linetype = :pie, aspect_ratio = :equal, grid=false, xticks=nothing, yticks=nothing)
contour(args...; kw...)    = plot(args...; kw...,  linetype = :contour)
contour!(args...; kw...)   = plot!(args...; kw..., linetype = :contour)
contour3d(args...; kw...)  = plot(args...; kw...,  linetype = :contour3d)
contour3d!(args...; kw...) = plot!(args...; kw..., linetype = :contour3d)
surface(args...; kw...)    = plot(args...; kw...,  linetype = :surface)
surface!(args...; kw...)   = plot!(args...; kw..., linetype = :surface)
wireframe(args...; kw...)  = plot(args...; kw...,  linetype = :wireframe)
wireframe!(args...; kw...) = plot!(args...; kw..., linetype = :wireframe)
path3d(args...; kw...)     = plot(args...; kw...,  linetype = :path3d)
path3d!(args...; kw...)    = plot!(args...; kw..., linetype = :path3d)
plot3d(args...; kw...)     = plot(args...; kw...,  linetype = :path3d)
plot3d!(args...; kw...)    = plot!(args...; kw..., linetype = :path3d)
scatter3d(args...; kw...)  = plot(args...; kw...,  linetype = :scatter3d)
scatter3d!(args...; kw...) = plot!(args...; kw..., linetype = :scatter3d)
boxplot(args...; kw...)    = plot(args...; kw...,  linetype = :box)
boxplot!(args...; kw...)   = plot!(args...; kw..., linetype = :box)
violin(args...; kw...)     = plot(args...; kw...,  linetype = :violin)
violin!(args...; kw...)    = plot!(args...; kw..., linetype = :violin)
quiver(args...; kw...)     = plot(args...; kw...,  linetype = :quiver)
quiver!(args...; kw...)    = plot!(args...; kw..., linetype = :quiver)


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

  # override IJulia inline display
  if isijulia()
    @eval import IJulia
    IJulia.display_dict(plt::AbstractPlot) = Dict{ASCIIString, ByteString}("text/html" => sprint(writemime, "text/html", plt))
  end

  setup_dataframes()
  setup_atom()
end

# ---------------------------------------------------------

end # module
