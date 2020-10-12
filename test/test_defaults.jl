using Plots, Test

const PLOTS_DEFAULTS = Dict(:theme => :wong2)

@testset "Loading theme" begin
    Plots.__init__()
    plot(1:5)[1][1][:series_color] == colorant"black"
end
