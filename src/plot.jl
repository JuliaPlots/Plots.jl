
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
  linetype        # :line, :step, :stepinverted, :sticks, :dots, :none, :heatmap
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
  plt = plot(plotter(); getPlotKeywordArgs(kw, 1, 0)...)  # create a new, blank plot
  plot!(plt, args...; kw...)  # add to it
end

# this adds to the current plot
function  plot!(args...; kw...)
  plot!(currentPlot(), args...; kw...)
end

# this adds to a specific plot... most plot commands will flow through here
function plot!(plt::Plot, args...; kw...)

  # # increment n if we're going directly to the package's plot method
  # if length(args) == 0
  #   plt.n += 1
  # end

  # plot!(plt.plotter, plt, args...; kw...)


  kwList = createKWargsList(plt, args...; kw...)
  for (i,d) in enumerate(kwList)
    plt.n += 1
    plot!(plt.plotter, plt; d...)
  end

  currentPlot!(plt)

  # do we want to show it?
  d = Dict(kw)
  if haskey(d, :show) && d[:show]
    display(plt)
  end

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
  [getPlotKeywordArgs(kw, 1, plt.n + 1)]
end

# create one series where y is vectors of numbers
function createKWargsList{T<:Real}(plt::PlottingObject, y::AVec{T}; kw...)
  d = getPlotKeywordArgs(kw, 1, plt.n + 1)
  d[:x] = 1:length(y)
  d[:y] = y
  [d]
end

# create one series where x/y are vectors of numbers
function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AVec{T}, y::AVec{S}; kw...)
  @assert length(x) == length(y)
  d = getPlotKeywordArgs(kw, 1, plt.n + 1)
  d[:x] = x
  d[:y] = y
  [d]
end

