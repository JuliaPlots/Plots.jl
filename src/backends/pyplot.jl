
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
    :color_palette,
    :fillrange,
    :fillcolor,
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
    :xflip,
    :yflip,
    :z,
    # :linkx,
    # :linky,
    # :linkfunc,
  ]
supportedAxes(::PyPlotPackage) = _allAxes
supportedTypes(::PyPlotPackage) = [:none, :line, :path, :step, :stepinverted, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline]
supportedStyles(::PyPlotPackage) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PyPlotPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :hexagon]
supportedScales(::PyPlotPackage) = [:identity, :log, :log2, :log10]
subplotSupported(::PyPlotPackage) = true

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant) = map(f->float(f(c)), (red, green, blue, alpha))
getPyPlotColor(scheme::ColorScheme) = getPyPlotColor(getColor(scheme))

# getPyPlotColorMap(c::ColorGradient) = PyPlot.matplotlib[:colors][:ListedColormap](map(getPyPlotColor, getColorVector(c)))
function getPyPlotColorMap(c::ColorGradient)
  pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", map(getPyPlotColor, getColorVector(c)))
end

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
function getPyPlotMarker(marker::@compat(AbstractString))
  @assert length(marker) == 1
  marker
end

function getPyPlotDrawStyle(linetype::Symbol)
  linetype == :step && return "steps-post"
  linetype == :stepinverted && return "steps-pre"
  return "default"
end


immutable PyPlotFigWrapper
  fig
end

immutable PyPlotAxisWrapper
  ax
end

# addPyPlotAxis(fig, layout) = error("Only GridLayouts are supported with PyPlot")

# function addPyPlotAxis(fig, layout::GridLayout, idx::Int)

# end


# get a reference to the correct axis
function getLeftAxis(wrap::PyPlotFigWrapper)
  # @show wrap.fig.o[:axes]
  axes = wrap.fig.o[:axes]
  if isempty(axes)
    return wrap.fig.o[:add_subplot](111)
  end
  axes[1]
end
getLeftAxis(wrap::PyPlotAxisWrapper) = wrap.ax
getLeftAxis(plt::Plot{PyPlotPackage}) = getLeftAxis(plt.o)
getRightAxis(x) = getLeftAxis(x)[:twinx]()
getAxis(plt::Plot{PyPlotPackage}, axis::Symbol) = (axis == :right ? getRightAxis : getLeftAxis)(plt)

# left axis is PyPlot.<func>, right axis is "f.axes[0].twinx().<func>"
function getPyPlotFunction(plt::Plot, axis::Symbol, linetype::Symbol)

  # in the 2-axis case we need to get: <rightaxis>[:<func>]
  ax = getAxis(plt, axis)

  # if axis == :right
    # ax = getRightAxis(plt.o)  
    ax[:set_ylabel](plt.initargs[:yrightlabel])
    fmap = @compat Dict(
        :hist => :hist,
        :sticks => :bar,
        :bar => :bar,
        :heatmap => :hexbin,
        :hexbin => :hexbin,
        :scatter => :scatter
      )
    return ax[get(fmap, linetype, :plot)]
    # return ax[linetype == :hist ? :hist : (linetype in (:sticks,:bar) ? :bar : (linetype in (:heatmap,:hexbin) ? :hexbin : :plot))]
  # end

  # # get the function
  # fmap = @compat Dict(
  #     :hist => PyPlot.plt[:hist],
  #     :sticks => PyPlot.bar,
  #     :bar => PyPlot.bar,
  #     :heatmap => PyPlot.hexbin,
  #     :hexbin => PyPlot.hexbin,
  #     :scatter => PyPlot.scatter
  #   )
  # return get(fmap, linetype, PyPlot.plot)
  # # return linetype == :hist ? PyPlot.plt[:hist] : (linetype in (:sticks,:bar) ? PyPlot.bar : (linetype in (:heatmap,:hexbin) ? PyPlot.hexbin : PyPlot.plot))
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


