import Unitful: m, s, cm, DimensionError
import Plots: PLOTS_SEED, Plot, with
import SentinelArrays: ChainedVector
import GeometryBasics
import OffsetArrays
import FreeType  # for `unicodeplots`
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
const PREVIOUS_DEFAULT_BACKEND = load_preference(Plots, "default_backend")

# NOTE: don't use `plotly` (test hang, not surprised), test only the backends used in the docs
const TEST_BACKENDS =
    :gr, :unicodeplots, :pythonplot, :pgfplotsx, :plotlyjs, :gaston, :inspectdr

# initial load - required for `should_warn_on_unsupported`
# TODO add back once packageext with backends work
# unicodeplots()
# pgfplotsx()
# plotlyjs()
# plotly()
# hdf5()
# gr()
import GR
import UnicodePlots
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
    # "unitful", # many fail
    # "hdf5plots",
    # "pgfplotsx",
    # "plotly",
    # "animations", # some failing
    # "output", # some plotly failing
    # "preferences", # no default backend
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

if PREVIOUS_DEFAULT_BACKEND === nothing
    delete_preferences!(Plots, "default_backend")  # restore the absence of a preference
else
    Plots.set_default_backend!(PREVIOUS_DEFAULT_BACKEND)  # reset to previous state
end
