const TEST_PACKAGES =
    strip.(
        split(
            get(
                ENV,
                "PLOTSBASE_TEST_PACKAGES",
                "GR,UnicodePlots,PythonPlot,PGFPlotsX,PlotlyJS,Gaston",
            ),
            ",",
        )
    )
const TEST_BACKENDS = Symbol.(lowercase.(TEST_PACKAGES))

using PlotsBase

# initialize all backends
for pkg in TEST_PACKAGES
    @eval import $(Symbol(pkg))  # trigger extension
    getproperty(PlotsBase, Symbol(lowercase(pkg)))()
end
gr()

import Unitful: m, s, cm, DimensionError
import PlotsBase: PLOTS_SEED, Plot, with
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
using RecipesBase
using TestImages
using Unitful
using FileIO
using Dates
using Test

is_auto() = PlotsBase.bool_env("VISUAL_REGRESSION_TESTS_AUTO")
is_pkgeval() = PlotsBase.bool_env("JULIA_PKGEVAL")
is_ci() = PlotsBase.bool_env("CI")

is_ci() || @eval using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30

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
        # skip the majority of tests if we only want to update reference images or under `PkgEval` (timeout limit)
        if is_auto() || is_pkgeval()
            name != "backends" && continue
        end
        gr()  # reset to default backend (safer)
        include("test_$name.jl")
    end
end
