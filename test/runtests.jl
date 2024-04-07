const TEST_PACKAGES =
    let val = get(ENV, "PLOTS_TEST_PACKAGES", "GR,UnicodePlots,PythonPlot")
        strip.(split(val, ","))
    end
using PlotsBase

# initialize all backends
for pkg in TEST_PACKAGES
    @eval begin
        import $(Symbol(pkg))  # trigger extension
        $(Symbol(lowercase(pkg)))()
    end
end
gr()

using Plots
using Test

for name in ()
    @testset "$name" begin
        include("test_$name.jl")
    end
end
