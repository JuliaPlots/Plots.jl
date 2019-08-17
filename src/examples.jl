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

PlotExample("Lines",
    "A simple line plot of the columns.",
    [:(begin
        plot(Plots.fakedata(50,5), w=3)
    end)]
),

PlotExample("Functions, adding data, and animations",
"""
Plot multiple functions.  You can also put the function first, or use the form `plot(f,
xmin, xmax)` where f is a Function or AbstractVector{Function}.\n\nGet series data:
`x, y = plt[i]`.  Set series data: `plt[i] = (x,y)`. Add to the series with
`push!`/`append!`.\n\nEasily build animations.  (`convert` or `ffmpeg` must be available
to generate the animation.)  Use command `gif(anim, filename, fps=15)` to save the
animation.
""",
    [:(begin
        p = plot([sin,cos], zeros(0), leg=false)
        anim = Animation()
        for x in range(0, stop=10π, length=100)
            push!(p, x, Float64[sin(x), cos(x)])
            frame(anim)
        end
    end)]
),

PlotExample("Parametric plots",
    "Plot function pair (x(u), y(u)).",
    [:(begin
        plot(sin, x->sin(2x), 0, 2π, line=4, leg=false, fill=(0,:orange))
    end)]
),

PlotExample("Colors",
"""
Access predefined palettes (or build your own with the `colorscheme` method).
Line/marker colors are auto-generated from the plot's palette, unless overridden.  Set
the `z` argument to turn on series gradients.
""",
    [:(begin
y = rand(100)
plot(0:10:100,rand(11,4),lab="lines",w=3,palette=:grays,fill=0, α=0.6)
scatter!(y, zcolor=abs.(y.-0.5), m=(:heat,0.8,Plots.stroke(1,:green)), ms=10*abs.(y.-0.5).+4,
         lab="grad")
    end)]
),

PlotExample("Global",
"""
Change the guides/background/limits/ticks.  Convenience args `xaxis` and `yaxis` allow
you to pass a tuple or value which will be mapped to the relevant args automatically.
The `xaxis` below will be replaced with `xlabel` and `xlims` args automatically during
the preprocessing step. You can also use shorthand functions: `title!`, `xaxis!`,
`yaxis!`, `xlabel!`, `ylabel!`, `xlims!`, `ylims!`, `xticks!`, `yticks!`
""",
    [:(begin
using Statistics
y = rand(20,3)
plot(y, xaxis=("XLABEL",(-5,30),0:2:20,:flip), background_color = RGB(0.2,0.2,0.2),
     leg=false)
hline!(mean(y, dims = 1)+rand(1,3), line=(4,:dash,0.6,[:lightgreen :green :darkgreen]))
vline!([5,10])
title!("TITLE")
yaxis!("YLABEL", :log10)
    end)]
),

# PlotExample("Two-axis",
#             "Use the `axis` arguments.",
#             [
#               :(plot(Vector[randn(100), randn(100)*100], axis = [:l :r], ylabel="LEFT", yrightlabel="RIGHT", xlabel="X", title="TITLE"))
#             ]),

PlotExample("Images",
    "Plot an image.  y-axis is set to flipped",
    [:(begin
    import FileIO
    path = download("http://juliaplots.org/PlotReferenceImages.jl/Plots/pyplot/0.7.0/ref1.png")
    img = FileIO.load(path)
        plot(img)
    end)]
),

PlotExample("Arguments",
"""
Plot multiple series with different numbers of points.  Mix arguments that apply to all
series (marker/markersize) with arguments unique to each series (colors).  Special
arguments `line`, `marker`, and `fill` will automatically figure out what arguments to
set (for example, we are setting the `linestyle`, `linewidth`, and `color` arguments with
`line`.)  Note that we pass a matrix of colors, and this applies the colors to each
series.
""",
    [:(begin
        ys = Vector[rand(10), rand(20)]
        plot(ys, color=[:black :orange], line=(:dot,4), marker=([:hex :d],12,0.8,Plots.stroke(3,:gray)))
    end)]
),

PlotExample("Build plot in pieces",
    "Start with a base plot...",
    [:(begin
        plot(rand(100)/3, reg=true, fill=(0,:green))
    end)]
),

PlotExample("",
    "and add to it later.",
    [:(begin
        scatter!(rand(100), markersize=6, c=:orange)
    end)]
),

