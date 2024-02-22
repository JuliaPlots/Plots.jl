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

# NOTE: don't use `plotly` (test hang, not surprised), test only the backends used in the docs
const TEST_BACKENDS = let
    var = get(ENV, "PLOTS_TEST_BACKENDS", nothing)
    if var !== nothing
        Symbol.(lowercase.(strip.(split(var, ","))))
    else
        [
            :gr,
            :unicodeplots,
            # :pythonplot, # currently segfaults
            :pgfplotsx,
            :plotlyjs,
            # :gaston, # currently doesn't precompile (on julia v1.10)
            # :inspectdr # currently doesn't precompile
        ]
    end
end

# initial load - required for `should_warn_on_unsupported`

import GR
import UnicodePlots
import PythonPlot
import PGFPlotsX
import PlotlyJS
# import Gaston
# initialize all backends
for be in TEST_BACKENDS
    getproperty(Plots, be)()
end
gr()

is_auto() = Plots.bool_env("VISUAL_REGRESSION_TESTS_AUTO", "false")
is_pkgeval() = Plots.bool_env("JULIA_PKGEVAL", "false")
is_ci() = Plots.bool_env("CI", "false")

if !is_ci()
    @eval using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30
end

for name in (
    # "quality", # Persistent tasks cannot resolve versions
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
    "pgfplotsx",
    "plotly",
    # "animations", # some failing
    # "output", # some plotly failing
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
