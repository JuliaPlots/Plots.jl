

const _allAxes        = [:auto, :left, :right]
const _axesAliases    = Dict(
    :a => :auto, 
    :l => :left, 
    :r => :right
  )

const _allTypes       = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter,
                         :heatmap, :hexbin, :hist, :bar, :hline, :vline, :ohlc]
const _typeAliases    = Dict(
    :n            => :none,
    :no           => :none,
    :l            => :line,
    :p            => :path,
    :stepinv      => :steppre,
    :stepinverted => :steppre,
    :step         => :steppost,
    :step         => :steppost,
    :stair        => :steppost,
    :stairs       => :steppost,
    :stem         => :sticks,
    :dots         => :scatter,
    :histogram    => :hist,
  )

const _allStyles      = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _styleAliases   = Dict(
    :a    => :auto,
    :s    => :solid,
    :d    => :dash,
    :dd   => :dashdot,
    :ddd  => :dashdotdot,
  )

const _allMarkers     = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon, :octagon]
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

supportedAxes(::PlottingPackage) = _allAxes
supportedTypes(::PlottingPackage) = _allTypes
supportedStyles(::PlottingPackage) = _allStyles
supportedMarkers(::PlottingPackage) = _allMarkers
subplotSupported(::PlottingPackage) = true

supportedAxes() = supportedAxes(plotter())
supportedTypes() = supportedTypes(plotter())
supportedStyles() = supportedStyles(plotter())
supportedMarkers() = supportedMarkers(plotter())
subplotSupported() = subplotSupported(plotter())

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
_seriesDefaults[:args]        = []     # additional args to pass to the backend
_seriesDefaults[:kwargs]      = []   # additional keyword args to pass to the backend
                              # note: can be Vector{Dict} or Vector{Tuple} 


const _plotDefaults = Dict{Symbol, Any}()

# plot globals
_plotDefaults[:title]             = ""
_plotDefaults[:xlabel]            = ""
_plotDefaults[:ylabel]            = ""
_plotDefaults[:yrightlabel]       = ""
_plotDefaults[:legend]            = true
_plotDefaults[:background_color]  = colorant"white"
_plotDefaults[:foreground_color]  = :auto
_plotDefaults[:xticks]            = :auto
_plotDefaults[:yticks]            = :auto
_plotDefaults[:size]              = (800,600)
_plotDefaults[:windowtitle]       = "Plots.jl"
_plotDefaults[:show]              = false



# TODO: x/y scales

const _allArgs = sort(collect(union(keys(_seriesDefaults), keys(_plotDefaults))))
supportedArgs(::PlottingPackage) = _allArgs
supportedArgs() = supportedArgs(plotter())


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
  sort(collect(keys(filter((k,v)-> v==val, aliasMap))))
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
    :mc           => :markercolor,
    :mcolor       => :markercolor,
    :ms           => :markersize,
    :msize        => :markersize,
    :nb           => :nbins,
    :nbin         => :nbins,
    :fill         => :fillto,
    :area         => :fillto,
    :g            => :group,
    :r            => :ribbon,
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
    :xlim         => :xticks,
    :ylim         => :yticks,
    :windowsize   => :size,
    :wsize        => :size,
    :wtitle       => :windowtitle,
    :display      => :show,
  )

# add all pluralized forms to the _keyAliases dict
for arg in keys(_seriesDefaults)
  _keyAliases[makeplural(arg)] = arg
end



# -----------------------------------------------------------------------------

# update the defaults globally

function plotDefault(k::Symbol)
  if haskey(_seriesDefaults, k)
    return _seriesDefaults[k]
  elseif haskey(_plotDefaults, k)
    return _plotDefaults[k]
  else
    error("Unknown key: ", k)
  end
end

function plotDefault!(k::Symbol, v)
  if haskey(_seriesDefaults, k)
    _seriesDefaults[k] = v
  elseif haskey(_plotDefaults, k)
    _plotDefaults[k] = v
  else
    error("Unknown key: ", k)
  end
end

# -----------------------------------------------------------------------------



function warnOnUnsupported(pkg::PlottingPackage, d::Dict)
  d[:axis] in supportedAxes(pkg) || warn("axis $(d[:axis]) is unsupported with $pkg.  Choose from: $(supportedAxes(pkg))")
  d[:linetype] == :none || d[:linetype] in supportedTypes(pkg) || warn("linetype $(d[:linetype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))")
  d[:linestyle] in supportedStyles(pkg) || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))")
  d[:marker] == :none || d[:marker] in supportedMarkers(pkg) || warn("marker $(d[:marker]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))")
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



# # note: idx is the index of this series within this call, n is the index of the series from all calls to plot/subplot
# function getPlotKeywordArgs(pkg::PlottingPackage, kw, idx::Int, n::Int)
#   d = Dict(kw)

#   # # replace alternate names
#   # for tup in kw
#   #   if haskey(ALT_ARG_NAMES, tup)
#   #     d[tup[1]] = ALT_ARG_NAMES[tup]
#   #   end
#   # end

#   # default to a white background, but only on the initial call (so we don't change the background automatically)
#   if haskey(d, :background_color)
#     d[:background_color] = getRGBColor(d[:background_color])
#   elseif n == 0
#     d[:background_color] = colorant"white"
#   end

#   # fill in d with either 1) plural value, 2) value, 3) default
#   for k in keys(PLOT_DEFAULTS)
#     plural = makeplural(k)
#     if !haskey(d, k)
#       if n == 0 || k != :size
#         d[k] = haskey(d, plural) ? autopick(d[plural], idx) : PLOT_DEFAULTS[k]
#       end
#     end
#     delete!(d, plural)
#   end

#   # auto-pick
#   if n > 0
#     if d[:axis] == :auto
#       d[:axis] = autopick_ignore_none_auto(supportedAxes(pkg), n)
#     end
#     # if d[:linetype] == :auto
#     #   d[:linetype] = autopick_ignore_none_auto(supportedTypes(pkg), n)
#     # end
#     if d[:linestyle] == :auto
#       d[:linestyle] = autopick_ignore_none_auto(supportedStyles(pkg), n)
#     end
#     if d[:marker] == :auto
#       d[:marker] = autopick_ignore_none_auto(supportedMarkers(pkg), n)
#     end
    
#   end

#   # # swap out dots for no line and a marker
#   # if haskey(d, :linetype) && d[:linetype] == :scatter
#   #   d[:linetype] = :none
#   #   if d[:marker] == :none
#   #     d[:marker] = :ellipse
#   #   end
#   # end



#   # handle plot initialization differently
#   if n == 0
#     delete!(d, :x)
#     delete!(d, :y)
#   else
#     # once the plot is created, we can get line/marker colors
  
#     # update color
#     d[:color] = getRGBColor(d[:color], n)

#     # update markercolor
#     mc = d[:markercolor]
#     mc = (mc == :match ? d[:color] : getRGBColor(mc, n))
#     d[:markercolor] = mc

#     # set label
#     label = d[:label]
#     label = (label == "AUTO" ? "y$n" : label)
#     if d[:axis] == :right && length(label) >= 4 && label[end-3:end] != " (R)"
#       label = string(label, " (R)")
#     end
#     d[:label] = label

#     warnOnUnsupported(pkg, d)
#   end


#   d
# end


# -----------------------------------------------------------------------------


# TODO: arg aliases

