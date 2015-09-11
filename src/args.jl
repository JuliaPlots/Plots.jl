

# const COLORS = [:black, :blue, :green, :red, :darkGray, :darkCyan, :darkYellow, :darkMagenta,
#                 :darkBlue, :darkGreen, :darkRed, :gray, :cyan, :yellow, :magenta]
const COLORS = distinguishable_colors(20)
const NUMCOLORS = length(COLORS)

# these are valid choices... first one is default value if unset
const LINE_AXES = (:left, :right)
const LINE_TYPES = (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar)
const LINE_STYLES = (:solid, :dash, :dot, :dashdot, :dashdotdot)
const LINE_MARKERS = (:none, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon)

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
PLOT_DEFAULTS[:markersize] = 3
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

# TODO: x/y scales


# -----------------------------------------------------------------------------

plotDefault(sym::Symbol) = PLOT_DEFAULTS[sym]
function plotDefault!(sym::Symbol, val)
  PLOT_DEFAULTS[sym] = val
end

# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))
autocolor(idx::Integer) = COLORS[mod1(idx,NUMCOLORS)]


# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
# note: if plt is nothing, we aren't doing anything with the color anyways
function getRGBColor(c, n::Int = 0)

  # auto-assign a color based on plot index
  if c == :auto && n > 0
    c = autocolor(n)
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


# note: i is the index of this series within this call, n is the index of the series from all calls to plot/subplot
function getPlotKeywordArgs(kw, i::Int, n::Int)
  d = Dict(kw)
  outd = Dict()

  # default to a white background, but only on the initial call (so we don't change the background automatically)
  if haskey(d, :background_color)
    outd[:background_color] = getRGBColor(d[:background_color])
  elseif n == 0
    d[:background_color] = colorant"white"
  end

  # fill in outd with either 1) plural value, 2) value, 3) default
  for k in keys(PLOT_DEFAULTS)
    plural = makeplural(k)
    if haskey(d, plural)
      outd[k] = d[plural][i]
    elseif haskey(d, k)
      outd[k] = d[k]
    else
      outd[k] = PLOT_DEFAULTS[k]
    end
  end

  # once the plot is created, we can get line/marker colors
  if n > 0
    # update color
    outd[:color] = getRGBColor(outd[:color], n)

    # update markercolor
    mc = outd[:markercolor]
    mc = (mc == :match ? outd[:color] : getRGBColor(mc, n))
    outd[:markercolor] = mc

    # set label
    label = outd[:label]
    outd[:label] = string(label == "AUTO" ? "y_$n" : label, outd[:axis] == :left ? "" : " (R)")
  end

  outd
end

