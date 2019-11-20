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
    pgfx_plot = plot(1:5)
    Plots._update_plot_object(pgfx_plot)
    @test pgfx_plot.o.the_plot isa PGFPlotsX.TikzDocument

    @testset "3D docs example" begin
        n = 100
        ts = range(0, stop=8π, length=n)
        x = ts .* map(cos, ts)
        y = (0.1ts) .* map(sin, ts)
        z = 1:n
        pl = plot(x, y, z, zcolor=reverse(z), m=(10, 0.8, :blues, Plots.stroke(0)), leg=false, cbar=true, w=5)
        pgfx_plot = plot!(pl, zeros(n), zeros(n), 1:n, w=10)
        Plots._update_plot_object(pgfx_plot)
        if @test_nowarn(haskey(Plots.pgfx_axes(pgfx_plot.o)[1].options.dict, "colorbar") == true)
            @test Plots.pgfx_axes(pgfx_plot.o)[1]["colorbar"] === nothing
        end
     end # testset
     @testset "Color docs example" begin
        y = rand(100)
        plot(0:10:100, rand(11, 4), lab="lines", w=3, palette=:grays, fill=0, α=0.6)
        pl = scatter!(y, zcolor=abs.(y .- 0.5), m=(:heat, 0.8, Plots.stroke(1, :green)), ms=10 * abs.(y .- 0.5) .+ 4, lab="grad")
        Plots._update_plot_object(pl)
        axis = Plots.pgfx_axes(pl.o)[1]
        @test count( x->x isa PGFPlotsX.LegendEntry, axis.contents ) == 5
        @test count( x->x isa PGFPlotsX.Plot, axis.contents ) == 5
        # TODO: marker size does not adjust
        # TODO: marker stroke is incorrect
     end # testset
     @testset "Plot in pieces" begin
        plot(rand(100) / 3, reg=true, fill=(0, :green))
        scatter!(rand(100), markersize=6, c=:orange)
     end # testset
     @testset "Marker types" begin
        markers = filter((m->begin
           m in Plots.supported_markers()
           end), Plots._shape_keys)
        markers = reshape(markers, 1, length(markers))
        n = length(markers)
        x = (range(0, stop=10, length=n + 2))[2:end - 1]
        y = repeat(reshape(reverse(x), 1, :), n, 1)
        scatter(x, y, m=(8, :auto), lab=map(string, markers), bg=:linen, xlim=(0, 10), ylim=(0, 10))
     end # testset
     @testset "Layout" begin
        plot(Plots.fakedata(100, 10), layout=4, palette=[:grays :blues :heat :lightrainbow], bg_inside=[:orange :pink :darkblue :black])
        # TODO: no extra space for outer legends
     end # testset
     @testset "Polar plots" begin
        Θ = range(0, stop=1.5π, length=100)
        r = abs.(0.1 * randn(100) + sin.(3Θ))
        plot(Θ, r, proj=:polar, m=2)
        # TODO: handle polar plots
     end # testset
     @testset "Histogram 2D" begin
        histogram2d(randn(10000), randn(10000), nbins=20)
        # TODO: totally broken, errors also for pgfplots
     end # testset
     @testset "Contours" begin
        x = 1:0.5:20
        y = 1:0.5:10
        f(x, y) = begin
           (3x + y ^ 2) * abs(sin(x) + cos(y))
        end
        X = repeat(reshape(x, 1, :), length(y), 1)
        Y = repeat(y, 1, length(x))
        Z = map(f, X, Y)
        p1 = contour(x, y, f, fill=true)
        p2 = contour(x, y, Z)
        plot(p1, p2)
        # TODO: totally broken, also errors for pgfplots
     end # testset
end # testset
