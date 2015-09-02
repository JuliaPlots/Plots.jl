

const COLORS = [:black, :blue, :green, :red, :darkGray, :darkCyan, :darkYellow, :darkMagenta,
                :darkBlue, :darkGreen, :darkRed, :gray, :cyan, :yellow, :magenta]
const NUMCOLORS = length(COLORS)

# these are valid choices... first one is default value if unset
const LINE_AXES = (:left, :right)
const LINE_TYPES = (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap)
const LINE_STYLES = (:solid, :dash, :dot, :dashdot, :dashdotdot)
const LINE_MARKERS = (:none, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon)

const DEFAULT_axis = LINE_AXES[1]
const DEFAULT_color = :auto
const DEFAULT_label = "AUTO"
const DEFAULT_width = 2
const DEFAULT_linetype = LINE_TYPES[1]
const DEFAULT_linestyle = LINE_STYLES[1]
const DEFAULT_marker = LINE_MARKERS[1]
const DEFAULT_markercolor = :auto
const DEFAULT_markersize = 10
const DEFAULT_heatmap_n = 100
const DEFAULT_heatmap_c = (0.15, 0.5)

const DEFAULT_title = ""
const DEFAULT_xlabel = ""
const DEFAULT_ylabel = ""
const DEFAULT_yrightlabel = ""
