const TEST_PACKAGES =
    let val = get(ENV, "PLOTS_TEST_PACKAGES", "GR,UnicodePlots,PythonPlot")
        Symbol.(strip.(split(val, ",")))
    end
const TEST_BACKENDS = NamedTuple(p => Symbol(lowercase(string(p))) for p ∈ TEST_PACKAGES)

using PlotsBase

# initialize all backends
for pkg ∈ TEST_PACKAGES
    @eval begin
        import $pkg  # trigger extension
        $(TEST_BACKENDS[pkg])()
    end
end
gr()

using Plots
using Test

for pkg ∈ TEST_PACKAGES
    @testset "simple plots using $pkg" begin
        @eval $(TEST_BACKENDS[pkg])()
        pl = plot(1:2)
        @test pl isa PlotsBase.Plot
        show(devnull, pl)
    end
end
