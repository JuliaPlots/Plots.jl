
# https://github.com/stevengj/PyPlot.jl

immutable PyPlotPackage <: PlottingPackage end

pyplot!() = plotter!(:pyplot)

# -------------------------------


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
  linetype == :step && return "steps-post"
  linetype == :stepinverted && return "steps-pre"
  return "default"
end

# get a reference to the right axis
getLeftAxis(o) = o.o[:axes][1]
getRightAxis(o) = getLeftAxis(o)[:twinx]()

# left axis is PyPlot.<func>, right axis is "f.axes[0].twinx().<func>"
function getPyPlotFunction(plt::Plot, axis::Symbol, linetype::Symbol)
  if axis == :right
    ax = getRightAxis(plt.o)  
    ax[:set_ylabel](plt.initargs[:yrightlabel])
    return ax[linetype == :hist ? :hist : (linetype in (:sticks,:bar) ? :bar : (linetype in (:heatmap,:hexbin) ? :hexbin : :plot))]
  end
  return linetype == :hist ? PyPlot.plt[:hist] : (linetype in (:sticks,:bar) ? PyPlot.bar : (linetype in (:heatmap,:hexbin) ? PyPlot.hexbin : PyPlot.plot))
end

# ------------------------------------------------------------------

# TODO:
# fillto   # might have to use barHack/histogramHack??
# heatmap
# subplot
# reg             # true or false, add a regression line for each line
# pos             # (Int,Int), move the enclosing window to this position
# windowtitle     # string or symbol, set the title of the enclosing windowtitle
# screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)
# show            # true or false, show the plot (in case you don't want the window to pop up right away)

function plot(pkg::PyPlotPackage; kw...)
  # create the figure
  d = Dict(kw)
  w,h = map(px2inch, d[:size])
  bgcolor = getPyPlotColor(d[:background_color])
  o = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96)

  PyPlot.title(d[:title])
  PyPlot.xlabel(d[:xlabel])
  PyPlot.ylabel(d[:ylabel])

  plt = Plot(o, pkg, 0, d, Dict[])
  plt
end


function plot!(::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)
  lt = d[:linetype]
  extraargs = Dict()

  plotfunc = getPyPlotFunction(plt, d[:axis], lt)

  # we have different args depending on plot type
  if lt in (:hist, :sticks, :bar)

    # NOTE: this is unsupported because it does the wrong thing... it shifts the whole axis
    # extraargs[:bottom] = d[:fillto]

    if lt == :hist
      extraargs[:bins] = d[:nbins]
    else
      extraargs[:width] = (lt == :sticks ? 0.1 : 0.9)
    end

  elseif lt in (:heatmap, :hexbin)

    extraargs[:gridsize] = d[:nbins]

  else

    # all but color/label
    extraargs[:linestyle] = getPyPlotLineStyle(lt, d[:linestyle])
    extraargs[:marker] = getPyPlotMarker(d[:marker])
    extraargs[:markersize] = d[:markersize]
    extraargs[:markerfacecolor] = getPyPlotColor(d[:markercolor])
    extraargs[:drawstyle] = getPyPlotDrawStyle(lt)

  end

  # set these for all types
  extraargs[:figure] = plt.o
  extraargs[:color] = getPyPlotColor(d[:color])
  extraargs[:linewidth] = d[:width]
  extraargs[:label] = d[:label]

  # do the plot
  if lt == :hist
    d[:serieshandle] = plotfunc(d[:y]; extraargs...)
  else
    d[:serieshandle] = plotfunc(d[:x], d[:y]; extraargs...)
  end

  push!(plt.seriesargs, d)
  plt
end

function addPyPlotLegend(plt::Plot)
  # add a legend?
  # try
    if plt.initargs[:legend]
      # gotta do this to ensure both axes are included
      args = filter(x -> !(x[:linetype] in (:hist,:hexbin,:heatmap)), plt.seriesargs)
      if length(args) > 0
        PyPlot.legend([d[:serieshandle][1] for d in args], [d[:label] for d in args], loc="best")
      end
    end
  # catch ex
  #   warn("Error adding PyPlot legend: ", ex)
  # end
end

function Base.display(::PyPlotPackage, plt::Plot)
  addPyPlotLegend(plt)
  display(plt.o)
end

# -------------------------------

function savepng(::PyPlotPackage, plt::PlottingObject, fn::String, args...)
  addPyPlotLegend(plt)
  f = open(fn, "w")
  writemime(f, "image/png", plt.o)
  close(f)
end

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

