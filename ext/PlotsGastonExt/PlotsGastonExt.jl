module PlotsGastonExt

using Gaston
using Plots: Plots,
    mesh3d_triangles
import Plots: _show, _display
using Plots.Commons
using Plots.PlotsPlots
using Plots.Subplots
using Plots.PlotsSeries
using Plots.Fonts
using Plots.PlotUtils: alphacolor, hex

include("initialization.jl")
include("gaston.jl")

end # module
