
calcMidpoints(edges::AbstractVector) = Float64[0.5 * (edges[i] + edges[i+1]) for i in 1:length(edges)-1]

"Make histogram-like bins of data"
function binData(data, nbins)
  lo, hi = extrema(data)
  edges = collect(linspace(lo, hi, nbins+1))
  midpoints = calcMidpoints(edges)
  buckets = Int[max(2, min(searchsortedfirst(edges, x), length(edges)))-1 for x in data]
  counts = zeros(Int, length(midpoints))
  for b in buckets
    counts[b] += 1
  end
  edges, midpoints, buckets, counts
end

"""
A hacky replacement for a histogram when the backend doesn't support histograms directly.
Convert it into a bar chart with the appropriate x/y values.
"""
function histogramHack(; kw...)
  d = Dict(kw)

  # we assume that the y kwarg is set with the data to be binned, and nbins is also defined
  edges, midpoints, buckets, counts = binData(d[:y], d[:nbins])
  d[:x] = midpoints
  d[:y] = float(counts)
  d[:linetype] = :bar
  d[:fillrange] = d[:fillrange] == nothing ? 0.0 : d[:fillrange]
  d
end

"""
A hacky replacement for a bar graph when the backend doesn't support bars directly.
Convert it into a line chart with fillrange set.
"""
function barHack(; kw...)
  d = Dict(kw)
  midpoints = d[:x]
  heights = d[:y]
  fillrange = d[:fillrange] == nothing ? 0.0 : d[:fillrange]

  # estimate the edges
  dists = diff(midpoints) * 0.5
  edges = zeros(length(midpoints)+1)
  for i in 1:length(edges)
    if i == 1
      edge = midpoints[1] - dists[1]
    elseif i == length(edges)
      edge = midpoints[i-1] + dists[i-2]
    else
      edge = midpoints[i-1] + dists[i-1]
    end
    edges[i] = edge
  end

  x = Float64[]
  y = Float64[]
  for i in 1:length(heights)
    e1, e2 = edges[i:i+1]
    append!(x, [e1, e1, e2, e2])
    append!(y, [fillrange, heights[i], heights[i], fillrange])
  end

  d[:x] = x
  d[:y] = y
  d[:linetype] = :path
  d[:fillrange] = fillrange
  d
end


"""
A hacky replacement for a sticks graph when the backend doesn't support sticks directly.
Convert it into a line chart that traces the sticks, and a scatter that sets markers at the points.
"""
function sticksHack(; kw...)
  dLine = Dict(kw)
  dScatter = copy(dLine)

  # these are the line vertices
  x = Float64[]
  y = Float64[]
  fillrange = dLine[:fillrange] == nothing ? 0.0 : dLine[:fillrange]

  # calculate the vertices
  yScatter = dScatter[:y]
  for (i,xi) in enumerate(dScatter[:x])
    yi = yScatter[i]
    for j in 1:3 push!(x, xi) end
    append!(y, [fillrange, yScatter[i], fillrange])
  end

  # change the line args
  dLine[:x] = x
  dLine[:y] = y
  dLine[:linetype] = :path
  dLine[:markershape] = :none
  dLine[:fillrange] = nothing

  # change the scatter args
  dScatter[:linetype] = :none

  dLine, dScatter
end

function regressionXY(x, y)
  # regress
  β, α = convert(Matrix{Float64}, [x ones(length(x))]) \ convert(Vector{Float64}, y)

  # make a line segment
  regx = [minimum(x), maximum(x)]
  regy = β * regx + α
  regx, regy
end

# ------------------------------------------------------------------------------------


nop() = nothing

get_mod(v::AVec, idx::Int) = v[mod1(idx, length(v))]
get_mod(v::AMat, idx::Int) = size(v,1) == 1 ? v[1, mod1(idx, size(v,2))] : v[:, mod1(idx, size(v,2))]
get_mod(v, idx::Int) = v

makevec(v::AVec) = v
makevec{T}(v::T) = T[v]

"duplicate a single value, or pass the 2-tuple through"
maketuple(x::Real) = (x,x)
maketuple{T,S}(x::@compat(Tuple{T,S})) = x


