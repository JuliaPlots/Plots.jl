module PlotsUnicodePlotsExt

using UnicodePlots
using Plots: Plots, isijulia, texmath2unicode, straightline_data, shape_data
# TODO: eliminate this list
using Plots:
    bbox,
    left,
    right,
    bottom,
    top,
    plotarea,
    axis_drawing_info,
    _guess_best_legend_position,
    prepare_output
using Plots: GridLayout
using RecipesPipeline: RecipesPipeline
using NaNMath: NaNMath
using Plots.Arrows
using Plots.Axes
using Plots.Axes: has_ticks
using Plots.Annotations
using Plots.Colorbars
using Plots.Colors
using Plots.Commons
using Plots.Fonts
using Plots.Fonts: Font, PlotText
using Plots.PlotMeasures
using Plots.PlotsPlots
using Plots.PlotsSeries
using Plots.Subplots
using Plots.Shapes
using Plots.Shapes: Shape
using Plots.Ticks

import Plots: _before_layout_calcs, _display

include("initialization.jl")
include("unicodeplots.jl")

end # module
