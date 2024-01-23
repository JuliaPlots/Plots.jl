"""
Holds all data needed for a documentation example... header, description, and plotting expression (Expr)
"""
mutable struct PlotExample
    header::AbstractString
    desc::AbstractString
    external::Bool  # requires external optional dependencies not listed in [deps]
    imports::Union{Nothing,Expr}
    exprs::Expr
end

# COV_EXCL_START
PlotExample(header::AbstractString, expr::Expr) = PlotExample(header, "", expr)
PlotExample(header::AbstractString, imports::Expr, expr::Expr) =
    PlotExample(header, "", false, imports, expr)
PlotExample(header::AbstractString, desc::AbstractString, expr::Expr) =
    PlotExample(header, desc, false, nothing, expr)
PlotExample(header::AbstractString, desc::AbstractString, imports::Expr, expr::Expr) =
    PlotExample(header, desc, false, imports, expr)
# COV_EXCL_STOP

# the _examples we'll run for each backend
const _examples = PlotExample[
    PlotExample( # 1
        "Lines",
        "A simple line plot of the columns.",
        :(plot(Plots.fakedata(50, 5), w = 3)),
    ),
    PlotExample( # 2
        "Functions, adding data, and animations",
        """
        Plot multiple functions. You can also put the function first, or use the form `plot(f,
        xmin, xmax)` where f is a Function or AbstractVector{Function}.\n\nGet series data:
        `x, y = plt[i]`.  Set series data: `plt[i] = (x,y)`. Add to the series with
        `push!`/`append!`.\n\nEasily build animations.  (`convert` or `ffmpeg` must be available
        to generate the animation.)  Use command `gif(anim, filename, fps=15)` to save the
        animation.
        """,
        quote
            p = plot([sin, cos], zeros(0), leg = false, xlims = (0, 2π), ylims = (-1, 1))
            anim = Animation()
            for x in range(0, stop = 2π, length = 20)
                push!(p, x, Float64[sin(x), cos(x)])
                frame(anim)
            end
        end,
    ),
    PlotExample( # 3
        "Parametric plots",
        "Plot function pair (x(u), y(u)).",
        :(plot(sin, x -> sin(2x), 0, 2π, line = 4, leg = false, fill = (0, :orange))),
    ),
    PlotExample( # 4
        "Colors",
        """
        Access predefined palettes (or build your own with the `colorscheme` method).
        Line/marker colors are auto-generated from the plot's palette, unless overridden.  Set
        the `z` argument to turn on series gradients.
        """,
        quote
            y = rand(100)
            plot(
                0:10:100,
                rand(11, 4),
                lab = "lines",
                w = 3,
                palette = cgrad(:grays),
                fill = 0,
                α = 0.6,
            )
            scatter!(
                y,
                zcolor = abs.(y .- 0.5),
                m = (:heat, 0.8, Plots.stroke(1, :green)),
                ms = 10 * abs.(y .- 0.5) .+ 4,
                lab = "grad",
            )
        end,
    ),
    PlotExample( # 5
        "Global",
        """
        Change the guides/background/limits/ticks.  Convenience args `xaxis` and `yaxis` allow
        you to pass a tuple or value which will be mapped to the relevant args automatically.
        The `xaxis` below will be replaced with `xlabel` and `xlims` args automatically during
        the preprocessing step. You can also use shorthand functions: `title!`, `xaxis!`,
        `yaxis!`, `xlabel!`, `ylabel!`, `xlims!`, `ylims!`, `xticks!`, `yticks!`
        """,
        :(using Statistics),
        quote
            y = rand(20, 3)
            plot(
                y,
                xaxis = ("XLABEL", (-5, 30), 0:2:20, :flip),
                background_color = RGB(0.2, 0.2, 0.2),
                leg = false,
            )
            hline!(
                mean(y, dims = 1) + rand(1, 3),
                line = (4, :dash, 0.6, [:lightgreen :green :darkgreen]),
            )
            vline!([5, 10])
            title!("TITLE")
            yaxis!("YLABEL", :log10, minorgrid = true)
        end,
    ),
    PlotExample( # 6
        "Images",
        "Plot an image.  y-axis is set to flipped",
        true,
        :(import Downloads, FileIO),
        quote
            path = Downloads.download(
                "http://juliaplots.org/PlotReferenceImages.jl/Plots/pyplot/0.7.0/ref1.png",
            )
            img = FileIO.load(path)
            plot(img)
        end,
    ),
    PlotExample( # 7
        "Arguments",
        """
        Plot multiple series with different numbers of points.  Mix arguments that apply to all
        series (marker/markersize) with arguments unique to each series (colors).  Special
        arguments `line`, `marker`, and `fill` will automatically figure out what arguments to
        set (for example, we are setting the `linestyle`, `linewidth`, and `color` arguments with
        `line`.)  Note that we pass a matrix of colors, and this applies the colors to each
        series.
        """,
        quote
            plot(
                [rand(10), rand(20)],
                color = [:black :orange],
                line = (:dot, 4),
                marker = ([:hex :d], 12, 0.8, Plots.stroke(3, :gray)),
            )
        end,
    ),
    PlotExample( # 8
        "Build plot in pieces",
        "Start with a base plot...",
        :(plot(rand(100) / 3, reg = true, fill = (0, :green))),
    ),
    PlotExample( # 9
        "",
        "and add to it later.",
        :(scatter!(rand(100), markersize = 6, c = :orange)),
    ),
    PlotExample( # 10
        "Histogram2D",
        :(histogram2d(randn(10_000), randn(10_000), nbins = 20)),
    ),
    PlotExample( # 11
        "Line types",
        quote
            linetypes = [:path :steppre :steppost :sticks :scatter]
            n = length(linetypes)
            x = map(_ -> sort(rand(20)), 1:n)
            y = rand(20, n)
            plot(x, y, line = (linetypes, 3), lab = map(string, linetypes), ms = 15)
        end,
    ),
    PlotExample( # 12
        "Line styles",
        quote
            styles = filter(
                s -> s in Plots.supported_styles(),
                [:solid, :dash, :dot, :dashdot, :dashdotdot],
            )
            styles = reshape(styles, 1, length(styles)) # Julia 0.6 unfortunately gives an error when transposing symbol vectors
            plot(
                cumsum(randn(20, length(styles)), dims = 1),
                line = (5, styles),
                label = map(string, styles),
                legendtitle = "linestyle",
            )
        end,
    ),
    PlotExample( # 13
        "Marker types",
        quote
            markers = filter(m -> m in Plots.supported_markers(), Plots._shape_keys)
            markers = permutedims(markers)
            n = length(markers)
            x = range(0, stop = 10, length = n + 2)[2:(end - 1)]
            y = repeat(reshape(reverse(x), 1, :), n, 1)
            scatter(
                x,
                y,
                m = markers,
                markersize = 8,
                lab = map(string, markers),
                bg = :linen,
                xlim = (0, 10),
                ylim = (0, 10),
            )
        end,
    ),
    PlotExample( # 14
        "Bar",
        "`bar(x, y)` plots bars with heights `y` and centers at `x`. `x` defaults to `eachindex(y)`.",
        :(plot(bar(randn(10)), bar([0, 3, 5], [1, 2, 6]), legend = false)),
    ),
    PlotExample( # 15
        "Histogram",
        :(histogram(randn(1_000), bins = :scott, weights = repeat(1:5, outer = 200))),
    ),
    PlotExample( # 16
        "Subplots",
        """
        Use the `layout` keyword, and optionally the convenient `@layout` macro to generate
        arbitrarily complex subplot layouts.
        """,
        quote
            l = @layout([a{0.1h}; b [c; d e]])
            plot(
                randn(100, 5),
                layout = l,
                t = [:line :histogram :scatter :steppre :bar],
                leg = false,
                ticks = nothing,
                border = :none,
            )
        end,
    ),
    PlotExample( # 17
        "Adding to subplots",
        """
        Note here the automatic grid layout, as well as the order in which new series are added
        to the plots.
        """,
        quote
            plot(
                Plots.fakedata(100, 10),
                layout = 4,
                palette = cgrad.([:grays :blues :heat :lightrainbow]),
                bg_inside = [:orange :pink :darkblue :black],
            )
        end,
    ),
    PlotExample( # 18
        "",
        :(using Random),
        quote
            Random.seed!(111)
            plot!(Plots.fakedata(100, 10))
        end,
    ),
    PlotExample( # 19
        "Open/High/Low/Close",
        """
        Create an OHLC chart.  Pass in a list of (open,high,low,close) tuples as your `y`
        argument.  This uses recipes to first convert the tuples to OHLC objects, and
        subsequently create a :path series with the appropriate line segments.
        """,
        quote
            n = 20
            hgt = rand(n) .+ 1
            bot = randn(n)
            openpct = rand(n)
            closepct = rand(n)
            y = OHLC[
                (
                    openpct[i] * hgt[i] + bot[i],
                    bot[i] + hgt[i],
                    bot[i],
                    closepct[i] * hgt[i] + bot[i],
                ) for i in 1:n
            ]
            ohlc(y)
        end,
    ),
    PlotExample( # 20
        "Annotations",
        """
        The `annotations` keyword is used for text annotations in data-coordinates.
        Pass in a 3-tuple of vectors `(x, y, text)`, or a vector of annotations,
        each of which is a tuple of `x`, `y` and `text`.
        You can position annotations using relative coordinates with the syntax
        `((px, py), text)`, where for example `px=.25` positions the annotation at `25%` of
        the subplot's axis width.
        `text` may be a simple `String`, or a `PlotText` object, which can be built with the
        method `text(string, attrs...)`.
        This wraps font and color attributes and allows you to set text styling.
        `text` may also be a tuple `(string, attrs...)` of arguments which are passed
        to `Plots.text`.

        `annotate!(ann)` is shorthand for `plot!(; annotation=ann)`,
        and `annotate!(x, y, txt)` for `plot!(; annotation=(x,y,txt))`.

        Series annotations are used for annotating individual data points.
        They require only the annotation; x/y values are computed.  Series annotations
        require either plain `String`s or `PlotText` objects.
        """,
        quote
            y = rand(10)
            plot(y, annotations = (3, y[3], Plots.text("this is #3", :left)), leg = false)
            # single vector of annotation tuples
            annotate!([
                (5, y[5], ("this is #5", 16, :red, :center)),
                (10, y[10], ("this is #10", :right, 20, "courier")),
            ])
            # `x, y, text` vectors
            annotate!([2, 8], y[[2, 8]], ["#2", "#8"])
            scatter!(
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
        end,
    ),
    PlotExample( # 21
        "Custom Markers",
        """A `Plots.Shape` is a light wrapper around vertices of a polygon.  For supported
        backends, pass arbitrary polygons as the marker shapes.  Note: The center is (0,0) and
        the size is expected to be rougly the area of the unit circle.
        """,
        quote
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
            plot(
                0.1:0.2:0.9,
                0.7rand(5) .+ 0.15,
                line = (3, :dash, :lightblue),
                marker = (Shape(verts), 30, RGBA(0, 0, 0, 0.2)),
                bg = :pink,
                fg = :darkblue,
                xlim = (0, 1),
                ylim = (0, 1),
                leg = false,
            )
        end,
    ),
    PlotExample( # 22
        "Contours",
        """
        Any value for fill works here.  We first build a filled contour from a function, then an
        unfilled contour from a matrix.
        """,
        quote
            x = 1:0.5:20
            y = 1:0.5:10
            f(x, y) = (3x + y^2) * abs(sin(x) + cos(y))
            X = repeat(reshape(x, 1, :), length(y), 1)
            Y = repeat(y, 1, length(x))
            Z = map(f, X, Y)
            p1 = contour(x, y, f, fill = true)
            p2 = contour(x, y, Z)
            plot(p1, p2)
        end,
    ),
    PlotExample( # 23
        "Pie",
        quote
            x = ["Nerds", "Hackers", "Scientists"]
            y = [0.4, 0.35, 0.25]
            pie(x, y, title = "The Julia Community", l = 0.5)
        end,
    ),
    PlotExample( # 24
        "3D",
        quote
            n = 100
            ts = range(0, stop = 8π, length = n)
            z = 1:n
            plot(
                ts .* map(cos, ts),
                0.1ts .* map(sin, ts),
                z,
                zcolor = reverse(z),
                m = (10, 0.8, :blues, Plots.stroke(0)),
                leg = false,
                cbar = true,
                w = 5,
            )
            plot!(zeros(n), zeros(n), 1:n, w = 10)
        end,
    ),
    PlotExample( # 25
        "DataFrames",
        "Plot using DataFrame column symbols.",
        true,
        :(using StatsPlots, RDatasets),
        quote
            iris = RDatasets.dataset("datasets", "iris")
            @df iris scatter(
                :SepalLength,
                :SepalWidth,
                group = :Species,
                title = "My awesome plot",
                xlabel = "Length",
                ylabel = "Width",
                marker = (0.5, [:cross :hex :star7], 12),
                bg = RGB(0.2, 0.2, 0.2),
            )
        end,
    ),
    PlotExample( # 26
        "Groups and Subplots",
        quote
            group = rand(map(i -> "group $i", 1:4), 100)
            plot(
                rand(100),
                layout = @layout([a b; c]),
                group = group,
                linetype = [:bar :scatter :steppre],
                linecolor = :match,
            )
        end,
    ),
    PlotExample( # 27
        "Polar Plots",
        quote
            Θ = range(0, stop = 1.5π, length = 100)
            r = abs.(0.1 * randn(100) + sin.(3Θ))
            plot(Θ, r, proj = :polar, m = 2)
        end,
    ),
    PlotExample( # 28
        "Heatmap, categorical axes, and aspect_ratio",
        quote
            xs = [string("x", i) for i in 1:10]
            ys = [string("y", i) for i in 1:4]
            z = float((1:4) * reshape(1:10, 1, :))
            heatmap(xs, ys, z, aspect_ratio = 1)
        end,
    ),
    PlotExample( # 29
        "Layouts, margins, label rotation, title location",
        :(using Plots.PlotMeasures),  # for Measures, e.g. mm and px
        quote
            plot(
                rand(100, 6),
                layout = @layout([a b; c]),
                title = ["A" "B" "C"],
                titlelocation = :left,
                left_margin = [20mm 0mm],
                bottom_margin = 10px,
                xrotation = 60,
            )
        end,
    ),
    PlotExample( # 30
        "Boxplot and Violin series recipes",
        "",
        true,
        :(using StatsPlots, RDatasets),
        quote
            singers = RDatasets.dataset("lattice", "singer")
            @df singers violin(:VoicePart, :Height, line = 0, fill = (0.2, :blue))
            @df singers boxplot!(
                :VoicePart,
                :Height,
                line = (2, :black),
                fill = (0.3, :orange),
            )
        end,
    ),
    PlotExample( # 31
        "Animation with subplots",
        "The `layout` macro can be used to create an animation with subplots.",
        quote
            l = @layout([[a; b] c])
            p = plot(
                plot([sin, cos], 1, ylims = (-1, 1), leg = false),
                scatter([atan, cos], 1, ylims = (-1, 1.5), leg = false),
                plot(log, 1, ylims = (0, 2), leg = false),
                layout = l,
                xlims = (1, 2π),
            )

            anim = Animation()
            for x in range(1, stop = 2π, length = 20)
                plot(push!(p, x, Float64[sin(x), cos(x), atan(x), cos(x), log(x)]))
                frame(anim)
            end
        end,
    ),
    PlotExample( # 32
        "Spy",
        """
        For a matrix `mat` with unique nonzeros `spy(mat)` returns a colorless plot. If `mat` has
        various different nonzero values, a colorbar is added. The colorbar can be disabled with
        `legend = nothing`.
        """,
        :(using SparseArrays),
        quote
            a = spdiagm(
                0 => ones(50),
                1 => ones(49),
                -1 => ones(49),
                10 => ones(40),
                -10 => ones(40),
            )
            b = spdiagm(0 => 1:50, 1 => 1:49, -1 => 1:49, 10 => 1:40, -10 => 1:40)
            plot(spy(a), spy(b), title = ["Unique nonzeros" "Different nonzeros"])
        end,
    ),
    PlotExample( # 33
        "Magic grid argument",
        "The grid lines can be modified individually for each axis with the magic `grid` argument.",
        quote
            x = rand(10)
            p1 = plot(x, title = "Default looks")
            p2 = plot(x, grid = (:y, :olivedrab, :dot, 1, 0.9), title = "Modified y grid")
            p3 = plot(deepcopy(p2), title = "Add x grid")
            xgrid!(p3, :on, :cadetblue, 2, :dashdot, 0.4)
            plot(p1, p2, p3, layout = (1, 3), label = "", fillrange = 0, fillalpha = 0.3)
        end,
    ),
    PlotExample( # 34
        "Framestyle",
        """
        The style of the frame/axes of a (sub)plot can be changed with the `framestyle`
        attribute. The default framestyle is `:axes`.
        """,
        quote
            scatter(
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
        end,
    ),
    PlotExample( # 35
        "Lines and markers with varying colors",
        """
        You can use the `line_z` and `marker_z` properties to associate a color with
        each line segment or marker in the plot.
        """,
        quote
            t = range(0, stop = 1, length = 100)
            θ = 6π .* t
            x = t .* cos.(θ)
            y = t .* sin.(θ)
            p1 = plot(x, y, line_z = t, linewidth = 3, legend = false)
            p2 = scatter(x, y, marker_z = +, color = :bluesreds, legend = false)
            plot(p1, p2)
        end,
    ),
    PlotExample( # 36
        "Portfolio Composition maps",
        "see: https://stackoverflow.com/a/37732384",
        :(using Random),
        quote
            Random.seed!(111)
            tickers = ["IBM", "Google", "Apple", "Intel"]
            N, D = 10, length(tickers)
            weights = rand(N, D)
            weights ./= sum(weights, dims = 2)
            returns = sort!((1:N) + D * randn(N))

            portfoliocomposition(weights, returns, labels = permutedims(tickers))
        end,
    ),
    PlotExample( # 37
        "Ribbons",
        """
        Ribbons can be added to lines via the `ribbon` keyword;
        you can pass a tuple of arrays (upper and lower bounds),
        a single Array (for symmetric ribbons), a Function, or a number.
        """,
        quote
            plot(
                plot(0:10; ribbon = (LinRange(0, 2, 11), LinRange(0, 1, 11))),
                plot(0:10; ribbon = 0:0.5:5),
                plot(0:10; ribbon = sqrt),
                plot(0:10; ribbon = 1),
            )
        end,
    ),
    PlotExample( # 38
        "Histogram2D (complex values)",
        "",
        quote
            n = 10_000
            x = exp.(0.1 * randn(n) .+ randn(n) .* (im))
            histogram2d(
                x,
                nbins = (20, 40),
                show_empty_bins = true,
                normed = true,
                aspect_ratio = 1,
            )
        end,
    ),
    PlotExample( # 39
        "Unconnected lines using `missing` or `NaN`",
        """
        Missing values and non-finite values, including `NaN`, are not plotted.
        Instead, lines are separated into segments at these values.
        """,
        quote
            x, y = [1, 2, 2, 1, 1], [1, 2, 1, 2, 1]
            plot(
                plot([rand(5); NaN; rand(5); NaN; rand(5)]),
                plot([1, missing, 2, 3], marker = true),
                plot([x; NaN; x .+ 2], [y; NaN; y .+ 1], arrow = 2),
                plot([1, 2 + 3im, Inf, 4im, 3, -Inf * im, 0, 3 + 3im], marker = true),
                legend = false,
            )
        end,
    ),
    PlotExample( # 40
        "Lens",
        "A lens lets you easily magnify a region of a plot. x and y coordinates refer to the to be magnified region and the via the `inset` keyword the subplot index and the bounding box (in relative coordinates) of the inset plot with the magnified plot can be specified. Additional attributes count for the inset plot.",
        quote
            plot(
                [(0, 0), (0, 0.9), (1, 0.9), (2, 1), (3, 0.9), (80, 0)],
                legend = :outertopright,
                minorgrid = true,
                minorticks = 2,
            )
            plot!([(0, 0), (0, 0.9), (2, 0.9), (3, 1), (4, 0.9), (80, 0)])
            plot!([(0, 0), (0, 0.9), (3, 0.9), (4, 1), (5, 0.9), (80, 0)])
            plot!([(0, 0), (0, 0.9), (4, 0.9), (5, 1), (6, 0.9), (80, 0)])
            lens!([1, 6], [0.9, 1.1], inset = (1, bbox(0.5, 0.0, 0.4, 0.4)))
        end,
    ),
    PlotExample( # 41
        "Array Types",
        "Plots supports different `Array` types that follow the `AbstractArray` interface, like `StaticArrays` and `OffsetArrays`.",
        true,
        :(using StaticArrays, OffsetArrays),
        quote
            sv = SVector{10}(rand(10))
            ov = OffsetVector(rand(10), -2)
            plot(Any[sv, ov], label = ["StaticArray" "OffsetArray"])
            plot!(3ov, ribbon = ov, label = "OffsetArray ribbon")
        end,
    ),
    PlotExample( # 42
        "Setting defaults and font arguments",
        quote
            default(
                titlefont = (20, "times"),
                legendfontsize = 18,
                guidefont = (18, :darkgreen),
                tickfont = (12, :orange),
                guide = "x",
                framestyle = :zerolines,
                yminorgrid = true,
            )
            plot(
                [sin, cos],
                -2π,
                2π,
                label = ["sin(θ)" "cos(θ)"],
                title = "Trigonometric Functions",
                xlabel = "θ",
                linewidth = 2,
                legend = :outertopleft,
            )
        end,
    ),
    PlotExample( # 43
        "Heatmap with DateTime axis",
        :(using Dates),
        :(heatmap(DateTime.(2016:2020), 1:5, rand(5, 5))),
    ),
    PlotExample( # 44
        "Linked axes",
        quote
            x = -5:0.1:5
            plot(plot(x, x -> x^2), plot(x, x -> sin(x)), layout = 2, link = :y)
        end,
    ),
    PlotExample( # 45
        "Error bars and array type recipes",
        quote
            struct Measurement <: Number
                val::Float64
                err::Float64
            end
            value(m::Measurement) = m.val
            uncertainty(m::Measurement) = m.err

            @recipe function f(::Type{T}, m::T) where {T<:AbstractArray{<:Measurement}}
                if !(
                    get(plotattributes, :seriestype, :path) in (
                        :contour,
                        :contourf,
                        :contour3d,
                        :heatmap,
                        :surface,
                        :wireframe,
                        :image,
                    )
                )
                    error_sym = Symbol(plotattributes[:letter], :error)
                    plotattributes[error_sym] = uncertainty.(m)
                end
                value.(m)
            end
        end,
        quote
            x = Measurement.(10sort(rand(10)), rand(10))
            y = Measurement.(10sort(rand(10)), rand(10))
            z = Measurement.(10sort(rand(10)), rand(10))
            surf = Measurement.((1:10) .* (1:10)', rand(10, 10))

            plot(
                scatter(x, [x y]),
                scatter(x, y, z),
                heatmap(x, y, surf),
                wireframe(x, y, surf),
                legend = :topleft,
            )
        end,
    ),
    PlotExample( # 46
        "Tuples and `Point`s as data",
        "",
        true,
        :(using GeometryBasics, Distributions),
        quote
            d = MvNormal([1.0 0.75; 0.75 2.0])
            plot([(1, 2), (3, 2), (2, 1), (2, 3)])
            scatter!(Point2.(eachcol(rand(d, 1_000))), alpha = 0.25)
        end,
    ),
    PlotExample( # 47
        "Mesh3d",
        """
        Allows to plot arbitrary 3d meshes. If only x,y,z are given the mesh is generated automatically.
        You can also specify the connections using the connections keyword.
        The connections can be specified in two ways: Either as a tuple of vectors where each vector
        contains the 0-based indices of one point of a triangle, such that elements at the same
        position of these vectors form a triangle. Or as a vector of NTuple{3,Ints} where each element
        contains the 1-based indices of the three points of a triangle.
        """,
        quote
            # specify the vertices
            x = [0, 1, 2, 0]
            y = [0, 0, 1, 2]
            z = [0, 2, 0, 1]

            # specify the triangles
            # every column is one triangle,
            # where the values denote the indices of the vertices of the triangle
            i = [0, 0, 0, 1]
            j = [1, 2, 3, 2]
            k = [2, 3, 1, 3]
            # Or: cns = [(1, 2, 3), (1, 3, 4), (1, 4, 2), (2, 3, 4)] (1-based indexing)

            # the four triangles gives above give a tetrahedron
            mesh3d(
                x,
                y,
                z;
                connections = (i, j, k), # connections = cns
                title = "triangles",
                xlabel = "x",
                ylabel = "y",
                zlabel = "z",
                legend = :none,
                margin = 2Plots.mm,
            )
        end,
    ),
    PlotExample( # 48
        "Vectors of markershapes and segments",
        :(using Base.Iterators: cycle, take),
        quote
            yv = ones(9)
            ys = [1; 1; NaN; ones(6)]
            y = 5 .- [yv 2ys 3yv 4ys]

            plt_color_rows = plot(
                y,
                seriestype = [:path :path :scatter :scatter],
                markershape = collect(take(cycle((:utriangle, :rect)), 9)),
                markersize = 8,
                color = collect(take(cycle((:red, :black)), 9)),
            )

            plt_z_cols = plot(
                y,
                markershape = [:utriangle :x :circle :square],
                markersize = [5 10 10 5],
                marker_z = [5 4 3 2],
                line_z = [1 3 3 1],
                linewidth = [1 10 5 1],
            )

            plot(plt_color_rows, plt_z_cols)
        end,
    ),
    PlotExample( # 49
        "Polar heatmaps",
        quote
            θ = range(0, 2π; length = 100)
            ρ = range(0, 120; length = 50)
            z = sin.(ρ ./ 10) .* cos.(θ)'
            heatmap(
                θ,
                ρ,
                z;
                projection = :polar,
                color = :cividis,
                right_margin = 2Plots.mm,
            )
        end,
    ),
    PlotExample( # 50
        "3D surface with axis guides",
        quote
            xs = collect(0.1:0.05:2.0)
            ys = collect(0.2:0.1:2.0)

            X = [x for x in xs for _ in ys]
            Y = [y for _ in xs for y in ys]

            Z = (x, y) -> 1 / x + y * x^2

            surface(
                X,
                Y,
                Z.(X, Y),
                xlabel = "longer xlabel",
                ylabel = "longer ylabel",
                zlabel = "longer zlabel",
            )
        end,
    ),
    PlotExample( # 51
        "Images with custom axes",
        "",
        true,
        :(using TestImages),
        quote
            img = testimage("lighthouse")

            # plot the image reversing the first dimension and setting yflip = false
            plot(
                [-π, π],
                [-1, 1],
                reverse(img, dims = 1),
                yflip = false,
                aspect_ratio = :none,
            )
            # plot other data
            plot!(sin, -π, π, lw = 3, color = :red)
        end,
    ),
    PlotExample( # 52
        "3d quiver",
        quote
            ϕs = range(-π, π, length = 50)
            θs = range(0, π, length = 25)
            θqs = range(1, π - 1, length = 25)

            x = vec([sin(θ) * cos(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θs)])
            y = vec([sin(θ) * sin(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θs)])
            z = vec([cos(θ) for (ϕ, θ) in Iterators.product(ϕs, θs)])

            u = 0.1vec([sin(θ) * cos(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])
            v = 0.1vec([sin(θ) * sin(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])
            w = 0.1vec([cos(θ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])

            quiver(x, y, z, quiver = (u, v, w))
        end,
    ),
    PlotExample( # 53
        "Step Types",
        "A comparison of the various step-like `seriestype`s",
        quote
            x = 1:5
            y = [1, 2, 3, 2, 1]
            default(shape = :circle)
            plot(
                plot(x, y, markershape = :circle, seriestype = :steppre, label = "steppre"),
                plot(x, y, markershape = :circle, seriestype = :stepmid, label = "stepmid"),
                plot(
                    x,
                    y,
                    markershape = :circle,
                    seriestype = :steppost,
                    label = "steppost",
                ),
                layout = (3, 1),
            )
        end,
    ),
    PlotExample( # 54
        "Guide positions and alignment",
        quote
            plot(
                rand(10, 4),
                layout = 4,
                xguide = "x guide",
                yguide = "y guide",
                xguidefonthalign = [:left :right :right :left],
                yguidefontvalign = [:top :bottom :bottom :top],
                xguideposition = :top,
                yguideposition = [:right :left :right :left],
                ymirror = [false true true false],
                xmirror = [false false true true],
                legend = false,
                seriestype = [:bar :scatter :path :stepmid],
            )
        end,
    ),
    PlotExample( # 55
        "3D axis flip / mirror",
        :(using LinearAlgebra),
        quote
            Plots.with(scalefonts = 0.5) do
                x, y = collect(-6:0.5:10), collect(-8:0.5:8)

                args = x, y, (x, y) -> sinc(norm([x, y]) / π)
                kw = (
                    xlabel = "x",
                    ylabel = "y",
                    zlabel = "z",
                    grid = true,
                    minorgrid = true,
                )

                plots = [wireframe(args..., title = "wire"; kw...)]

                for ax in (:x, :y, :z)
                    push!(
                        plots,
                        wireframe(
                            args...,
                            title = "wire-flip-$ax",
                            xflip = ax === :x,
                            yflip = ax === :y,
                            zflip = ax === :z;
                            kw...,
                        ),
                    )
                end

                for ax in (:x, :y, :z)
                    push!(
                        plots,
                        wireframe(
                            args...,
                            title = "wire-mirror-$ax",
                            xmirror = ax === :x,
                            ymirror = ax === :y,
                            zmirror = ax === :z;
                            kw...,
                        ),
                    )
                end

                plot(
                    plots...,
                    layout = (@layout [_ ° _; ° ° °; ° ° °]),
                    margin = 0Plots.px,
                )
            end
        end,
    ),
    PlotExample( # 56
        "Bar plot customizations",
        """
        Width of bars may be specified as `bar_width`.
        The bars' baseline may be specified as `fillto`.
        Each may be scalar, or a vector specifying one value per bar.
        """,
        quote
            plot(
                bar(
                    [-1, 0, 2, 3],
                    [1, 3, 6, 2],
                    fill_z = 4:-1:1,
                    alpha = [1, 0.2, 0.8, 0.5],
                    label = "",
                    bar_width = 1:4,
                ),
                bar(
                    rand(5),
                    bar_width = 1.2,
                    alpha = 0.8,
                    color = [:lightsalmon, :tomato, :crimson, :firebrick, :darkred],
                    fillto = 0:-0.1:-0.4,
                    label = "reds",
                ),
            )
        end,
    ),
    PlotExample( # 57
        "Vertical and horizontal spans",
        "`vspan` and `hspan` can be used to shade horizontal and vertical ranges.",
        quote
            hspan([1, 2, 3, 4]; label = "hspan", legend = :topleft)
            vspan!([2, 3]; alpha = 0.5, label = "vspan")
            plot!([0, 2, 3, 5], [-1, 3, 2, 6]; c = :black, lw = 2, label = "line")
        end,
    ),
    PlotExample( # 58
        "Stacked area chart",
        "`areaplot` draws stacked area plots.",
        quote
            areaplot(
                1:3,
                [1 2 3; 7 8 9; 4 5 6],
                seriescolor = [:red :green :blue],
                fillalpha = [0.2 0.3 0.4],
            )
        end,
    ),
    PlotExample( # 59
        "Annotations at discrete locations",
        quote
            x, y = ["a", "b", "c"], [1, 5, 15]
            p = scatter(["a", "b"], ["q", "r"], ms = 8, legend = false, tickfontsize = 20)
            annotate!(
                ["a", "b"],
                ["r", "q"],
                [text("ar", :top, :left, 50), text("bq", :bottom, :right, 20)],
            )
        end,
    ),
    PlotExample( # 60
        "3D projection",
        "3D plots projection: orthographic (isometric) and perspective (fps).",
        quote
            # 3d cube segments
            x = [
                [-1, +1],
                [-1, -1],
                [-1, +1],
                [+1, +1],
                [+1, +1],
                [-1, -1],
                [-1, -1],
                [+1, +1],
                [-1, +1],
                [-1, -1],
                [-1, +1],
                [+1, +1],
            ]
            y = [
                [+1, +1],
                [-1, +1],
                [-1, -1],
                [-1, +1],
                [+1, +1],
                [+1, +1],
                [-1, -1],
                [-1, -1],
                [+1, +1],
                [-1, +1],
                [-1, -1],
                [-1, +1],
            ]
            z = [
                [+1, +1],
                [+1, +1],
                [+1, +1],
                [+1, +1],
                [-1, +1],
                [-1, +1],
                [-1, +1],
                [-1, +1],
                [-1, -1],
                [-1, -1],
                [-1, -1],
                [-1, -1],
            ]
            kw = (
                aspect_ratio = :equal,
                label = :none,
                xlabel = "x",
                ylabel = "y",
                zlabel = "z",
                xlims = (-1.1, 1.1),
                ylims = (-1.1, 1.1),
                zlims = (-1.1, 1.1),
            )
            plot(
                plot(
                    x,
                    y,
                    z;
                    proj_type = :ortho,
                    title = "orthographic (isometric)",
                    camera = (45, round(atand(1 / √2); digits = 3)),
                    kw...,
                ),
                plot(
                    x,
                    y,
                    z;
                    proj_type = :persp,
                    title = "perspective (fps)",
                    camera = (0, 0),
                    kw...,
                ),
            )
        end,
    ),
    PlotExample(  # 61
        "Bézier curve",
        :(curves([1, 2, 3, 4], [1, 1, 2, 4], title = "Bézier curve")),
    ),
    PlotExample(  # 62
        "Filled area - hatched patterns",
        "Plot hatched regions.",
        quote
            y = rand(10)
            plot(y .+ 1, fillrange = y, fillstyle = :/)
        end,
    ),
    PlotExample(  # 63
        "Shared axes (twin)",
        "`twinx` (shared `x` axis) and `twiny` (shared `y` axis) example usage.",
        quote
            kw = (; lab = "", title_loc = :left)
            x = π:0.1:(2π)

            plot(
                x,
                sin.(x),
                xaxis = "common X label",
                yaxis = "Y label 1",
                color = :red,
                title = "twinx";
                kw...,
            )
            pl = plot!(twinx(), x, 2cos.(x), yaxis = "Y label 2"; kw...)

            plot(
                x,
                cos.(x),
                xaxis = "X label 1",
                yaxis = "common Y label",
                color = :red,
                title = "twiny";
                kw...,
            )
            pr = plot!(twiny(), 2x, cos.(2x), xaxis = "X label 2"; kw...)

            plot(pl, pr)
        end,
    ),
    PlotExample(  # 64
        "Legend positions",
        "Horizontal or vertical legends, at different locations.",
        quote
            legs = (
                :topleft,
                :top,
                :topright,
                :left,
                :inside,
                :right,
                :bottomleft,
                :bottom,
                :bottomright,
            )
            leg_plots(; kw...) = map(
                leg -> plot(
                    [0:1, reverse(0:1)];
                    marker = :circle,
                    ticks = :none,
                    leg_title = leg,
                    leg,
                    kw...,
                ),
                legs,
            )
            w, h = Plots._plot_defaults[:size]
            Plots.with(scalefonts = 0.5, size = (2w, 2h)) do
                plot(leg_plots()..., leg_plots(legend_column = -1)...; layout = (6, 3))
            end
        end,
    ),
    PlotExample(  # 65
        "Outer legend positions",
        "Horizontal or vertical legends, at different locations.",
        quote
            legs = (
                :topleft,
                :top,
                :topright,
                :left,
                nothing,
                :right,
                :bottomleft,
                :bottom,
                :bottomright,
            )
            leg_plots(; kw...) = map(
                leg -> plot(
                    [0:1, reverse(0:1)];
                    marker = :circle,
                    ticks = :none,
                    leg_title = leg,
                    leg = leg isa Symbol ? Symbol(:outer, leg) : :none,
                    kw...,
                ),
                legs,
            )
            w, h = Plots._plot_defaults[:size]
            Plots.with(scalefonts = 0.5, size = (2w, 2h)) do
                plot(leg_plots()..., leg_plots(legend_column = -1)...; layout = (6, 3))
            end
        end,
    ),
    PlotExample( # 66
        "Specifying edges and missing values for barplots",
        "In `bar(x, y)`, `x` may be the same length as `y` to specify bar centers, or one longer to specify bar edges.",
        :(plot(
            bar(-5:5, randn(10)),                  # bar edges at -5:5
            bar(-2:2, [2, -2, NaN, -1, 1], color = 1:5), # bar centers at -2:2, one missing value
            legend = false,
        )),
    ),
]

# Some constants for PlotDocs and PlotReferenceImages
_animation_examples = [2, 31]
_backend_skips = Dict(
    :gr => [],
    :pyplot => [],
    :plotlyjs => [
        21,
        24,
        25,
        30,
        49,
        50,
        51,
        55,
        56,
        62,
        63,  # twin axes unsupported
        64,  # legend pos unsupported
        65,  # legend pos unsupported
        66,  # bar: vector-valued `color` unsupported
    ],
    :pgfplotsx => [
        6,  # images
        16,  # pgfplots thinks the upper panel is too small
        32,  # spy
        49,  # polar heatmap
        51,  # image with custom axes
        56,  # custom bar plot
        62,  # fillstyle unsupported
    ],
    :inspectdr => [
        4,
        6,
        10,
        22,
        24,
        28,
        30,
        38,
        43,
        45,
        47,
        48,
        49,
        50,
        51,
        55,
        56,
        60,
        62,
        63,
        64,
        65,
    ],
    :unicodeplots => [
        5,  # limits issue
        6,  # embedded images supported, but requires `using ImageInTerminal`, disable for docs
        16,  # nested layout unsupported
        21,  # custom markers unsupported
        26,  # nested layout unsupported
        29,  # nested layout unsupported
        31,  # nested layout unsupported
        33,  # grid lines unsupported
        34,  # framestyle unsupported
        37,  # ribbons / filled unsupported
        43,  # heatmap with DateTime
        45,  # error bars
        49,  # polar heatmap
        51,  # drawing on top of image unsupported
        55,  # mirror unsupported, resolution too low
        56,  # barplots
        62,  # fillstyle
        63,  # twin axes unsupported
        64,  # legend pos unsupported
        65,  # legend pos unsupported
    ],
    :gaston => [
        31,  # animations - needs github.com/mbaz/Gaston.jl/pull/178
        49,  # TODO: support polar
        60,  # :perspective projection unsupported
        63,  # FXIME: twin axes misalignement
    ],
)
_backend_skips[:plotly] = _backend_skips[:plotlyjs]
_backend_skips[:pythonplot] = _backend_skips[:pyplot]

# ---------------------------------------------------------------------------------
# replace `f(args...)` with `f(rng, args...)` for `f ∈ (rand, randn)`
replace_rand(ex) = ex

function replace_rand(ex::Expr)
    expr = Expr(ex.head)
    foreach(arg -> push!(expr.args, replace_rand(arg)), ex.args)
    if Meta.isexpr(ex, :call) && ex.args[1] ∈ (:rand, :randn, :(Plots.fakedata))
        pushfirst!(expr.args, ex.args[1])
        expr.args[2] = :rng
    end
    expr
end

# make and display one plot
test_examples(i::Integer; kw...) = test_examples(backend_name(), i; kw...)

function test_examples(
    pkgname::Symbol,
    i::Integer;
    debug = false,
    disp = false,
    rng = nothing,
    callback = nothing,
)
    @info "Testing plot: $pkgname:$i:$(_examples[i].header)"

    m = Module(Symbol(:PlotsExamples, pkgname))

    # prevent leaking variables (esp. functions) directly into Plots namespace
    Base.eval(m, quote
        using Random
        using Plots
        Plots.debug!($debug)
        backend($(QuoteNode(pkgname)))
        rng = $rng
        rng === nothing || Random.seed!(rng, Plots.PLOTS_SEED)
        theme(:default)
    end)
    (imp = _examples[i].imports) === nothing || Base.eval(m, imp)
    exprs = _examples[i].exprs
    rng === nothing || (exprs = Plots.replace_rand(exprs))
    Base.eval(m, exprs)

    disp && Base.eval(m, :(gui(current())))
    callback === nothing || callback(m, pkgname, i)
    m.Plots.current()
end

# generate all plots and create a dict mapping idx --> plt
"""
test_examples(pkgname[, idx]; debug=false, disp=false, sleep=nothing, skip=[], only=nothing, callback=nothing)

Run the `idx` test example for a given backend, or all examples if `idx` is not specified.
"""
function test_examples(
    pkgname::Symbol;
    debug = false,
    disp = false,
    sleep = nothing,
    skip = [],
    only = nothing,
    callback = nothing,
    strict = false,
)
    plts = Dict()
    for i in eachindex(_examples)
        i ∈ something(only, (i,)) || continue
        i ∈ skip && continue
        try
            plts[i] = test_examples(pkgname, i; debug, disp, callback)
        catch ex
            # COV_EXCL_START
            if strict
                rethrow(ex)
            else
                @warn "Example $pkgname:$i:$(_examples[i].header) failed with: $ex"
            end
            # COV_EXCL_STOP
        end
        sleep === nothing || Base.sleep(sleep)
    end
    plts
end
