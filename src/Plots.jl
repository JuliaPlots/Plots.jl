module Plots

using Colors

export
  Plot,
  plotter,
  plot,
  currentPlot,
  plotDefault,
  scatter,
  bar,
  hist,
  heatmap,

  plotter!,
  plot!,
  currentPlot!,
  plotDefault!,
  scatter!,
  bar!,
  hist!,
  heatmap!,

  savepng

# ---------------------------------------------------------

typealias AVec AbstractVector
typealias AMat AbstractMatrix

abstract PlottingPackage

const IMG_DIR = "$(ENV["HOME"])/.julia/v0.4/Plots/img/"


# ---------------------------------------------------------

type Plot
  o  # the underlying object
  plotter::PlottingPackage
end


type CurrentPlot
  nullableplot::Nullable{Plot}
end
const CURRENT_PLOT = CurrentPlot(Nullable{Plot}())

isplotnull() = isnull(CURRENT_PLOT.nullableplot)

function currentPlot()
  if isplotnull()
    error("No current plot")
  end
  get(CURRENT_PLOT.nullableplot)
end
currentPlot!(plot) = (CURRENT_PLOT.nullableplot = Nullable(plot))

# ---------------------------------------------------------

include("plotter.jl")
include("qwt.jl")
include("gadfly.jl")

# ---------------------------------------------------------

include("args.jl")
include("plot.jl")


# const LINE_TYPES = (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hist, :bar)
scatter(args...; kw...) = plot(args...; kw..., linetype = :dots)
scatter!(args...; kw...) = plot!(args...; kw..., linetype = :dots)
bar(args...; kw...) = plot(args...; kw..., linetype = :bar)
bar!(args...; kw...) = plot!(args...; kw..., linetype = :bar)
hist(args...; kw...) = plot(args...; kw..., linetype = :hist)
hist!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
heatmap(args...; kw...) = plot(args...; kw..., linetype = :heatmap)
heatmap!(args...; kw...) = plot!(args...; kw..., linetype = :heatmap)


# ---------------------------------------------------------

# # TODO: how do we handle NA values in dataframes?
# function plot!(plt::Plot, df::DataFrame; kw...)                 # one line per DataFrame column, labels == names(df)
# end

# function plot!(plt::Plot, df::DataFrame, columns; kw...)        # one line per column, but on a subset of column names
# end


# plot(args...; kw...) = currentPlot!(plot(plotter(), args...; kw...))



# subplot(args...; kw...) = subplot(plotter(), args...; kw...)
savepng(args...; kw...) = savepng(plotter(), args...; kw...)



# ---------------------------------------------------------

end # module
