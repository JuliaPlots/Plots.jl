module PlotsBase

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

# multiple weakdeps triggers (keep in sync with Project.toml !)
const WEAKDEPS = Expr(
    :block,
    :(import UnitfulLatexify),
    :(import LaTeXStrings),
    :(import Latexify),
    :(import Contour),
    :(import Colors),
)

using Base.Meta

import PrecompileTools
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
import Tables
import TableOperations
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

#! format: off
export
    grid,
    bbox,
    plotarea,
    KW,

    @cm,
    @mm,
    @in,

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
    @P_str,
    Animation,

    test_examples,
    coords,

    plotattr,
    scalefontsizes,
    resetfontsizes

#! format: on
const _project = Pkg.Types.read_package(normpath(@__DIR__, "..", "Project.toml"))
const _version = _project.version
const _compat  = _project.compat

include("Commons/Commons.jl")
using .Commons
using .Commons.Frontend

Commons.@generic_functions attr attr!

include("df.jl")
include("Fonts.jl")
include("Ticks.jl")
include("DataSeries.jl")
include("Subplots.jl")
include("Axes.jl")
include("Surfaces.jl")
include("Colorbars.jl")
include("Plots.jl")
include("layouts.jl")
include("utils.jl")
include("axes_utils.jl")
include("legend.jl")
include("Shapes.jl")
include("Annotations.jl")
include("Arrows.jl")
include("Strokes.jl")
include("BezierCurves.jl")
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
include("init.jl")
include("users.jl")

PlotsBase.@precompile_backend None

end
