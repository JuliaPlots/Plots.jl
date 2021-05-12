using Plots, Test

@testset "Default colors and alphas" begin
    t = range(0, 3π, length = 100)
    @test surface(t, t, (x, y) -> x * sin(x) - y * cos(y))[1][1][:seriesalpha] !== nothing
    @test surface(t, t, (x, y) -> x * sin(x) - y * cos(y))[1][1][:fillalpha] !== nothing
    @test plot(t, t)[1][1][:fillalpha] !== nothing
    @test plot(t, t)[1][1][:seriesalpha] !== nothing
end

const PLOTS_DEFAULTS = Dict(:theme => :wong2)
Plots.__init__()

@testset "Loading theme" begin
    @test plot(1:5)[1][1][:seriescolor] == RGBA(colorant"black")
end

empty!(PLOTS_DEFAULTS)
Plots.__init__()
