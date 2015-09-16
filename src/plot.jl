
type CurrentPlot
  nullableplot::Nullable{PlottingObject}
end
const CURRENT_PLOT = CurrentPlot(Nullable{PlottingObject}())

isplotnull() = isnull(CURRENT_PLOT.nullableplot)

function currentPlot()
  if isplotnull()
    error("No current plot/subplot")
  end
  get(CURRENT_PLOT.nullableplot)
end
currentPlot!(plot::PlottingObject) = (CURRENT_PLOT.nullableplot = Nullable(plot))

# ---------------------------------------------------------


Base.string(plt::Plot) = "Plot{$(plt.plotter) n=$(plt.n)}"
Base.print(io::IO, plt::Plot) = print(io, string(plt))
Base.show(io::IO, plt::Plot) = print(io, string(plt))

getplot(plt::Plot) = plt


doc"""
The main plot command.  Call `plotter!(:module)` to set the current plotting backend.
Commands are converted into the relevant plotting commands for that package:

```
  plotter!(:gadfly)
  plot(1:10)    # this effectively calls `y = 1:10; Gadfly.plot(x=1:length(y), y=y)`
  plotter!(:qwt)
  plot(1:10)    # this effectively calls `Qwt.plot(1:10)`
```

Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
  plot(args...; kw...)                  # creates a new plot window, and sets it to be the currentPlot
  plot!(args...; kw...)                 # adds to the `currentPlot`
  plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

There are lots of ways to pass in data... just try it and it will likely work as expected.
When you pass in matrices, it splits by columns.  See the documentation for more info.

Some keyword arguments you can set:

```
  axis            # :left or :right
  color           # can be a string ("red") or a symbol (:red) or a ColorsTypes.jl Colorant (RGB(1,0,0)) or :auto (which lets the package pick)
  label           # string or symbol, applies to that line, may go in a legend
  width           # width of a line
  linetype        # :line, :step, :stepinverted, :sticks, :scatter, :none, :heatmap
  linestyle       # :solid, :dash, :dot, :dashdot, :dashdotdot
  marker          # :none, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon
  markercolor     # same choices as `color`
  markersize      # size of the marker
  nbins           # number of bins for heatmap/hexbin and histograms
  heatmap_c       # color cutoffs for Qwt heatmaps
  fillto          # fillto value for area plots
  title           # string or symbol, title of the plot
  xlabel          # string or symbol, label on the bottom (x) axis
  ylabel          # string or symbol, label on the left (y) axis
  yrightlabel     # string or symbol, label on the right (y) axis
  reg             # true or false, add a regression line for each line
  size            # (Int,Int), resize the enclosing window
  pos             # (Int,Int), move the enclosing window to this position
  windowtitle     # string or symbol, set the title of the enclosing windowtitle
  screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)
  show            # true or false, show the plot (in case you don't want the window to pop up right away)
```

When plotting multiple lines, you can give every line the same trait by using the singular, or add an "s" to pluralize.
  (yes I know it's not gramatically correct, but it's easy to use and implement)

```
  plot(rand(100,2); colors = [:red, RGB(.5,.5,0)], axiss = [:left, :right], width = 5)  # note the width=5 is applied to both lines
```

"""


# -------------------------

# this creates a new plot with args/kw and sets it to be the current plot
function plot(args...; kw...)
  pkg = plotter()
  plt = plot(pkg; getPlotKeywordArgs(pkg, kw, 1, 0)...)  # create a new, blank plot
  plot!(plt, args...; kw...)  # add to it
end


function plot_display(args...; kw...)
  plt = plot(args...; kw...)
  display(plt)
  plt
end

# this adds to the current plot
function  plot!(args...; kw...)
  plot!(currentPlot(), args...; kw...)
end

# not allowed:
function plot!(subplt::Subplot, args...; kw...)
  error("Can't call plot! on a Subplot!")
end

# this adds to a specific plot... most plot commands will flow through here
function plot!(plt::Plot, args...; kw...)

  kwList = createKWargsList(plt, args...; kw...)
  for (i,d) in enumerate(kwList)
    plt.n += 1
    plot!(plt.plotter, plt; d...)
  end

  currentPlot!(plt)

  # NOTE: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
  # # do we want to show it?
  # d = Dict(kw)
  # if haskey(d, :show) && d[:show]
  #   display(plt)
  # end

  plt
end

# show/update the plot
function Base.display(plt::PlottingObject)
  display(plt.plotter, plt)
end

# -------------------------



doc"Build a vector of dictionaries which hold the keyword arguments for a call to plot!"

# no args... 1 series
function createKWargsList(plt::PlottingObject; kw...)
  d = Dict(kw)
  @assert haskey(d, :y)
  if !haskey(d, :x)
    d[:x] = 1:length(d[:y])
  end
  [getPlotKeywordArgs(plt.plotter, d, 1, plt.n + 1)]
end


# ----------------------------------------------------------------------------
# Arrays of numbers
# ----------------------------------------------------------------------------


