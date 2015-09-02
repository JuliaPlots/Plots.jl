module Plots

export
  Plot,
  plotter,
  plotter!,
  plot,
  plot!,
  savepng

# ---------------------------------------------------------

typealias AVec AbstractVector
typealias AMat AbstractMatrix


const IMG_DIR = "$(ENV["HOME"])/.julia/v0.4/Plots/img/"


# ---------------------------------------------------------

type Plot
  o  # the underlying object
  plotter::Symbol
  xdata::Vector{AVec}
  ydata::Vector{AVec}
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
