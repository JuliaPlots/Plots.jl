
type CurrentPlot
  nullableplot::Nullable{PlottingObject}
end
const CURRENT_PLOT = CurrentPlot(Nullable{PlottingObject}())

isplotnull() = isnull(CURRENT_PLOT.nullableplot)

function current()
  if isplotnull()
    error("No current plot/subplot")
  end
  get(CURRENT_PLOT.nullableplot)
end
current(plot::PlottingObject) = (CURRENT_PLOT.nullableplot = Nullable(plot))

# ---------------------------------------------------------


Base.string(plt::Plot) = "Plot{$(plt.backend) n=$(plt.n)}"
Base.print(io::IO, plt::Plot) = print(io, string(plt))
Base.show(io::IO, plt::Plot) = print(io, string(plt))

getplot(plt::Plot) = plt
getplotargs(plt::Plot, idx::Int = 1) = plt.plotargs
convertSeriesIndex(plt::Plot, n::Int) = n

# ---------------------------------------------------------


"""
The main plot command.  Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
  plot(args...; kw...)                  # creates a new plot window, and sets it to be the current
  plot!(args...; kw...)                 # adds to the `current`
  plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

There are lots of ways to pass in data, and lots of keyword arguments... just try it and it will likely work as expected.
When you pass in matrices, it splits by columns.  See the documentation for more info.
"""

# this creates a new plot with args/kw and sets it to be the current plot
function plot(args...; kw...)
  pkg = backend()
  d = Dict(kw)
  preprocessArgs!(d)
  dumpdict(d, "After plot preprocessing")

  plotargs = merge(d, getPlotArgs(pkg, d, 1))
  dumpdict(plotargs, "Plot args")
  plt = _create_plot(pkg; plotargs...)  # create a new, blank plot

  delete!(d, :background_color)
  plot!(plt, args...; d...)  # add to it
end



# this adds to the current plot, or creates a new plot if none are current
function  plot!(args...; kw...)
  local plt
  try
    plt = current()
  catch
    return plot(args...; kw...)
  end
  plot!(current(), args...; kw...)
end

# not allowed:
function plot!(subplt::Subplot, args...; kw...)
  error("Can't call plot! on a Subplot!")
end

# this adds to a specific plot... most plot commands will flow through here
function plot!(plt::Plot, args...; kw...)
  d = Dict(kw)
  preprocessArgs!(d)

  # for plotting recipes, swap out the args and update the parameter dictionary
  args = _apply_recipe(d, args...; kw...)

  dumpdict(d, "After plot! preprocessing")

  warnOnUnsupportedArgs(plt.backend, d)

  # grouping
  groupargs = get(d, :group, nothing) == nothing ? [] : [extractGroupArgs(d[:group], args...)]

  # just in case the backend needs to set up the plot (make it current or something)
  _before_add_series(plt)

  # get the list of dictionaries, one per series
  seriesArgList, xmeta, ymeta = createKWargsList(plt, groupargs..., args...; d...)

  # if we were able to extract guide information from the series inputs, then update the plot
  # @show xmeta, ymeta
  updateDictWithMeta(d, plt.plotargs, xmeta, true)
  updateDictWithMeta(d, plt.plotargs, ymeta, false)

  # now we can plot the series
  for (i,di) in enumerate(seriesArgList)
    plt.n += 1

    if !stringsSupported()
      setTicksFromStringVector(d, di, :x, :xticks)
      setTicksFromStringVector(d, di, :y, :yticks)
    end

    # remove plot args
    for k in keys(_plotDefaults)
      delete!(di, k)
    end

    dumpdict(di, "Series $i")

    _add_series(plt.backend, plt; di...)
  end

  _add_annotations(plt, d)

  warnOnUnsupportedScales(plt.backend, d)


  # add title, axis labels, ticks, etc
  if !haskey(d, :subplot)
    merge!(plt.plotargs, d)
    dumpdict(plt.plotargs, "Updating plot items")
    _update_plot(plt, plt.plotargs)
  end

  _update_plot_pos_size(plt, d)

  current(plt)

  # NOTE: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
  # # do we want to show it?
  if haskey(d, :show) && d[:show]
    gui()
  end

  plt
end

# --------------------------------------------------------------------

# if x or y are a vector of strings, we should create a list of unique strings,
# and map x/y to be the index of the string... then set the x/y tick labels
function setTicksFromStringVector(d::Dict, di::Dict, sym::Symbol, ticksym::Symbol)
  # if the x or y values are strings, set ticks to the unique values, and x/y to the indices of the ticks

  v = di[sym]
  isa(v, AbstractArray) || return

  T = eltype(v)
  if T <: @compat(AbstractString) || (!isempty(T.types) && all(x -> x <: @compat(AbstractString), T.types))

    ticks = unique(di[sym])
    di[sym] = Int[findnext(ticks, v, 1) for v in di[sym]]

    if !haskey(d, ticksym) || d[ticksym] == :auto
      d[ticksym] = (collect(1:length(ticks)), UTF8String[t for t in ticks])
    end
  end
end