makePyPlotCurrent(wrap::PyPlotFigWrapper) = PyPlot.figure(wrap.fig.o[:number])
makePyPlotCurrent(wrap::PyPlotAxisWrapper) = PyPlot.sca(wrap.ax.o)
makePyPlotCurrent(plt::Plot{PyPlotPackage}) = makePyPlotCurrent(plt.o)
# makePyPlotCurrent(plt::Plot) = PyPlot.figure(plt.o.o[:number])


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

  # standalone plots will create a figure, but not if part of a subplot (do it later)
  if haskey(d, :subplot)
    wrap = nothing
  else
    wrap = PyPlotFigWrapper(PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96))
  end

  # num = wrap.o[:number]
  plt = Plot(wrap, pkg, 0, d, Dict[])
  plt
end


function plot!(pkg::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)

  # fig = plt.o
  ax = getAxis(plt, d[:axis])
  lt = d[:linetype]
  if !(lt in supportedTypes(pkg))
    error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
  end

  if lt == :sticks
    d,_ = sticksHack(;d...)
  
  elseif lt == :scatter
    # d[:linetype] = :none
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  elseif lt in (:hline,:vline)
    linewidth = d[:linewidth]
    linecolor = getPyPlotColor(d[:color])
    linestyle = getPyPlotLineStyle(lt, d[:linestyle])
    for yi in d[:y]
      # func = (lt == :hline ? PyPlot.axhline : PyPlot.axvline)
      func = ax[lt == :hline ? :axhline : axvline]
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
      extraargs[:s] = d[:markersize]^2
      #extraargs[:linewidths] = d[:linewidth]
      c = d[:markercolor]
      if isa(c, ColorGradient) && d[:z] != nothing
        extraargs[:c] = convert(Vector{Float64}, d[:z])
        extraargs[:cmap] = getPyPlotColorMap(c)
      else
        extraargs[:c] = getPyPlotColor(c)
      end
    else
      extraargs[:markersize] = d[:markersize]
      extraargs[:markerfacecolor] = getPyPlotColor(d[:markercolor])
      extraargs[:drawstyle] = getPyPlotDrawStyle(lt)
    end
  end

  # set these for all types
  # extraargs[:figure] = plt.o
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
  # ax = getLeftAxis(plt)
  ax[:set_axis_bgcolor](getPyPlotColor(plt.initargs[:background_color]))

  fillrange = d[:fillrange]
  if fillrange != nothing
    fillcolor = getPyPlotColor(d[:fillcolor])
    if typeof(fillrange) <: @compat(Union{Real, AVec})
      ax[:fill_between](d[:x], fillrange, d[:y], facecolor = fillcolor)
    else
      ax[:fill_between](d[:x], fillrange..., facecolor = fillcolor)
    end
  end

  push!(plt.seriesargs, d)
  plt
end


# -----------------------------------------------------------------

function addPyPlotLims(ax, lims, isx::Bool)
  lims == :auto && return
  ltype = limsType(lims)
  if ltype == :limits
    # (isx ? PyPlot.xlim : PyPlot.ylim)(lims...)
    # @show isx, lims, ax
    ax[isx ? :set_xlim : :set_ylim](lims...)
  else
    error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
  end
end

function addPyPlotTicks(ax, ticks, isx::Bool)
  ticks == :auto && return
  if ticks == :none
    ticks = zeros(0)
  end

  ttype = ticksType(ticks)
  if ttype == :ticks
    # (isx ? PyPlot.xticks : PyPlot.yticks)(ticks)
    ax[isx ? :set_xticks : :set_yticks](ticks)
  elseif ttype == :ticks_and_labels
    # (isx ? PyPlot.xticks : PyPlot.yticks)(ticks...)
    ax[isx ? :set_xticks : :set_yticks](ticks...)
  else
    error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
  end
end

