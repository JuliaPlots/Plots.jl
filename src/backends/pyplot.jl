
# https://github.com/tbreloff/Qwt.jl

immutable PyPlotPackage <: PlottingPackage end

pyplot!() = plotter!(:pyplot)

# -------------------------------

# function adjustQwtKeywords(iscreating::Bool; kw...)
#   d = Dict(kw)
#   d[:heatmap_n] = d[:nbins]

#   if d[:linetype] == :hexbin
#     d[:linetype] = :heatmap
#   elseif d[:linetype] == :dots
#     d[:linetype] = :none
#     d[:marker] = :hexagon
#   elseif !iscreating && d[:linetype] == :bar
#     return barHack(; kw...)
#   elseif !iscreating && d[:linetype] == :hist
#     return barHack(; histogramHack(; kw...)...)
#   end
#   d
# end


# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant) = map(f->float(f(c)), (red, green, blue, alpha))

# get the style (solid, dashed, etc)
function getPyPlotLineStyle(linetype::Symbol, linestyle::Symbol)
  linetype == :none && return " "
  linestyle == :solid && return "-"
  linestyle == :dash && return "--"
  linestyle == :dot && return ":"
  linestyle == :dashdot && return "-."
  linestyle == :dashdotdot && return "-."
  warn("Unknown linestyle $linestyle")
  return "-"
end

# get the marker shape
function getPyPlotMarker(marker::Symbol)
  marker == :none && return " "
  marker == :ellipse && return "o"
  marker == :rect && return "s"
  marker == :diamond && return "D"
  marker == :utriangle && return "^"
  marker == :dtriangle && return "v"
  marker == :cross && return "x"
  marker == :xcross && return "+"
  marker == :star1 && return "*"
  marker == :star2 && return "*"
  marker == :hexagon && return "h"
  warn("Unknown marker $marker")
  return "o"
end

# pass through
function getPyPlotMarker(marker::String)
  @assert length(marker) == 1
  marker
end

function getPyPlotDrawStyle(linetype::Symbol)
  linetype == :step && "steps-post"
  linetype == :stepinverted && "steps-pre"
  return "default"
end


function plot(pkg::PyPlotPackage; kw...)
  # create the figure
  d = Dict(kw)
  w,h = map(px2inch, d[:size])
  bgcolor = getPyPlotColor(d[:background_color])
  @show w h
  o = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96)

  plt = Plot(o, pkg, 0, d, Dict[])
  plt
end

# TODO:
# - 2-axis
# - bar
# - hist
# - fillto/area
# - heatmap
# - subplot
# title           # string or symbol, title of the plot
# xlabel          # string or symbol, label on the bottom (x) axis
# ylabel          # string or symbol, label on the left (y) axis
# yrightlabel     # string or symbol, label on the right (y) axis
# reg             # true or false, add a regression line for each line
# pos             # (Int,Int), move the enclosing window to this position
# windowtitle     # string or symbol, set the title of the enclosing windowtitle
# screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)
# show            # true or false, show the plot (in case you don't want the window to pop up right away)

function plot!(::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)

  lt = d[:linetype]
  PyPlot.plot(d[:x], d[:y]; figure = plt.o,
                     color = getPyPlotColor(d[:color]),
                     linewidth = d[:width],
                     linestyle = getPyPlotLineStyle(lt, d[:linestyle]),
                     marker = getPyPlotMarker(d[:marker]),
                     markersize = d[:markersize],
                     markerfacecolor = getPyPlotColor(d[:markercolor]),
                     drawstyle = getPyPlotDrawStyle(lt),
                     label = d[:label],
    )

  if plt.initargs[:legend]
    PyPlot.legend()
  end

  push!(plt.seriesargs, d)
  plt
end

function Base.display(::PyPlotPackage, plt::Plot)
  display(plt.o)
end

# -------------------------------

savepng(::PyPlotPackage, plt::PlottingObject, fn::String, args...) = error("unsupported")

# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::PyPlotPackage, subplt::Subplot)
  # i = 0
  # rows = []
  # for rowcnt in subplt.layout.rowcounts
  #   push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
  #   i += rowcnt
  # end
  # subplt.o = Qwt.vsplitter(rows...)
  error("unsupported")
end


function Base.display(::PyPlotPackage, subplt::Subplot)
  # for plt in subplt.plts
  #   Qwt.refresh(plt.o)
  # end
  # Qwt.showwidget(subplt.o)
  display(subplt.o)
end

