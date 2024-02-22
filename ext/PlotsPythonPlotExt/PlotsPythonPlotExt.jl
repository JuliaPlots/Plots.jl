module PlotsPythonPlotExt

import Plots:
    _before_layout_calcs,
    _create_backend_figure,
    _display,
    _show,
    _update_min_padding!,
    _update_plot_object,
    closeall,
    is_marker_supported,
    labelfunc

using NaNMath: NaNMath
using Plots.Annotations
using Plots.Arrows
using Plots.Axes
using Plots.Colorbars
using Plots.Colorbars: cbar_fill, cbar_gradient, cbar_lines
using Plots.Colors
using Plots.Commons
using Plots.Commons: _all_markers, _3dTypes, single_color
using Plots.Fonts
using Plots.Fonts: Font, PlotText
using Plots.PlotMeasures
using Plots.PlotMeasures: px2inch
using Plots.PlotUtils: PlotUtils, ColorGradient, plot_color, color_list,
        cgrad
using Plots.PlotsPlots
using Plots.PlotsSeries
using Plots.Shapes
using Plots.Shapes: Shape
using Plots.Subplots
using Plots.Ticks
using Plots.Ticks: no_minor_intervals
using Plots:
    DPI,
    Plots,
    Surface,
    _cycle,
    _guess_best_legend_position,
    axis_drawing_info,
    axis_drawing_info_3d,
    bbox,
    bottom,
    convert_to_polar,
    heatmap_edges,
    is3d,
    is_2tuple,
    is_uniformly_spaced,
    isautop,
    isortho,
    labelfunc_tex,
    mesh3d_triangles,
    left,
    merge_with_base_supported,
    plotarea,
    right,
    shape_data,
    straightline_data,
    top,
    isscalar,
    isvector,
    supported_scales,
    ticks_type,
    legend_angle,
    legend_anchor_index,
    legend_pos_from_angle,
    width,
    ispositive,
    height,
    bbox_to_pcts
using PythonPlot: PythonPlot

const PythonCall = PythonPlot.PythonCall
const mpl_toolkits = PythonCall.pynew() # PythonCall.pyimport("mpl_toolkits")
const mpl = PythonPlot.matplotlib
const numpy = PythonCall.pynew() # PythonCall.pyimport("numpy")

using RecipesPipeline: RecipesPipeline

include("initialization.jl")
include("pythonplot.jl")

end # module
