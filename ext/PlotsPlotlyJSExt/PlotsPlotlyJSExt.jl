module PlotsPlotlyJSExt

using PlotlyJS: PlotlyJS
using Plots: Plots, Plot, plotly_show_js
import Plots: _show, display, closeall

include("initialization.jl")
include("plotlyjs.jl")

end # module
