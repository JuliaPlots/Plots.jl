module PlotsBase

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using Base.Meta

import PrecompileTools
import TableOperations
import LinearAlgebra
import SparseArrays
import Preferences
import UnicodeFun
import Statistics
import StatsBase
import Downloads
import Reexport
import Measures
import NaNMath
import Showoff
import Random
import Base64
import Printf
import Dates
import Unzip
import JLFzf
import JSON
import Pkg

Reexport.@reexport using RecipesBase
Reexport.@reexport using PlotThemes
Reexport.@reexport using PlotUtils

import RecipesBase: plot, plot!, animate, is_explicit, grid
import RecipesPipeline:
    RecipesPipeline,
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
    pop_kw!,
    Volume,
    is3d

export
    grid,
    bbox,
    plotarea,
    KW,

    theme,
    protect,
    plot,
    plot!,
    attr!,
    @df,

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

    text,
    font,
    stroke,
    brush,
    OHLC,
    arrow,
    Shape,
    cgrad,

    frame,
    gif,
    mov,
    mp4,
    webm,
    animate,
    @animate,
    @gif,
    Animation,

    test_examples,
    coords,

    plotattr,
    scalefontsizes,
    resetfontsizes

const _project = Pkg.Types.read_package(normpath(@__DIR__, "..", "Project.toml"))
const _version = _project.version
const _compat = _project.compat

include("Commons/Commons.jl")
using .Commons
# using .Commons.Frontend
Commons.@generic_functions attr attr! annotate!
include("DF.jl")
using .DF
include("Fonts.jl")
Reexport.@reexport using .Fonts
include("Ticks.jl")
using .Ticks
include("DataSeries.jl")
using .DataSeries
include("Subplots.jl")
using .Subplots
include("Axes.jl")
using .Axes
include("Surfaces.jl")
using .Surfaces
include("Colorbars.jl")
using .Colorbars
include("Plots.jl")
using .Plots
include("layouts.jl")
include("utils.jl")
include("axes_utils.jl")
include("legend.jl")
include("Shapes.jl")
using .Shapes
include("Annotations.jl")
using .Annotations
include("Arrows.jl")
using .Arrows
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
include("alignment.jl")
include("output.jl")
include("shorthands.jl")
include("backends.jl")
include("web.jl")
include("plotly.jl")
using .Plotly
include("init.jl")
include("users.jl")

PlotsBase.@precompile_backend None

end
