using Pkg
Pkg.status(; outdated = true, mode = Pkg.PKGMODE_MANIFEST)

const TEST_PACKAGES = let val = get(
        ENV,
        "PLOTSBASE_TEST_PACKAGES",
        "GR,UnicodePlots,PythonPlot,PGFPlotsX,PlotlyJS,Gaston",
    )
    Symbol.(strip.(split(val, ",")))
end
const TEST_BACKENDS = NamedTuple(p => Symbol(lowercase(string(p))) for p in TEST_PACKAGES)

get!(ENV, "MPLBACKEND", "agg")
get!(ENV, "PLOTSBASE_PLOTLYJS_UNSAFE_ELECTRON", "true")

using PlotsBase
eval(PlotsBase.WEAKDEPS)

# initialize all backends
for pkg in TEST_PACKAGES
    @eval begin
        import $pkg  # trigger extension
        $(TEST_BACKENDS[pkg])()
    end
end

import Unitful: m, s, cm, DimensionError
import PlotsBase: SEED, Plot, with
import SentinelArrays: ChainedVector
import GeometryBasics
import OffsetArrays
import Downloads
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

const broken_examples = Int[]  # NOTE: unexpected pass is a failure
Sys.isapple() && push!(broken_examples, 50)  # FIXME: https://github.com/jheinen/GR.jl/issues/550

const skipped_examples = Int[]  # NOTE: won't error, regardless of the test output
push!(skipped_examples, 62)  # TODO: remove when new GR release is out and lands through CI (compat issues)

function available_channels()
    juliaup = "https://julialang-s3.julialang.org/juliaup"
    for i in 1:6
        buf = PipeBuffer()
        Downloads.download("$juliaup/DBVERSION", buf)
        dbversion = VersionNumber(readline(buf))
        dbversion.major == 1 || continue
        buf = PipeBuffer()
        Downloads.download(
            "$juliaup/versiondb/versiondb-$dbversion-x86_64-unknown-linux-gnu.json",
            buf,
        )
        json = JSON.parse(buf)
        haskey(json, "AvailableChannels") || continue
        return json["AvailableChannels"]
        sleep(10i)
    end
    return
end

"""
julia> is_latest("lts")
julia> is_latest("release")
"""
function is_latest(variant)
    channels = available_channels()
    ver = VersionNumber(split(channels[variant]["Version"], '+') |> first)
    dev = occursin("DEV", string(VERSION))  # or length(VERSION.prerelease) < 2
    return !dev &&
        VersionNumber(ver.major, ver.minor, 0, ("",)) ≤
        VERSION <
        VersionNumber(ver.major, ver.minor + 1)
end

is_auto() = Base.get_bool_env("VISUAL_REGRESSION_TESTS_AUTO", false)
is_pkgeval() = Base.get_bool_env("JULIA_PKGEVAL", false)
is_ci() = Base.get_bool_env("CI", false)

is_ci() || @eval using Gtk  # see JuliaPlots/VisualRegressionTests.jl/issues/30

# skip the majority of tests if we only want to update reference images or under `PkgEval` (timeout limit)
names = if is_auto()
    ["reference"]
elseif is_pkgeval()
    ["backends"]
else
    [
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
    ]
end

for name in names
    @testset "$name" begin
        haskey(TEST_BACKENDS, :GR) && gr()  # reset to default backend
        include("test_$name.jl")
    end
end