PlotExample("Histogram2D",
    "",
    [:(begin
        histogram2d(randn(10000), randn(10000), nbins=20)
    end)]
),

PlotExample("Line types",
    "",
    [:(begin
        linetypes = [:path :steppre :steppost :sticks :scatter]
        n = length(linetypes)
        x = Vector[sort(rand(20)) for i in 1:n]
        y = rand(20,n)
        plot(x, y, line=(linetypes,3), lab=map(string,linetypes), ms=15)
    end)]
),

PlotExample("Line styles",
    "",
    [:(begin
styles = filter(s -> s in Plots.supported_styles(),
                [:solid, :dash, :dot, :dashdot, :dashdotdot])
styles = reshape(styles, 1, length(styles)) # Julia 0.6 unfortunately gives an error when transposing symbol vectors
n = length(styles)
y = cumsum(randn(20,n), dims = 1)
plot(y, line = (5, styles), label = map(string,styles), legendtitle = "linestyle")
             end)]
),

PlotExample("Marker types",
    "",
    [:(begin
        markers = filter(m -> m in Plots.supported_markers(), Plots._shape_keys)
        markers = reshape(markers, 1, length(markers))
        n = length(markers)
        x = range(0, stop=10, length=n+2)[2:end-1]
        y = repeat(reshape(reverse(x),1,:), n, 1)
        scatter(x, y, m=(8,:auto), lab=map(string,markers), bg=:linen, xlim=(0,10), ylim=(0,10))
    end)]
),

PlotExample("Bar",
    "x is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)",
    [:(begin
        bar(randn(99))
    end)]
),

PlotExample("Histogram",
    "",
    [:(begin
        histogram(randn(1000), bins = :scott, weights = repeat(1:5, outer = 200))
    end)]
),

PlotExample("Subplots",
"""
Use the `layout` keyword, and optionally the convenient `@layout` macro to generate
arbitrarily complex subplot layouts.
""",
    [:(begin
l = @layout([a{0.1h}; b [c;d e]])
plot(randn(100,5), layout=l, t=[:line :histogram :scatter :steppre :bar], leg=false,
     ticks=nothing, border=:none)
    end)]
),

PlotExample("Adding to subplots",
"""
Note here the automatic grid layout, as well as the order in which new series are added
to the plots.
""",
    [:(begin
plot(Plots.fakedata(100,10), layout=4, palette=[:grays :blues :heat :lightrainbow],
     bg_inside=[:orange :pink :darkblue :black])
    end)]
),

PlotExample("",
    "",
    [:(begin
        using Random
        Random.seed!(111)
        plot!(Plots.fakedata(100,10))
    end)]
),

PlotExample("Open/High/Low/Close",
"""
Create an OHLC chart.  Pass in a list of (open,high,low,close) tuples as your `y`
argument.  This uses recipes to first convert the tuples to OHLC objects, and
subsequently create a :path series with the appropriate line segments.
""",
    [:(begin
n=20
hgt=rand(n).+1
bot=randn(n)
openpct=rand(n)
closepct=rand(n)
y = OHLC[(openpct[i]*hgt[i]+bot[i], bot[i]+hgt[i], bot[i],
          closepct[i]*hgt[i]+bot[i]) for i in 1:n]
ohlc(y)
    end)]
),

PlotExample("Annotations",
"""
The `annotations` keyword is used for text annotations in data-coordinates.  Pass in a
tuple (x,y,text) or a vector of annotations.  `annotate!(ann)` is shorthand for `plot!(;
annotation=ann)`.  Series annotations are used for annotating individual data points.
They require only the annotation... x/y values are computed.  A `PlotText` object can be
build with the method `text(string, attr...)`, which wraps font and color attributes.
""",
    [:(begin
y = rand(10)
plot(y, annotations = (3,y[3], Plots.text("this is #3",:left)), leg=false)
annotate!([(5, y[5], Plots.text("this is #5",16,:red,:center)),
          (10, y[10], Plots.text("this is #10",:right,20,"courier"))])
scatter!(range(2, stop=8, length=6), rand(6), marker=(50,0.2,:orange),
         series_annotations = ["series","annotations","map","to","series",
                               Plots.text("data",:green)])
    end)]
),

