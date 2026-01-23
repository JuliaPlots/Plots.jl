module Plots

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using Dates, Printf, Statistics, Base64, LinearAlgebra, SparseArrays, Random, TOML
using PrecompileTools, Reexport, RelocatableFolders
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
# ---------------------------------------------------------

import NaNMath # define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum(x::AbstractArray{<:AbstractFloat}) = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum(x::AbstractArray{<:AbstractFloat}) = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean(x::AbstractArray{<:AbstractFloat}) = NaNMath.mean(x)
ignorenan_mean(x) = Statistics.mean(x)
ignorenan_extrema(x::AbstractArray{<:AbstractFloat}) = NaNMath.extrema(x)
ignorenan_extrema(x) = Base.extrema(x)

# ---------------------------------------------------------
import Measures
include("plotmeasures.jl")
using .PlotMeasures
import .PlotMeasures: Length, AbsoluteLength, Measure, width, height
# ---------------------------------------------------------

const PLOTS_SEED = 1234
const PX_PER_INCH = 100
const DPI = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX = MM_PER_INCH / PX_PER_INCH

include("types.jl")
include("utils.jl")
include("colorbars.jl")
include("axes.jl")
include("args.jl")
include("components.jl")
include("legend.jl")
include("consts.jl")
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("layouts.jl")
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
