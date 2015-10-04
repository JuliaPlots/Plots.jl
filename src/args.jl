

const _allAxes = [:auto, :left, :right]
const _axesAliases = Dict(
    :a => :auto, 
    :l => :left, 
    :r => :right
  )

const _allTypes = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter,
                   :heatmap, :hexbin, :hist, :bar, :hline, :vline, :ohlc]
const _typeAliases = Dict(
    :n             => :none,
    :no            => :none,
    :l             => :line,
    :p             => :path,
    :stepinv       => :steppre,
    :stepsinv      => :steppre,
    :stepinverted  => :steppre,
    :stepsinverted => :steppre,
    :step          => :steppost,
    :steps         => :steppost,
    :stair         => :steppost,
    :stairs        => :steppost,
    :stem          => :sticks,
    :stems         => :sticks,
    :dots          => :scatter,
    :histogram     => :hist,
  )

const _allStyles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _styleAliases = Dict(
    :a    => :auto,
    :s    => :solid,
    :d    => :dash,
    :dd   => :dashdot,
    :ddd  => :dashdotdot,
  )

const _allMarkers = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle,
                     :cross, :xcross, :star1, :star2, :hexagon, :octagon]
const _markerAliases = Dict(
    :n            => :none,
    :no           => :none,
    :a            => :auto,
    :circle       => :ellipse,
    :c            => :ellipse,
    :square       => :rect,
    :sq           => :rect,
    :r            => :rect,
    :d            => :diamond,
    :^            => :utriangle,
    :ut           => :utriangle,
    :utri         => :utriangle,
    :uptri        => :utriangle,
    :uptriangle   => :utriangle,
    :v            => :dtriangle,
    :V            => :dtriangle,
    :dt           => :dtriangle,
    :dtri         => :dtriangle,
    :downtri      => :dtriangle,
    :downtriangle => :dtriangle,
    :+            => :cross,
    :plus         => :cross,
    :x            => :xcross,
    :X            => :xcross,
    :star         => :star1,
    :s            => :star1,
    :s2           => :star2,
    :h            => :hexagon,
    :hex          => :hexagon,
    :o            => :octagon,
    :oct          => :octagon,
  )

const _allScales = [:identity, :log, :log2, :log10, :asinh, :sqrt]
const _scaleAliases = Dict(
    :none => :identity,
    :ln   => :log,
  )

supportedAxes(::PlottingPackage) = _allAxes
supportedTypes(::PlottingPackage) = _allTypes
supportedStyles(::PlottingPackage) = _allStyles
supportedMarkers(::PlottingPackage) = _allMarkers
supportedScales(::PlottingPackage) = _allScales
subplotSupported(::PlottingPackage) = true

supportedAxes() = supportedAxes(backend())
supportedTypes() = supportedTypes(backend())
supportedStyles() = supportedStyles(backend())
supportedMarkers() = supportedMarkers(backend())
supportedScales() = supportedScales(backend())
subplotSupported() = subplotSupported(backend())

# -----------------------------------------------------------------------------

const _seriesDefaults = Dict{Symbol, Any}()

# series-specific
_seriesDefaults[:axis]        = :left
_seriesDefaults[:color]       = :auto
_seriesDefaults[:label]       = "AUTO"
_seriesDefaults[:width]       = 1
_seriesDefaults[:linetype]    = :path
_seriesDefaults[:linestyle]   = :solid
_seriesDefaults[:marker]      = :none
_seriesDefaults[:markercolor] = :match
_seriesDefaults[:markersize]  = 6
_seriesDefaults[:nbins]       = 100               # number of bins for heatmaps and hists
_seriesDefaults[:heatmap_c]   = (0.15, 0.5)
_seriesDefaults[:fillto]      = nothing          # fills in the area
_seriesDefaults[:reg]         = false               # regression line?
_seriesDefaults[:group]       = nothing
_seriesDefaults[:ribbon]      = nothing
_seriesDefaults[:annotation]  = nothing
_seriesDefaults[:z]           = nothing
# _seriesDefaults[:args]        = []     # additional args to pass to the backend
# _seriesDefaults[:kwargs]      = []   # additional keyword args to pass to the backend
#                               # note: can be Vector{Dict} or Vector{Tuple} 


const _plotDefaults = Dict{Symbol, Any}()

