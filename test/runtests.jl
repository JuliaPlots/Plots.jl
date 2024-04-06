const TEST_PACKAGES =
    let val = get(ENV, "PLOTS_TEST_PACKAGES", "GR,UnicodePlots,PythonPlot")
        strip.(split(val, ","))
    end
using PlotsBase

# initialize all backends
for pkg in TEST_PACKAGES
    @eval import $(Symbol(pkg))  # trigger extension
    getproperty(PlotsBase, Symbol(lowercase(pkg)))()
end
gr()

using Preferences
using Plots
using Test

is_auto() = Plots.PlotsBase.bool_env("VISUAL_REGRESSION_TESTS_AUTO")
is_pkgeval() = Plots.PlotsBase.bool_env("JULIA_PKGEVAL")
is_ci() = Plots.PlotsBase.bool_env("CI")

# get `Preferences` set backend, if any
const PREVIOUS_DEFAULT_BACKEND = load_preference(Plots, "default_backend")

for name in ("preferences",)
    @testset "$name" begin
        include("test_$name.jl")
    end
end

if PREVIOUS_DEFAULT_BACKEND ≡ nothing
    delete_preferences!(Plots, "default_backend")  # restore the absence of a preference
else
    Plots.set_default_backend!(PREVIOUS_DEFAULT_BACKEND)  # reset to previous state
end
