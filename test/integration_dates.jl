using Plots, Test, Dates

@testset "Limits" begin
    y=[1.0*i*i for i in 1:10]
    x=[Date(2019,11,i) for i in 1:10]

    rx=[x[3],x[5]]

    ref_ylims = (y[begin], y[end])
    ref_xlims = (x[1].instant.periods.value, x[end].instant.periods.value)
    p = plot(x,y, widen = false)
    vspan!(p, rx, label="", alpha=0.2)
    @test Plots.ylims(p) == ref_ylims
    @test Plots.xlims(p) == ref_xlims
end # testset
