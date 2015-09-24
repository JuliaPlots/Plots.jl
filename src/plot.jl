
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

  warnOnUnsupportedArgs(plt.plotter, d)

  # TODO: handle a "group by" mechanism.
  # will probably want to check for the :group kw param, and split into
  # index partitions/filters to be passed through to the next step.
  # Ideally we don't change the insides ot createKWargsList too much to 
  # save from code repetition.  We could consider adding a throw
  groupargs = haskey(d, :group) ? [extractGroupArgs(d[:group], args...)] : []
  # @show groupargs

  # just in case the backend needs to set up the plot (make it current or something)
  preparePlotUpdate(plt)

  # get the list of dictionaries, one per series
  kwList, xmeta, ymeta = createKWargsList(plt, groupargs..., args...; d...)
  # @show xmeta ymeta typeof(xmeta) typeof(ymeta)

  # if we were able to extract guide information from the series inputs, then update the plot
  updateDictWithMeta(d, plt.initargs, xmeta, true)
  updateDictWithMeta(d, plt.initargs, ymeta, false)

  # now we can plot the series
  for (i,di) in enumerate(kwList)
    plt.n += 1
    # println("Plotting: ", di)
    plot!(plt.plotter, plt; di...)
  end

  # add title, axis labels, ticks, etc
  updatePlotItems(plt, d)
  currentPlot!(plt)

  # NOTE: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
  # # do we want to show it?
  if haskey(d, :show) && d[:show]
    gui()
  end

  plt
end

preparePlotUpdate(plt::Plot) = nothing


# should we update the x/y label given the meta info during input slicing?
function updateDictWithMeta(d::Dict, initargs::Dict, meta::Symbol, isx::Bool)
  lsym = isx ? :xlabel : :ylabel
  if initargs[lsym] == plotDefault(lsym)
    d[lsym] = string(meta)
  end
end
updateDictWithMeta(d::Dict, initargs::Dict, meta, isx::Bool) = nothing


# --------------------------------------------------------------------


# create a new "createKWargsList" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

typealias FuncOrFuncs Union{Function, AVec{Function}}

# missing
convertToAnyVector(v::Void; kw...) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer; kw...) = Any[zero(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector{T<:Real}(v::AVec{T}; kw...) = Any[v], nothing

# numeric matrix
convertToAnyVector{T<:Real}(v::AMat{T}; kw...) = Any[v[:,i] for i in 1:size(v,2)], nothing

# function
convertToAnyVector(f::Function; kw...) = Any[f], nothing

# vector of OHLC
convertToAnyVector(v::AVec{OHLC}; kw...) = Any[v], nothing

# list of things (maybe other vectors, functions, or something else)
convertToAnyVector(v::AVec; kw...) = Any[vi for vi in v], nothing


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
  xs, xmeta = convertToAnyVector(x; kw...)
  ys, ymeta = convertToAnyVector(y; kw...)
  mx = length(xs)
  my = length(ys)
  ret = []
  for i in 1:max(mx, my)

    # try to set labels using ymeta
    d = Dict(kw)
    if !haskey(d, :label) && ymeta != nothing
      if isa(ymeta, Symbol)
        d[:label] = string(ymeta)
      elseif isa(ymeta, AVec{Symbol})
        d[:label] = string(ymeta[mod1(i,length(ymeta))])
      end
    end

    # build the series arg dict
    numUncounted = get(d, :numUncounted, 0)
    n = plt.n + i + numUncounted
    d = getSeriesArgs(plt.plotter, getinitargs(plt, n), d, i + numUncounted, convertSeriesIndex(plt, n), n)
    d[:x], d[:y] = computeXandY(xs[mod1(i,mx)], ys[mod1(i,my)])

    if haskey(d, :idxfilter)
      # @show d[:idxfilter] d[:x] d[:y]
      d[:x] = d[:x][d[:idxfilter]]
      d[:y] = d[:y][d[:idxfilter]]
    end

    # for linetype `line`, need to sort by x values
    if d[:linetype] == :line
      # order by x
      indices = sortperm(d[:x])
      d[:x] = d[:x][indices]
      d[:y] = d[:y][indices]
      d[:linetype] = :path
    end

    # add it to our series list
    push!(ret, d)
  end

  ret, xmeta, ymeta
end

# handle grouping
function createKWargsList(plt::PlottingObject, groupby::GroupBy, args...; kw...)
  ret = []
  for (i,glab) in enumerate(groupby.groupLabels)
    # TODO: don't automatically overwrite labels
    kwlist, xmeta, ymeta = createKWargsList(plt, args...; kw...,
                                            idxfilter = groupby.groupIds[i],
                                            label = string(glab),
                                            numUncounted = length(ret))  # we count the idx from plt.n + numUncounted + i
    append!(ret, kwlist)
  end
  ret, nothing, nothing # TODO: handle passing meta through
end

# pass it off to the x/y version
function createKWargsList(plt::PlottingObject, y; kw...)
  createKWargsList(plt, nothing, y; kw...)
end

function createKWargsList(plt::PlottingObject, f::FuncOrFuncs; kw...)
  error("Can't pass a Function or Vector{Function} for y without also passing x")
end

function createKWargsList(plt::PlottingObject, f::FuncOrFuncs, x; kw...)
  @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
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
    return [], nothing, nothing
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

  # expecting the column name of a dataframe that was passed in... anything else should error
  @eval function extractGroupArgs(s::Symbol, df::DataFrames.DataFrame, args...)
    if haskey(df, s)
      return extractGroupArgs(df[s])
    else
      error("Got a symbol, and expected that to be a key in d[:dataframe]. s=$s d=$d")
    end
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
  @eval convertToAnyVector(s::Symbol; kw...) = Any[getDataFrameFromKW(;kw...)[s]], s
  @eval convertToAnyVector(v::AVec{Symbol}; kw...) = (df = getDataFrameFromKW(;kw...); Any[df[s] for s in v]), v
end


# --------------------------------------------------------------------