PlotExample("Custom Markers",
"""A `Plots.Shape` is a light wrapper around vertices of a polygon.  For supported
backends, pass arbitrary polygons as the marker shapes.  Note: The center is (0,0) and
the size is expected to be rougly the area of the unit circle.
""",
    [:(begin
verts = [(-1.0,1.0),(-1.28,0.6),(-0.2,-1.4),(0.2,-1.4),(1.28,0.6),(1.0,1.0),
         (-1.0,1.0),(-0.2,-0.6),(0.0,-0.2),(-0.4,0.6),(1.28,0.6),(0.2,-1.4),
         (-0.2,-1.4),(0.6,0.2),(-0.2,0.2),(0.0,-0.2),(0.2,0.2),(-0.2,-0.6)]
x = 0.1:0.2:0.9
y = 0.7rand(5).+0.15
plot(x, y, line = (3,:dash,:lightblue), marker = (Shape(verts),30,RGBA(0,0,0,0.2)),
     bg=:pink, fg=:darkblue, xlim = (0,1), ylim=(0,1), leg=false)
    end)]
),

PlotExample("Contours",
"""
Any value for fill works here.  We first build a filled contour from a function, then an
unfilled contour from a matrix.
""",
    [:(begin
        x = 1:0.5:20
        y = 1:0.5:10
        f(x,y) = (3x+y^2)*abs(sin(x)+cos(y))
        X = repeat(reshape(x,1,:), length(y), 1)
        Y = repeat(y, 1, length(x))
        Z = map(f, X, Y)
        p1 = contour(x, y, f, fill=true)
        p2 = contour(x, y, Z)
        plot(p1, p2)
    end)]
),

PlotExample("Pie",
    "",
    [:(begin
        x = ["Nerds", "Hackers", "Scientists"]
        y = [0.4, 0.35, 0.25]
        pie(x, y, title="The Julia Community", l=0.5)
    end)]
),

PlotExample("3D",
    "",
    [:(begin
        n = 100
        ts = range(0, stop=8π, length=n)
        x = ts .* map(cos,ts)
        y = 0.1ts .* map(sin,ts)
        z = 1:n
        plot(x, y, z, zcolor=reverse(z), m=(10,0.8,:blues,Plots.stroke(0)), leg=false, cbar=true, w=5)
        plot!(zeros(n),zeros(n),1:n, w=10)
    end)]
),

PlotExample("DataFrames",
    "Plot using DataFrame column symbols.",
    [:(begin
        import RDatasets
        iris = RDatasets.dataset("datasets", "iris")
        @df iris scatter(:SepalLength, :SepalWidth, group=:Species,
            title = "My awesome plot", xlabel = "Length", ylabel = "Width",
            marker = (0.5, [:cross :hex :star7], 12), bg=RGB(.2,.2,.2))
    end)]
),

PlotExample("Groups and Subplots",
    "",
    [:(begin
        group = rand(map(i->"group $i",1:4),100)
        plot(rand(100), layout=@layout([a b;c]), group=group,
            linetype=[:bar :scatter :steppre], linecolor = :match)
    end)]
),

PlotExample("Polar Plots",
    "",
    [:(begin
        Θ = range(0, stop=1.5π, length=100)
        r = abs.(0.1randn(100)+sin.(3Θ))
        plot(Θ, r, proj=:polar, m=2)
    end)]
),

PlotExample("Heatmap, categorical axes, and aspect_ratio",
    "",
    [:(begin
        xs = [string("x",i) for i=1:10]
        ys = [string("y",i) for i=1:4]
        z = float((1:4)*reshape(1:10,1,:))
        heatmap(xs, ys, z, aspect_ratio=1)
    end)]
),

PlotExample("Layouts, margins, label rotation, title location",
    "",
    [:(begin
        using Plots.PlotMeasures # for Measures, e.g. mm and px
        plot(rand(100,6),layout=@layout([a b; c]),title=["A" "B" "C"],
                        title_location=:left, left_margin=[20mm 0mm],
                        bottom_margin=10px, xrotation=60)
    end)]
),

PlotExample("Boxplot and Violin series recipes",
    "",
    [:(begin
        import RDatasets
        singers = RDatasets.dataset("lattice", "singer")
        @df singers violin(:VoicePart, :Height, line = 0, fill = (0.2, :blue))
        @df singers boxplot!(:VoicePart, :Height, line = (2,:black), fill = (0.3, :orange))
    end)]
),

