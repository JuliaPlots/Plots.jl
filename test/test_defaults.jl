using Plots, Test

const PLOTS_DEFAULTS = Dict(:theme => :wong2)
Plots.__init__()

@testset "Loading theme" begin
    plot(1:5)[1][1][:color] == colorant"black"
end

empty!(PLOTS_DEFAULTS)
Plots.__init__()