# plot globals
_plotDefaults[:title]             = ""
_plotDefaults[:xlabel]            = ""
_plotDefaults[:ylabel]            = ""
_plotDefaults[:yrightlabel]       = ""
_plotDefaults[:legend]            = true
_plotDefaults[:background_color]  = colorant"white"
_plotDefaults[:foreground_color]  = :auto
_plotDefaults[:xlims]             = :auto
_plotDefaults[:ylims]             = :auto
_plotDefaults[:xticks]            = :auto
_plotDefaults[:yticks]            = :auto
_plotDefaults[:xscale]            = :identity
_plotDefaults[:yscale]            = :identity
_plotDefaults[:size]              = (800,600)
_plotDefaults[:pos]               = (0,0)
_plotDefaults[:windowtitle]       = "Plots.jl"
_plotDefaults[:show]              = false
_plotDefaults[:layout]            = nothing
_plotDefaults[:n]                 = -1
_plotDefaults[:nr]                = -1
_plotDefaults[:nc]                = -1



# TODO: x/y scales

const _allArgs = sort(collect(union(keys(_seriesDefaults), keys(_plotDefaults))))
supportedArgs(::PlottingPackage) = _allArgs
supportedArgs() = supportedArgs(backend())


# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]
autopick(notarr, idx::Integer) = notarr

autopick_ignore_none_auto(arr::AVec, idx::Integer) = autopick(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliasesAndAutopick(d::Dict, sym::Symbol, aliases::Dict, options::AVec, plotIndex::Int)
  if d[sym] == :auto
    d[sym] = autopick_ignore_none_auto(options, plotIndex)
  elseif haskey(aliases, d[sym])
    d[sym] = aliases[d[sym]]
  end
end

function aliases(aliasMap::Dict, val)
  # sort(vcat(val, collect(keys(filter((k,v)-> v==val, aliasMap)))))
  sortedkeys(filter((k,v)-> v==val, aliasMap))
end

# -----------------------------------------------------------------------------

# Alternate args

const _keyAliases = Dict(
    :c            => :color,
    :lab          => :label,
    :w            => :width,
    :linewidth    => :width,
    :type         => :linetype,
    :lt           => :linetype,
    :t            => :linetype,
    :style        => :linestyle,
    :s            => :linestyle,
    :ls           => :linestyle,
    :m            => :marker,
    :shape        => :marker,
    :mc           => :markercolor,
    :mcolor       => :markercolor,
    :ms           => :markersize,
    :msize        => :markersize,
    :nb           => :nbins,
    :nbin         => :nbins,
    :fill         => :fillto,
    :area         => :fillto,
    :g            => :group,
    :rib          => :ribbon,
    :ann          => :annotation,
    :anns         => :annotation,
    :annotate     => :annotation,
    :annotations  => :annotation,
    :xlab         => :xlabel,
    :ylab         => :ylabel,
    :yrlab        => :yrightlabel,
    :ylabr        => :yrightlabel,
    :y2lab        => :yrightlabel,
    :ylab2        => :yrightlabel,
    :ylabelright  => :yrightlabel,
    :ylabel2      => :yrightlabel,
    :y2label      => :yrightlabel,
    :leg          => :legend,
    :bg           => :background_color,
    :bgcolor      => :background_color,
    :bg_color     => :background_color,
    :background   => :background_color,
    :fg           => :foreground_color,
    :fgcolor      => :foreground_color,
    :fg_color     => :foreground_color,
    :foreground   => :foreground_color,
    :regression   => :reg,
    :xlim         => :xlims,
    :xlimit       => :xlims,
    :xlimits      => :xlims,
    :ylim         => :ylims,
    :ylimit       => :ylims,
    :ylimits      => :ylims,
    :xtick        => :xticks,
    :ytick        => :yticks,
    :windowsize   => :size,
    :wsize        => :size,
    :wtitle       => :windowtitle,
    :gui          => :show,
    :display      => :show,
  )

# add all pluralized forms to the _keyAliases dict
for arg in keys(_seriesDefaults)
  _keyAliases[makeplural(arg)] = arg
end



# -----------------------------------------------------------------------------

# update the defaults globally

"""
`default(key)` returns the current default value for that key
`default(key, value)` sets the current default value for that key
`default(; kw...)` will set the current default value for each key/value pair
"""

function default(k::Symbol)
  k = get(_keyAliases, k, k)
  if haskey(_seriesDefaults, k)
    return _seriesDefaults[k]
  elseif haskey(_plotDefaults, k)
    return _plotDefaults[k]
  else
    error("Unknown key: ", k)
  end
end

function default(k::Symbol, v)
  k = get(_keyAliases, k, k)
  if haskey(_seriesDefaults, k)
    _seriesDefaults[k] = v
  elseif haskey(_plotDefaults, k)
    _plotDefaults[k] = v
  else
    error("Unknown key: ", k)
  end
end

function default(; kw...)
  for (k,v) in kw
    default(k, v)
  end
end


# -----------------------------------------------------------------------------

"A special type that will break up incoming data into groups, and allow for easier creation of grouped plots"
type GroupBy
  groupLabels::Vector{UTF8String}   # length == numGroups
  groupIds::Vector{Vector{Int}}     # list of indices for each group
end


# this is when given a vector-type of values to group by
function extractGroupArgs(v::AVec, args...)
  groupLabels = sort(collect(unique(v)))
  n = length(groupLabels)
  if n > 20
    error("Too many group labels. n=$n  Is that intended?")
  end
  groupIds = Vector{Int}[filter(i -> v[i] == glab, 1:length(v)) for glab in groupLabels]
  GroupBy(groupLabels, groupIds)
end


# expecting a mapping of "group label" to "group indices"
function extractGroupArgs{T, V<:AVec{Int}}(idxmap::Dict{T,V}, args...)
  groupLabels = sortedkeys(idxmap)
  groupIds = VecI[collect(idxmap[k]) for k in groupLabels]
  GroupBy(groupLabels, groupIds)
end


# -----------------------------------------------------------------------------

function warnOnUnsupportedArgs(pkg::PlottingPackage, d::Dict)
  for k in sortedkeys(d)
    if !(k in supportedArgs(pkg)) && d[k] != default(k)
      warn("Keyword argument $k not supported with $pkg.  Choose from: $(supportedArgs(pkg))")
    end
  end
end


function warnOnUnsupported(pkg::PlottingPackage, d::Dict)
  d[:axis] in supportedAxes(pkg) || warn("axis $(d[:axis]) is unsupported with $pkg.  Choose from: $(supportedAxes(pkg))")
  d[:linetype] == :none || d[:linetype] in supportedTypes(pkg) || warn("linetype $(d[:linetype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))")
  d[:linestyle] in supportedStyles(pkg) || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))")
  d[:marker] == :none || d[:marker] in supportedMarkers(pkg) || warn("marker $(d[:marker]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))")
