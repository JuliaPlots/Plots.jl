module PlotsBase

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using Pkg, Dates, Printf, Statistics, Base64, LinearAlgebra, SparseArrays, Random
using Reexport, RelocatableFolders
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

function attr end
function attr! end
function rotate end
function rotate! end

#! format: on
import Measures
include("Measurements.jl")
using .Measurements
# ---------------------------------------------------------
macro ScopeModule(mod::Symbol, parent::Symbol, symbols...)
    import_ex = Expr(
        :import,
        Expr(
            :(:),
            Expr(:., :., :., parent),
            (Expr(:., s isa Expr ? s.args[1] : s) for s in symbols)...,
        ),
    )
    export_ex = Expr(:export, (s isa Expr ? s.args[1] : s for s in symbols)...)
    Expr(:module, true, mod, Expr(:block, import_ex, export_ex)) |> esc
end
import NaNMath
include("Commons/Commons.jl")
using .Commons
using .Commons.Frontend
# ---------------------------------------------------------
include("Fonts.jl")
@reexport using .Fonts
include("Ticks.jl")
using .Ticks
include("DataSeries.jl")
using .DataSeries
include("Layouts.jl")
using .Layouts
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
# ---------------------------------------------------------
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

include("backends/nobackend.jl")
include("abstract_backend.jl")
const CURRENT_BACKEND = CurrentBackend(:none)

include("alignment.jl")
include("output.jl")
include("shorthands.jl")
include("backends/web.jl")

include("backends/plotly.jl")
using .Plotly

include("init.jl")
include("users.jl")

end
