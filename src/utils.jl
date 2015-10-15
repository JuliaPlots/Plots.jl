
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

get_mod(v, idx::Int) = v[mod1(idx, length(v))]

makevec(v::AVec) = v
makevec{T}(v::T) = T[v]

"duplicate a single value, or pass the 2-tuple through"
maketuple(x::Real) = (x,x)
maketuple{T,S}(x::@compat(Tuple{T,S})) = x


unzip{T,S}(v::AVec{@compat(Tuple{T,S})}) = [vi[1] for vi in v], [vi[2] for vi in v]

# given 2-element lims and a vector of data x, widen lims to account for the extrema of x
function expandLimits!(lims, x)
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


function replaceAliases!(d::Dict, aliases::Dict)
  for (k,v) in d
    if haskey(aliases, k)
      d[aliases[k]] = v
      delete!(d, k)
    end
  end
end


sortedkeys(d::Dict) = sort(collect(keys(d)))


function regressionXY(x, y)
  # regress
  β, α = [x ones(length(x))] \ y

  # make a line segment
  regx = [minimum(x), maximum(x)]
  regy = β * regx + α
  regx, regy
end

# ticksType{T<:Real,S<:Real}(ticks::@compat(Tuple{T,S})) = :limits
ticksType{T<:Real}(ticks::AVec{T}) = :ticks
ticksType{T<:AVec,S<:AVec}(ticks::@compat(Tuple{T,S})) = :ticks_and_labels
ticksType(ticks) = :invalid

limsType{T<:Real,S<:Real}(lims::@compat(Tuple{T,S})) = :limits
limsType(lims::Symbol) = lims == :auto ? :auto : :invalid
limsType(lims) = :invalid



# ---------------------------------------------------------------

type DebugMode
  on::Bool
end
const _debugMode = DebugMode(false)

function debugplots(on = true)
  _debugMode.on = on
end

function dumpdict(d::Dict, prefix = "")
  _debugMode.on || return
  println()
  if prefix != ""
    println(prefix, ":")
  end
  for k in sort(collect(keys(d)))
    @printf("%14s: ", k)
    println(d[k])
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
  if !isa(xdata, UnitRange)
    error("Expected x is a UnitRange since you're trying to push a y value only")
  end
  plt[i] = (extendUnitRange(xdata), extendSeriesData(ydata, y))
  plt
end


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
  plt[i] = (extendUnitRange(xdata, length(y)), extendSeriesData(ydata, y))
  plt
end


# used in updating an existing series

extendUnitRange(v::UnitRange{Int}, n::Int = 1) = minimum(v):maximum(v)+n
extendSeriesData(v::AVec, z) = (push!(v, z); v)
extendSeriesData(v::AVec, z::AVec) = (append!(v, z); v)


# ---------------------------------------------------------------

function supportGraph(allvals, func)
  vals = reverse(sort(allvals))
  bs = sort(backends())
  x = ASCIIString[]
  y = ASCIIString[]
  for val in vals
    for b in bs
        supported = func(Plots.backendInstance(b))
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
    png(IMG_DIR * "/supported/$(string(func))")
  end
end

# ---------------------------------------------------------------


# Some conversion functions
# note: I borrowed these conversion constants from Compose.jl's Measure
const INCH_SCALAR = 25.4
const PX_SCALAR = 1 / 3.78 
inch2px(inches::Real) = float(inches * INCH_SCALAR / PX_SCALAR)
px2inch(px::Real) = float(px * PX_SCALAR / INCH_SCALAR)
inch2mm(inches::Real) = float(inches * INCH_SCALAR)
mm2inch(mm::Real) = float(mm / INCH_SCALAR)
px2mm(px::Real) = float(px * PX_SCALAR)
mm2px(mm::Real) = float(px / PX_SCALAR)