# create m series, 1 for each column of y
function createKWargsList(plt::PlottingObject, y::AMat; kw...)
  n,m = size(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = 1:n
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# create m series, 1 for each column of y
function createKWargsList(plt::PlottingObject, x::AVec, y::AMat; kw...)
  n,m = size(y)
  @assert length(x) == n
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = x
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# create m series, 1 for each column of y
function createKWargsList(plt::PlottingObject, x::AMat, y::AMat; kw...)
  @assert size(x) == size(y)
  n,m = size(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = x[:,i]
    d[:y] = y[:,i]
    push!(ret, d)
  end
  ret
end

# create 1 series, y = f(x)
function createKWargsList(plt::PlottingObject, x::AVec, f::Function; kw...)
  d = getPlotKeywordArgs(kw, 1, plt.n + 1)
  d[:x] = x
  d[:y] = map(f, x)
  [d]
end

# create m series, y = f(x), 1 for each column of x
function createKWargsList(plt::PlottingObject, x::AMat, f::Function; kw...)
  n,m = size(x)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = x[:,i]
    d[:y] = map(f, d[:x])
    push!(ret, d)
  end
  ret
end

# create m series, 1 for each item in y (assumes vectors of something other than numbers... functions? vectors?)
function createKWargsList(plt::PlottingObject, y::AVec; kw...)
  m = length(y)
  ret = []
  for i in 1:m
    d = getPlotKeywordArgs(kw, i, plt.n + i)
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
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = x
    d[:y] = getyvec(x, y[i])
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
    d = getPlotKeywordArgs(kw, i, plt.n + i)
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
    d = getPlotKeywordArgs(kw, i, plt.n + i)
    d[:x] = zeros(0)
    d[:y] = zeros(0)
    push!(ret, d)
  end
  ret
end

# TODO: handle DataFrames (might have NAs!)

# -------------------------

# # most calls should flow through here now... we create a Dict with the keyword args for each series, and plot them
# function plot!(pkg::PlottingPackage, plt::Plot, args...; kw...)
#   kwList = createKWargsList(plt, args...; kw...)
#   for (i,d) in enumerate(kwList)
#     plt.n += 1
#     plot!(pkg, plt; d...)
#   end
#   plt
# end

# -------------------------

# # These methods are various ways to add to an existing plot

# function plot!{T<:Real}(pkg::PlottingPackage, plt::Plot, y::AVec{T}; kw...)
#   plt.n += 1
#   # plot!(pkg, plt; x = 1:length(y), y = y, getPlotKeywordArgs(kw, 1, plt)...)
# end

# function plot!{T<:Real,S<:Real}(pkg::PlottingPackage, plt::Plot, x::AVec{T}, y::AVec{S}; kw...)              # one line (will assert length(x) == length(y))
#   @assert length(x) == length(y)
#   plt.n += 1
#   plot!(pkg, plt; x=x, y=y, getPlotKeywordArgs(kw, 1, plt)...)
# end

# function plot!(pkg::PlottingPackage, plt::Plot, y::AMat; kw...)                       # multiple lines (one per column of x), all sharing x = 1:size(y,1)
#   n,m = size(y)
#   for i in 1:m
#     plt.n += 1
#     plot!(pkg, plt; x = 1:n, y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, y::AMat; kw...)              # multiple lines (one per column of x), all sharing x (will assert length(x) == size(y,1))
#   n,m = size(y)
#   for i in 1:m
#     @assert length(x) == n
#     plt.n += 1
#     plot!(pkg, plt; x = x, y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# function plot!(pkg::PlottingPackage, plt::Plot, x::AMat, y::AMat; kw...)              # multiple lines (one per column of x/y... will assert size(x) == size(y))
#   @assert size(x) == size(y)
#   for i in 1:size(x,2)
#     plt.n += 1
#     plot!(pkg, plt; x = x[:,i], y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, f::Function; kw...)          # one line, y = f(x)
#   plt.n += 1
#   plot!(pkg, plt; x = x, y = map(f,x), getPlotKeywordArgs(kw, 1, plt)...)
# end

# function plot!(pkg::PlottingPackage, plt::Plot, x::AMat, f::Function; kw...)          # multiple lines, yᵢⱼ = f(xᵢⱼ)
#   for i in 1:size(x,2)
#     xi = x[:,i]
#     plt.n += 1
#     plot!(pkg, plt; x = xi, y = map(f, xi), getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# # function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, fs::AVec{Function}; kw...)   # multiple lines, yᵢⱼ = fⱼ(xᵢ)
# #   for i in 1:length(fs)
# #     plt.n += 1
# #     plot!(pkg, plt; x = x, y = map(fs[i], x), getPlotKeywordArgs(kw, i, plt)...)
# #   end
# #   plt
# # end

# function plot!(pkg::PlottingPackage, plt::Plot, y::AVec; kw...)                 # multiple lines, each with x = 1:length(y[i])
#   for i in 1:length(y)
#     plt.n += 1
#     plot!(pkg, plt; x = 1:length(y[i]), y = y[i], getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# function plot!{T<:Real}(pkg::PlottingPackage, plt::Plot, x::AVec{T}, y::AVec; kw...)        # multiple lines, will assert length(x) == length(y[i])
#   for i in 1:length(y)
#     if typeof(y[i]) <: AbstractVector
#       @assert length(x) == length(y[i])
#       plt.n += 1
#       plot!(pkg, plt; x = x, y = y[i], getPlotKeywordArgs(kw, i, plt)...)
#     elseif typeof(y[i]) == Function
#       plt.n += 1
#       plot!(pkg, plt; x = x, y = map(y[i], x), getPlotKeywordArgs(kw, 1, plt)...)
#     end
#   end
#   plt
# end

# function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, y::AVec; kw...)  # multiple lines, will assert length(x[i]) == length(y[i])
#   @assert length(x) == length(y)
#   for i in 1:length(x)
#     @assert length(x[i]) == length(y[i])
#     plt.n += 1
#     plot!(pkg, plt; x = x[i], y = y[i], getPlotKeywordArgs(kw, i, plt)...)
#   end
#   plt
# end

# function plot!(pkg::PlottingPackage, plt::Plot, n::Integer; kw...)                    # n lines, all empty (for updating plots)
#   for i in 1:n
#     plt.n += 1
#     plot(pkg, plt, x = zeros(0), y = zeros(0), getPlotKeywordArgs(kw, i, plt)...)
#   end
# end

# -------------------------

# # this is the core method... add to a plot object using kwargs, with args already converted into kwargs
# function plot!(pkg::PlottingPackage, plt::Plot; kw...)
#   plot!(pl, plt; kw...)
# end
