

doc"""
The main plot command.  You must call `plotter!(:ModuleName)` to set the current plotting environment first.
Commands are converted into the relevant plotting commands for that package:

```
  plotter!(:gadfly)
  plot(1:10)    # this calls `y = 1:10; Gadfly.plot(x=1:length(y), y=y)`
  plotter!(:qwt)
  plot(1:10)    # this calls `Qwt.plot(1:10)`
```

Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
  plot(args...; kw...)                  # creates a new plot window, and sets it to be the currentPlot
  plot!(args...; kw...)                 # adds to the `currentPlot`
  plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

Now that you know which plot object you're updating (new, current, or other), I'll leave it off for simplicity.
Here are some various args to supply, and the implicit mapping (AVec == AbstractVector and AMat == AbstractMatrix):

```
  plot(y::AVec; kw...)                       # one line... x = 1:length(y)
  plot(x::AVec, y::AVec; kw...)              # one line (will assert length(x) == length(y))
  plot(y::AMat; kw...)                       # multiple lines (one per column of x), all sharing x = 1:size(y,1)
  plot(x::AVec, y::AMat; kw...)              # multiple lines (one per column of x), all sharing x (will assert length(x) == size(y,1))
  plot(x::AMat, y::AMat; kw...)              # multiple lines (one per column of x/y... will assert size(x) == size(y))
  plot(x::AVec, f::Function; kw...)          # one line, y = f(x)
  plot(x::AMat, f::Function; kw...)          # multiple lines, yᵢⱼ = f(xᵢⱼ)
  plot(x::AVec, fs::AVec{Function}; kw...)   # multiple lines, yᵢⱼ = fⱼ(xᵢ)
  plot(y::AVec{AVec}; kw...)                 # multiple lines, each with x = 1:length(y[i])
  plot(x::AVec, y::AVec{AVec}; kw...)        # multiple lines, will assert length(x) == length(y[i])
  plot(x::AVec{AVec}, y::AVec{AVec}; kw...)  # multiple lines, will assert length(x[i]) == length(y[i])
  plot(n::Integer; kw...)                    # n lines, all empty (for updating plots)

  # TODO: how do we handle NA values in dataframes?
  plot(df::DataFrame; kw...)                 # one line per DataFrame column, labels == names(df)
  plot(df::DataFrame, columns; kw...)        # one line per column, but on a subset of column names
```

  TODO: DataFrames

You can swap out `plot` for `subplot`.  Each line will go into a separate plot.  Use the layout keyword:

```
  y = rand(100,3)
  subplot(y; layout=(2,2), kw...)           # creates 3 lines going into 3 separate plots, laid out on a 2x2 grid (last row is filled with plot #3)
  subplot(y; layout=(1,3), kw...)           # again 3 plots, all in the same row
  subplot(y; layout=[1,[2,3]])              # pass a nested Array to fully specify the layout.  here the first plot will take up the first row, 
                                            # and the others will share the second row
```

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

If you don't include a keyword argument, these are the defaults:
  
```
  axis = :left
  color = :auto
  label = automatically generated (y1, y2, ...., or y1 (R), y2 (R) for the right axis)
  width = 2
  linetype = :line
  linestype = :solid
  marker = :none
  markercolor = :auto
  markersize = 5
  title = ""
  xlabel = ""
  ylabel = ""
  yrightlabel = ""
  reg = false
  size = (800,600)
  pos = (0,0)
  windowtitle = ""
  screen = 1
  show = true
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
  plt = plot(plotter(); getPlotKeywordArgs(kw, 1)...)  # create a new, blank plot
  plot!(plt, args...; kw...)  # add to it
end

# this adds to the current plot
function  plot!(args...; kw...)
  plot!(currentPlot(), args...; kw...)
end

# this adds to a specific plot... most plot commands will flow through here
function plot!(plt::Plot, args...; kw...)

  # increment n if we're going directly to the package's plot method
  if length(args) == 0
    plt.n += 1
  end

  plot!(plt.plotter, plt, args...; kw...)
  currentPlot!(plt)

  # do we want to show it?
  d = Dict(kw)
  if haskey(d, :show) && d[:show]
    display(plt)
  end

  plt
end

# show/update the plot
function Base.display(plt::Plot)
  display(plt.plotter, plt)
end

# -------------------------

# These methods are various ways to add to an existing plot

function plot!{T<:Real}(pkg::PlottingPackage, plt::Plot, y::AVec{T}; kw...)
  plt.n += 1
  plot!(pkg, plt; x = 1:length(y), y = y, getPlotKeywordArgs(kw, 1, plt)...)
end

function plot!{T<:Real,S<:Real}(pkg::PlottingPackage, plt::Plot, x::AVec{T}, y::AVec{S}; kw...)              # one line (will assert length(x) == length(y))
  @assert length(x) == length(y)
  plt.n += 1
  plot!(pkg, plt; x=x, y=y, getPlotKeywordArgs(kw, 1, plt)...)
end

function plot!(pkg::PlottingPackage, plt::Plot, y::AMat; kw...)                       # multiple lines (one per column of x), all sharing x = 1:size(y,1)
  n,m = size(y)
  for i in 1:m
    plt.n += 1
    plot!(pkg, plt; x = 1:n, y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, y::AMat; kw...)              # multiple lines (one per column of x), all sharing x (will assert length(x) == size(y,1))
  n,m = size(y)
  for i in 1:m
    @assert length(x) == n
    plt.n += 1
    plot!(pkg, plt; x = x, y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AMat, y::AMat; kw...)              # multiple lines (one per column of x/y... will assert size(x) == size(y))
  @assert size(x) == size(y)
  for i in 1:size(x,2)
    plt.n += 1
    plot!(pkg, plt; x = x[:,i], y = y[:,i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, f::Function; kw...)          # one line, y = f(x)
  plot!(pkg, plt; x = x, y = map(f,x), getPlotKeywordArgs(kw, 1, plt)...)
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AMat, f::Function; kw...)          # multiple lines, yᵢⱼ = f(xᵢⱼ)
  for i in 1:size(x,2)
    xi = x[:,i]
    plt.n += 1
    plot!(pkg, plt; x = xi, y = map(f, xi), getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, fs::AVec{Function}; kw...)   # multiple lines, yᵢⱼ = fⱼ(xᵢ)
  for i in 1:length(fs)
    plt.n += 1
    plot!(pkg, plt; x = x, y = map(fs[i], x), getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, y::AVec; kw...)                 # multiple lines, each with x = 1:length(y[i])
  for i in 1:length(y)
    plt.n += 1
    plot!(pkg, plt; x = 1:length(y[i]), y = y[i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!{T<:Real}(pkg::PlottingPackage, plt::Plot, x::AVec{T}, y::AVec; kw...)        # multiple lines, will assert length(x) == length(y[i])
  for i in 1:length(y)
    @assert length(x) == length(y[i])
    plt.n += 1
    plot!(pkg, plt; x = x, y = y[i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, x::AVec, y::AVec; kw...)  # multiple lines, will assert length(x[i]) == length(y[i])
  @assert length(x) == length(y)
  for i in 1:length(x)
    @assert length(x[i]) == length(y[i])
    plt.n += 1
    plot!(pkg, plt; x = x[i], y = y[i], getPlotKeywordArgs(kw, i, plt)...)
  end
  plt
end

function plot!(pkg::PlottingPackage, plt::Plot, n::Integer; kw...)                    # n lines, all empty (for updating plots)
  for i in 1:n
    plt.n += 1
    plot(pkg, plt, x = zeros(0), y = zeros(0), getPlotKeywordArgs(kw, i, plt)...)
  end
end

# -------------------------

# # this is the core method... add to a plot object using kwargs, with args already converted into kwargs
# function plot!(pkg::PlottingPackage, plt::Plot; kw...)
#   plot!(pl, plt; kw...)
# end
