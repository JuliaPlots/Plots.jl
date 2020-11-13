"""
Holds all data needed for a documentation example... header, description, and plotting expression (Expr)
"""
mutable struct PlotExample
    header::AbstractString
    desc::AbstractString
    exprs::Vector{Expr}
end

# the _examples we'll run for each
const _examples = PlotExample[
    PlotExample( # 1
        "Lines",
        "A simple line plot of the columns.",
        [:(
            begin
                plot(Plots.fakedata(50, 5), w = 3)
            end
        )],
    ),
    PlotExample( # 2
        "Functions, adding data, and animations",
        """
        Plot multiple functions.  You can also put the function first, or use the form `plot(f,
        xmin, xmax)` where f is a Function or AbstractVector{Function}.\n\nGet series data:
        `x, y = plt[i]`.  Set series data: `plt[i] = (x,y)`. Add to the series with
        `push!`/`append!`.\n\nEasily build animations.  (`convert` or `ffmpeg` must be available
        to generate the animation.)  Use command `gif(anim, filename, fps=15)` to save the
        animation.
        """,
        [:(
            begin
                p = plot([sin, cos], zeros(0), leg = false, xlims = (0, 2π), ylims = (-1, 1))
                anim = Animation()
                for x in range(0, stop = 2π, length = 20)
                    push!(p, x, Float64[sin(x), cos(x)])
                    frame(anim)
                end
            end
        )],
    ),
    PlotExample( # 3
        "Parametric plots",
        "Plot function pair (x(u), y(u)).",
        [
            :(
                begin
                    plot(
                        sin,
                        x -> sin(2x),
                        0,
                        2π,
                        line = 4,
                        leg = false,
                        fill = (0, :orange),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 4
        "Colors",
        """
        Access predefined palettes (or build your own with the `colorscheme` method).
        Line/marker colors are auto-generated from the plot's palette, unless overridden.  Set
        the `z` argument to turn on series gradients.
        """,
        [
            :(
                begin
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
                end
            ),
        ],
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
        [
            :(
                begin
                    using Statistics
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
                    yaxis!("YLABEL", :log10)
                end
            ),
        ],
    ),

    PlotExample( # 6
        "Images",
        "Plot an image.  y-axis is set to flipped",
        [
            :(
                begin
                    import FileIO
                    path =
                            download("http://juliaplots.org/PlotReferenceImages.jl/Plots/pyplot/0.7.0/ref1.png")
                    img = FileIO.load(path)
                    plot(img)
                end
            ),
        ],
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
        [
            :(
                begin
                    ys = Vector[rand(10), rand(20)]
                    plot(
                        ys,
                        color = [:black :orange],
                        line = (:dot, 4),
                        marker = ([:hex :d], 12, 0.8, Plots.stroke(3, :gray)),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 8
        "Build plot in pieces",
        "Start with a base plot...",
        [:(
            begin
                plot(rand(100) / 3, reg = true, fill = (0, :green))
            end
        )],
    ),
    PlotExample( # 9
        "",
        "and add to it later.",
        [:(
            begin
                scatter!(rand(100), markersize = 6, c = :orange)
            end
        )],
    ),
    PlotExample( # 10
        "Histogram2D",
        "",
        [:(
            begin
                histogram2d(randn(10000), randn(10000), nbins = 20)
            end
        )],
    ),
    PlotExample( # 11
        "Line types",
        "",
        [
            :(
                begin
                    linetypes = [:path :steppre :steppost :sticks :scatter]
                    n = length(linetypes)
                    x = Vector[sort(rand(20)) for i = 1:n]
                    y = rand(20, n)
                    plot(
                        x,
                        y,
                        line = (linetypes, 3),
                        lab = map(string, linetypes),
                        ms = 15,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 12
        "Line styles",
        "",
        [
            :(
                begin
                    styles = filter(
                        s -> s in Plots.supported_styles(),
                        [:solid, :dash, :dot, :dashdot, :dashdotdot],
                    )
                    styles = reshape(styles, 1, length(styles)) # Julia 0.6 unfortunately gives an error when transposing symbol vectors
                    n = length(styles)
                    y = cumsum(randn(20, n), dims = 1)
                    plot(
                        y,
                        line = (5, styles),
                        label = map(string, styles),
                        legendtitle = "linestyle",
                    )
                end
            ),
        ],
    ),
    PlotExample( # 13
        "Marker types",
        "",
        [
            :(
                begin
                    markers = filter(
                        m -> m in Plots.supported_markers(),
                        Plots._shape_keys,
                    )
                    markers = reshape(markers, 1, length(markers))
                    n = length(markers)
                    x = range(0, stop = 10, length = n + 2)[2:(end - 1)]
                    y = repeat(reshape(reverse(x), 1, :), n, 1)
                    scatter(
                        x,
                        y,
                        m = (8, :auto),
                        lab = map(string, markers),
                        bg = :linen,
                        xlim = (0, 10),
                        ylim = (0, 10),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 14
        "Bar",
        "`x` is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)",
        [:(
            begin
                bar(randn(99))
            end
        )],
    ),
    PlotExample( # 15
        "Histogram",
        "",
        [
            :(
                begin
                    histogram(
                        randn(1000),
                        bins = :scott,
                        weights = repeat(1:5, outer = 200),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 16
        "Subplots",
        """
        Use the `layout` keyword, and optionally the convenient `@layout` macro to generate
        arbitrarily complex subplot layouts.
        """,
        [
            :(
                begin
                    l = @layout([a{0.1h}; b [c; d e]])
                    plot(
                        randn(100, 5),
                        layout = l,
                        t = [:line :histogram :scatter :steppre :bar],
                        leg = false,
                        ticks = nothing,
                        border = :none,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 17
        "Adding to subplots",
        """
        Note here the automatic grid layout, as well as the order in which new series are added
        to the plots.
        """,
        [
            :(
                begin
                    plot(
                        Plots.fakedata(100, 10),
                        layout = 4,
                        palette = cgrad.([:grays :blues :heat :lightrainbow]),
                        bg_inside = [:orange :pink :darkblue :black],
                    )
                end
            ),
        ],
    ),
    PlotExample( # 18
        "",
        "",
        [
            :(
                begin
                    using Random
                    Random.seed!(111)
                    plot!(Plots.fakedata(100, 10))
                end
            )
        ]
    ),
    PlotExample( # 19
        "Open/High/Low/Close",
        """
        Create an OHLC chart.  Pass in a list of (open,high,low,close) tuples as your `y`
        argument.  This uses recipes to first convert the tuples to OHLC objects, and
        subsequently create a :path series with the appropriate line segments.
        """,
        [
            :(
                begin
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
                        )
                        for i = 1:n
                    ]
                    ohlc(y)
                end
            ),
        ],
    ),
    PlotExample( # 20
        "Annotations",
        """
        The `annotations` keyword is used for text annotations in data-coordinates.  Pass in a
        tuple (x,y,text) or a vector of annotations.  `annotate!(ann)` is shorthand for `plot!(;
        annotation=ann)`.  Series annotations are used for annotating individual data points.
        They require only the annotation... x/y values are computed.  A `PlotText` object can be
        build with the method `text(string, attr...)`, which wraps font and color attributes.
        """,
        [
            :(
                begin
                    y = rand(10)
                    plot(
                        y,
                        annotations = (3, y[3], Plots.text("this is #3", :left)),
                        leg = false,
                    )
                    annotate!([
                        (5, y[5], Plots.text("this is #5", 16, :red, :center)),
                        (
                            10,
                            y[10],
                            Plots.text("this is #10", :right, 20, "courier"),
                        ),
                    ])
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
                end
            ),
        ],
    ),
    PlotExample( # 21
        "Custom Markers",
        """A `Plots.Shape` is a light wrapper around vertices of a polygon.  For supported
        backends, pass arbitrary polygons as the marker shapes.  Note: The center is (0,0) and
        the size is expected to be rougly the area of the unit circle.
        """,
        [
            :(
                begin
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
                    plot(
                        x,
                        y,
                        line = (3, :dash, :lightblue),
                        marker = (Shape(verts), 30, RGBA(0, 0, 0, 0.2)),
                        bg = :pink,
                        fg = :darkblue,
                        xlim = (0, 1),
                        ylim = (0, 1),
                        leg = false,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 22
        "Contours",
        """
        Any value for fill works here.  We first build a filled contour from a function, then an
        unfilled contour from a matrix.
        """,
        [:(
            begin
                x = 1:0.5:20
                y = 1:0.5:10
                f(x, y) = (3x + y^2) * abs(sin(x) + cos(y))
                X = repeat(reshape(x, 1, :), length(y), 1)
                Y = repeat(y, 1, length(x))
                Z = map(f, X, Y)
                p1 = contour(x, y, f, fill = true)
                p2 = contour(x, y, Z)
                plot(p1, p2)
            end
        )],
    ),
    PlotExample( # 23
        "Pie",
        "",
        [:(
            begin
                x = ["Nerds", "Hackers", "Scientists"]
                y = [0.4, 0.35, 0.25]
                pie(x, y, title = "The Julia Community", l = 0.5)
            end
        )],
    ),
    PlotExample( # 24
        "3D",
        "",
        [
            :(
                begin
                    n = 100
                    ts = range(0, stop = 8π, length = n)
                    x = ts .* map(cos, ts)
                    y = 0.1ts .* map(sin, ts)
                    z = 1:n
                    plot(
                        x,
                        y,
                        z,
                        zcolor = reverse(z),
                        m = (10, 0.8, :blues, Plots.stroke(0)),
                        leg = false,
                        cbar = true,
                        w = 5,
                    )
                    plot!(zeros(n), zeros(n), 1:n, w = 10)
                end
            ),
        ],
    ),
    PlotExample( # 25
        "DataFrames",
        "Plot using DataFrame column symbols.",
        [
            :(using StatsPlots), # can't be inside begin block because @df gets expanded first
            :(
                begin
                    import RDatasets
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
                end
            ),
        ],
    ),
    PlotExample( # 26
        "Groups and Subplots",
        "",
        [
            :(
                begin
                    group = rand(map(i -> "group $i", 1:4), 100)
                    plot(
                        rand(100),
                        layout = @layout([a b; c]),
                        group = group,
                        linetype = [:bar :scatter :steppre],
                        linecolor = :match,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 27
        "Polar Plots",
        "",
        [:(
            begin
                Θ = range(0, stop = 1.5π, length = 100)
                r = abs.(0.1 * randn(100) + sin.(3Θ))
                plot(Θ, r, proj = :polar, m = 2)
            end
        )],
    ),
    PlotExample( # 28
        "Heatmap, categorical axes, and aspect_ratio",
        "",
        [:(
            begin
                xs = [string("x", i) for i = 1:10]
                ys = [string("y", i) for i = 1:4]
                z = float((1:4) * reshape(1:10, 1, :))
                heatmap(xs, ys, z, aspect_ratio = 1)
            end
        )],
    ),
    PlotExample( # 29
        "Layouts, margins, label rotation, title location",
        "",
        [
            :(
                begin
                    using Plots.PlotMeasures # for Measures, e.g. mm and px
                    plot(
                        rand(100, 6),
                        layout = @layout([a b; c]),
                        title = ["A" "B" "C"],
                        titlelocation = :left,
                        left_margin = [20mm 0mm],
                        bottom_margin = 10px,
                        xrotation = 60,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 30
        "Boxplot and Violin series recipes",
        "",
        [
            :(using StatsPlots), # can't be inside begin block because @df gets expanded first
            :(
                begin
                    import RDatasets
                    singers = RDatasets.dataset("lattice", "singer")
                    @df singers violin(
                        :VoicePart,
                        :Height,
                        line = 0,
                        fill = (0.2, :blue),
                    )
                    @df singers boxplot!(
                        :VoicePart,
                        :Height,
                        line = (2, :black),
                        fill = (0.3, :orange),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 31
        "Animation with subplots",
        "The `layout` macro can be used to create an animation with subplots.",
        [
            :(
                begin
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
                        plot(push!(
                            p,
                            x,
                            Float64[sin(x), cos(x), atan(x), cos(x), log(x)],
                        ))
                        frame(anim)
                    end
                end
            ),
        ],
    ),
    PlotExample( # 32
        "Spy",
        """
        For a matrix `mat` with unique nonzeros `spy(mat)` returns a colorless plot. If `mat` has
        various different nonzero values, a colorbar is added. The colorbar can be disabled with
        `legend = nothing`.
        """,
        [
            :(
                begin
                    using SparseArrays
                    a = spdiagm(
                        0 => ones(50),
                        1 => ones(49),
                        -1 => ones(49),
                        10 => ones(40),
                        -10 => ones(40),
                    )
                    b = spdiagm(
                        0 => 1:50,
                        1 => 1:49,
                        -1 => 1:49,
                        10 => 1:40,
                        -10 => 1:40,
                    )
                    plot(
                        spy(a),
                        spy(b),
                        title = ["Unique nonzeros" "Different nonzeros"],
                    )
                end
            ),
        ],
    ),
    PlotExample( # 33
        "Magic grid argument",
        """
        The grid lines can be modified individually for each axis with the magic `grid` argument.
        """,
        [
            :(
                begin
                    x = rand(10)
                    p1 = plot(x, title = "Default looks")
                    p2 = plot(
                        x,
                        grid = (:y, :olivedrab, :dot, 1, 0.9),
                        title = "Modified y grid",
                    )
                    p3 = plot(deepcopy(p2), title = "Add x grid")
                    xgrid!(p3, :on, :cadetblue, 2, :dashdot, 0.4)
                    plot(
                        p1,
                        p2,
                        p3,
                        layout = (1, 3),
                        label = "",
                        fillrange = 0,
                        fillalpha = 0.3,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 34
        "Framestyle",
        """
        The style of the frame/axes of a (sub)plot can be changed with the `framestyle`
        attribute. The default framestyle is `:axes`.
        """,
        [
            :(
                begin
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
                end
            ),
        ],
    ),
    PlotExample( # 35
        "Lines and markers with varying colors",
        """
        You can use the `line_z` and `marker_z` properties to associate a color with
        each line segment or marker in the plot.
        """,
        [
            :(
                begin
                    t = range(0, stop = 1, length = 100)
                    θ = 6π .* t
                    x = t .* cos.(θ)
                    y = t .* sin.(θ)
                    p1 = plot(x, y, line_z = t, linewidth = 3, legend = false)
                    p2 = scatter(
                        x,
                        y,
                        marker_z = +,
                        color = :bluesreds,
                        legend = false,
                    )
                    plot(p1, p2)
                end
            ),
        ],
    ),
    PlotExample( # 36
        "Portfolio Composition maps",
        """
        see: http://stackoverflow.com/a/37732384/5075246
        """,
        [
            :(
                begin
                    using Random
                    Random.seed!(111)
                    tickers = ["IBM", "Google", "Apple", "Intel"]
                    N = 10
                    D = length(tickers)
                    weights = rand(N, D)
                    weights ./= sum(weights, dims = 2)
                    returns = sort!((1:N) + D * randn(N))

                    portfoliocomposition(
                        weights,
                        returns,
                        labels = permutedims(tickers),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 37
        "Ribbons",
        """
        Ribbons can be added to lines via the `ribbon` keyword;
        you can pass a tuple of arrays (upper and lower bounds),
        a single Array (for symmetric ribbons), a Function, or a number.
        """,
        [
            :(
                begin
                    plot(
                        plot(
                            0:10;
                            ribbon = (LinRange(0, 2, 11), LinRange(0, 1, 11)),
                        ),
                        plot(0:10; ribbon = 0:0.5:5),
                        plot(0:10; ribbon = sqrt),
                        plot(0:10; ribbon = 1),
                    )
                end
            ),
        ],
    ),
    PlotExample( # 38
        "Histogram2D (complex values)",
        "",
        [
            :(
                begin
                    n = 10_000
                    x = exp.(0.1 * randn(n) .+ randn(n) .* (im))
                    histogram2d(
                        x,
                        nbins = (20, 40),
                        show_empty_bins = true,
                        normed = true,
                        aspect_ratio = 1,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 39
        "Unconnected lines using `missing` or `NaN`",
        """
        Missing values and non-finite values, including `NaN`, are not plotted.
        Instead, lines are separated into segments at these values.
        """,
        [
            :(
                begin
                    x, y = [1, 2, 2, 1, 1], [1, 2, 1, 2, 1]
                    plot(
                        plot([rand(5); NaN; rand(5); NaN; rand(5)]),
                        plot([1, missing, 2, 3], marker = true),
                        plot([x; NaN; x .+ 2], [y; NaN; y .+ 1], arrow = 2),
                        plot(
                            [1, 2 + 3im, Inf, 4im, 3, -Inf * im, 0, 3 + 3im],
                            marker = true,
                        ),
                        legend = false,
                    )
                end
            ),
        ],
    ),
    PlotExample( # 40
        "Lens",
        "A lens lets you easily magnify a region of a plot. x and y coordinates refer to the to be magnified region and the via the `inset` keyword the subplot index and the bounding box (in relative coordinates) of the inset plot with the magnified plot can be specified. Additional attributes count for the inset plot.",
        [
            quote
                begin
                    plot(
                        [(0, 0), (0, 0.9), (1, 0.9), (2, 1), (3, 0.9), (80, 0)],
                        legend = :outertopright,
                    )
                    plot!([(0, 0), (0, 0.9), (2, 0.9), (3, 1), (4, 0.9), (80, 0)])
                    plot!([(0, 0), (0, 0.9), (3, 0.9), (4, 1), (5, 0.9), (80, 0)])
                    plot!([(0, 0), (0, 0.9), (4, 0.9), (5, 1), (6, 0.9), (80, 0)])
                    lens!(
                        [1, 6],
                        [0.9, 1.1],
                        inset = (1, bbox(0.5, 0.0, 0.4, 0.4)),
                    )
                end
            end,
        ],
    ),
    PlotExample( # 41
        "Array Types",
        "Plots supports different `Array` types that follow the `AbstractArray` interface, like `StaticArrays` and `OffsetArrays.`",
        [
            quote
                begin
                    using StaticArrays, OffsetArrays
                    sv = SVector{10}(rand(10))
                    ov = OffsetVector(rand(10), -2)
                    plot([sv, ov], label = ["StaticArray" "OffsetArray"])
                    plot!(3ov, ribbon=ov, label="OffsetArray ribbon")
                end
            end,
        ],
    ),
    PlotExample( # 42
        "Setting defaults and font arguments",
        "",
        [
            quote
                begin
                    using Plots
                    default(
                        titlefont = (20, "times"),
                        legendfontsize = 18,
                        guidefont = (18, :darkgreen),
                        tickfont = (12, :orange),
                        guide = "x",
                        framestyle = :zerolines,
                        yminorgrid = true
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
                end
            end,
        ],
    ),
    PlotExample( # 43
        "Heatmap with DateTime axis",
        "",
        [
            quote
                begin
                    using Dates
                    z = rand(5, 5)
                    x = DateTime.(2016:2020)
                    y = 1:5
                    heatmap(x, y, z)
                end
            end,
        ],
    ),
    PlotExample( # 44
        "Linked axes",
        "",
        [
            quote
                begin
                    x = -5:0.1:5
                    plot(plot(x, x->x^2), plot(x, x->sin(x)), layout = 2, link = :y)
                end
            end,
        ],
    ),
    PlotExample( # 45
        "Error bars and array type recipes",
        "",
        [
            quote
                begin
                    struct Measurement <: Number
                        val::Float64
                        err::Float64
                    end
                    value(m::Measurement) = m.val
                    uncertainty(m::Measurement) = m.err

                    @recipe function f(::Type{T}, m::T) where T <: AbstractArray{<:Measurement}
                        if !(get(plotattributes, :seriestype, :path) in [:contour, :contourf, :contour3d, :heatmap, :surface, :wireframe, :image])
                            error_sym = Symbol(plotattributes[:letter], :error)
                            plotattributes[error_sym] = uncertainty.(m)
                        end
                        value.(m)
                    end

                    x = Measurement.(10sort(rand(10)), rand(10))
                    y = Measurement.(10sort(rand(10)), rand(10))
                    z = Measurement.(10sort(rand(10)), rand(10))
                    surf = Measurement.((1:10) .* (1:10)', rand(10,10))

                    plot(
                        scatter(x, [x y]),
                        scatter(x, y, z),
                        heatmap(x, y, surf),
                        wireframe(x, y, surf),
                        legend = :topleft
                    )
                end
            end,
        ],
    ),
    PlotExample( # 46
        "Tuples and `Point`s as data",
        "",
        [quote
            using GeometryBasics
            using Distributions
            d = MvNormal([1.0 0.75; 0.75 2.0])
            plot([(1,2),(3,2),(2,1),(2,3)])
            scatter!(Point2.(eachcol(rand(d,1000))), alpha=0.25)
        end]
    ),
    PlotExample( # 47
	"Mesh3d",
	"""
	Allows to plot arbitrary 3d meshes. If only x,y,z are given the mesh is generated automatically.
	You can also specify the connections using the connections keyword.
    The connections are specified using a tuple of vectors. Each vector contains the 0-based indices of one point of a triangle,
	such that elements at the same position of these vectors form a triangle.
	""",
	[
		:(
		  begin
			# specify the vertices
			x=[0, 1, 2, 0]
			y=[0, 0, 1, 2]
			z=[0, 2, 0, 1]

			# specify the triangles
			# every column is one triangle,
			# where the values denote the indices of the vertices of the triangle
			i=[0, 0, 0, 1]
			j=[1, 2, 3, 2]
			k=[2, 3, 1, 3]

			# the four triangles gives above give a tetrahedron
			mesh3d(x,y,z;connections=(i,j,k))
		  end
		),
	],
    ),
    PlotExample( # 48
        "Vectors of markershapes and segments",
        "",
        [quote
            yv = ones(9)
            ys = [1; 1; NaN; ones(6)]
            plot(
                5 .- [yv 2ys 3yv 4ys],
                seriestype = [:path :path :scatter :scatter],
                markershape = [:utriangle, :rect],
                markersize = 8,
                color = [:red, :black],
            )
        end]
    ),
    PlotExample( # 49
        "Polar heatmaps",
        "",
        [quote
            z = (1:4) .+ (1:8)'
            heatmap(z, projection = :polar)
        end]
    ),
    PlotExample( # 50
        "3D surface with axis guides",
        "",
        [quote
        f(x,a) = 1/x + a*x^2
        xs = collect(0.1:0.05:2.0);
        as = collect(0.2:0.1:2.0);

        x_grid = [x for x in xs for y in as];
        a_grid = [y for x in xs for y in as];

        plot(x_grid, a_grid, f.(x_grid,a_grid),
            st = :surface,
            xlabel = "longer xlabel",
            ylabel = "longer ylabel",
            zlabel = "longer zlabel",
        )
        end]
    ),
    PlotExample( # 51
        "Images with custom axes",
        "",
        [quote
            using Plots
            using TestImages
            img = testimage("lighthouse")

            # plot the image reversing the first dimension and setting yflip = false
            plot([-π, π], [-1, 1], reverse(img, dims=1), yflip=false, aspect_ratio=:none)
            # plot other data
            plot!(sin, -π, π, lw=3, color=:red)
        end]
    ),
    PlotExample(
        "3d quiver",
        "",
        [quote
            using Plots

            ϕs = range(-π, π, length=50)
            θs = range(0, π, length=25)
            θqs = range(1, π-1, length=25)

            x = vec([sin(θ) * cos(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θs)])
            y = vec([sin(θ) * sin(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θs)])
            z = vec([cos(θ) for (ϕ, θ) in Iterators.product(ϕs, θs)])

            u = 0.1 * vec([sin(θ) * cos(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])
            v = 0.1 * vec([sin(θ) * sin(ϕ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])
            w = 0.1 * vec([cos(θ) for (ϕ, θ) in Iterators.product(ϕs, θqs)])

            quiver(x,y,z, quiver=(u,v,w))
        end]
    ),
]

# Some constants for PlotDocs and PlotReferenceImages
_animation_examples = [2, 31]
_backend_skips = Dict(
    :gr => [25, 30, 47],
    :pyplot => [2, 25, 30, 31, 47, 49],
    :plotlyjs => [2, 21, 24, 25, 30, 31, 49, 51],
    :plotly => [2, 21, 24, 25, 30, 31, 49, 51],
    :pgfplotsx => [
        2, # animation
        6, # images
        16, # pgfplots thinks the upper panel is too small
        30, # @df
        31, # animation
        32, # spy
        49, # polar heatmap
        51, # image with custom axes
    ],
)



# ---------------------------------------------------------------------------------

# make and display one plot
function test_examples(pkgname::Symbol, idx::Int; debug = false, disp = true)
    Plots._debugMode.on = debug
    @info("Testing plot: $pkgname:$idx:$(_examples[idx].header)")
    backend(pkgname)
    backend()

    # prevent leaking variables (esp. functions) directly into Plots namespace
    m = Module(:PlotExampleModule)
    Base.eval(m, :(using Plots))
    map(exprs -> Base.eval(m, exprs), _examples[idx].exprs)

    plt = current()
    if disp
        gui(plt)
    end
    plt
end

# generate all plots and create a dict mapping idx --> plt
"""
test_examples(pkgname[, idx]; debug = false, disp = true, sleep = nothing,
                                        skip = [], only = nothing

Run the `idx` test example for a given backend, or all examples if `idx`
is not specified.
"""
function test_examples(
    pkgname::Symbol;
    debug = false,
    disp = true,
    sleep = nothing,
    skip = [],
    only = nothing,
)
    Plots._debugMode.on = debug
    plts = Dict()
    for i in eachindex(_examples)
        only !== nothing && !(i in only) && continue
        i in skip && continue
        try
            plt = test_examples(pkgname, i, debug = debug, disp = disp)
            plts[i] = plt
        catch ex
            # TODO: put error info into markdown?
            @warn("Example $pkgname:$i:$(_examples[i].header) failed with: $ex")
        end
        if sleep !== nothing
            Base.sleep(sleep)
        end
    end
    plts
end