function updatePlotItems(plt::Plot{PyPlotPackage}, d::Dict)
  figorax = plt.o
  ax = getLeftAxis(figorax)
  # PyPlot.sca(ax)

  # title and axis labels
  haskey(d, :title) && PyPlot.title(d[:title])
  # haskey(d, :xlabel) && PyPlot.xlabel(d[:xlabel])
  haskey(d, :xlabel) && ax[:set_xlabel](d[:xlabel])
  if haskey(d, :ylabel)
    # ax = getLeftAxis(figorax)
    ax[:set_ylabel](d[:ylabel])
  end
  if haskey(d, :yrightlabel)
    rightax = getRightAxis(figorax)  
    rightax[:set_ylabel](d[:yrightlabel])
  end

  # scales
  haskey(d, :xscale) && applyPyPlotScale(ax, d[:xscale], true)
  haskey(d, :yscale) && applyPyPlotScale(ax, d[:yscale], false)

  # limits and ticks
  haskey(d, :xlims) && addPyPlotLims(ax, d[:xlims], true)
  haskey(d, :ylims) && addPyPlotLims(ax, d[:ylims], false)
  haskey(d, :xticks) && addPyPlotTicks(ax, d[:xticks], true)
  haskey(d, :yticks) && addPyPlotTicks(ax, d[:yticks], false)

  if get(d, :xflip, false)
    ax[:invert_xaxis]()
  end
  if get(d, :yflip, false)
    ax[:invert_yaxis]()
  end

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

function createPyPlotAnnotationObject(plt::Plot{PyPlotPackage}, x, y, val::@compat(AbstractString))
  ax = getLeftAxis(plt)
  ax[:annotate](val, xy = (x,y))
end

