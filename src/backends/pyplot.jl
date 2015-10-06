
# https://github.com/stevengj/PyPlot.jl

immutable PyPlotPackage <: PlottingPackage end

export pyplot
pyplot() = backend(:pyplot)

# -------------------------------

# supportedArgs(::PyPlotPackage) = setdiff(_allArgs, [:reg, :heatmap_c, :fill, :pos, :xlims, :ylims, :xticks, :yticks])
supportedArgs(::PyPlotPackage) = [
    :annotation,
    # :args,
    :axis,
    :background_color,
    :color,
    # :fill,
    :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    # :reg,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedAxes(::PyPlotPackage) = _allAxes
supportedTypes(::PyPlotPackage) = [:none, :line, :path, :step, :stepinverted, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline]
supportedStyles(::PyPlotPackage) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PyPlotPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :hexagon]
supportedScales(::PyPlotPackage) = [:identity, :log, :log2, :log10]
subplotSupported(::PyPlotPackage) = false

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant) = map(f->float(f(c)), (red, green, blue, alpha))

# get the style (solid, dashed, etc)
function getPyPlotLineStyle(linetype::Symbol, linestyle::Symbol)
  linetype == :none && return " "
  linestyle == :solid && return "-"
  linestyle == :dash && return "--"
  linestyle == :dot && return ":"
  linestyle == :dashdot && return "-."
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
  marker == :cross && return "+"
  marker == :xcross && return "x"
  marker == :star1 && return "*"
  # marker == :star2 && return "*"
  marker == :hexagon && return "h"
  warn("Unknown marker $marker")
  return "o"
end

# pass through
function getPyPlotMarker(marker::AbstractString)
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

  # in the 2-axis case we need to get: <rightaxis>[:<func>]
  if axis == :right
    ax = getRightAxis(plt.o[1])  
    ax[:set_ylabel](plt.initargs[:yrightlabel])
    fmap = Dict(
        :hist => :hist,
        :sticks => :bar,
        :bar => :bar,
        :heatmap => :hexbin,
        :hexbin => :hexbin,
        # :scatter => :scatter
      )
    return ax[get(fmap, linetype, :plot)]
    # return ax[linetype == :hist ? :hist : (linetype in (:sticks,:bar) ? :bar : (linetype in (:heatmap,:hexbin) ? :hexbin : :plot))]
  end

  # get the function
  fmap = Dict(
      :hist => PyPlot.plt[:hist],
      :sticks => PyPlot.bar,
      :bar => PyPlot.bar,
      :heatmap => PyPlot.hexbin,
      :hexbin => PyPlot.hexbin,
      # :scatter => PyPlot.scatter
    )
  return get(fmap, linetype, PyPlot.plot)
  # return linetype == :hist ? PyPlot.plt[:hist] : (linetype in (:sticks,:bar) ? PyPlot.bar : (linetype in (:heatmap,:hexbin) ? PyPlot.hexbin : PyPlot.plot))
end

function updateAxisColors(ax, fgcolor)
  for loc in ("bottom", "top", "left", "right")
    ax[:spines][loc][:set_color](fgcolor)
  end
  for axis in ("x", "y")
    ax[:tick_params](axis=axis, colors=fgcolor, which="both")
  end
  for axis in (:yaxis, :xaxis)
    ax[axis][:label][:set_color](fgcolor)
  end
  ax[:title][:set_color](fgcolor)
end

nop() = nothing
# makePyPlotCurrent(plt::Plot) = PyPlot.withfig(nop, plt.o[1])
makePyPlotCurrent(plt::Plot) = PyPlot.figure(plt.o[1].o[:number])
# makePyPlotCurrent(plt::Plot) = PyPlot.orig_figure(num = plt.o[1].o[:number])


function preparePlotUpdate(plt::Plot{PyPlotPackage})
  makePyPlotCurrent(plt)
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
  fig = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96)

  num = fig.o[:number]
  plt = Plot((fig, num), pkg, 0, d, Dict[])
  plt
end


