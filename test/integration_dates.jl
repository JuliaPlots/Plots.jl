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
    #@static if (haskey(ENV, "APPVEYOR") || haskey(ENV, "CI"))
    @static if haskey(ENV, "APPVEYOR")
        @info "Skipping display tests on AppVeyor"
    else
        @test isa(display(p), Nothing) == true
        closeall()
    end
end # testset

@testset "Date xlims" begin
    y=[1.0*i*i for i in 1:10]
    x=[Date(2019,11,i) for i in 1:10]
    span = (Date(2019,10,31), Date(2019,11,11))

    ref_xlims = map(date->date.instant.periods.value, span)

    p = plot(x,y, xlims=span, widen = false)

    @test Plots.xlims(p) == ref_xlims
    #@static if (haskey(ENV, "APPVEYOR") || haskey(ENV, "CI"))
    @static if haskey(ENV, "APPVEYOR")
        @info "Skipping display tests on AppVeyor"
    else
        @test isa(display(p), Nothing) == true
        closeall()
    end
end # testset

@testset "DateTime xlims" begin
    y=[1.0*i*i for i in 1:10]
    x=[DateTime(2019,11,i,11) for i in 1:10]
    span = (DateTime(2019,10,31,11,59,59), DateTime(2019,11,11,12,01,15))

    ref_xlims = map(date->date.instant.periods.value, span)

    p = plot(x,y, xlims=span, widen = false)
    @test Plots.xlims(p) == ref_xlims
    #@static if (haskey(ENV, "APPVEYOR") || haskey(ENV, "CI"))
    @static if haskey(ENV, "APPVEYOR")
        @info "Skipping display tests on AppVeyor"
    else
        @test isa(display(p), Nothing) == true
        closeall()
    end
end # testset
