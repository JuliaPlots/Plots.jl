using Plots, Test

const PLOTS_DEFAULTS = Dict(:theme => :wong2, :fontfamily => :palantino)
Plots.__init__()

@testset "Loading theme" begin
    pl = plot(1:5)plot(1:5)
    @test pl[1][1][:seriescolor] == RGBA(colorant"black")
    @test guidefont(pl[1][:xaxis]).family == "palantino"
end

empty!(PLOTS_DEFAULTS)
Plots.__init__()
