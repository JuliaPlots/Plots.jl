using Plots, Test
pgfplotsx()

function create_plot( args...; kwargs... )
    pgfx_plot = plot(args..., kwargs...)
    return pgfx_plot, repr("application/x-tex", pgfx_plot)
end

@testset "PGFPlotsX" begin
    pgfx_plot, pgfx_tex = create_plot(1:5)
    
    @test pgfx_plot.o isa PGFPlotsX.GroupPlot
end # testset
