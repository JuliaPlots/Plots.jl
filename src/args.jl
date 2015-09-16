

# const COLORS = [:black, :blue, :green, :red, :darkGray, :darkCyan, :darkYellow, :darkMagenta,
#                 :darkBlue, :darkGreen, :darkRed, :gray, :cyan, :yellow, :magenta]

const COLORS = distinguishable_colors(20)
const AXES = [:left, :right]
const TYPES = [:line, :step, :stepinverted, :sticks, :dots, :heatmap, :hexbin, :hist, :bar]
const STYLES = [:solid, :dash, :dot, :dashdot, :dashdotdot]
const MARKERS = [:ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon]

supportedAxes(::PlottingPackage) = AXES
supportedTypes(::PlottingPackage) = TYPES
supportedStyles(::PlottingPackage) = STYLES
supportedMarkers(::PlottingPackage) = MARKERS

supportedAxes() = supportedAxes(plotter())
supportedTypes() = supportedTypes(plotter())
supportedStyles() = supportedStyles(plotter())
supportedMarkers() = supportedMarkers(plotter())

# -----------------------------------------------------------------------------

const PLOT_DEFAULTS = Dict{Symbol, Any}()

# series-specific
PLOT_DEFAULTS[:axis] = :left
PLOT_DEFAULTS[:color] = :auto
PLOT_DEFAULTS[:label] = "AUTO"
PLOT_DEFAULTS[:width] = 1
PLOT_DEFAULTS[:linetype] = :line
PLOT_DEFAULTS[:linestyle] = :solid
PLOT_DEFAULTS[:marker] = :none
PLOT_DEFAULTS[:markercolor] = :match
PLOT_DEFAULTS[:markersize] = 6
PLOT_DEFAULTS[:nbins] = 100               # number of bins for heatmaps and hists
PLOT_DEFAULTS[:heatmap_c] = (0.15, 0.5)
PLOT_DEFAULTS[:fillto] = nothing          # fills in the area
PLOT_DEFAULTS[:reg] = false               # regression line?

# plot globals
PLOT_DEFAULTS[:title] = ""
PLOT_DEFAULTS[:xlabel] = ""
PLOT_DEFAULTS[:ylabel] = ""
PLOT_DEFAULTS[:yrightlabel] = ""
PLOT_DEFAULTS[:legend] = true
# PLOT_DEFAULTS[:background_color] = nothing
PLOT_DEFAULTS[:xticks] = true
PLOT_DEFAULTS[:yticks] = true
PLOT_DEFAULTS[:size] = (600,400)
PLOT_DEFAULTS[:windowtitle] = "Plots.jl"
# PLOT_DEFAULTS[:show] = true

PLOT_DEFAULTS[:args] = []     # additional args to pass to the backend
PLOT_DEFAULTS[:kwargs] = []   # additional keyword args to pass to the backend
                              # note: can be Vector{Dict} or Vector{Tuple} 

# TODO: x/y scales


# -----------------------------------------------------------------------------

plotDefault(sym::Symbol) = PLOT_DEFAULTS[sym]
function plotDefault!(sym::Symbol, val)
  PLOT_DEFAULTS[sym] = val
end

# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]


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
  if isa(c, String)
    c = parse(Colorant, c)
  end

  # should be a RGB now... either it was passed in, generated automatically, or created from a string
  @assert isa(c, RGB)

  # return the RGB
  c
end

# const ALT_ARG_NAMES = Dict{Tuple{Symbol,Symbol}, Any}()
# ALT_ARG_NAMES[(:linetype, :scatter)] = :dots

function warnOnUnsupported(pkg::PlottingPackage, d::Dict)
  d[:axis] in supportedAxes(pkg) || warn("axis $(d[:axis]) is unsupported with $pkg.  Choose from: $(supportedAxes(pkg))")
  d[:linetype] == :none || d[:linetype] in supportedTypes(pkg) || warn("linetype $(d[:linetype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))")
  d[:linestyle] in supportedStyles(pkg) || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))")
  d[:marker] == :none || d[:marker] in supportedMarkers(pkg) || warn("marker $(d[:marker]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))")
end


# note: idx is the index of this series within this call, n is the index of the series from all calls to plot/subplot
function getPlotKeywordArgs(pkg::PlottingPackage, kw, idx::Int, n::Int)
  d = Dict(kw)

  # # replace alternate names
  # for tup in kw
  #   if haskey(ALT_ARG_NAMES, tup)
  #     d[tup[1]] = ALT_ARG_NAMES[tup]
  #   end
  # end

  # default to a white background, but only on the initial call (so we don't change the background automatically)
  if haskey(d, :background_color)
    d[:background_color] = getRGBColor(d[:background_color])
  elseif n == 0
    d[:background_color] = colorant"white"
  end

  # fill in d with either 1) plural value, 2) value, 3) default
  for k in keys(PLOT_DEFAULTS)
    plural = makeplural(k)
    if !haskey(d, k)
      if n == 0 || k != :size
        d[k] = haskey(d, plural) ? d[plural][idx] : PLOT_DEFAULTS[k]
      end
    end
    delete!(d, plural)
  end

  # auto-pick
  if n > 0
    if d[:axis] == :auto
      d[:axis] = autopick(supportedAxes(pkg), n)
    end
    if d[:linetype] == :auto
      d[:linetype] = autopick(supportedTypes(pkg), n)
    end
    if d[:linestyle] == :auto
      d[:linestyle] = autopick(supportedStyles(pkg), n)
    end
    if d[:marker] == :auto
      d[:marker] = autopick(supportedMarkers(pkg), n)
    end
    
  end

  # swap out dots for no line and a marker
  if haskey(d, :linetype) && d[:linetype] == :dots
    d[:linetype] = :none
    if d[:marker] == :none
      d[:marker] = :ellipse
    end
  end



  # handle plot initialization differently
  if n == 0
    delete!(d, :x)
    delete!(d, :y)
  else
    # once the plot is created, we can get line/marker colors
  
    # update color
    d[:color] = getRGBColor(d[:color], n)

    # update markercolor
    mc = d[:markercolor]
    mc = (mc == :match ? d[:color] : getRGBColor(mc, n))
    d[:markercolor] = mc

    # set label
    label = d[:label]
    label = (label == "AUTO" ? "y_$n" : label)
    if d[:axis] == :right && length(label) >= 4 && label[end-3:end] != " (R)"
      label = string(label, " (R)")
    end
    d[:label] = label

    warnOnUnsupported(pkg, d)
  end


  d
end

