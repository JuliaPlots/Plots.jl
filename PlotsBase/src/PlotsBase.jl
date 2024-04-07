module PlotsBase

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
import UnicodeFun
import StatsBase
import Downloads
import Measures
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

    theme,
    protect,
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

    translate,
    translate!,
    rotate,
    rotate!,
    center,
    plotattr,
    scalefontsizes,
    resetfontsizes

#! format: on
import NaNMath

const _project = Pkg.Types.read_package(normpath(@__DIR__, "..", "Project.toml"))
const _version = _project.version
const _compat  = _project.compat

include("Commons/Commons.jl")
using .Commons
using .Commons.Frontend

Commons.@generic_functions attr attr! rotate rotate!

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
include("preferences.jl")
include("init.jl")
include("users.jl")

# COV_EXCL_START
@setup_workload begin
    @compile_workload begin
        # TODO: backend agnostic statements
    end
end
# COV_EXCL_STOP

end
