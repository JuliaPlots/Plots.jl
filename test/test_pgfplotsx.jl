using Plots, Test
pgfplotsx()

function create_plot( args...; kwargs... )
    pgfx_plot = plot(args...; kwargs...)
    return pgfx_plot, repr("application/x-tex", pgfx_plot)
end

function create_plot!( args...; kwargs... )
    pgfx_plot = plot!(args...; kwargs...)
    return pgfx_plot, repr("application/x-tex", pgfx_plot)
end

@testset "PGFPlotsX" begin
    pgfx_plot, pgfx_tex = create_plot(1:5)

    @test pgfx_plot.o isa PGFPlotsX.GroupPlot
     @testset "3D docs example" begin
        n = 100
        ts = range(0, stop=8π, length=n)
        x = ts .* map(cos, ts)
        y = (0.1ts) .* map(sin, ts)
        z = 1:n
        pl = plot(x, y, z, zcolor=reverse(z), m=(10, 0.8, :blues, Plots.stroke(0)), leg=false, cbar=true, w=5)
                    @show PGFPlotsX.CUSTOM_PREAMBLE
                    @show PGFPlotsX.CUSTOM_PREAMBLE_PATH
        pgfx_plot, pgfx_tex = create_plot!(pl, zeros(n), zeros(n), 1:n, w=10)
        if @test_nowarn(haskey(pgfx_plot.o.contents[1].options.dict, "colormap") == true)
            @test pgfx_plot.o.contents[1]["colormap"] === nothing
        end
     end # testset
end # testset
