using Plots, Test, Dates

@testset "Limits" begin
    y=[1.0*i*i for i in 1:10]
    x=[Date(2019,11,i) for i in 1:10]

    rx=[x[3],x[5]]

    p = plot(x,y, widen = false)
    vspan!(p, rx, label="", alpha=0.2)

    ref_ylims = (y[1], y[end])
    ref_xlims = (x[1].instant.periods.value, x[end].instant.periods.value)
    @test Plots.ylims(p) == ref_ylims
    @test Plots.xlims(p) == ref_xlims
end # testset
