using Test, Plots, Unitful, LaTeXStrings

function create_plot(args...; kwargs...)
    pl = plot(args...; kwargs...)
    return pl, repr("application/x-tex", pl)
end

function create_plot!(args...; kwargs...)
    pl = plot!(args...; kwargs...)
    return pl, repr("application/x-tex", pl)
end

function get_pgf_axes(pl)
    Plots._update_plot_object(pl)
    Plots.pgfx_axes(pl.o)
end

Plots.with(:pgfplotsx) do
    pl = plot(1:5)
    axis = first(get_pgf_axes(pl))
    @test pl.o.the_plot isa PGFPlotsX.TikzDocument
    @test pl.series_list[1].plotattributes[:quiver] === nothing
    @test count(x -> x isa PGFPlotsX.Plot, axis.contents) == 1
    @test !haskey(axis.contents[1].options.dict, "fill")
    @test occursin("documentclass", Plots.pgfx_preamble(pl))
    @test occursin("documentclass", Plots.pgfx_preamble())

    @testset "Legends" begin
        pl = plot(rand(5, 2), lab = ["1" ""], arrow = true)
        scatter!(pl, rand(5))
        axis_contents = first(get_pgf_axes(pl)).contents
        leg_entries = filter(x -> x isa PGFPlotsX.LegendEntry, axis_contents)
        series = filter(x -> x isa PGFPlotsX.Plot, axis_contents)
        @test length(leg_entries) == 2
        @test length(series) == 5
        @test !haskey(series[1].options.dict, "forget plot")
        @test haskey(series[2].options.dict, "forget plot")
        @test haskey(series[3].options.dict, "forget plot")
        @test haskey(series[4].options.dict, "forget plot")
        @test !haskey(series[5].options.dict, "forget plot")
    end

    @testset "3D docs example" begin
        n = 100
        ts = range(0, stop = 8π, length = n)
        x = ts .* map(cos, ts)
        y = (0.1ts) .* map(sin, ts)
        z = 1:n
        pl = plot(
            x,
            y,
            z,
            zcolor = reverse(z),
            m = (10, 0.8, :blues, Plots.stroke(0)),
            leg = false,
            cbar = true,
            w = 5,
        )
        pl = plot!(pl, zeros(n), zeros(n), 1:n, w = 10)
        axis = first(get_pgf_axes(pl))
        if @test_nowarn(haskey(axis.options.dict, "colorbar"))
            @test axis["colorbar"] === nothing
        end
    end

    @testset "Color docs example" begin
        y = rand(100)
        plot(
            0:10:100,
            rand(11, 4),
            lab = "lines",
            w = 3,
            palette = :grays,
            fill = 0,
            α = 0.6,
        )
        pl = scatter!(
            y,
            zcolor = abs.(y .- 0.5),
            m = (:hot, 0.8, Plots.stroke(1, :green)),
            ms = 10 * abs.(y .- 0.5) .+ 4,
            lab = ["grad", "", "ient"],
        )
        axis = first(get_pgf_axes(pl))
        @test count(x -> x isa PGFPlotsX.LegendEntry, axis.contents) == 6
        @test count(x -> x isa PGFPlotsX.Plot, axis.contents) == 108 # each marker is its own plot, fillranges create 2 plot-objects
        marker = axis.contents[15]
        @test marker isa PGFPlotsX.Plot
        @test marker.options["mark"] == "*"
        @test marker.options["mark options"]["color"] == RGBA{Float64}(colorant"green", 0.8)
        @test marker.options["mark options"]["line width"] == 0.75 # 1px is 0.75pt
    end

    @testset "Plot in pieces" begin
        pl = plot(rand(100) / 3, reg = true, fill = (0, :green))
        scatter!(pl, rand(100), markersize = 6, c = :orange)
        axis_contents = first(get_pgf_axes(pl)).contents
        leg_entries = filter(x -> x isa PGFPlotsX.LegendEntry, axis_contents)
        series = filter(x -> x isa PGFPlotsX.Plot, axis_contents)
        @test length(leg_entries) == 2
        @test length(series) == 4
        @test haskey(series[1].options.dict, "forget plot")
        @test !haskey(series[2].options.dict, "forget plot")
        @test haskey(series[3].options.dict, "forget plot")
        @test !haskey(series[4].options.dict, "forget plot")
    end

    @testset "Marker types" begin
        markers = filter((m -> begin
            m in Plots.supported_markers()
        end), Plots._shape_keys)
        markers = reshape(markers, 1, length(markers))
        n = length(markers)
        x = (range(0, stop = 10, length = n + 2))[2:(end - 1)]
        y = repeat(reshape(reverse(x), 1, :), n, 1)
        @test scatter(
            x,
            y,
            m = (8, :auto),
            lab = map(string, markers),
            bg = :linen,
            xlim = (0, 10),
            ylim = (0, 10),
        ) isa Plots.Plot
    end

    @testset "Layout" begin
        @test plot(
            Plots.fakedata(100, 10),
            layout = 4,
            palette = [:grays :blues :hot :rainbow],
            bg_inside = [:orange :pink :darkblue :black],
        ) isa Plots.Plot
    end

    @testset "Polar plots" begin
        Θ = range(0, stop = 1.5π, length = 100)
        r = abs.(0.1 * randn(100) + sin.(3Θ))
        @test plot(Θ, r, proj = :polar, m = 2) isa Plots.Plot
    end

    @testset "Drawing shapes" begin
        verts = [
            (-1.0, 1.0),
            (-1.28, 0.6),
            (-0.2, -1.4),
            (0.2, -1.4),
            (1.28, 0.6),
            (1.0, 1.0),
            (-1.0, 1.0),
            (-0.2, -0.6),
            (0.0, -0.2),
            (-0.4, 0.6),
            (1.28, 0.6),
            (0.2, -1.4),
            (-0.2, -1.4),
            (0.6, 0.2),
            (-0.2, 0.2),
            (0.0, -0.2),
            (0.2, 0.2),
            (-0.2, -0.6),
        ]
        x = 0.1:0.2:0.9
        y = 0.7 * rand(5) .+ 0.15
        @test plot(
            x,
            y,
            line = (3, :dash, :lightblue),
            marker = (Shape(verts), 30, RGBA(0, 0, 0, 0.2)),
            bg = :pink,
            fg = :darkblue,
            xlim = (0, 1),
            ylim = (0, 1),
            leg = false,
        ) isa Plots.Plot
    end

    @testset "Histogram 2D" begin
        @test histogram2d(randn(10_000), randn(10_000), nbins = 20) isa Plots.Plot
    end

    @testset "Heatmap-like" begin
        xs = [string("x", i) for i in 1:10]
        ys = [string("y", i) for i in 1:4]
        z = float((1:4) * reshape(1:10, 1, :))
        pl = heatmap(xs, ys, z, aspect_ratio = 1)
        axis = first(get_pgf_axes(pl))
        if @test_nowarn(haskey(axis.options.dict, "colorbar"))
            @test axis["colorbar"] === nothing
            @test axis["colormap name"] == "plots1"
        end

        @test wireframe(xs, ys, z, aspect_ratio = 1) isa Plots.Plot
        # TODO: clims are wrong
    end

    @testset "Contours" begin
        x = 1:0.5:20
        y = 1:0.5:10
        f(x, y) = (3x + y^2) * abs(sin(x) + cos(y))
        X = repeat(reshape(x, 1, :), length(y), 1)
        Y = repeat(y, 1, length(x))
        Z = map(f, X, Y)
        p2 = contour(x, y, Z)
        p1 = contour(x, y, f, fill = true)
        p3 = contour3d(x, y, Z)
        @test plot(p1, p2) isa Plots.Plot
        @test_nowarn Plots._update_plot_object(p3)
        # TODO: colorbar for filled contours
    end

    @testset "Varying colors" begin
        t = range(0, stop = 1, length = 100)
        θ = (6π) .* t
        x = t .* cos.(θ)
        y = t .* sin.(θ)
        p1 = plot(x, y, line_z = t, linewidth = 3, legend = false)
        p2 = scatter(x, y, marker_z = (x, y) -> x + y, color = :bwr, legend = false)
        @test plot(p1, p2) isa Plots.Plot
    end

    @testset "Framestyles" begin
        # TODO: support :semi
        pl = scatter(
            fill(randn(10), 6),
            fill(randn(10), 6),
            framestyle = [:box :semi :origin :zerolines :grid :none],
            title = [":box" ":semi" ":origin" ":zerolines" ":grid" ":none"],
            color = permutedims(1:6),
            layout = 6,
            label = "",
            markerstrokewidth = 0,
            ticks = -2:2,
        )
        for (i, axis) in enumerate(get_pgf_axes(pl))
            opts = axis.options
            # just check by indexing (not defined -> throws)
            opts["x axis line style"]
            opts["y axis line style"]
            if i == 3
                opts["axis x line*"]
                opts["axis y line*"]
            end
            @test true
        end
    end

    @testset "Quiver" begin
        x = (-2pi):0.2:(2 * pi)
        y = sin.(x)

        u = ones(length(x))
        v = cos.(x)
        pl = plot(x, y, quiver = (u, v), arrow = true)
        @test pl isa Plots.Plot
        # TODO: could adjust limits to fit arrows if too long, but how ?
        # mktempdir() do path
        #    @test_nowarn savefig(pl, path*"arrow.pdf")
        # end
    end

    @testset "Annotations" begin
        y = rand(10)
        ann = (3, y[3], Plots.text("this is \\#3", :left))
        pl = plot(y, annotations = ann, leg = false)
        axis_content = first(get_pgf_axes(pl)).contents
        nodes = filter(x -> !isa(x, PGFPlotsX.Plot), axis_content)
        @test length(nodes) == 1
        mktempdir() do path
            file_path = joinpath(path, "annotations.tex")
            @test_nowarn savefig(pl, file_path)
            open(file_path) do io
                lines = readlines(io)
                @test count(s -> occursin("node", s), lines) == 1
            end
        end
        annotate!([
            (5, y[5], Plots.text("this is \\#5", 16, :red, :center)),
            (10, y[10], Plots.text("this is \\#10", :right, 20, "courier")),
        ])
        axis_content = first(get_pgf_axes(pl)).contents
        nodes = filter(x -> !isa(x, PGFPlotsX.Plot), axis_content)
        @test length(nodes) == 3
        mktempdir() do path
            file_path = joinpath(path, "annotations.tex")
            @test_nowarn savefig(pl, file_path)
            open(file_path) do io
                lines = readlines(io)
                @test count(s -> occursin("node", s), lines) == 3
            end
        end
        pl = scatter!(
            range(2, stop = 8, length = 6),
            rand(6),
            marker = (50, 0.2, :orange),
            series_annotations = [
                "series",
                "annotations",
                "map",
                "to",
                "series",
                Plots.text("data", :green),
            ],
        )
        axis_content = first(get_pgf_axes(pl)).contents
        nodes = filter(x -> !isa(x, PGFPlotsX.Plot), axis_content)
        @test length(nodes) == 9
        mktempdir() do path
            file_path = joinpath(path, "annotations.tex")
            @test_nowarn savefig(pl, file_path)
            open(file_path) do io
                lines = readlines(io)
                @test count(s -> occursin("node", s), lines) == 9
            end
            # test .tikz extension
            file_path = joinpath(path, "annotations.tikz")
            @test_nowarn savefig(pl, file_path)
            @test_nowarn open(file_path) do io
            end
        end
    end

    @testset "Ribbon" begin
        aa = rand(10)
        bb = rand(10)
        cc = rand(10)
        conf = [aa - cc bb - cc]
        pl = plot(collect(1:10), fill(1, 10), ribbon = (conf[:, 1], conf[:, 2]))
        axis_contents = first(get_pgf_axes(pl)).contents
        plots = filter(x -> x isa PGFPlotsX.Plot, axis_contents)
        @test length(plots) == 3
        @test haskey(plots[1].options.dict, "fill")
        @test haskey(plots[2].options.dict, "fill")
        @test !haskey(plots[3].options.dict, "fill")
        @test pl.o !== nothing
        @test pl.o.the_plot !== nothing
    end

    @testset "Markers and Paths" begin
        pl = plot(
            5 .- ones(9),
            markershape = [:utriangle, :rect],
            markersize = 8,
            color = [:red, :black],
        )
        axis_contents = first(get_pgf_axes(pl)).contents
        plots = filter(x -> x isa PGFPlotsX.Plot, axis_contents)
        @test length(plots) == 9
    end

    @testset "Groups and Subplots" begin
        group = rand(map(i -> "group $i", 1:4), 100)
        pl = plot(
            rand(100),
            layout = @layout([a b; c]),
            group = group,
            linetype = [:bar :scatter :steppre],
            linecolor = :match,
        )
        axis_contents = first(get_pgf_axes(pl)).contents
        legend_entries = filter(x -> x isa PGFPlotsX.LegendEntry, axis_contents)
        @test length(legend_entries) == 2
    end

    @testset "Extra kwargs" begin
        pl = plot(1:5, test = "me")
        @test pl[1][1].plotattributes[:extra_kwargs][:test] == "me"
        pl = plot(1:5, test = "me", extra_kwargs = :subplot)
        @test pl[1].attr[:extra_kwargs][:test] == "me"
        pl = plot(1:5, test = "me", extra_kwargs = :plot)
        @test pl.attr[:extra_plot_kwargs][:test] == "me"
        pl = plot(
            1:5,
            extra_kwargs = Dict(
                :plot => Dict(:test => "me"),
                :series => Dict(:and => "me too"),
            ),
        )
        @test pl.attr[:extra_plot_kwargs][:test] == "me"
        @test pl[1][1].plotattributes[:extra_kwargs][:and] == "me too"
        pl = plot(
            plot(1:5, title = "Line"),
            scatter(
                1:5,
                title = "Scatter",
                extra_kwargs = Dict(:subplot => Dict("axis line shift" => "10pt")),
            ),
        )
        axes = get_pgf_axes(pl)
        @test !haskey(axes[1].options.dict, "axis line shift")
        @test haskey(axes[2].options.dict, "axis line shift")
        pl = plot(
            x -> x,
            -1:1;
            add = raw"\node at (0,0.5) {\huge hi};",
            extra_kwargs = :subplot,
        )
        @test pl[1][:extra_kwargs] == Dict(:add => raw"\node at (0,0.5) {\huge hi};")
        axis_contents = first(get_pgf_axes(pl)).contents
        @test filter(x -> x isa String, axis_contents)[1] ==
              raw"\node at (0,0.5) {\huge hi};"
        plot!(pl)
        @test pl[1][:extra_kwargs] == Dict(:add => raw"\node at (0,0.5) {\huge hi};")
        axis_contents = first(get_pgf_axes(pl)).contents
        @test filter(x -> x isa String, axis_contents)[1] ==
              raw"\node at (0,0.5) {\huge hi};"
    end

    @testset "Titlefonts" begin
        pl = plot(1:5, title = "Test me", titlefont = (2, :left))
        @test pl[1][:title] == "Test me"
        @test pl[1][:titlefontsize] == 2
        @test pl[1][:titlefonthalign] === :left
        ax_opt = first(get_pgf_axes(pl)).options
        @test ax_opt["title"] == "Test me"
        @test(haskey(ax_opt.dict, "title style")) isa Test.Pass
        pl = plot(1:5, plot_title = "Test me", plot_titlefont = (2, :left))
        @test pl[:plot_title] == "Test me"
        @test pl[:plot_titlefontsize] == 2
        @test pl[:plot_titlefonthalign] === :left
        pl = heatmap(
            rand(3, 3),
            colorbar_title = "Test me",
            colorbar_titlefont = (12, :right),
        )
        @test pl[1][:colorbar_title] == "Test me"
        @test pl[1][:colorbar_titlefontsize] == 12
        @test pl[1][:colorbar_titlefonthalign] === :right
    end

    @testset "Latexify - LaTeXStrings" begin
        @test Plots.pgfx_sanitize_string("A string, with 2 punctuation chars.") ==
              "A string, with 2 punctuation chars."
        @test Plots.pgfx_sanitize_string("Interpolação polinomial") ==
              raw"Interpola$\textnormal{\c{c}}$$\tilde{a}$o polinomial"
        @test Plots.pgfx_sanitize_string("∫∞ ∂x") == raw"$\int$$\infty$ $\partial$x"

        # special LaTeX characters
        @test Plots.pgfx_sanitize_string("this is #3").s == raw"this is \#3"
        @test Plots.pgfx_sanitize_string("10% increase").s == raw"10\% increase"
        @test Plots.pgfx_sanitize_string("underscores _a_").s == raw"underscores \_a\_"
        @test Plots.pgfx_sanitize_string("plot 1 & 2 & 3").s == raw"plot 1 \& 2 \& 3"
        @test Plots.pgfx_sanitize_string("GDP in \$").s == raw"GDP in \$"
        @test Plots.pgfx_sanitize_string("curly { test }").s == raw"curly \{ test \}"

        @test Plots.pgfx_sanitize_string(L"this is #5").s == raw"$this is \#5$"
        @test Plots.pgfx_sanitize_string(L"10% increase").s == raw"$10\% increase$"
    end

    @testset "Setting correct plot titles" begin
        plt1 = plot(rand(10, 5))
        plt2 = plot(rand(10))

        @test plot(plt1, plt2, layout = (1, 2), plot_titles = ["(a)" "(b)"]) !== nothing
    end

    if Sys.islinux() && Sys.which("pdflatex") ≢ nothing
        @testset "Issues - actually compile `.tex`" begin
            # Plots.jl/issues/4308
            fn = tempname() * ".pdf"
            pl = plot((1:10) .^ 2, (1:10) .^ 2, xscale = :log10)
            Plots.pdf(pl, fn)
            @test isfile(fn)
        end
    end

    @testset "Unitful interaction" begin
        yreg = r"ylabel=\{((?:[^{}]*\{[^{}]*\})*[^{}]*?)\}"
        pl1 = plot([1u"s", 2u"s"], [1u"m", 2u"m"], xlabel = "t", ylabel = "diameter")
        pl2 = plot([1u"s", 2u"s"], [1u"m/s^2", 2u"m/s^2"])
        pl1_tex = String(repr("application/x-tex", pl1))
        pl2_tex = String(repr("application/x-tex", pl2))
        @test pl1_tex[findfirst(yreg, pl1_tex)] == "ylabel={diameter (\$\\mathrm{m}\$)}"
        @test pl2_tex[findfirst(yreg, pl2_tex)] ==
              "ylabel={\$\\mathrm{m}\\,\\mathrm{s}^{-2}\$}"
    end
end