unzip{T,S}(v::AVec{@compat(Tuple{T,S})}) = [vi[1] for vi in v], [vi[2] for vi in v]

# given 2-element lims and a vector of data x, widen lims to account for the extrema of x
function _expand_limits(lims, x)
  try
    e1, e2 = extrema(x)
    lims[1] = min(lims[1], e1)
    lims[2] = max(lims[2], e2)
  # catch err
  #   warn(err)
  end
  nothing
end


# if the type exists in a list, replace the first occurence.  otherwise add it to the end
function addOrReplace(v::AbstractVector, t::DataType, args...; kw...)
    for (i,vi) in enumerate(v)
        if isa(vi, t)
            v[i] = t(args...; kw...)
            return
        end
    end
    push!(v, t(args...; kw...))
    return
end

function replaceType(vec, val)
  filter!(x -> !isa(x, typeof(val)), vec)
  push!(vec, val)
end

function replaceAliases!(d::Dict, aliases::Dict)
  ks = collect(keys(d))
  for k in ks
    if haskey(aliases, k)
      d[aliases[k]] = d[k]
      delete!(d, k)
    end
  end
end

createSegments(z) = collect(repmat(z',2,1))[2:end]

Base.first(c::Colorant) = c
Base.first(x::Symbol) = x


sortedkeys(d::Dict) = sort(collect(keys(d)))

"create an (n+1) list of the outsides of heatmap rectangles"
function heatmap_edges(v::AVec)
  vmin, vmax = extrema(v)
  extra = 0.5 * (vmax-vmin) / (length(v)-1)
  vcat(vmin-extra, 0.5 * (v[1:end-1] + v[2:end]), vmax+extra)
end


function fakedata(sz...)
  y = zeros(sz...)
  for r in 2:size(y,1)
    y[r,:] = 0.95 * y[r-1,:] + randn(size(y,2))'
  end
  y
end

isijulia() = isdefined(Main, :IJulia) && Main.IJulia.inited
isatom() = isdefined(Main, :Atom) && Atom.isconnected()

istuple(::Tuple) = true
istuple(::Any) = false
isvector(::AVec) = true
isvector(::Any) = false
ismatrix(::AMat) = true
ismatrix(::Any) = false
isscalar(::Real) = true
isscalar(::Any) = false




# ticksType{T<:Real,S<:Real}(ticks::@compat(Tuple{T,S})) = :limits
ticksType{T<:Real}(ticks::AVec{T}) = :ticks
ticksType{T<:AbstractString}(ticks::AVec{T}) = :labels
ticksType{T<:AVec,S<:AVec}(ticks::@compat(Tuple{T,S})) = :ticks_and_labels
ticksType(ticks) = :invalid

limsType{T<:Real,S<:Real}(lims::@compat(Tuple{T,S})) = :limits
limsType(lims::Symbol) = lims == :auto ? :auto : :invalid
limsType(lims) = :invalid


Base.convert{T<:Real}(::Type{Vector{T}}, rng::Range{T}) = T[x for x in rng]
Base.convert{T<:Real,S<:Real}(::Type{Vector{T}}, rng::Range{S}) = T[x for x in rng]

Base.merge(a::AbstractVector, b::AbstractVector) = sort(unique(vcat(a,b)))

# ---------------------------------------------------------------

wraptuple(x::@compat(Tuple)) = x
wraptuple(x) = (x,)

trueOrAllTrue(f::Function, x::AbstractArray) = all(f, x)
trueOrAllTrue(f::Function, x) = f(x)

allLineTypes(arg) = trueOrAllTrue(a -> get(_typeAliases, a, a) in _allTypes, arg)
allStyles(arg) = trueOrAllTrue(a -> get(_styleAliases, a, a) in _allStyles, arg)
allShapes(arg) = trueOrAllTrue(a -> get(_markerAliases, a, a) in _allMarkers, arg) ||
                  trueOrAllTrue(a -> isa(a, Shape), arg)
allAlphas(arg) = trueOrAllTrue(a -> (typeof(a) <: Real && a > 0 && a < 1) ||
                                    (typeof(a) <: AbstractFloat && (a == zero(typeof(a)) || a == one(typeof(a)))), arg)
allReals(arg)   = trueOrAllTrue(a -> typeof(a) <: Real, arg)
allFunctions(arg) = trueOrAllTrue(a -> isa(a, Function), arg)

# ---------------------------------------------------------------


"""
Allows temporary setting of backend and defaults for Plots. Settings apply only for the `do` block.  Example:
```
with(:gadfly, size=(400,400), type=:hist) do
  plot(rand(10))
  plot(rand(10))
end
```
"""
function with(f::Function, args...; kw...)

  # dict to store old and new keyword args for anything that changes
  newdefs = Dict(kw)
  olddefs = Dict()
  for k in keys(newdefs)
    olddefs[k] = default(k)
  end

  # save the backend
  if CURRENT_BACKEND.sym == :none
    pickDefaultBackend()
  end
  oldbackend = CURRENT_BACKEND.sym

  for arg in args

    # change backend?
    if arg in backends()
      backend(arg)
    end

    # # TODO: generalize this strategy to allow args as much as possible
    # #       as in:  with(:gadfly, :scatter, :legend, :grid) do; ...; end
    # # TODO: can we generalize this enough to also do something similar in the plot commands??

    # k = :linetype
    # if arg in _allTypes
    #   olddefs[k] = default(k)
    #   newdefs[k] = arg
    # elseif haskey(_typeAliases, arg)
    #   olddefs[k] = default(k)
    #   newdefs[k] = _typeAliases[arg]
    # end

    k = :legend
    if arg in (k, :leg)
      olddefs[k] = default(k)
      newdefs[k] = true
    end

    k = :grid
    if arg == k
      olddefs[k] = default(k)
      newdefs[k] = true
    end
  end

  # display(olddefs)
  # display(newdefs)

  # now set all those defaults
  default(; newdefs...)

  # call the function
  ret = f()

  # put the defaults back
  default(; olddefs...)

  # revert the backend
  if CURRENT_BACKEND.sym != oldbackend
    backend(oldbackend)
  end

  # return the result of the function
  ret
end

# ---------------------------------------------------------------

type DebugMode
  on::Bool
end
const _debugMode = DebugMode(false)

function debugplots(on = true)
  _debugMode.on = on
end

debugshow(x) = show(x)
debugshow(x::AbstractArray) = print(summary(x))

function dumpdict(d::Dict, prefix = "", alwaysshow = false)
  _debugMode.on || alwaysshow || return
  println()
  if prefix != ""
    println(prefix, ":")
  end
  for k in sort(collect(keys(d)))
    @printf("%14s: ", k)
    debugshow(d[k])
    println()
  end
  println()
end


function dumpcallstack()
  error()  # well... you wanted the stacktrace, didn't you?!?
end

# ---------------------------------------------------------------


# push/append/clear/set the underlying plot data
# NOTE: backends should implement the getindex and setindex! methods to get/set the x/y data objects


# index versions
function Base.push!(plt::Plot, i::Integer, x::Real, y::Real)
  xdata, ydata = plt[i]
  plt[i] = (extendSeriesData(xdata, x), extendSeriesData(ydata, y))
  plt
end
function Base.push!(plt::Plot, i::Integer, y::Real)
  xdata, ydata = plt[i]
  # if !isa(xdata, UnitRange)
  #   error("Expected x is a UnitRange since you're trying to push a y value only. typeof(x) = $(typeof(xdata))")
  # end
  plt[i] = (extendSeriesByOne(xdata), extendSeriesData(ydata, y))
  plt
end

Base.push!(plt::Plot, y::Real) = push!(plt, 1, y)

# update all at once
function Base.push!(plt::Plot, x::AVec, y::AVec)
  nx = length(x)
  ny = length(y)
  for i in 1:plt.n
    push!(plt, i, x[mod1(i,nx)], y[mod1(i,ny)])
  end
  plt
end

function Base.push!(plt::Plot, x::Real, y::AVec)
  push!(plt, [x], y)
end

function Base.push!(plt::Plot, y::AVec)
  ny = length(y)
  for i in 1:plt.n
    push!(plt, i, y[mod1(i,ny)])
  end
  plt
end


# append to index
function Base.append!(plt::Plot, i::Integer, x::AVec, y::AVec)
  @assert length(x) == length(y)
  xdata, ydata = plt[i]
  plt[i] = (extendSeriesData(xdata, x), extendSeriesData(ydata, y))
  plt
end

function Base.append!(plt::Plot, i::Integer, y::AVec)
  xdata, ydata = plt[i]
  if !isa(xdata, UnitRange{Int})
    error("Expected x is a UnitRange since you're trying to push a y value only")
  end
  plt[i] = (extendSeriesByOne(xdata, length(y)), extendSeriesData(ydata, y))
  plt
end


# used in updating an existing series

extendSeriesByOne(v::UnitRange{Int}, n::Int = 1) = isempty(v) ? (1:n) : (minimum(v):maximum(v)+n)
extendSeriesByOne(v::AVec, n::Integer = 1) = isempty(v) ? (1:n) : vcat(v, (1:n) + maximum(v))
extendSeriesData{T}(v::Range{T}, z::Real) = extendSeriesData(float(collect(v)), z)
extendSeriesData{T}(v::Range{T}, z::AVec) = extendSeriesData(float(collect(v)), z)
extendSeriesData{T}(v::AVec{T}, z::Real) = (push!(v, convert(T, z)); v)
extendSeriesData{T}(v::AVec{T}, z::AVec) = (append!(v, convert(Vector{T}, z)); v)


# ---------------------------------------------------------------

function supportGraph(allvals, func)
  vals = reverse(sort(allvals))
  bs = sort(backends())
  x = ASCIIString[]
  y = ASCIIString[]
  for val in vals
    for b in bs
        supported = func(Plots._backend_instance(b))
        if val in supported
            push!(x, string(b))
            push!(y, string(val))
        end
      end
  end
  n = length(vals)

  scatter(x,y,
          m=:rect,
          ms=10,
          size=(300,100+18*n),
          # xticks=(collect(1:length(bs)), bs),
          leg=false
         )
end

supportGraphArgs() = supportGraph(_allArgs, supportedArgs)
supportGraphTypes() = supportGraph(_allTypes, supportedTypes)
supportGraphStyles() = supportGraph(_allStyles, supportedStyles)
supportGraphMarkers() = supportGraph(_allMarkers, supportedMarkers)
supportGraphScales() = supportGraph(_allScales, supportedScales)
supportGraphAxes() = supportGraph(_allAxes, supportedAxes)

function dumpSupportGraphs()
  for func in (supportGraphArgs, supportGraphTypes, supportGraphStyles,
               supportGraphMarkers, supportGraphScales, supportGraphAxes)
    plt = func()
    png(joinpath(Pkg.dir("ExamplePlots"), "docs", "examples", "img", "supported", "$(string(func))"))
  end
end

# ---------------------------------------------------------------


# Some conversion functions
# note: I borrowed these conversion constants from Compose.jl's Measure
const PX_PER_INCH = 100
const DPI = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX = MM_PER_INCH / PX_PER_INCH
inch2px(inches::Real) = float(inches * PX_PER_INCH)
px2inch(px::Real) = float(px / PX_PER_INCH)
inch2mm(inches::Real) = float(inches * MM_PER_INCH)
mm2inch(mm::Real) = float(mm / MM_PER_INCH)
px2mm(px::Real) = float(px * MM_PER_PX)
mm2px(mm::Real) = float(px / MM_PER_PX)


"Smallest x in plot"
xmin(plt::Plot) = minimum([minimum(d[:x]) for d in plt.seriesargs])
"Largest x in plot"
xmax(plt::Plot) = maximum([maximum(d[:x]) for d in plt.seriesargs])

"Extrema of x-values in plot"
Base.extrema(plt::Plot) = (xmin(plt), xmax(plt))
