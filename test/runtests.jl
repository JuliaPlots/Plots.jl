import Unitful: m, s, cm, DimensionError
import Plots: PLOTS_SEED, Plot, with
import SentinelArrays: ChainedVector
import GeometryBasics
import ImageMagick
import LibGit2
import Aqua
import JSON

using VisualRegressionTests
using RecipesPipeline
using FilePathsBase
using LaTeXStrings
using RecipesBase
using TestImages
using Unitful
using FileIO
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
    "quality",
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
    "unitful",
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
