module PlotsPGFPlotsXExt

using PGFPlotsX: PGFPlotsX
using LaTeXStrings: LaTeXString
using UUIDs: uuid4
using Latexify: Latexify
using Contour: Contour # TODO: this could become its own extensionoo
using PlotUtils: PlotUtils, ColorGradient, color_list
using Printf: @sprintf

using Plots: Plots, straightline_data, shape_data
# TODO: eliminate this list
using Plots:
    bbox,
    left,
    right,
    bottom,
    width,
    height,
    labelfunc_tex,
    top,
    plotarea,
    axis_drawing_info,
    _guess_best_legend_position,
    prepare_output,
    current
using Plots: GridLayout
using RecipesPipeline: RecipesPipeline
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
using Plots.Surfaces
using Plots.Shapes
using Plots.Shapes: Shape
using Plots.Ticks

import Plots: _display, _show, _update_min_padding!, labelfunc, _create_backend_figure, _series_added, _update_plot_object, pgfx_sanitize_string

include("initialization.jl")
include("pgfplotsx.jl")

end # module