function addAnnotations{X,Y,V}(plt::Plot{PyPlotPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    createPyPlotAnnotationObject(plt, ann...)
  end
end

# -----------------------------------------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{PyPlotPackage}, isbefore::Bool)
  l = subplt.layout

  w,h = map(px2inch, subplt.initargs[1][:size])
  bgcolor = getPyPlotColor(subplt.initargs[1][:background_color])
  fig = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96)

  nr = nrows(l)
  for (i,(r,c)) in enumerate(l)

    # add the plot to the figure
    nc = ncols(l, r)
    fakeidx = (r-1) * nc + c
    ax = fig[:add_subplot](nr, nc, fakeidx)

    subplt.plts[i].o = PyPlotAxisWrapper(ax)
  end

  # isa(l, GridLayout) || error("Unsupported layout ", l)

  # iargs = subplt.initargs[1]
  # w,h = map(px2inch, iargs[:size])
  # bgcolor = getPyPlotColor(iargs[:background_color])
  # n, m = nrows(l), ncols(l)
  # fig, axes = PyPlot.subplots(n, m,
  #                             sharex = get(iargs,:linkx,false),
  #                             sharey = get(iargs,:linky,false),
  #                             figsize = (w,h),
  #                             facecolor = bgcolor,
  #                             dpi = 96)

  # # @show axes
  # @assert length(axes) == length(subplt.plts)

  # axes = vec(reshape(axes, n, m)')

  # for (i,plt) in enumerate(subplt.plts)
  #   plt.o = PyPlotAxisWrapper(axes[i])
  # end

  # @show fig axes
  subplt.o = PyPlotFigWrapper(fig)
  true


  # # TODO: set plt.o = PyPlotAxisWrapper(ax) for each plot
  # for (i,(r,c)) in enumerate(subplt.layout)
  #   plt = subplt.plts[i]
  #   plt.o = PyPlotAxisWrapper(subplt.o.fig.o[:add_subplot]())
  #   # return wrap.fig.o[:add_subplot](111)
end



# # create the underlying object (each backend will do this differently)
# function buildSubplotObject!(subplt::Subplot{PyPlotPackage}, isbefore::Bool)
#   l = subplt.layout
#   isa(l, GridLayout) || error("Unsupported layout ", l)

#   iargs = subplt.initargs[1]
#   w,h = map(px2inch, iargs[:size])
#   bgcolor = getPyPlotColor(iargs[:background_color])
#   n, m = nrows(l), ncols(l)
#   fig, axes = PyPlot.subplots(n, m,
#                               sharex = get(iargs,:linkx,false),
#                               sharey = get(iargs,:linky,false),
#                               figsize = (w,h),
#                               facecolor = bgcolor,
#                               dpi = 96)

#   # @show axes
#   @assert length(axes) == length(subplt.plts)

#   axes = vec(reshape(axes, n, m)')

#   for (i,plt) in enumerate(subplt.plts)
#     plt.o = PyPlotAxisWrapper(axes[i])
#   end

#   # @show fig axes
#   subplt.o = PyPlotFigWrapper(fig)
#   true


#   # # TODO: set plt.o = PyPlotAxisWrapper(ax) for each plot
#   # for (i,(r,c)) in enumerate(subplt.layout)
#   #   plt = subplt.plts[i]
#   #   plt.o = PyPlotAxisWrapper(subplt.o.fig.o[:add_subplot]())
#   #   # return wrap.fig.o[:add_subplot](111)
# end

function handleLinkInner(plt::Plot{PyPlotPackage}, isx::Bool)
  if isx
    plot!(plt, xticks=zeros(0), xlabel="")
  else
    plot!(plt, yticks=zeros(0), ylabel="")
  end
end

function expandLimits!(lims, plt::Plot{PyPlotPackage}, isx::Bool)
  pltlims = plt.o.ax[isx ? :get_xbound : :get_ybound]()
  expandLimits!(lims, pltlims)
end

# -----------------------------------------------------------------

# function addPyPlotLegend(plt::Plot)
function addPyPlotLegend(plt::Plot, ax)
  if plt.initargs[:legend]
    # gotta do this to ensure both axes are included
    args = filter(x -> !(x[:linetype] in (:hist,:hexbin,:heatmap,:hline,:vline)), plt.seriesargs)
    if length(args) > 0
      # PyPlot.legend([d[:serieshandle] for d in args], [d[:label] for d in args], loc="best")
      ax[:legend]([d[:serieshandle] for d in args], [d[:label] for d in args], loc="best")
    end
  end
end

function finalizePlot(plt::Plot{PyPlotPackage})
  wrap = plt.o
  ax = getLeftAxis(plt)
  addPyPlotLegend(plt, ax)
  updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  PyPlot.draw()
end

function Base.writemime(io::IO, m::MIME"image/png", plt::Plot{PyPlotPackage})
  # wrap = plt.o
  # # addPyPlotLegend(plt)
  # # ax = fig.o[:axes][1]
  # ax = getLeftAxis(plt)
  # addPyPlotLegend(plt, ax)
  # updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  finalizePlot(plt)
  writemime(io, m, plt.o.fig)
end


function Base.display(::PlotsDisplay, plt::Plot{PyPlotPackage})
  # wrap = plt.o
  # # addPyPlotLegend(plt)
  # # ax = fig.o[:axes][1]
  # ax = getLeftAxis(plt)
  # addPyPlotLegend(plt, ax)
  # updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  # # wrap.fig.o[:show]()
  # PyPlot.draw()
  # display(wrap.fig)
  finalizePlot(plt)
end


function finalizePlot(subplt::Subplot{PyPlotPackage})
  fig = subplt.o.fig
  for (i,plt) in enumerate(subplt.plts)
    # fig.o[:axes][i] = getLeftAxis(plt)
    finalizePlot(plt)
  end
end

function Base.display(::PlotsDisplay, subplt::Subplot{PyPlotPackage})
  # for plt in subplt.plts
  #   finalizePlot(plt)
  # end
  finalizePlot(subplt)
  display(subplt.o.fig)
end


function Base.writemime(io::IO, m::MIME"image/png", subplt::Subplot{PyPlotPackage})
  # wrap = plt.o
  # # addPyPlotLegend(plt)
  # # ax = fig.o[:axes][1]
  # ax = getLeftAxis(plt)
  # addPyPlotLegend(plt, ax)
  # updateAxisColors(ax, getPyPlotColor(plt.initargs[:foreground_color]))
  # for plt in subplt.plts
  #   finalizePlot(plt)
  # end
  finalizePlot(subplt)
  writemime(io, m, subplt.o.fig)
end
