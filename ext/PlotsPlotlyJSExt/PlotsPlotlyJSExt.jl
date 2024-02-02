module PlotsPlotlyJSExt

using PlotlyJS: PlotlyJS
using Plots: Plots, Plot, plotly_show_js, isplotnull, current
import Plots: _show, _display, closeall

include("initialization.jl")
include("plotlyjs.jl")

end # module
