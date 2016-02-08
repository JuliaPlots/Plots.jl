
 __precompile__()

module Plots

using Compat
using Reexport
@reexport using Colors
using Requires

export
  Plot,
  Subplot,
  SubplotLayout,
  GridLayout,
  FlexLayout,
  AVec,
  AMat,

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
  histogram,
  histogram!,
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

  title!,
  xlabel!,
  ylabel!,
  xlims!,
  ylims!,
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

  # recipes
  PlotRecipe,
  # EllipseRecipe,
  # spy,
  corrplot


# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("colors.jl")
include("components.jl")
include("plotter2.jl")
include("args.jl")
include("plot.jl")
include("subplot.jl")
include("recipes.jl")
include("animation.jl")
include("output.jl")


# ---------------------------------------------------------

scatter(args...; kw...)    = plot(args...; kw...,  linetype = :scatter)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :scatter)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
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
pie(args...; kw...)        = plot(args...; kw...,  linetype = :pie)
pie!(args...; kw...)       = plot!(args...; kw..., linetype = :pie)
contour(args...; kw...)    = plot(args...; kw...,  linetype = :contour)
contour!(args...; kw...)   = plot!(args...; kw..., linetype = :contour)
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


title!(s::@compat(AbstractString); kw...)                 = plot!(; title = s, kw...)
xlabel!(s::@compat(AbstractString); kw...)                = plot!(; xlabel = s, kw...)
ylabel!(s::@compat(AbstractString); kw...)                = plot!(; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S}); kw...) = plot!(; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S}); kw...) = plot!(; ylims = lims, kw...)
xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
xticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; xticks = v, kw...)
yticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; yticks = v, kw...)
xticks!{T<:Real,S<:@compat(AbstractString)}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:@compat(AbstractString)}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; yticks = (ticks,labels), kw...)
annotate!(anns...; kw...)                                 = plot!(; annotation = anns, kw...)
annotate!{T<:Tuple}(anns::AVec{T}; kw...)                 = plot!(; annotation = anns, kw...)
xflip!(flip::Bool = true; kw...)                          = plot!(; xflip = flip, kw...)
yflip!(flip::Bool = true; kw...)                          = plot!(; yflip = flip, kw...)
xaxis!(args...; kw...)                                    = plot!(; xaxis = args, kw...)
yaxis!(args...; kw...)                                    = plot!(; yaxis = args, kw...)

title!(plt::Plot, s::@compat(AbstractString); kw...)                  = plot!(plt; title = s, kw...)
xlabel!(plt::Plot, s::@compat(AbstractString); kw...)                 = plot!(plt; xlabel = s, kw...)
ylabel!(plt::Plot, s::@compat(AbstractString); kw...)                 = plot!(plt; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}); kw...)  = plot!(plt; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}); kw...)  = plot!(plt; ylims = lims, kw...)
xlims!(plt::Plot, xmin::Real, xmax::Real; kw...)                      = plot!(plt; xlims = (xmin,xmax), kw...)
ylims!(plt::Plot, ymin::Real, ymax::Real; kw...)                      = plot!(plt; ylims = (ymin,ymax), kw...)
xticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; xticks = ticks, kw...)
yticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; yticks = ticks, kw...)
xticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; yticks = (ticks,labels), kw...)
annotate!(plt::Plot, anns...; kw...)                                  = plot!(plt; annotation = anns, kw...)
annotate!{T<:Tuple}(plt::Plot, anns::AVec{T}; kw...)                  = plot!(plt; annotation = anns, kw...)
xflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; xflip = flip, kw...)
yflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; yflip = flip, kw...)
xaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; xaxis = args, kw...)
yaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; yaxis = args, kw...)



# ---------------------------------------------------------


# try
#   import DataFrames
#   dataframes()
# end

# const CURRENT_BACKEND = pickDefaultBackend()

# for be in backends()
#   try
#     backend(be)
#     backend()
#   catch err
#     @show err
#   end
# end

const CURRENT_BACKEND = CurrentBackend(:none)

# function __init__()
#   # global const CURRENT_BACKEND = pickDefaultBackend()
#   # global const CURRENT_BACKEND = CurrentBackend(:none)

#   # global CURRENT_BACKEND
#   # println("[Plots.jl] Default backend: ", CURRENT_BACKEND.sym)

#   # # auto init dataframes if the import statement doesn't error out
#   # try
#   #   @eval import DataFrames
#   #   dataframes()
#   # end
# end

# ---------------------------------------------------------

end # module
