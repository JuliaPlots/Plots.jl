
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
getinitargs(plt::Plot, idx::Int = 1) = plt.initargs
convertSeriesIndex(plt::Plot, n::Int) = n

# ---------------------------------------------------------


doc"""
The main plot command.  Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
  plot(args...; kw...)                  # creates a new plot window, and sets it to be the currentPlot
  plot!(args...; kw...)                 # adds to the `currentPlot`
  plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

There are lots of ways to pass in data, and lots of keyword arguments... just try it and it will likely work as expected.
When you pass in matrices, it splits by columns.  See the documentation for more info.
"""

# this creates a new plot with args/kw and sets it to be the current plot
function plot(args...; kw...)
  pkg = plotter()
  d = Dict(kw)
  replaceAliases!(d, _keyAliases)

  # # ensure we're passing in an RGB
  # if haskey(d, :background_color)
  #   d[:background_color] = convertColor(d[:background_color])
  # end

  plt = plot(pkg; getPlotArgs(pkg, d, 1)...)  # create a new, blank plot

  delete!(d, :background_color)
  plot!(plt, args...; d...)  # add to it
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

  d = Dict(kw)
  replaceAliases!(d, _keyAliases)

  # TODO: handle a "group by" mechanism.
  # will probably want to check for the :group kw param, and split into
  # index partitions/filters to be passed through to the next step.
  # Ideally we don't change the insides ot createKWargsList too much to 
  # save from code repetition.  We could consider adding a throw

  kwList = createKWargsList(plt, args...; d...)
  for (i,d) in enumerate(kwList)
    plt.n += 1
    plot!(plt.plotter, plt; d...)
  end

  updatePlotItems(plt.plotter, plt, d)
  currentPlot!(plt)

  # NOTE: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
  # # do we want to show it?
  # if haskey(d, :show) && d[:show]
  #   display(plt)
  # end

  plt
end

# # show/update the plot
# function Base.display(plt::PlottingObject)
#   display(plt.plotter, plt)
# end

# --------------------------------------------------------------------


# create a new "createKWargsList" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type

typealias FuncOrFuncs Union{Function, AVec{Function}}

# missing
convertToAnyVector(v::Void; kw...) = Any[nothing]

# fixed number of blank series
convertToAnyVector(n::Integer; kw...) = Any[zero(0) for i in 1:n]

# numeric vector
convertToAnyVector{T<:Real}(v::AVec{T}; kw...) = Any[v]

# numeric matrix
convertToAnyVector{T<:Real}(v::AMat{T}; kw...) = Any[v[:,i] for i in 1:size(v,2)]

# function
convertToAnyVector(f::Function; kw...) = Any[f]

# list of things (maybe other vectors, functions, or something else)
convertToAnyVector(v::AVec; kw...) = Any[vi for vi in v]


# --------------------------------------------------------------------

# in computeXandY, we take in any of the possible items, convert into proper x/y vectors, then return.
# this is also where all the "set x to 1:length(y)" happens, and also where we assert on lengths.
computeX(x::Void, y) = 1:length(y)
computeX(x, y) = x
computeY(x, y::Function) = map(y, x)
computeY(x, y) = y
function computeXandY(x, y)
  x, y = computeX(x,y), computeY(x,y)
  @assert length(x) == length(y)
  x, y
end


# --------------------------------------------------------------------

# create n=max(mx,my) series arguments. the shorter list is cycled through
# note: everything should flow through this
function createKWargsList(plt::PlottingObject, x, y; kw...)
  xs = convertToAnyVector(x; kw...)
  ys = convertToAnyVector(y; kw...)
  mx = length(xs)
  my = length(ys)
  ret = []
  for i in 1:max(mx, my)
    n = plt.n + i
    d = getSeriesArgs(plt.plotter, getinitargs(plt, n), kw, i, convertSeriesIndex(plt, n), n)
    d[:x], d[:y] = computeXandY(xs[mod1(i,mx)], ys[mod1(i,my)])

    if d[:linetype] == :line
      # order by x
      indices = sortperm(d[:x])
      d[:x] = d[:x][indices]
      d[:y] = d[:y][indices]
      d[:linetype] = :path
    end

    push!(ret, d)
  end
  ret
end

# pass it off to the x/y version
function createKWargsList(plt::PlottingObject, y; kw...)
  createKWargsList(plt, nothing, y; kw...)
end

function createKWargsList(plt::PlottingObject, f::FuncOrFuncs; kw...)
  error("Can't pass a Function or Vector{Function} for y without also passing x")
