# Plots

[![Build Status](https://travis-ci.org/tbreloff/Plots.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Plots.jl)
[![Plots](http://pkg.julialang.org/badges/Plots_0.3.svg)](http://pkg.julialang.org/?pkg=Plots&ver=0.3)
[![Plots](http://pkg.julialang.org/badges/Plots_0.4.svg)](http://pkg.julialang.org/?pkg=Plots&ver=0.4)
[![Coverage Status](https://coveralls.io/repos/tbreloff/Plots.jl/badge.svg?branch=master)](https://coveralls.io/r/tbreloff/Plots.jl?branch=master)
[![codecov.io](http://codecov.io/github/tbreloff/Plots.jl/coverage.svg?branch=master)](http://codecov.io/github/tbreloff/Plots.jl?branch=master)

#### Author: Thomas Breloff (@tbreloff)

Plots is a plotting API and toolset.  My goals with the package are:

- **Intuitive**.  Start generating complex plots without reading volumes of documentation.  Commands should "just work".
- **Concise**.  Less code means fewer mistakes and more efficient development/analysis.
- **Flexible**.  Produce your favorite plots from your favorite package, but quicker and simpler.
- **Consistent**.  Don't commit to one graphics package.  Use the same code and access the strengths of all backends.
- **Lightweight**.  Very few dependencies, since backends are loaded and initialized dynamically.

Use the preprocessing pipeline in Plots to fully describe your visualization before it calls the backend code.  This maintains modularity and allows for efficient separation of front end code, algorithms, and backend graphics.  New graphical backends can be added with minimal effort.

Check out the [summary graphs](img/supported/supported.md) for the features that each backend supports.

Please add wishlist items, bugs, or any other comments/questions to the issues list.

## Examples for each implemented backend:

- [Gadfly.jl/Immerse.jl](docs/gadfly_examples.md)
- [PyPlot.jl](docs/pyplot_examples.md)
- [UnicodePlots.jl](docs/unicodeplots_examples.md)
- [Qwt.jl](docs/qwt_examples.md)
- [Winston.jl](docs/winston_examples.md)

Also check out the many [IJulia notebooks](http://nbviewer.ipython.org/github/tbreloff/Plots.jl/tree/master/examples/) with many examples.

## Installation

First, add the package

```julia
Pkg.add("Plots")

# if you want the latest features:
Pkg.checkout("Plots")

# or for the bleeding edge:
Pkg.checkout("Plots", "dev")
```

then get any plotting packages you need (obviously, you should get at least one backend).

```julia
Pkg.add("Gadfly")
Pkg.add("Immerse")
Pkg.add("PyPlot")
Pkg.add("UnicodePlots")
Pkg.clone("https://github.com/tbreloff/Qwt.jl.git")
Pkg.add("Winston")
```

## Use

Load it in.  The underlying plotting backends are not imported until `backend()` is called (which happens
on your first call to `plot` or `subplot`).  This means that you don't need any backends to be installed when you call `using Plots`.

Plots will try to figure out a good default backend for you automatically based on what backends are installed.

```julia
using Plots
```

Do a plot in Gadfly (inspired by [this example](http://gadflyjl.org/geom_point.html)), then save a png:

```julia
gadfly()        # switch to Gadfly as a backend
dataframes()    # turn on support for DataFrames inputs

# load some data
using RDatasets
iris = dataset("datasets", "iris");

# This will bring up a browser window with the plot. Add a semicolon at the end to skip display. 
scatter(iris, :SepalLength, :SepalWidth, group=:Species, m=([:+ :d :s], 12), smooth=0.99, bg=:black)

# save a png (equivalent to png("gadfly1.png") and savefig("gadfly1.png"))
png("gadfly1")
```

![gadfly_plt](img/gadfly1.png)

## API

Call `backend(backend::Symbol)` or the shorthands (`gadfly()`, `qwt()`, `unicodeplots()`, etc) to set the current plotting backend.
Subsequent commands are converted into the relevant plotting commands for that package:

```julia
gadfly()
plot(1:10)    # this effectively calls `y = 1:10; Gadfly.plot(x=1:length(y), y=y)`
qwt()
plot(1:10)    # this effectively calls `Qwt.plot(1:10)`
```

Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```julia
plot(args...; kw...)                  # creates a new plot window, and sets it to be the `current`
plot!(args...; kw...)                 # adds to the `current`
plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

Now that you know which plot object you're updating (new, current, or other), I'll leave it off for simplicity.
There are many ways to pass in data to the plot functions... some examples:

- Vector-like (subtypes of AbstractArray{T,1})
- Matrix-like (subtypes of AbstractArray{T,2})
- Vectors of Vectors
- Functions
- Vectors of Functions
- DataFrames with column symbols (initialize with `dataframes()`)

In general, you can pass in a `y` only, or an `x` and `y`, both of whatever type(s) you want, and Plots will slice up the data as needed.
For matrices, data is split by columns.  For functions, data is mapped.  For DataFrames, a Symbol/Symbols in place of x/y will map to
the relevant column(s).

Here are some example usages... remember you can always use `plot!` to update an existing plot, and that, unless specified, you will update the `current()`.

```julia
plot()                                    # empty plot object
plot(4)                                   # initialize with 4 empty series
plot(rand(10))                            # plot 1 series... x = 1:10
plot(rand(10,5))                          # plot 5 series... x = 1:10
plot(rand(10), rand(10))                  # plot 1 series
plot(rand(10,5), rand(10))                # plot 5 series... y is the same for all
plot(sin, rand(10))                       # y = sin(x)
plot(rand(10), sin)                       # same... y = sin(x)
plot([sin,cos], 0:0.1:π)                  # plot 2 series, sin(x) and cos(x)
plot([sin,cos], 0, π)                     # plot sin and cos on the range [0, π]
plot(1:10, Any[rand(10), sin])            # plot 2 series, y = rand(10) for the first, y = sin(x) for the second... x = 1:10 for both
plot(dataset("Ecdat", "Airline"), :Cost)  # plot from a DataFrame (call `dataframes()` first to import DataFrames and initialize)
```

All plot methods accept a number of keyword arguments (see the tables below), which follow some rules:
- Many arguments have aliases which are replaced during preprocessing.  `c` is the same as `color`, `m` is the same as `marker`, etc.  You can choose how verbose you'd like to be.  (see the tables below)
- There are some special arguments (`xaxis`, `yaxis`, `line`, `marker`, `fill` and the aliases `l`, `m`, `f`) which magically set many related things at once.  (see the __Tip__ below)
- If the argument is a "matrix-type", then each column will map to a series, cycling through columns if there are fewer columns than series.  Anything else will apply the argument value to every series.
- Many arguments accept many different types... for example the `color` (also `markercolor`, `fillcolor`, etc) argument will accept strings or symbols with a color name, or any `Colors.Colorant`, or a `ColorScheme`, or a symbol representing a `ColorGradient`, or an AbstractVector of colors/symbols/etc...

You can update certain plot settings after plot creation (not supported on all backends):

```julia
plot!(title = "New Title", xlabel = "New xlabel", ylabel = "New ylabel")
plot!(xlims = (0, 5.5), ylims = (-2.2, 6), xticks = 0:0.5:10, yticks = [0,1,5,10])

# using shorthands:
xaxis!("mylabel", :log10, :flip)
```

With `subplot`, create multiple plots at once, with flexible layout options:

```julia
y = rand(100,3)
subplot(y; n = 3)             # create an automatic grid, and let it figure out the shape
subplot(y; n = 3, nr = 1)     # create an automatic grid, but fix the number of rows
subplot(y; n = 3, nc = 1)     # create an automatic grid, but fix the number of columns
subplot(y; layout = [1, 2])   # explicit layout.  Lists the number of plots in each row
```

__Tip__: You can call `subplot!(args...; kw...)` to add to an existing subplot.

__Tip__: Calling `subplot!` on a `Plot` object, or `plot!` on a `Subplot` object will throw an error.

Shorthands:

```julia
scatter(args...; kw...)    = plot(args...; kw...,  linetype = :scatter)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :scatter)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
heatmap(args...; kw...)    = plot(args...; kw...,  linetype = :heatmap)
heatmap!(args...; kw...)   = plot!(args...; kw..., linetype = :heatmap)
sticks(args...; kw...)     = plot(args...; kw...,  linetype = :sticks, marker = :ellipse)
sticks!(args...; kw...)    = plot!(args...; kw..., linetype = :sticks, marker = :ellipse)
hline(args...; kw...)      = plot(args...; kw...,  linetype = :hline)
hline!(args...; kw...)     = plot!(args...; kw..., linetype = :hline)
vline(args...; kw...)      = plot(args...; kw...,  linetype = :vline)
vline!(args...; kw...)     = plot!(args...; kw..., linetype = :vline)
ohlc(args...; kw...)       = plot(args...; kw...,  linetype = :ohlc)
ohlc!(args...; kw...)      = plot!(args...; kw..., linetype = :ohlc)

title!(s::AbstractString)                 = plot!(title = s)
xlabel!(s::AbstractString)                = plot!(xlabel = s)
ylabel!(s::AbstractString)                = plot!(ylabel = s)
xlims!{T<:Real,S<:Real}(lims::Tuple{T,S}) = plot!(xlims = lims)
ylims!{T<:Real,S<:Real}(lims::Tuple{T,S}) = plot!(ylims = lims)
xticks!{T<:Real}(v::AVec{T})              = plot!(xticks = v)
yticks!{T<:Real}(v::AVec{T})              = plot!(yticks = v)
xflip!(flip::Bool = true)                 = plot!(xflip = flip)
yflip!(flip::Bool = true)                 = plot!(yflip = flip)
xaxis!(args...)                           = plot!(xaxis = args)
yaxis!(args...)                           = plot!(yaxis = args)
annotate!(anns)                           = plot!(annotation = anns)
```

### Keyword arguments:

Keyword | Default | Type | Aliases 
---- | ---- | ---- | ----
`:annotation` | `nothing` | Series | `:ann`, `:annotate`, `:annotations`, `:anns`  
`:axis` | `left` | Series | `:axiss`  
`:background_color` | `RGB{U8}(1.0,1.0,1.0)` | Plot | `:background`, `:bg`, `:bg_color`, `:bgcolor`  
`:color` | `auto` | Series | `:c`, `:colors`  
`:color_palette` | `auto` | Plot | `:palette`  
`:fill` | `nothing` | Series | `:area`, `:f`  
`:fillcolor` | `match` | Series | `:fc`, `:fcolor`, `:fillcolors`  
`:fillopacity` | `nothing` | Series | `:fillopacitys`, `:fo`  
`:fillrange` | `nothing` | Series | `:fillranges`, `:fillrng`  
`:foreground_color` | `auto` | Plot | `:fg`, `:fg_color`, `:fgcolor`, `:foreground`  
`:grid` | `true` | Plot |   
`:group` | `nothing` | Series | `:g`, `:groups`  
`:guidefont` | `Plots.Font("Helvetica",11,:hcenter,:vcenter,0.0,RGB{U8}(0.0,0.0,0.0))` | Plot |   
`:label` | `AUTO` | Series | `:lab`, `:labels`  
`:layout` | `nothing` | Plot |   
`:legend` | `true` | Plot | `:leg`  
`:legendfont` | `Plots.Font("Helvetica",8,:hcenter,:vcenter,0.0,RGB{U8}(0.0,0.0,0.0))` | Plot |   
`:line` | `nothing` | Series | `:l`  
`:lineopacity` | `nothing` | Series | `:lineopacitys`, `:lo`  
`:linestyle` | `solid` | Series | `:linestyles`, `:ls`, `:s`, `:style`  
`:linetype` | `path` | Series | `:linetypes`, `:lt`, `:t`, `:type`  
`:linewidth` | `1` | Series | `:linewidths`, `:lw`, `:w`, `:width`  
`:link` | `false` | Plot |   
`:linkfunc` | `nothing` | Plot |   
`:linkx` | `false` | Plot | `:xlink`  
`:linky` | `false` | Plot | `:ylink`  
`:marker` | `nothing` | Series | `:m`, `:mark`  
`:markercolor` | `match` | Series | `:markercolors`, `:mc`, `:mcolor`  
`:markeropacity` | `nothing` | Series | `:alpha`, `:markeropacitys`, `:mo`, `:opacity`  
`:markershape` | `none` | Series | `:markershapes`, `:shape`  
`:markersize` | `6` | Series | `:markersizes`, `:ms`, `:msize`  
`:n` | `-1` | Plot |   
`:nbins` | `100` | Series | `:nb`, `:nbin`, `:nbinss`  
`:nc` | `-1` | Plot |   
`:nr` | `-1` | Plot |   
`:pos` | `(0,0)` | Plot |   
`:show` | `false` | Plot | `:display`, `:gui`  
`:size` | `(500,300)` | Plot | `:windowsize`, `:wsize`  
`:smooth` | `false` | Series | `:reg`, `:regression`, `:smooths`  
`:tickfont` | `Plots.Font("Helvetica",8,:hcenter,:vcenter,0.0,RGB{U8}(0.0,0.0,0.0))` | Plot |   
`:title` | `` | Plot |   
`:windowtitle` | `Plots.jl` | Plot | `:wtitle`  
`:xaxis` | `nothing` | Plot |   
`:xflip` | `false` | Plot |   
`:xlabel` | `` | Plot | `:xlab`  
`:xlims` | `auto` | Plot | `:xlim`, `:xlimit`, `:xlimits`  
`:xscale` | `identity` | Plot |   
`:xticks` | `auto` | Plot | `:xtick`  
`:yaxis` | `nothing` | Plot |   
`:yflip` | `false` | Plot |   
`:ylabel` | `` | Plot | `:ylab`  
`:ylims` | `auto` | Plot | `:ylim`, `:ylimit`, `:ylimits`  
`:yrightlabel` | `` | Plot | `:y2lab`, `:y2label`, `:ylab2`, `:ylabel2`, `:ylabelright`, `:ylabr`, `:yrlab`  
`:yscale` | `identity` | Plot |   
`:yticks` | `auto` | Plot | `:ytick`  
`:z` | `nothing` | Series | `:zs`  


### Plot types:

Type | Desc | Aliases
---- | ---- | ----
`:none` | No line | `:n`, `:no`  
`:line` | Lines with sorted x-axis | `:l`  
`:path` | Lines | `:p`  
`:steppre` | Step plot (vertical then horizontal) | `:stepinv`, `:stepinverted`, `:stepsinv`, `:stepsinverted`  
`:steppost` | Step plot (horizontal then vertical) | `:stair`, `:stairs`, `:step`, `:steps`  
`:sticks` | Vertical lines | `:stem`, `:stems`  
`:scatter` | Points, no lines | `:dots`  
`:heatmap` | Colored regions by density |   
`:hexbin` | Similar to heatmap |   
`:hist` | Histogram (doesn't use x) | `:histogram`  
`:bar` | Bar plot (centered on x values) |   
`:hline` | Horizontal line (doesn't use x) |   
`:vline` | Vertical line (doesn't use x) |   
`:ohlc` | Open/High/Low/Close chart (expects y is AbstractVector{Plots.OHLC}) |   


### Line styles:

Type | Aliases
---- | ----
`:auto` | `:a`  
`:solid` | `:s`  
`:dash` | `:d`  
`:dot` |   
`:dashdot` | `:dd`  
`:dashdotdot` | `:ddd`  


### Markers:

Type | Aliases
---- | ----
`:none` | `:n`, `:no`  
`:auto` | `:a`  
`:cross` | `:+`, `:plus`  
`:diamond` | `:d`  
`:dtriangle` | `:V`, `:downtri`, `:downtriangle`, `:dt`, `:dtri`, `:v`  
`:ellipse` | `:c`, `:circle`  
`:heptagon` | `:hep`  
`:hexagon` | `:h`, `:hex`  
`:octagon` | `:o`, `:oct`  
`:pentagon` | `:p`, `:pent`  
`:rect` | `:r`, `:sq`, `:square`  
`:star4` |   
`:star5` | `:s`, `:star`, `:star1`  
`:star6` |   
`:star7` |   
`:star8` | `:s2`, `:star2`  
`:utriangle` | `:^`, `:uptri`, `:uptriangle`, `:ut`, `:utri`  
`:xcross` | `:X`, `:x`  


__Tip__: With supported backends, you can pass a `Plots.Shape` object for the `marker`/`markershape` arguments.  `Shape` takes a vector of 2-tuples in the constructor, defining the points of the polygon's shape in a unit-scaled coordinate space.  To make a square, for example, you could do `Shape([(1,1),(1,-1),(-1,-1),(-1,1)])`

__Tip__: You can see the default value for a given argument with `default(arg::Symbol)`, and set the default value with `default(arg::Symbol, value)` or `default(; kw...)`.  For example set the default window size and whether we should show a legend with `default(size=(600,400), leg=false)`.

__Tip__: There are some helper arguments you can set:  `xaxis`, `yaxis`, `line`, `marker`, `fill`.  These go through special preprocessing to extract values into individual arguments.  The order doesn't matter, and if you pass a single value it's equivalent to wrapping it in a Tuple.  Examples:

```
plot(y, xaxis = ("mylabel", :log, :flip, (-1,1)))   # this sets the `xlabel`, `xscale`, `xflip`, and `xlims` arguments automatically
plot(y, line = (:bar, :blue, :dot, 10))             # this sets the `linetype`, `color`, `linestyle`, and `linewidth` arguments automatically
plot(y, marker = (:rect, :red, 10))                 # this sets the `markershape`, `markercolor`, and `markersize` arguments automatically
plot(y, fill = (:green, 10))                        # this sets the `fillcolor` and `fillrange` arguments automatically
                                                    # Note: `fillrange` can be:
                                                              a number (fill to horizontal line)
                                                              a vector of numbers (different for each data point)
                                                              a tuple of vectors (fill a band)
```

__Tip__: When plotting multiple lines, you can set all series to use the same value, or pass in a matrix to cycle through values.  Example:

```julia
plot(rand(100,4); color = [:red RGB(0,0,1)],     # (Matrix) lines 1 and 3 are red, lines 2 and 4 are blue
                  axis = :auto,                  # lines 1 and 3 are on the left axis, lines 2 and 4 are on the right
                  markershape = [:rect, :star]   # (Vector) ALL lines are passed the vector [:rect, :star1]
                  width = 5)                     # all lines have a width of 5
```

__Tip__: Not all features are supported for each backend, but you can see what's supported by calling the functions: `supportedArgs()`, `supportedAxes()`, `supportedTypes()`, `supportedStyles()`, `supportedMarkers()`, `subplotSupported()`

__Tip__: Call `gui()` to display the plot in a window.  Interactivity depends on backend.  Plotting at the REPL (without semicolon) implicitly calls `gui()`.

### Animations

Animations are created in 3 steps (see example #2):
- Initialize an `Animation` object.
- Save each frame of the animation with `frame(anim)`.
- Convert the frames to an animated gif with `gif(anim, filename, fps=15)`


## TODO features:

- [x] Plot vectors/matrices/functions
- [x] Plot DataFrames
- [x] Histograms
- [x] Grouping
- [x] Annotations
- [x] Scales
- [x] Categorical Inputs (strings, etc... for hist, bar? or can split one series into multiple?)
- [x] Custom markers
- [x] Animations
- [x] Subplots
- [ ] Contours
- [ ] Boxplots
- [ ] 3D plotting
- [ ] Scenes/Drawing
- [ ] Graphs
- [ ] Interactivity (GUIs)

## TODO backends:

- [x] Gadfly.jl
- [x] Immerse.jl
- [x] PyPlot.jl
- [x] UnicodePlots.jl
- [x] Qwt.jl
- [x] Winston.jl
- [ ] GLPlot.jl
- [ ] Bokeh.jl
- [ ] Vega.jl
- [ ] Gaston.jl
- [ ] Plotly.jl
- [ ] GoogleCharts.jl
- [ ] PLplot.jl
- [ ] TextPlots.jl
- [ ] ASCIIPlots.jl
- [ ] Sparklines.jl
- [ ] Hinton.jl
- [ ] ImageTerm.jl
- [ ] GraphViz.jl
- [ ] TikzGraphs.jl
- [ ] GraphLayout.jl

## More information on backends (both supported and unsupported)

See the wiki at: https://github.com/JuliaPlot/juliaplot_docs/wiki


