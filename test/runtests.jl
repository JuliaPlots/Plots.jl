import Plots: PLOTS_SEED, Plot, with
import GeometryBasics
import ImageMagick
import LibGit2
import JSON

using VisualRegressionTests
using RecipesPipeline
using LaTeXStrings
using RecipesBase
using TestImages
using FileIO
using FilePathsBase
using Plots
using Dates
using Test
using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30

# initial load - required for `should_warn_on_unsupported`
unicodeplots()
pgfplotsx()
plotlyjs()
plotly()
hdf5()
gr()

for name in (
    "misc",
    "utils",
    "args",
    "defaults",
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
        gr()  # reset to default backend
        include("test_$name.jl")
    end
end
