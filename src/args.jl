

const COLORS = [:black, :blue, :green, :red, :darkGray, :darkCyan, :darkYellow, :darkMagenta,
                :darkBlue, :darkGreen, :darkRed, :gray, :cyan, :yellow, :magenta]
const NUMCOLORS = length(COLORS)

# these are valid choices... first one is default value if unset
const LINE_AXES = (:left, :right)
const LINE_TYPES = (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap)
const LINE_STYLES = (:solid, :dash, :dot, :dashdot, :dashdotdot)
const LINE_MARKERS = (:none, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon)


const PLOT_DEFAULTS = Dict{Symbol, Any}()
PLOT_DEFAULTS[:axis] = :left
PLOT_DEFAULTS[:color] = :auto
PLOT_DEFAULTS[:label] = "AUTO"
PLOT_DEFAULTS[:width] = 1
PLOT_DEFAULTS[:linetype] = :line
PLOT_DEFAULTS[:linestyle] = :solid
PLOT_DEFAULTS[:marker] = :none
PLOT_DEFAULTS[:markercolor] = :auto
PLOT_DEFAULTS[:markersize] = 10
PLOT_DEFAULTS[:heatmap_n] = 100
PLOT_DEFAULTS[:heatmap_c] = (0.15, 0.5)
PLOT_DEFAULTS[:title] = ""
PLOT_DEFAULTS[:xlabel] = ""
PLOT_DEFAULTS[:ylabel] = ""
PLOT_DEFAULTS[:yrightlabel] = ""

plotDefault(sym::Symbol) = PLOT_DEFAULTS[sym]
function plotDefault!(sym::Symbol, val)
  PLOT_DEFAULTS[sym] = val
end

makeplural(s::Symbol) = Symbol(string(s,"s"))
autocolor(idx::Integer) = COLORS[mod1(idx,NUMCOLORS)]


function getPlotKeywordArgs(kw, i::Int)
  d = Dict(kw)
  kw = Dict()

  for k in keys(PLOT_DEFAULTS)
    plural = makeplural(k)
    if haskey(d, plural)
      kw[k] = d[plural][i]
    elseif haskey(d, k)
      kw[k] = d[k]
    else
      kw[k] = PLOT_DEFAULTS[k]
    end
  end

  kw
end

# const DEFAULT_axis = LINE_AXES[1]
# const DEFAULT_color = :auto
# const DEFAULT_label = "AUTO"
# const DEFAULT_width = 2
# const DEFAULT_linetype = LINE_TYPES[1]
# const DEFAULT_linestyle = LINE_STYLES[1]
# const DEFAULT_marker = LINE_MARKERS[1]
# const DEFAULT_markercolor = :auto
# const DEFAULT_markersize = 10
# const DEFAULT_heatmap_n = 100
# const DEFAULT_heatmap_c = (0.15, 0.5)

# const DEFAULT_title = ""
# const DEFAULT_xlabel = ""
# const DEFAULT_ylabel = ""
# const DEFAULT_yrightlabel = ""