# --------------------------------------------------------------------

_before_add_series(plt::Plot) = nothing

# --------------------------------------------------------------------

# should we update the x/y label given the meta info during input slicing?
function updateDictWithMeta(d::Dict, plotargs::Dict, meta::Symbol, isx::Bool)
  lsym = isx ? :xlabel : :ylabel
  if plotargs[lsym] == default(lsym)
    d[lsym] = string(meta)
  end
end
updateDictWithMeta(d::Dict, plotargs::Dict, meta, isx::Bool) = nothing

# --------------------------------------------------------------------

annotations(::@compat(Void)) = []
annotations{X,Y,V}(v::AVec{@compat(Tuple{X,Y,V})}) = v
annotations{X,Y,V}(t::@compat(Tuple{X,Y,V})) = [t]
annotations(anns) = error("Expecting a tuple (or vector of tuples) for annotations: ",
                       "(x, y, annotation)\n    got: $(typeof(anns))")

function _add_annotations(plt::Plot, d::Dict)
  anns = annotations(get(d, :annotation, nothing))
  if !isempty(anns)
    _add_annotations(plt, anns)
  end
end


# --------------------------------------------------------------------

function Base.copy(plt::Plot)
  backend(plt.backend)
  plt2 = plot(; plt.plotargs...)
  for sargs in plt.seriesargs
    sargs = filter((k,v) -> haskey(_seriesDefaults,k), sargs)
    plot!(plt2; sargs...)
  end
  plt2
end

# --------------------------------------------------------------------

# create a new "createKWargsList" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

typealias FuncOrFuncs @compat(Union{Function, AVec{Function}})

# missing
convertToAnyVector(v::@compat(Void); kw...) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer; kw...) = Any[zeros(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector{T<:Real}(v::AVec{T}; kw...) = Any[v], nothing

# string vector
convertToAnyVector{T<:@compat(AbstractString)}(v::AVec{T}; kw...) = Any[v], nothing

# numeric matrix
convertToAnyVector{T<:Real}(v::AMat{T}; kw...) = Any[v[:,i] for i in 1:size(v,2)], nothing

# function
convertToAnyVector(f::Function; kw...) = Any[f], nothing

# surface
convertToAnyVector(s::Surface; kw...) = Any[s], nothing

# vector of OHLC
convertToAnyVector(v::AVec{OHLC}; kw...) = Any[v], nothing

# dates
convertToAnyVector{D<:Union{Date,DateTime}}(dts::AVec{D}; kw...) = Any[dts], nothing

# list of things (maybe other vectors, functions, or something else)
function convertToAnyVector(v::AVec; kw...)
  if all(x -> typeof(x) <: Real, v)
    # all real numbers wrap the whole vector as one item
    Any[convert(Vector{Float64}, v)], nothing
  else
    # something else... treat each element as an item
    Any[vi for vi in v], nothing
  end
end


# --------------------------------------------------------------------

# in computeXandY, we take in any of the possible items, convert into proper x/y vectors, then return.
# this is also where all the "set x to 1:length(y)" happens, and also where we assert on lengths.
computeX(x::@compat(Void), y) = 1:length(y)
computeX(x, y) = copy(x)
computeY(x, y::Function) = map(y, x)
computeY(x, y) = copy(y)
function computeXandY(x, y)
  if x == nothing && isa(y, Function)
    error("If you want to plot the function `$y`, you need to define the x values somehow!")
  end
  x, y = computeX(x,y), computeY(x,y)
  # @assert length(x) == length(y)
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
  ret = Any[]
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
    dumpdict(d, "before getSeriesArgs")
    d = getSeriesArgs(plt.backend, getplotargs(plt, n), d, i + numUncounted, convertSeriesIndex(plt, n), n)
    dumpdict(d, "after getSeriesArgs")
    d[:x], d[:y] = computeXandY(xs[mod1(i,mx)], ys[mod1(i,my)])

    if haskey(d, :idxfilter)
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

    # cleanup those fields that were used only for generating kw args
    for k in (:idxfilter, :numUncounted, :dataframe)
      delete!(d, k)
    end

    # add it to our series list
    push!(ret, d)
  end

  ret, xmeta, ymeta
end

# handle grouping
function createKWargsList(plt::PlottingObject, groupby::GroupBy, args...; kw...)
  ret = Any[]
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

# 3d line or scatter
function createKWargsList(plt::PlottingObject, x::AVec, y::AVec, zvec::AVec; kw...)
  d = Dict(kw)
  if !(get(d, :linetype, :none) in _3dTypes)
    d[:linetype] = :path3d
  end
  createKWargsList(plt, x, y; z=zvec, d...)
end

# contours or surfaces... function grid
function createKWargsList(plt::PlottingObject, x::AVec, y::AVec, zf::Function; kw...)
  # only allow sorted x/y for now
  # TODO: auto sort x/y/z properly
  @assert x == sort(x)
  @assert y == sort(y)
  surface = Float64[zf(xi, yi) for xi in x, yi in y]
  createKWargsList(plt, x, y, surface; kw...)  # passes it to the zmat version
end

# contours or surfaces... matrix grid
function createKWargsList{T<:Real}(plt::PlottingObject, x::AVec, y::AVec, zmat::AMat{T}; kw...)
  # only allow sorted x/y for now
  # TODO: auto sort x/y/z properly
  @assert x == sort(x)
  @assert y == sort(y)
  @assert size(zmat) == (length(x), length(y))
  # surf = Surface(convert(Matrix{Float64}, zmat))
  # surf = Array(Any,1,1)
  # surf[1,1] = convert(Matrix{Float64}, zmat)
  d = Dict(kw)
  d[:z] = Surface(convert(Matrix{Float64}, zmat))
  if !(get(d, :linetype, :none) in (:contour, :surface, :wireframe))
    d[:linetype] = :contour
  end
  createKWargsList(plt, x, y; d...) #, z = surf)
end

# contours or surfaces... general x, y grid
function createKWargsList{T<:Real}(plt::PlottingObject, x::AMat{T}, y::AMat{T}, zmat::AMat{T}; kw...)
  @assert size(zmat) == size(x) == size(y)
  surf = Surface(convert(Matrix{Float64}, zmat))
  # surf = Array(Any,1,1)
  # surf[1,1] = convert(Matrix{Float64}, zmat)
  d = Dict(kw)
  d[:z] = Surface(convert(Matrix{Float64}, zmat))
  if !(get(d, :linetype, :none) in (:contour, :surface, :wireframe))
    d[:linetype] = :contour
  end
  createKWargsList(plt, Any[x], Any[y]; d...) #kw..., z = surf, linetype = :contour)
end


function createKWargsList(plt::PlottingObject, surf::Surface; kw...)
  createKWargsList(plt, 1:size(surf.surf,1), 1:size(surf.surf,2), convert(Matrix{Float64}, surf.surf); kw...)
end

function createKWargsList(plt::PlottingObject, x::AVec, y::AVec, surf::Surface; kw...)
  createKWargsList(plt, x, y, convert(Matrix{Float64}, surf.surf); kw...)
end

function createKWargsList(plt::PlottingObject, f::FuncOrFuncs; kw...)
  createKWargsList(plt, f, xmin(plt), xmax(plt); kw...)
end

# list of functions
function createKWargsList(plt::PlottingObject, f::FuncOrFuncs, x; kw...)
  @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
  createKWargsList(plt, x, f; kw...)
end

# special handling... xmin/xmax with function(s)
function createKWargsList(plt::PlottingObject, f::FuncOrFuncs, xmin::Real, xmax::Real; kw...)
  width = get(plt.plotargs, :size, (100,))[1]
  x = collect(linspace(xmin, xmax, width))  # we don't need more than the width
  createKWargsList(plt, x, f; kw...)
end

mapFuncOrFuncs(f::Function, u::AVec) = map(f, u)
mapFuncOrFuncs(fs::AVec{Function}, u::AVec) = [map(f, u) for f in fs]

# special handling... xmin/xmax with parametric function(s)
createKWargsList{T<:Real}(plt::PlottingObject, fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec{T}; kw...) = createKWargsList(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u); kw...)
createKWargsList{T<:Real}(plt::PlottingObject, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs; kw...) = createKWargsList(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u); kw...)
createKWargsList(plt::PlottingObject, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Real, umax::Real, numPoints::Int = 1000; kw...) = createKWargsList(plt, fx, fy, linspace(umin, umax, numPoints); kw...)

