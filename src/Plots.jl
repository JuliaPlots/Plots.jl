__precompile__()

module Plots

using Colors

export
  plotter,
  plot,
  subplot,

  plotter!,
  plot!,
  subplot!,

  currentPlot,
  plotDefault,
  scatter,
  bar,
  histogram,
  heatmap,

  currentPlot!,
  plotDefault!,
  scatter!,
  bar!,
  histogram!,
  heatmap!,

  savepng

# ---------------------------------------------------------


const IMG_DIR = Pkg.dir("Plots") * "/img/"


# ---------------------------------------------------------

include("types.jl")
include("utils.jl")

# ---------------------------------------------------------

include("qwt.jl")
include("gadfly.jl")
include("plotter.jl")

# ---------------------------------------------------------

include("args.jl")
include("plot.jl")
include("subplot.jl")


# ---------------------------------------------------------

scatter(args...; kw...)    = plot(args...; kw...,  linetype = :none, marker = :hexagon)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :none, marker = :hexagon)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
heatmap(args...; kw...)    = plot(args...; kw...,  linetype = :heatmap)
heatmap!(args...; kw...)   = plot!(args...; kw..., linetype = :heatmap)


# ---------------------------------------------------------


savepng(args...; kw...) = savepng(currentPlot(), args...; kw...)
savepng(plt::PlottingObject, args...; kw...) = savepng(plt.plotter, plt, args...; kw...)


# ---------------------------------------------------------

end # module