end

function createKWargsList(plt::PlottingObject, f::FuncOrFuncs, x; kw...)
  @assert !(x <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
  createKWargsList(plt, x, f; kw...)
end

# special handling... xmin/xmax with function(s)
function createKWargsList(plt::PlottingObject, f::FuncOrFuncs, xmin::Real, xmax::Real; kw...)
  width = plt.initargs[:size][1]
  x = collect(linspace(xmin, xmax, width))  # we don't need more than the width
  createKWargsList(plt, x, f; kw...)
end

mapFuncOrFuncs(f::Function, u::AVec) = map(f, u)
mapFuncOrFuncs(fs::AVec{Function}, u::AVec) = [map(f, u) for f in fs]

# special handling... xmin/xmax with parametric function(s)
function createKWargsList(plt::PlottingObject, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Real, umax::Real, numPoints::Int = 1000; kw...)
  u = collect(linspace(umin, umax, numPoints))
  createKWargsList(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u); kw...)
end


# special handling... no args... 1 series
function createKWargsList(plt::PlottingObject; kw...)
  d = Dict(kw)
  if !haskey(d, :y)
    # assume we just want to create an empty plot object which can be added to later
    return []
    # error("Called plot/subplot without args... must set y in the keyword args.  Example: plot(; y=rand(10))")
  end
  
  if haskey(d, :x)
    return createKWargsList(plt, d[:x], d[:y]; kw...)
  else
    return createKWargsList(plt, d[:y]; kw...)
  end
end

# --------------------------------------------------------------------

"For DataFrame support.  Imports DataFrames and defines the necessary methods which support them."
function dataframes!()
  @eval import DataFrames

  @eval function createKWargsList(plt::PlottingObject, df::DataFrames.DataFrame, args...; kw...)
    createKWargsList(plt, args...; kw..., dataframe = df)
  end

  @eval function getDataFrameFromKW(; kw...)
    for (k,v) in kw
      if k == :dataframe
        return v
      end
    end
    error("Missing dataframe argument in arguments!")
  end

  # the conversion functions for when we pass symbols or vectors of symbols to reference dataframes
  @eval convertToAnyVector(s::Symbol; kw...) = Any[getDataFrameFromKW(;kw...)[s]]
  @eval convertToAnyVector(v::AVec{Symbol}; kw...) = (df = getDataFrameFromKW(;kw...); Any[df[s] for s in v])
end


# --------------------------------------------------------------------



# doc"Build a vector of dictionaries which hold the keyword arguments for a call to plot!"

# # no args... 1 series
# function createKWargsList(plt::PlottingObject; kw...)
#   d = Dict(kw)
#   @assert haskey(d, :y)
#   if !haskey(d, :x)
#     d[:x] = 1:length(d[:y])
#   end
#   [getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), d, 1, plt.n + 1)]
# end


# # ----------------------------------------------------------------------------
# # Arrays of numbers
# # ----------------------------------------------------------------------------


# # create one series where y is vectors of numbers
# function createKWargsList{T<:Real}(plt::PlottingObject, y::AVec{T}; kw...)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   d[:x] = 1:length(y)
#   d[:y] = y
#   [d]
# end

# # create one series where x/y are vectors of numbers
# function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AVec{T}, y::AVec{S}; kw...)
#   @assert length(x) == length(y)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   d[:x] = x
#   d[:y] = y
#   [d]
# end

# # create m series, 1 for each column of y
# function createKWargsList{T<:Real}(plt::PlottingObject, y::AMat{T}; kw...)
#   n,m = size(y)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = 1:n
#     d[:y] = y[:,i]
#     push!(ret, d)
#   end
#   ret
# end

# # create m series, 1 for each column of y
# function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AVec{T}, y::AMat{S}; kw...)
#   n,m = size(y)
#   @assert length(x) == n
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x
#     d[:y] = y[:,i]
#     push!(ret, d)
#   end
#   ret
# end

# # create m series, 1 for each column of y
# function createKWargsList{T<:Real,S<:Real}(plt::PlottingObject, x::AMat{T}, y::AMat{S}; kw...)
#   @assert size(x) == size(y)
#   n,m = size(y)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x[:,i]
#     d[:y] = y[:,i]
#     push!(ret, d)
#   end
#   ret
# end

# # ----------------------------------------------------------------------------
# # Functions
# # ----------------------------------------------------------------------------