end

function warnOnUnsupportedScales(pkg::PlottingPackage, d::Dict)
  for k in (:xscale, :yscale)
    if haskey(d, k)
      d[k] in supportedScales(pkg) || warn("scale $(d[k]) is unsupported with $pkg.  Choose from: $(supportedScales(pkg))")
    end
  end
end


# build the argument dictionary for the plot
function getPlotArgs(pkg::PlottingPackage, kw, idx::Int)
  d = Dict(kw)

  # add defaults?
  for k in keys(_plotDefaults)
    if haskey(d, k)
      v = d[k]
      if isa(v, AbstractVector) && !isempty(v)
        # we got a vector, cycling through
        d[k] = autopick(v, idx)
      end
    else
      d[k] = _plotDefaults[k]
    end
  end

  for k in (:xscale, :yscale)
    if haskey(_scaleAliases, d[k])
      d[k] = _scaleAliases[d[k]]
    end
  end

  # convert color
  handlePlotColors(pkg, d)
  # d[:background_color] = getBackgroundRGBColor(d[:background_color], d)

  # no need for these
  delete!(d, :x)
  delete!(d, :y)

  d
end



# build the argument dictionary for a series
function getSeriesArgs(pkg::PlottingPackage, initargs::Dict, kw, commandIndex::Int, plotIndex::Int, globalIndex::Int)  # TODO, pass in initargs, not plt
  d = Dict(kw)

  # add defaults?
  for k in keys(_seriesDefaults)
    if haskey(d, k)
      v = d[k]
      if isa(v, AbstractVector) && !isempty(v)
        # we got a vector, cycling through
        d[k] = autopick(v, commandIndex)
      end
    else
      d[k] = _seriesDefaults[k]
    end
  end
  
  if haskey(_typeAliases, d[:linetype])
    d[:linetype] = _typeAliases[d[:linetype]]
  end

  aliasesAndAutopick(d, :axis, _axesAliases, supportedAxes(pkg), plotIndex)
  aliasesAndAutopick(d, :linestyle, _styleAliases, supportedStyles(pkg), plotIndex)
  aliasesAndAutopick(d, :marker, _markerAliases, supportedMarkers(pkg), plotIndex)

  # update color
  d[:color] = getSeriesRGBColor(d[:color], initargs, plotIndex)

  # update markercolor
  mc = d[:markercolor]
  mc = (mc == :match ? d[:color] : getSeriesRGBColor(mc, initargs, plotIndex))
  d[:markercolor] = mc

  # set label
  label = d[:label]
  label = (label == "AUTO" ? "y$globalIndex" : label)
  if d[:axis] == :right && length(label) >= 4 && label[end-3:end] != " (R)"
    label = string(label, " (R)")
  end
  d[:label] = label

  warnOnUnsupported(pkg, d)


  d
end


