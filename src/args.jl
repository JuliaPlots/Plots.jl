

# const COLORS = [:black, :blue, :green, :red, :darkGray, :darkCyan, :darkYellow, :darkMagenta,
#                 :darkBlue, :darkGreen, :darkRed, :gray, :cyan, :yellow, :magenta]

const COLORS = distinguishable_colors(20)
const AXES = [:left, :right]
const TYPES = [:line,
               :step,
               :stepinverted,
               :sticks,
               :scatter,
               :heatmap,
               :hexbin,
               :hist,
               :bar,
               :hline,
               :vline,
               :ohlc,
              ]
const STYLES = [:solid, :dash, :dot, :dashdot, :dashdotdot]
const MARKERS = [:ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon, :octagon]

const ALL_AXES = vcat(:auto, AXES)
const ALL_TYPES = vcat(:none, TYPES)
const ALL_STYLES = vcat(:auto, STYLES)
const ALL_MARKERS = vcat(:none, :auto, MARKERS)

supportedAxes(::PlottingPackage) = ALL_AXES
supportedTypes(::PlottingPackage) = ALL_TYPES
supportedStyles(::PlottingPackage) = ALL_STYLES
supportedMarkers(::PlottingPackage) = ALL_MARKERS
subplotSupported(::PlottingPackage) = true

supportedAxes() = supportedAxes(plotter())
supportedTypes() = supportedTypes(plotter())
supportedStyles() = supportedStyles(plotter())
supportedMarkers() = supportedMarkers(plotter())
subplotSupported() = subplotSupported(plotter())

# -----------------------------------------------------------------------------

const _seriesDefaults = Dict{Symbol, Any}()

# series-specific
_seriesDefaults[:axis] = :left
_seriesDefaults[:color] = :auto
_seriesDefaults[:label] = "AUTO"
_seriesDefaults[:width] = 1
_seriesDefaults[:linetype] = :line
_seriesDefaults[:linestyle] = :solid
_seriesDefaults[:marker] = :none
_seriesDefaults[:markercolor] = :match
_seriesDefaults[:markersize] = 6
_seriesDefaults[:nbins] = 100               # number of bins for heatmaps and hists
_seriesDefaults[:heatmap_c] = (0.15, 0.5)
_seriesDefaults[:fillto] = nothing          # fills in the area
_seriesDefaults[:reg] = false               # regression line?
_seriesDefaults[:group] = nothing
_seriesDefaults[:ribbon] = nothing
_seriesDefaults[:args] = []     # additional args to pass to the backend
_seriesDefaults[:kwargs] = []   # additional keyword args to pass to the backend
                              # note: can be Vector{Dict} or Vector{Tuple} 


const _plotDefaults = Dict{Symbol, Any}()

# plot globals
_plotDefaults[:title] = ""
_plotDefaults[:xlabel] = ""
_plotDefaults[:ylabel] = ""
_plotDefaults[:yrightlabel] = ""
_plotDefaults[:legend] = true
_plotDefaults[:background_color] = colorant"white"
_plotDefaults[:xticks] = true
_plotDefaults[:yticks] = true
_plotDefaults[:size] = (600,400)
_plotDefaults[:windowtitle] = "Plots.jl"
_plotDefaults[:show] = false



# const seriesKeys = [:axis, :color, :label, :width, :linetype, :linestyle, :marker, :markercolor, :markersize, :nbins, :heatmap_c, :fillto, :reg, :group, :ribbon]
# const plotKeys = [:title, :xlabel, :ylabel, :yrightlabel, :legend, :background_color, :xticks, :yticks, :size, :windowtitle, :show]

# TODO: x/y scales

const ARGS = sort(collect(intersect(keys(_seriesDefaults), keys(_plotDefaults))))
supportedArgs(::PlottingPackage) = ARGS
supportedArgs() = supportedArgs(plotter())


# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]
autopick(notarr, idx::Integer) = notarr