PlotExample("Animation with subplots",
    "The `layout` macro can be used to create an animation with subplots.",
    [:(begin
        l = @layout([[a; b] c])
        p = plot(plot([sin,cos],1,leg=false),
        scatter([atan,cos],1,leg=false),
        plot(log,1,xlims=(1,10π),ylims=(0,5),leg=false),layout=l)

        anim = Animation()
        for x = range(1, stop=10π, length=100)
          plot(push!(p,x,Float64[sin(x),cos(x),atan(x),cos(x),log(x)]))
          frame(anim)
        end
    end)]
),

PlotExample("Spy",
"""
For a matrix `mat` with unique nonzeros `spy(mat)` returns a colorless plot. If `mat` has
various different nonzero values, a colorbar is added. The colorbar can be disabled with
`legend = nothing`.
""",
    [:(begin
    using SparseArrays
    a = spdiagm(0 => ones(50), 1 => ones(49), -1 => ones(49), 10 => ones(40), -10 => ones(40))
    b = spdiagm(0 => 1:50, 1 => 1:49, -1 => 1:49, 10 => 1:40, -10 => 1:40)
    plot(spy(a), spy(b), title = ["Unique nonzeros" "Different nonzeros"])
    end)]
),

PlotExample("Magic grid argument",
"""
The grid lines can be modified individually for each axis with the magic `grid` argument.
""",
    [:(begin
    x = rand(10)
    p1 = plot(x, title = "Default looks")
    p2 = plot(x, grid = (:y, :olivedrab, :dot, 1, 0.9), title = "Modified y grid")
    p3 = plot(deepcopy(p2), title = "Add x grid")
    xgrid!(p3, :on, :cadetblue, 2, :dashdot, 0.4)
    plot(p1, p2, p3, layout = (1, 3), label = "", fillrange = 0, fillalpha = 0.3)
    end)]
),

PlotExample("Framestyle",
"""
The style of the frame/axes of a (sub)plot can be changed with the `framestyle`
attribute. The default framestyle is `:axes`.
""",
    [:(begin
    scatter(fill(randn(10), 6), fill(randn(10), 6),
        framestyle = [:box :semi :origin :zerolines :grid :none],
        title = [":box" ":semi" ":origin" ":zerolines" ":grid" ":none"],
        color = permutedims(1:6), layout = 6, label = "", markerstrokewidth = 0,
        ticks = -2:2)
    end)]
),

PlotExample("Lines and markers with varying colors",
"""
You can use the `line_z` and `marker_z` properties to associate a color with
each line segment or marker in the plot.
""",
    [:(begin
        t = range(0, stop=1, length=100)
        θ = 6π .* t
        x = t .* cos.(θ)
        y = t .* sin.(θ)
        p1 = plot(x, y, line_z=t, linewidth=3, legend=false)
        p2 = scatter(x, y, marker_z=(x,y)->x+y, color=:bluesreds, legend=false)
        plot(p1, p2)
    end)]
),

PlotExample("Portfolio Composition maps",
"""
see: http://stackoverflow.com/a/37732384/5075246
""",
    [:(begin
    using Random
    Random.seed!(111)
    tickers = ["IBM", "Google", "Apple", "Intel"]
    N = 10
    D = length(tickers)
    weights = rand(N,D)
    weights ./= sum(weights, dims = 2)
    returns = sort!((1:N) + D*randn(N))

    portfoliocomposition(weights, returns, labels = permutedims(tickers))
    end)]
),

]

# Some constants for PlotDocs and PlotReferenceImages
_animation_examples = [2, 30]
_backend_skips = Dict(
    :gr => [25, 30],
    :pyplot => [25, 30],
    :plotlyjs => [2, 21, 25, 30, 31],
    :pgfplots => [2, 5, 6, 10, 16, 20, 22, 23, 25, 28, 30],
)



# ---------------------------------------------------------------------------------

# make and display one plot
function test_examples(pkgname::Symbol, idx::Int; debug = false, disp = true)
  Plots._debugMode.on = debug
  @info("Testing plot: $pkgname:$idx:$(_examples[idx].header)")
  backend(pkgname)
  backend()
  map(eval, _examples[idx].exprs)
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
function test_examples(pkgname::Symbol; debug = false, disp = true, sleep = nothing,
                                        skip = [], only = nothing)
  Plots._debugMode.on = debug
  plts = Dict()
  for i in 1:length(_examples)
    only !== nothing && !(i in only) && continue
    i in skip && continue
    try
      plt = test_examples(pkgname, i, debug=debug, disp=disp)
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