# (x,y) tuples
function createKWargsList{R1<:Real,R2<:Real}(plt::PlottingObject, xy::AVec{Tuple{R1,R2}}; kw...)
  createKWargsList(plt, unzip(xy)...; kw...)
end
function createKWargsList{R1<:Real,R2<:Real}(plt::PlottingObject, xy::Tuple{R1,R2}; kw...)
  createKWargsList(plt, [xy[1]], [xy[2]]; kw...)
end

@require FixedSizeArrays begin
  unzip{T}(x::AVec{FixedSizeArrays.Vec{2,T}}) = T[xi[1] for xi in x], T[xi[2] for xi in x]
  unzip{T}(x::FixedSizeArrays.Vec{2,T}) = T[x[1]], T[x[2]]

  function createKWargsList{T<:Real}(plt::PlottingObject, xy::AVec{FixedSizeArrays.Vec{2,T}}; kw...)
    createKWargsList(plt, unzip(xy)...; kw...)
  end
  function createKWargsList{T<:Real}(plt::PlottingObject, xy::FixedSizeArrays.Vec{2,T}; kw...)
    createKWargsList(plt, [xy[1]], [xy[2]]; kw...)
  end
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
function dataframes()
  @eval import DataFrames

  @eval function createKWargsList(plt::PlottingObject, df::DataFrames.AbstractDataFrame, args...; kw...)
    createKWargsList(plt, args...; kw..., dataframe = df)
  end

  # expecting the column name of a dataframe that was passed in... anything else should error
  @eval function extractGroupArgs(s::Symbol, df::DataFrames.AbstractDataFrame, args...)
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
