using Plots: guidefont, series_annotations, PLOTS_SEED, _current_plots_version

using VisualRegressionTests
using RecipesPipeline
using RecipesBase
using StableRNGs
using TestImages
using LibGit2
using Random
using FileIO
using Plots
using Dates
using JSON
using Test
using Gtk

import GeometryBasics
import ImageMagick

is_ci() = get(ENV, "CI", "false") == "true"
const PLOTS_IMG_TOL = parse(
    Float64,
    get(ENV, "PLOTS_IMG_TOL", is_ci() ? (Sys.iswindows() ? "2e-3" : "1e-4") : "1e-5"),
)

for name in (
    "misc",
    "utils",
    "args",
    "defaults",
    "pipeline",
    "axis_letter",
    "dates",
    "axes",
    "layouts",
    "contours",
    "components",
    "shorthands",
    "recipes",
    "hdf5plots",
    "pgfplotsx",
    "plotly",
    "animations",
    "output",
    "backends",
)
    @testset "$name" begin
        include("test_$name.jl")
    end
end
