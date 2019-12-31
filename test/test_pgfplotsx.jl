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
    @test pgfx_plot.series_list[1].plotattributes[:quiver] === nothing
    axis = Plots.pgfx_axes(pgfx_plot.o)[1]
    @test count( x-> x isa PGFPlotsX.Plot, axis.contents ) == 1
    @test !haskey(axis.contents[1].options.dict, "fill")

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
        @test count( x->x isa PGFPlotsX.Plot, axis.contents ) == 108 # each marker is its own plot, fillranges create 2 plot-objects
        marker = axis.contents[15]
        @test marker isa PGFPlotsX.Plot
        @test marker.options["mark"] == "*"
        @test marker.options["mark options"]["color"] == RGBA{Float64}( colorant"green", 0.8)
        @test marker.options["mark options"]["line width"] == 1
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
     end # testset
     @testset "Polar plots" begin
        Θ = range(0, stop=1.5π, length=100)
        r = abs.(0.1 * randn(100) + sin.(3Θ))
        plot(Θ, r, proj=:polar, m=2)
     end # testset
     @testset "Drawing shapes" begin
        verts = [(-1.0, 1.0), (-1.28, 0.6), (-0.2, -1.4), (0.2, -1.4), (1.28, 0.6), (1.0, 1.0), (-1.0, 1.0), (-0.2, -0.6), (0.0, -0.2), (-0.4, 0.6), (1.28, 0.6), (0.2, -1.4), (-0.2, -1.4), (0.6, 0.2), (-0.2, 0.2), (0.0, -0.2), (0.2, 0.2), (-0.2, -0.6)]
         x = 0.1:0.2:0.9
         y = 0.7 * rand(5) .+ 0.15
         plot(x, y, line=(3, :dash, :lightblue), marker=(Shape(verts), 30, RGBA(0, 0, 0, 0.2)), bg=:pink, fg=:darkblue, xlim=(0, 1), ylim=(0, 1), leg=false)
     end # testset
     @testset "Histogram 2D" begin
        histogram2d(randn(10000), randn(10000), nbins=20)
     end # testset
     @testset "Heatmap-like" begin
        xs = [string("x", i) for i = 1:10]
        ys = [string("y", i) for i = 1:4]
        z = float((1:4) * reshape(1:10, 1, :))
        pgfx_plot = heatmap(xs, ys, z, aspect_ratio=1)
        Plots._update_plot_object(pgfx_plot)
        if @test_nowarn(haskey(Plots.pgfx_axes(pgfx_plot.o)[1].options.dict, "colorbar") == true)
           @test Plots.pgfx_axes(pgfx_plot.o)[1]["colorbar"] === nothing
           @test Plots.pgfx_axes(pgfx_plot.o)[1]["colormap name"] == "plots1"
        end

        pgfx_plot = wireframe(xs, ys, z, aspect_ratio=1)
        # TODO: clims are wrong
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
        p2 = contour(x, y, Z)
        p1 = contour(x, y, f, fill=true)
        plot(p1, p2)
        # TODO: colorbar for filled contours
     end # testset
     @testset "Varying colors" begin
        t = range(0, stop=1, length=100)
         θ = (6π) .* t
         x = t .* cos.(θ)
         y = t .* sin.(θ)
         p1 = plot(x, y, line_z=t, linewidth=3, legend=false)
         p2 = scatter(x, y, marker_z=((x, y)->begin
                             x + y
                         end), color=:bluesreds, legend=false)
         plot(p1, p2)
     end # testset
     @testset "Framestyles" begin
        scatter(fill(randn(10), 6), fill(randn(10), 6), framestyle=[:box :semi :origin :zerolines :grid :none], title=[":box" ":semi" ":origin" ":zerolines" ":grid" ":none"], color=permutedims(1:6), layout=6, label="", markerstrokewidth=0, ticks=-2:2)
        # TODO: support :semi
     end # testset
     @testset "Quiver" begin
        x = -2pi:0.2:2*pi
        y = sin.(x)

        u = ones(length(x))
        v = cos.(x)
        arrow_plot = plot( x, y, quiver = (u, v), arrow = true )
        # TODO: could adjust limits to fit arrows if too long, but how?
        # TODO: get latex available on CI
        # mktempdir() do path
        #    @test_nowarn savefig(arrow_plot, path*"arrow.pdf")
        # end
     end # testset
     @testset "Annotations" begin
        y = rand(10)
        plot(y, annotations=(3, y[3], Plots.text("this is \\#3", :left)), leg=false)
        annotate!([(5, y[5], Plots.text("this is \\#5", 16, :red, :center)), (10, y[10], Plots.text("this is \\#10", :right, 20, "courier"))])
        annotation_plot = scatter!(range(2, stop=8, length=6), rand(6), marker=(50, 0.2, :orange), series_annotations=["series", "annotations", "map", "to", "series", Plots.text("data", :green)])
        # mktempdir() do path
        #    @test_nowarn savefig(annotation_plot, path*"annotation.pdf")
        # end
     end # testset
     @testset "Ribbon" begin
        aa = rand(10)
        bb = rand(10)
        cc = rand(10)
        conf = [aa-cc bb-cc]
        ribbon_plot = plot(collect(1:10),fill(1,10), ribbon=(conf[:,1],conf[:,2]))
        Plots._update_plot_object(ribbon_plot)
        axis = Plots.pgfx_axes(ribbon_plot.o)[1]
        plots = filter(x->x isa PGFPlotsX.Plot, axis.contents)
        @test length(plots) == 4
        @test !haskey(plots[1].options.dict, "fill")
        @test !haskey(plots[2].options.dict, "fill")
        @test !haskey(plots[3].options.dict, "fill")
        @test haskey(plots[4].options.dict, "fill")
        @test ribbon_plot.o !== nothing
        @test ribbon_plot.o.the_plot !== nothing
     #    mktempdir() do path
     #       @test_nowarn savefig(ribbon_plot, path*"ribbon.svg")
     #    end
     end # testset
  end # testset
