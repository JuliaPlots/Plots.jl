import Unitful: m, s, cm, DimensionError
import Plots: PLOTS_SEED, Plot, with
import SentinelArrays: ChainedVector
import GeometryBasics
import OffsetArrays
import ImageMagick
import LibGit2
import Aqua
import JSON

using VisualRegressionTests
using RecipesPipeline
using FilePathsBase
using LaTeXStrings
using Preferences
using RecipesBase
using TestImages
using Unitful
using FileIO
using Plots
using Dates
using Test
using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30

# get `Preferences` set backend, if any
const previous_default_backend = load_preference(Plots, "default_backend")

# initial load - required for `should_warn_on_unsupported`
unicodeplots()
pgfplotsx()
plotlyjs()
plotly()
hdf5()
gr()

is_auto() = Plots.bool_env("VISUAL_REGRESSION_TESTS_AUTO", "false")
is_pkgeval() = Plots.bool_env("JULIA_PKGEVAL", "false")
is_ci() = Plots.bool_env("CI", "false")

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
        if is_auto() || is_pkgeval()
            # skip the majority of tests if we only want to update reference images or under `PkgEval` (timeout limit)
            name != "backends" && continue
        end
        gr()  # reset to default backend (safer)
        include("test_$name.jl")
    end
end

# reset to previous state
if previous_default_backend !== nothing
    Plots.set_default_backend!(previous_default_backend; force = true)
end
