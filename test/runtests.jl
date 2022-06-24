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