# create one series where y is vectors of numbers
function createKWargsList{T<:Real}(plt::PlottingObject, y::AVec{T}; kw...)
  d = getPlotKeywordArgs(plt.plotter, kw, 1, plt.n + 1)
  d[:x] = 1:length(y)
  d[:y] = y
  [d]
end

# create one series where x/y are vectors of numbers
function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AVec{T}, y::AVec{S}; kw...)
  @assert length(x) == length(y)
  d = getPlotKeywordArgs(plt.plotter, kw, 1, plt.n + 1)
  d[:x] = x
  d[:y] = y
  [d]
end

# create m series, 1 for each column of y
function createKWargsList{T<:Real}(plt::PlottingObject, y::AMat{T}; kw...)
  n,m = size(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = 1:n
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# create m series, 1 for each column of y
function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AVec{T}, y::AMat{S}; kw...)
  n,m = size(y)
  @assert length(x) == n
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# create m series, 1 for each column of y
function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AMat{T}, y::AMat{S}; kw...)
  @assert size(x) == size(y)
  n,m = size(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x[:,i]
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------


# create 1 series, y = f(x), x ∈ [xmin, xmax]
function createKWargsList(plt::PlottingObject, f::Function, xmin::Real, xmax::Real; kw...)
  d = getPlotKeywordArgs(plt.plotter, kw, 1, plt.n + 1)
  width = plt.initargs[:size][1]
  d[:x] = collect(linspace(xmin, xmax, width))  # we don't need more than the width
  d[:y] = map(f, d[:x])
  [d]
end

# create m series, yᵢ = fᵢ(x), x ∈ [xmin, xmax]
function createKWargsList(plt::PlottingObject, fs::Vector{Function}, xmin::Real, xmax::Real; kw...)
  m = length(fs)
  ret = []
  width = plt.initargs[:size][1]
  x = collect(linspace(xmin, xmax, width)) # we don't need more than the width
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x
    d[:y] = map(fs[i], x)
    push!(ret, d)
  end
  ret
end

# create 1 series, x = fx(u), y = fy(u); u ∈ [umin, umax]
function createKWargsList(plt::PlottingObject, fx::Function, fy::Function, umin::Real, umax::Real; kw...)
  d = getPlotKeywordArgs(plt.plotter, kw, 1, plt.n + 1)
  width = plt.initargs[:size][1]
  u = collect(linspace(umin, umax, width))  # we don't need more than the width
  d[:x] = map(fx, u)
  d[:y] = map(fy, u)
  [d]
end

# create 1 series, y = f(x)
function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec{T}, f::Function; kw...)
  d = getPlotKeywordArgs(plt.plotter, kw, 1, plt.n + 1)
  d[:x] = x
  d[:y] = map(f, x)
  [d]
end
createKWargsList{T<:Real}(plt::PlottingObject, f::Function, x::AVec{T}; kw...) = createKWargsList(plt, x, f; kw...)

# create m series, y = f(x), 1 for each column of x
function createKWargsList{T<:Real}(plt::PlottingObject, x::AMat{T}, f::Function; kw...)
  n,m = size(x)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x[:,i]
    d[:y] = map(f, d[:x])
    push!(ret, d)
  end
  ret
end
createKWargsList{T<:Real}(plt::PlottingObject, f::Function, x::AMat{T}; kw...) = createKWargsList(plt, x, f; kw...)


# ----------------------------------------------------------------------------
# Other combinations... lists of vectors, etc
# ----------------------------------------------------------------------------


# create m series, 1 for each item in y (assumes vectors of something other than numbers... functions? vectors?)
function createKWargsList(plt::PlottingObject, y::AVec; kw...)
  m = length(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = 1:length(y[i])
    d[:y] = y[i]
    push!(ret, d)
  end
  ret
end

function getyvec(x::AVec, y::AVec)
  @assert length(x) == length(y)
  y
end
getyvec(x::AVec, f::Function) = map(f, x)
getyvec(x, y) = error("Couldn't create yvec from types: x ($(typeof(x))), y ($(typeof(y)))")

# same, but given an x to use for all series
function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec{T}, y::AVec; kw...)
  m = length(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x
    d[:y] = getyvec(x, y[i])
    push!(ret, d)
  end
  ret
end

# x is vec of vec, but y is a matrix
function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec, y::AMat{T}; kw...)
  n,m = size(y)
  @assert length(x) == m
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x[i]
    d[:y] = getyvec(x[i], y[:,i])
    push!(ret, d)
  end
  ret
end

# same, but m series of (x[i],y[i])
function createKWargsList(plt::PlottingObject, x::AVec, y::AVec; kw...)
  @assert length(x) == length(y)
  m = length(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = x[i]
    d[:y] = getyvec(x[i], y[i])
    push!(ret, d)
  end
  ret
end

# n empty series
function createKWargsList(plt::PlottingObject, n::Integer; kw...)
  ret = []
  for i in 1:n
    d = getPlotKeywordArgs(plt.plotter, kw, i, plt.n + i)
    d[:x] = zeros(0)
    d[:y] = zeros(0)
    push!(ret, d)
  end
  ret
end

# TODO: handle DataFrames (might have NAs!)

# -------------------------

