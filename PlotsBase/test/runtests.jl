const TEST_PACKAGES =
    let val = get(
            ENV,
            "PLOTSBASE_TEST_PACKAGES",
            "GR,UnicodePlots,PythonPlot,PGFPlotsX,PlotlyJS,Gaston",
        )
        Symbol.(strip.(split(val, ",")))
    end
const TEST_BACKENDS = NamedTuple(p => Symbol(lowercase(string(p))) for p ∈ TEST_PACKAGES)

get!(ENV, "MPLBACKEND", "agg")

using PlotsBase

# always initialize GR
import GR
gr()

# initialize all backends
for pkg ∈ TEST_PACKAGES
    @eval begin
        import $pkg  # trigger extension
        $(TEST_BACKENDS[pkg])()
    end
end

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
using Preferences
using TestImages
using Unitful
using FileIO
using Dates
using Test

is_auto() = PlotsBase.bool_env("VISUAL_REGRESSION_TESTS_AUTO")
is_pkgeval() = PlotsBase.bool_env("JULIA_PKGEVAL")
is_ci() = PlotsBase.bool_env("CI")

is_ci() || @eval using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30

ref_name(i) = "ref" * lpad(i, 3, '0')

const broken_examples = if Sys.isapple()
    [50] # FIXME: https://github.com/jheinen/GR.jl/issues/550
else
    []
end

for name ∈ (
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
    "reference",
    "backends",
    "preferences",
    "quality",
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
