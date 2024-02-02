module PlotsPlotlyJSExt

using PlotlyJS: PlotlyJS
using Plots.Commons
using Plots.Plotly
using Plots.PlotsPlots
import Plots: _show, _display, closeall, current, isplotnull

include("initialization.jl")
include("plotlyjs.jl")

end # module
