module Plots

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using Pkg, Dates, Printf, Statistics, Base64, LinearAlgebra, SparseArrays, Random
using PrecompileTools, Preferences, Reexport, RelocatableFolders
using Base.Meta
@reexport using RecipesBase
@reexport using PlotThemes
@reexport using PlotUtils

import RecipesBase: plot, plot!, animate, is_explicit, grid
import RecipesPipeline
import Requires: @require
import RecipesPipeline:
    inverse_scale_func,
    datetimeformatter,
    AbstractSurface,
    group_as_matrix, # for StatsPlots
    dateformatter,
    timeformatter,
    needs_3d_axes,
    DefaultsDict,
    explicitkeys,
    scale_func,
    is_surface,
    Formatted,
    reset_kw!,
    SliceIt,
    Surface,
    pop_kw!,
    Volume,
    is3d
import UnicodeFun
import StatsBase
import Downloads
import Showoff
import Unzip
import JLFzf
import JSON

#! format: off
export
    grid,
    bbox,
    plotarea,
    KW,

    wrap,
    theme,

    plot,
    plot!,
    attr!,

    current,
    default,
    with,
    twinx,
    twiny,

    pie,
    pie!,
    plot3d,
    plot3d!,

    title!,
    annotate!,

    xlims,
    ylims,
    zlims,

    savefig,
    png,
    gui,
    inline,
    closeall,

    backend,
    backends,
    backend_name,
    backend_object,
    aliases,

    Shape,
    text,
    font,
    stroke,
    brush,
    Surface,
    OHLC,
    arrow,
    Segments,
    Formatted,

    Animation,
    frame,
    gif,
    mov,
    mp4,
    webm,
    animate,
    @animate,
    @gif,
    @P_str,

    test_examples,
    iter_segments,
    coords,

    translate,
    translate!,
    rotate,
    rotate!,
    center,
    BezierCurve,

    plotattr,
    scalefontsize,
    scalefontsizes,
    resetfontsizes
#! format: on
using Measures: Measures
include("PlotMeasures.jl")
using .PlotMeasures
using .PlotMeasures: Length, AbsoluteLength, Measure
import .PlotMeasures: width, height
# ---------------------------------------------------------

include("Commons.jl")
using .Commons
include("args.jl")
# ---------------------------------------------------------
include("Fonts.jl")
@reexport using .Fonts
using .Fonts: Font, PlotText
include("Ticks.jl")
using .Ticks
include("Series.jl")
using .PlotsSeries
include("Subplots.jl")
using .Subplots
include("Axes.jl")
using .Axes
include("PlotsPlots.jl")
using .PlotsPlots
include("layouts.jl")
# ---------------------------------------------------------
include("utils.jl")
include("axes_utils.jl")
include("colorbars.jl")
include("legend.jl")
include("consts.jl")
include("Shapes.jl")
@reexport using .Shapes
import .Shapes: Shape, _shapes
include("Annotations.jl")
using .Annotations
import .Annotations: SeriesAnnotations
include("Arrows.jl")
using .Arrows
import .Arrows: Arrow
include("Surfaces.jl")
using .Surfaces
include("Strokes.jl")
using .Strokes
include("BezierCurves.jl")
using .BezierCurves
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("arg_desc.jl")
include("recipes.jl")
include("animation.jl")
include("examples.jl")
include("plotattr.jl")
include("backends.jl")
const CURRENT_BACKEND = CurrentBackend(:none)
include("output.jl")
include("shorthands.jl")
include("backends/web.jl")
include("init.jl")

end
