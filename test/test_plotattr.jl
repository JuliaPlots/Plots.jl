using Plots, Test

tplot = plot([1:5, 1:5, 2:6, 2:6], layout = 2, this = :that, line = (5, :dash), title = ["A" "B"], xlims=[:auto (0,Inf)])
@testset "Get attributes" begin
    @test getattr(tplot, :size) == default(:size) == getattr(tplot, :sizes)
    @test getattr(tplot, :linestyle) == permutedims(fill(:dash, 4))
    @test getattr(tplot, :title) == ["A" "B"]
    @test getattr(tplot, :xlims) == [:auto (0, Inf)] #Note: this is different from Plots.xlims.(tplot.subplots)
    @test getattr(tplot, :lims) == [(xaxis = :auto, yaxis = :auto, zaxis = :auto), (xaxis = (0, Inf), yaxis = :auto, zaxis = :auto)]
end