function plot!(pkg::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)

  fig, num = plt.o
  # PyPlot.figure(num)  # makes this current
  # makePyPlotCurrent(plt)

  lt = d[:linetype]
  if !(lt in supportedTypes(pkg))
    error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
  end

  if lt == :sticks
    d,_ = sticksHack(;d...)
  
  elseif lt == :scatter
    d[:linetype] = :none
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  elseif lt in (:hline,:vline)
    linewidth = d[:linewidth]
    linecolor = getPyPlotColor(d[:color])
    linestyle = getPyPlotLineStyle(lt, d[:linestyle])
    for yi in d[:y]
      func = (lt == :hline ? PyPlot.axhline : PyPlot.axvline)
      func(yi, linewidth=d[:linewidth], color=linecolor, linestyle=linestyle)
    end

  end

  lt = d[:linetype]
  extraargs = Dict()

  plotfunc = getPyPlotFunction(plt, d[:axis], lt)

  # we have different args depending on plot type
  if lt in (:hist, :sticks, :bar)

    # NOTE: this is unsupported because it does the wrong thing... it shifts the whole axis
    # extraargs[:bottom] = d[:fill]

    if lt == :hist
      extraargs[:bins] = d[:nbins]
    else
      extraargs[:linewidth] = (lt == :sticks ? 0.1 : 0.9)
    end

  elseif lt in (:heatmap, :hexbin)

    extraargs[:gridsize] = d[:nbins]

  else

    extraargs[:linestyle] = getPyPlotLineStyle(lt, d[:linestyle])
    extraargs[:marker] = getPyPlotMarker(d[:markershape])

    if lt == :scatter
      extraargs[:s] = d[:markersize]
      extraargs[:c] = getPyPlotColor(d[:markercolor])
      extraargs[:linewidths] = d[:linewidth]
      if haskey(d, :colorscheme)
        extraargs[:cmap] = d[:colorscheme]
      end
    else
      extraargs[:markersize] = d[:markersize]
      extraargs[:markerfacecolor] = getPyPlotColor(d[:markercolor])
      extraargs[:drawstyle] = getPyPlotDrawStyle(lt)
    end
  end

  # set these for all types
  extraargs[:figure] = plt.o
  extraargs[:color] = getPyPlotColor(d[:color])
  extraargs[:linewidth] = d[:linewidth]
  extraargs[:label] = d[:label]

  # do the plot
  if lt == :hist
    d[:serieshandle] = plotfunc(d[:y]; extraargs...)[1]
  elseif lt in (:scatter, :heatmap, :hexbin)
    d[:serieshandle] = plotfunc(d[:x], d[:y]; extraargs...)
  else
    d[:serieshandle] = plotfunc(d[:x], d[:y]; extraargs...)[1]
  end

  # this sets the bg color inside the grid
  fig.o[:axes][1][:set_axis_bgcolor](getPyPlotColor(plt.initargs[:background_color]))

  push!(plt.seriesargs, d)
  plt
end


# -----------------------------------------------------------------

function addPyPlotLims(lims, isx::Bool)
  lims == :auto && return
  ltype = limsType(lims)
  if ltype == :limits
    (isx ? PyPlot.xlim : PyPlot.ylim)(lims...)
  else
    error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
  end
end

function addPyPlotTicks(ticks, isx::Bool)
  ticks == :auto && return
  ttype = ticksType(ticks)
  if ttype == :ticks
    (isx ? PyPlot.xticks : PyPlot.yticks)(ticks)
  elseif ttype == :ticks_and_labels
    (isx ? PyPlot.xticks : PyPlot.yticks)(ticks...)
  else
    error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
  end
end

function updatePlotItems(plt::Plot{PyPlotPackage}, d::Dict)
  fig = plt.o[1]

  # title and axis labels
  haskey(d, :title) && PyPlot.title(d[:title])
  haskey(d, :xlabel) && PyPlot.xlabel(d[:xlabel])
  if haskey(d, :ylabel)
    ax = getLeftAxis(fig)
    ax[:set_ylabel](d[:ylabel])
  end
  if haskey(d, :yrightlabel)
    ax = getRightAxis(fig)  
    ax[:set_ylabel](d[:yrightlabel])
  end

  # limits and ticks
  haskey(d, :xlims) && addPyPlotLims(d[:xlims], true)
  haskey(d, :ylims) && addPyPlotLims(d[:ylims], false)
  haskey(d, :xticks) && addPyPlotTicks(d[:xticks], true)
  haskey(d, :yticks) && addPyPlotTicks(d[:yticks], false)

  # scales
  ax = getLeftAxis(fig)
  haskey(d, :xscale) && applyPyPlotScale(ax, d[:xscale], true)
  haskey(d, :yscale) && applyPyPlotScale(ax, d[:yscale], false)

end

function applyPyPlotScale(ax, scaleType::Symbol, isx::Bool)
  func = ax[isx ? :set_xscale : :set_yscale]
  scaleType == :identity && return func("linear")
  scaleType == :log && return func("log", basex = e, basey = e)
  scaleType == :log2 && return func("log", basex = 2, basey = 2)
  scaleType == :log10 && return func("log", basex = 10, basey = 10)
  warn("Unhandled scaleType: ", scaleType)
end

# -----------------------------------------------------------------

function createPyPlotAnnotationObject(plt::Plot{PyPlotPackage}, x, y, val::AbstractString)
  ax = getLeftAxis(plt.o[1])
  ax[:annotate](val, xy = (x,y))
end

function addAnnotations{X,Y,V}(plt::Plot{PyPlotPackage}, anns::AVec{Tuple{X,Y,V}})
  for ann in anns
    createPyPlotAnnotationObject(plt, ann...)
  end
end

# -----------------------------------------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{PyPlotPackage})
  error("unsupported")
end

# -----------------------------------------------------------------

function addPyPlotLegend(plt::Plot)
  if plt.initargs[:legend]
    # gotta do this to ensure both axes are included
    args = filter(x -> !(x[:linetype] in (:hist,:hexbin,:heatmap,:hline,:vline)), plt.seriesargs)
    if length(args) > 0
      PyPlot.legend([d[:serieshandle] for d in args], [d[:label] for d in args], loc="best")
    end
  end
end


function Base.writemime(io::IO, m::MIME"image/png", plt::PlottingObject{PyPlotPackage})
  fig, num = plt.o
  addPyPlotLegend(plt)
  ax = fig.o[:axes][1]
  updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  writemime(io, m, fig)
end


function Base.display(::PlotsDisplay, plt::Plot{PyPlotPackage})
  fig, num = plt.o
  addPyPlotLegend(plt)
  ax = fig.o[:axes][1]
  updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  display(fig)
end

function Base.display(::PlotsDisplay, subplt::Subplot{PyPlotPackage})
  display(subplt.o)
end