autopick_ignore_none_auto(arr::AVec, idx::Integer) = autopick(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

# -----------------------------------------------------------------------------

# Alternate args

const keyAliases = Dict(
    :c => :color,
    :l => :label,
    :w => :width,
    :linewidth => :width,
    :type => :linetype,
    :t => :linetype,
    :style => :linestyle,
    :s => :linestyle,
    :m => :marker,
    :mc => :markercolor,
    :mcolor => :markercolor,
    :ms => :markersize,
    :msize => :markersize,
    :nb => :nbins,
    :nbin => :nbins,
    :fill => :fillto,
    :g => :group,
    :r => :ribbon,
    :xlab => :xlabel,
    :ylab => :ylabel,
    :yrlab => :yrightlabel,
    :ylabr => :yrightlabel,
    :y2lab => :yrightlabel,
    :ylab2 => :yrightlabel,
    :ylabelright => :yrightlabel,
    :ylabel2 => :yrightlabel,
    :y2label => :yrightlabel,
    :leg => :legend,
    :bg => :background_color,
    :bgcolor => :background_color,
    :bg_color => :background_color,
    :background => :background_color,
    :windowsize => :size,
    :wsize => :size,
    :wtitle => :windowtitle,
    :display => :show,
  )

# add all pluralized forms to the keyAliases dict
for arg in keys(_seriesDefaults)
  keyAliases[makeplural(arg)] = arg
end


function replaceAliases!(d::Dict)
  for (k,v) in d
    if haskey(keyAliases, k)
      d[keyAliases[k]] = v
      delete!(d, k)
    end
  end
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


# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
# note: if plt is nothing, we aren't doing anything with the color anyways
function getRGBColor(c, n::Int = 0)

  # auto-assign a color based on plot index
  if c == :auto && n > 0
    c = autopick(COLORS, n)
  end

  # convert it from a symbol/string
  if isa(c, Symbol)
    c = string(c)
  end
  if isa(c, AbstractString)
    c = parse(Colorant, c)
  end

  # should be a RGB now... either it was passed in, generated automatically, or created from a string
  @assert isa(c, RGB)

  # return the RGB
  c
end



function warnOnUnsupported(pkg::PlottingPackage, d::Dict)
  d[:axis] in supportedAxes(pkg) || warn("axis $(d[:axis]) is unsupported with $pkg.  Choose from: $(supportedAxes(pkg))")
  d[:linetype] == :none || d[:linetype] in supportedTypes(pkg) || warn("linetype $(d[:linetype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))")
  d[:linestyle] in supportedStyles(pkg) || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))")
  d[:marker] == :none || d[:marker] in supportedMarkers(pkg) || warn("marker $(d[:marker]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))")
end


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
  d[:background_color] = getRGBColor(d[:background_color])

  # no need for these
  delete!(d, :x)
  delete!(d, :y)

  d
end



# note: idx is the index of this series within this call, n is the index of the series from all calls to plot/subplot
function getSeriesArgs(pkg::PlottingPackage, kw, idx::Int, n::Int)
  d = Dict(kw)

  # add defaults?
  for k in keys(_seriesDefaults)
    if haskey(d, k)
      v = d[k]
      if isa(v, AbstractVector) && !isempty(v)
        # we got a vector, cycling through
        d[k] = autopick(v, idx)
      end
    else
      d[k] = _seriesDefaults[k]
    end
  end

  # auto-pick
  if d[:axis] == :auto
    d[:axis] = autopick_ignore_none_auto(supportedAxes(pkg), n)
  end
  if d[:linestyle] == :auto
    d[:linestyle] = autopick_ignore_none_auto(supportedStyles(pkg), n)
  end
  if d[:marker] == :auto
    d[:marker] = autopick_ignore_none_auto(supportedMarkers(pkg), n)
  end

  # update color
  d[:color] = getRGBColor(d[:color], n)

  # update markercolor
  mc = d[:markercolor]
  mc = (mc == :match ? d[:color] : getRGBColor(mc, n))
  d[:markercolor] = mc

  # set label
  label = d[:label]
  label = (label == "AUTO" ? "y$n" : label)
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

