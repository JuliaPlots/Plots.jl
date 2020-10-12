using Plots, Test

const PLOTS_DEFAULTS = Dict(:theme => :wong2)
Plots.__init__()

@testset "Loading theme" begin
    @test plot(1:5)[1][1][:seriescolor] == colorant"black"
end

empty!(PLOTS_DEFAULTS)
Plots.__init__()
