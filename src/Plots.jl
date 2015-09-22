__precompile__()

module Plots

using Reexport
@reexport using Colors

export
  plotter,
  plotter!,
  plot,
  plot!,
  plot_display,
  plot_display!,
  subplot,
  subplot!,

  currentPlot,
  currentPlot!,
  plotDefault,
  plotDefault!,
  scatter,
  scatter!,
  bar,
  bar!,
  histogram,
  histogram!,
  heatmap,
  heatmap!,
  sticks,
  sticks!,
  hline,
  hline!,
  vline,
  vline!,
  ohlc,
  ohlc!,

  title!,
  xlabel!,
  ylabel!,

  savepng,
  gui,

  backends,
  aliases,
  dataframes!,
  OHLC,

  supportedArgs,
  supportedAxes,
  supportedTypes,
  supportedStyles,
  supportedMarkers,
  subplotSupported

# ---------------------------------------------------------


const IMG_DIR = Pkg.dir("Plots") * "/img/"


# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("colors.jl")
include("plotter.jl")
include("args.jl")
include("plot.jl")
include("subplot.jl")


# ---------------------------------------------------------

scatter(args...; kw...)    = plot(args...; kw...,  linetype = :scatter)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :scatter)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
heatmap(args...; kw...)    = plot(args...; kw...,  linetype = :heatmap)
heatmap!(args...; kw...)   = plot!(args...; kw..., linetype = :heatmap)
sticks(args...; kw...)     = plot(args...; kw...,  linetype = :sticks, marker = :ellipse)
sticks!(args...; kw...)    = plot!(args...; kw..., linetype = :sticks, marker = :ellipse)
hline(args...; kw...)      = plot(args...; kw...,  linetype = :hline)
hline!(args...; kw...)     = plot!(args...; kw..., linetype = :hline)
vline(args...; kw...)      = plot(args...; kw...,  linetype = :vline)
vline!(args...; kw...)     = plot!(args...; kw..., linetype = :vline)
ohlc(args...; kw...)       = plot(args...; kw...,  linetype = :ohlc)
ohlc!(args...; kw...)      = plot!(args...; kw..., linetype = :ohlc)


title!(s::AbstractString) = plot!(title = s)
xlabel!(s::AbstractString) = plot!(xlabel = s)
ylabel!(s::AbstractString) = plot!(ylabel = s)

title!(plt::Plot, s::AbstractString) = plot!(plt; title = s)
xlabel!(plt::Plot, s::AbstractString) = plot!(plt; xlabel = s)
ylabel!(plt::Plot, s::AbstractString) = plot!(plt; ylabel = s)


# ---------------------------------------------------------


savepng(args...; kw...) = savepng(currentPlot(), args...; kw...)
savepng(plt::PlottingObject, fn::AbstractString; kw...) = (io = open(fn, "w"); writemime(io, MIME("image/png"), plt); close(io))
# savepng(plt::PlottingObject, args...; kw...) = savepng(plt.plotter, plt, args...; kw...)
# savepng(::PlottingPackage, plt::PlottingObject, fn::AbstractString, args...) = error("unsupported")  # fallback so multiple dispatch doesn't get confused if it's missing


gui(plt::PlottingObject = currentPlot()) = display(PlotsDisplay(), plt)


# override the REPL display to open a gui window
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::PlottingObject) = gui(plt)



function __init__()
  global const CURRENT_BACKEND = pickDefaultBackend()
  println("[Plots.jl] Default backend: ", CURRENT_BACKEND.sym)
end

# ---------------------------------------------------------

end # module