# # create 1 series, y = f(x), x ∈ [xmin, xmax]
# function createKWargsList(plt::PlottingObject, f::Function, xmin::Real, xmax::Real; kw...)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   width = plt.initargs[:size][1]
#   d[:x] = collect(linspace(xmin, xmax, width))  # we don't need more than the width
#   d[:y] = map(f, d[:x])
#   [d]
# end

# # create m series, yᵢ = fᵢ(x), x ∈ [xmin, xmax]
# function createKWargsList(plt::PlottingObject, fs::Vector{Function}, xmin::Real, xmax::Real; kw...)
#   m = length(fs)
#   ret = []
#   width = plt.initargs[:size][1]
#   x = collect(linspace(xmin, xmax, width)) # we don't need more than the width
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x
#     d[:y] = map(fs[i], x)
#     push!(ret, d)
#   end
#   ret
# end

# # create 1 series, x = fx(u), y = fy(u); u ∈ [umin, umax]
# function createKWargsList(plt::PlottingObject, fx::Function, fy::Function, umin::Real, umax::Real; kw...)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   width = plt.initargs[:size][1]
#   u = collect(linspace(umin, umax, width))  # we don't need more than the width
#   d[:x] = map(fx, u)
#   d[:y] = map(fy, u)
#   [d]
# end

# # create 1 series, y = f(x)
# function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec{T}, f::Function; kw...)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   d[:x] = x
#   d[:y] = map(f, x)
#   [d]
# end
# createKWargsList{T<:Real}(plt::PlottingObject, f::Function, x::AVec{T}; kw...) = createKWargsList(plt, x, f; kw...)

# # create m series, y = f(x), 1 for each column of x
# function createKWargsList{T<:Real}(plt::PlottingObject, x::AMat{T}, f::Function; kw...)
#   n,m = size(x)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x[:,i]
#     d[:y] = map(f, d[:x])
#     push!(ret, d)
#   end
#   ret
# end
# createKWargsList{T<:Real}(plt::PlottingObject, f::Function, x::AMat{T}; kw...) = createKWargsList(plt, x, f; kw...)


# # ----------------------------------------------------------------------------
# # Other combinations... lists of vectors, etc
# # ----------------------------------------------------------------------------


# # create m series, 1 for each item in y (assumes vectors of something other than numbers... functions? vectors?)
# function createKWargsList(plt::PlottingObject, y::AVec; kw...)
#   m = length(y)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = 1:length(y[i])
#     d[:y] = y[i]
#     push!(ret, d)
#   end
#   ret
# end

# function getyvec(x::AVec, y::AVec)
#   @assert length(x) == length(y)
#   y
# end
# getyvec(x::AVec, f::Function) = map(f, x)
# getyvec(x, y) = error("Couldn't create yvec from types: x ($(typeof(x))), y ($(typeof(y)))")

# # same, but given an x to use for all series
# function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec{T}, y::AVec; kw...)
#   m = length(y)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x
#     d[:y] = getyvec(x, y[i])
#     push!(ret, d)
#   end
#   ret
# end

# # x is vec of vec, but y is a matrix
# function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec, y::AMat{T}; kw...)
#   n,m = size(y)
#   @assert length(x) == m
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x[i]
#     d[:y] = getyvec(x[i], y[:,i])
#     push!(ret, d)
#   end
#   ret
# end

# # same, but m series of (x[i],y[i])
# function createKWargsList(plt::PlottingObject, x::AVec, y::AVec; kw...)
#   @assert length(x) == length(y)
#   m = length(y)
#   ret = []
#   for i in 1:m
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = x[i]
#     d[:y] = getyvec(x[i], y[i])
#     push!(ret, d)
#   end
#   ret
# end

# # n empty series
# function createKWargsList(plt::PlottingObject, n::Integer; kw...)
#   ret = []
#   for i in 1:n
#     d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+i), kw, i, plt.n + i)
#     d[:x] = zeros(0)
#     d[:y] = zeros(0)
#     push!(ret, d)
#   end
#   ret
# end

# # vector of tuples... to be used for things like OHLC
# createKWargsList{T<:Tuple}(plt::PlottingObject, y::AVec{T}; kw...) = createKWargsList(plt, 1:length(y), y; kw...)

# function createKWargsList{S<:Real, T<:Tuple}(plt::PlottingObject, x::AVec{S}, y::AVec{T}; kw...)
#   d = getSeriesArgs(plt.plotter, getinitargs(plt, plt.n+1), kw, 1, plt.n + 1)
#   d[:x] = x
#   d[:y] = y
#   [d]
# end


# TODO: handle DataFrames (might have NAs!)

# -------------------------

