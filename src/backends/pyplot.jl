
# https://github.com/stevengj/PyPlot.jl

# -------------------------------

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant) = map(f->float(f(c)), (red, green, blue, alpha))
getPyPlotColor(scheme::ColorScheme) = getPyPlotColor(getColor(scheme))
getPyPlotColor(c) = getPyPlotColor(convertColor(c))

function getPyPlotColorMap(c::ColorGradient)
  pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", map(getPyPlotColor, getColorVector(c)))
end
getPyPlotColorMap(c) = getPyPlotColorMap(ColorGradient(:redsblues))

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

function getPyPlotMarker(marker::Shape)
  n = length(marker.vertices)
  mat = zeros(n+1,2)
  for (i,vert) in enumerate(marker.vertices)
    mat[i,1] = vert[1]
    mat[i,2] = vert[2]
  end
  mat[n+1,:] = mat[1,:]
  pypath.pymember("Path")(mat)
  # marker.vertices
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
  marker == :star5 && return "*"
  marker == :pentagon && return "p"
  marker == :hexagon && return "h"
  marker == :octagon && return "8"
  haskey(_shapes, marker) && return getPyPlotMarker(_shapes[marker])

  warn("Unknown marker $marker")
  return "o"
end

# pass through
function getPyPlotMarker(marker::@compat(AbstractString))
  @assert length(marker) == 1
  marker
end

function getPyPlotDrawStyle(linetype::Symbol)
  linetype == :steppost && return "steps-post"
  linetype == :steppre && return "steps-pre"
  return "default"
end


immutable PyPlotFigWrapper
  fig
end

immutable PyPlotAxisWrapper
  ax
  fig
end

getfig(wrap::@compat(Union{PyPlotAxisWrapper,PyPlotFigWrapper})) = wrap.fig



# get a reference to the correct axis
function getLeftAxis(wrap::PyPlotFigWrapper)
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
  ax[:set_ylabel](plt.initargs[:yrightlabel])
  fmap = @compat Dict(
      :hist => :hist,
      :sticks => :bar,
      :bar => :bar,
      :heatmap => :hexbin,
      :hexbin => :hexbin,
      :scatter => :scatter,
      :contour => :contour,
    )
  return ax[get(fmap, linetype, :plot)]
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
makePyPlotCurrent(wrap::PyPlotAxisWrapper) = nothing #PyPlot.sca(wrap.ax.o)
makePyPlotCurrent(plt::Plot{PyPlotPackage}) = makePyPlotCurrent(plt.o)


function preparePlotUpdate(plt::Plot{PyPlotPackage})
  makePyPlotCurrent(plt)
end


# ------------------------------------------------------------------

# TODO:
# fillto   # might have to use barHack/histogramHack??
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

  plt = Plot(wrap, pkg, 0, d, Dict[])
  plt
end


function plot!(pkg::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)

  ax = getAxis(plt, d[:axis])
  lt = d[:linetype]
  if !(lt in supportedTypes(pkg))
    error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
  end

  if lt == :sticks
    d,_ = sticksHack(;d...)
  
  elseif lt == :scatter
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  elseif lt in (:hline,:vline)
    linewidth = d[:linewidth]
    linecolor = getPyPlotColor(d[:color])
    linestyle = getPyPlotLineStyle(lt, d[:linestyle])
    for yi in d[:y]
      func = ax[lt == :hline ? :axhline : axvline]
      func(yi, linewidth=d[:linewidth], color=linecolor, linestyle=linestyle)
    end

  end

  lt = d[:linetype]
  extra_kwargs = Dict()

  plotfunc = getPyPlotFunction(plt, d[:axis], lt)

  # we have different args depending on plot type
  if lt in (:hist, :sticks, :bar)

    # NOTE: this is unsupported because it does the wrong thing... it shifts the whole axis
    # extra_kwargs[:bottom] = d[:fill]

    if lt == :hist
      extra_kwargs[:bins] = d[:nbins]
    else
      extra_kwargs[:linewidth] = (lt == :sticks ? 0.1 : 0.9)
    end

  elseif lt in (:heatmap, :hexbin)
    extra_kwargs[:gridsize] = d[:nbins]
    extra_kwargs[:cmap] = getPyPlotColorMap(d[:color])

  elseif lt == :contour
    extra_kwargs[:cmap] = getPyPlotColorMap(d[:color])
    extra_kwargs[:linewidths] = d[:linewidth]
    extra_kwargs[:linestyles] = getPyPlotLineStyle(lt, d[:linestyle])
    # TODO: will need to call contourf to fill in the contours

  else

    extra_kwargs[:linestyle] = getPyPlotLineStyle(lt, d[:linestyle])
    extra_kwargs[:marker] = getPyPlotMarker(d[:markershape])

    if lt == :scatter
      extra_kwargs[:s] = d[:markersize]^2
      c = d[:markercolor]
      if isa(c, ColorGradient) && d[:z] != nothing
        extra_kwargs[:c] = convert(Vector{Float64}, d[:z])
        extra_kwargs[:cmap] = getPyPlotColorMap(c)
      else
        extra_kwargs[:c] = getPyPlotColor(c)
      end
    else
      extra_kwargs[:markersize] = d[:markersize]
      extra_kwargs[:markerfacecolor] = getPyPlotColor(d[:markercolor])
      extra_kwargs[:markeredgecolor] = getPyPlotColor(plt.initargs[:foreground_color])
      extra_kwargs[:markeredgewidth] = d[:linewidth]
      extra_kwargs[:drawstyle] = getPyPlotDrawStyle(lt)
    end
  end

  # set these for all types
  if lt != :contour
    extra_kwargs[:color] = getPyPlotColor(d[:color])
    extra_kwargs[:linewidth] = d[:linewidth]
    extra_kwargs[:label] = d[:label]
  end

  # do the plot
  d[:serieshandle] = if lt == :hist
    plotfunc(d[:y]; extra_kwargs...)[1]
  elseif lt == :contour
    handle = plotfunc(d[:x], d[:y], d[:surface], d[:nlevels]; extra_kwargs...)
    if d[:fillrange] != nothing
      handle = ax[:contourf](d[:x], d[:y], d[:surface], d[:nlevels]; cmap = getPyPlotColorMap(d[:fillcolor]))
    end
    handle
  elseif lt in (:scatter, :heatmap, :hexbin)
    plotfunc(d[:x], d[:y]; extra_kwargs...)
  else
    plotfunc(d[:x], d[:y]; extra_kwargs...)[1]
  end

  # add the colorbar legend
  if plt.initargs[:legend] && haskey(extra_kwargs, :cmap)
    PyPlot.colorbar(d[:serieshandle])
  end

  # this sets the bg color inside the grid
  ax[:set_axis_bgcolor](getPyPlotColor(plt.initargs[:background_color]))

  fillrange = d[:fillrange]
  if fillrange != nothing && lt != :contour
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


function Base.getindex(plt::Plot{PyPlotPackage}, i::Integer)
  series = plt.seriesargs[i][:serieshandle]
  try
    return series[:get_data]()
  catch
    xy = series[:get_offsets]()
    return vec(xy[:,1]), vec(xy[:,2])
  end
  # series[:relim]()
  # mapping = getGadflyMappings(plt, i)[1]
  # mapping[:x], mapping[:y]
end

function Base.setindex!(plt::Plot{PyPlotPackage}, xy::Tuple, i::Integer)
  series = plt.seriesargs[i][:serieshandle]
  try
    series[:set_data](xy...)
  catch
    series[:set_offsets](hcat(xy...))
  end

  ax = series[:axes]
  if plt.initargs[:xlims] == :auto
    xmin, xmax = ax[:get_xlim]()
    ax[:set_xlim](min(xmin, minimum(xy[1])), max(xmax, maximum(xy[1])))
  end
  if plt.initargs[:ylims] == :auto
    ymin, ymax = ax[:get_ylim]()
    ax[:set_ylim](min(ymin, minimum(xy[2])), max(ymax, maximum(xy[2])))
  end

  # getLeftAxis(plt)[:relim]()
  # getRightAxis(plt)[:relim]()
  # for mapping in getGadflyMappings(plt, i)
  #   mapping[:x], mapping[:y] = xy
  # end
  plt
end

# -----------------------------------------------------------------

function addPyPlotLims(ax, lims, isx::Bool)
  lims == :auto && return
  ltype = limsType(lims)
  if ltype == :limits
    ax[isx ? :set_xlim : :set_ylim](lims...)
  else
    error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
  end
end

function addPyPlotTicks(ax, ticks, isx::Bool)
  ticks == :auto && return
  if ticks == :none || ticks == nothing
    ticks = zeros(0)
  end

  ttype = ticksType(ticks)
  if ttype == :ticks
    ax[isx ? :set_xticks : :set_yticks](ticks)
  elseif ttype == :ticks_and_labels
    ax[isx ? :set_xticks : :set_yticks](ticks...)
  else
    error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
  end
end

usingRightAxis(plt::Plot{PyPlotPackage}) = any(args -> args[:axis] in (:right,:auto), plt.seriesargs)

function updatePlotItems(plt::Plot{PyPlotPackage}, d::Dict)
  figorax = plt.o
  ax = getLeftAxis(figorax)
  # PyPlot.sca(ax)

  # title and axis labels
  # haskey(d, :title) && PyPlot.title(d[:title])
  haskey(d, :title) && ax[:set_title](d[:title])
  haskey(d, :xlabel) && ax[:set_xlabel](d[:xlabel])
  if haskey(d, :ylabel)
    ax[:set_ylabel](d[:ylabel])
  end
  if usingRightAxis(plt) && get(d, :yrightlabel, "") != ""
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

  axes = [getLeftAxis(figorax)]
  if usingRightAxis(plt)
    push!(axes, getRightAxis(figorax))
  end

  # font sizes
  for ax in axes
    # haskey(d, :yrightlabel) || continue
    

    # guides
    sz = get(d, :guidefont, plt.initargs[:guidefont]).pointsize
    ax[:title][:set_fontsize](sz)
    ax[:xaxis][:label][:set_fontsize](sz)
    ax[:yaxis][:label][:set_fontsize](sz)

    # ticks
    sz = get(d, :tickfont, plt.initargs[:tickfont]).pointsize
    for sym in (:get_xticklabels, :get_yticklabels)
      for lab in ax[sym]()
        lab[:set_fontsize](sz)
      end
    end
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


function createPyPlotAnnotationObject(plt::Plot{PyPlotPackage}, x, y, val::PlotText)
  ax = getLeftAxis(plt)
  ax[:annotate](val.str,
    xy = (x,y),
    family = val.font.family,
    color = getPyPlotColor(val.font.color),
    horizontalalignment = val.font.halign == :hcenter ? "center" : string(val.font.halign),
    verticalalignment = val.font.valign == :vcenter ? "center" : string(val.font.valign),
    rotation = val.font.rotation * 180 / π,
    size = val.font.pointsize
  )
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

  w,h = map(px2inch, getinitargs(subplt,1)[:size])
  bgcolor = getPyPlotColor(getinitargs(subplt,1)[:background_color])
  fig = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = 96)

  nr = nrows(l)
  for (i,(r,c)) in enumerate(l)

    # add the plot to the figure
    nc = ncols(l, r)
    fakeidx = (r-1) * nc + c
    ax = fig[:add_subplot](nr, nc, fakeidx)

    subplt.plts[i].o = PyPlotAxisWrapper(ax, fig)
  end

  subplt.o = PyPlotFigWrapper(fig)
  true
end


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
    args = filter(x -> !(x[:linetype] in (:hist,:hexbin,:heatmap,:hline,:vline,:contour)), plt.seriesargs)
    if length(args) > 0
      ax[:legend]([d[:serieshandle] for d in args],
                  [d[:label] for d in args],
                  loc="best",
                  fontsize = plt.initargs[:legendfont].pointsize
                  # framealpha = 0.6
                 )
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

# # allow for writing any supported mime
# for mime in keys(PyPlot.aggformats)
#   @eval function Base.writemime(io::IO, m::MIME{symbol{$mime}}, plt::Plot{PyPlotPackage})
#     finalizePlot(plt)
#     writemime(io, m, getfig(plt.o))
#   end
# end

# function Base.writemime(io::IO, m::@compat(Union{MIME"image/svg+xml", MIME"image/png"}, plt::Plot{PyPlotPackage})
#   finalizePlot(plt)
#   writemime(io, m, getfig(plt.o))
# end


# NOTE: to bring up a GUI window in IJulia, need some extra steps
function Base.display(::PlotsDisplay, plt::PlottingObject{PyPlotPackage})
  finalizePlot(plt)
  if isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
    display(getfig(plt.o))
  else
    PyPlot.ion()
    PyPlot.figure(getfig(plt.o).o[:number])
    PyPlot.draw_if_interactive()
    PyPlot.ioff()
  end
end


function finalizePlot(subplt::Subplot{PyPlotPackage})
  fig = subplt.o.fig
  for (i,plt) in enumerate(subplt.plts)
    finalizePlot(plt)
  end
end

# function Base.display(::PlotsDisplay, subplt::Subplot{PyPlotPackage})
#   finalizePlot(subplt)
#   PyPlot.ion()
#   PyPlot.figure(getfig(subplt.o).o[:number])
#   PyPlot.draw_if_interactive()
#   PyPlot.ioff()
#   # display(getfig(subplt.o))
# end

# # allow for writing any supported mime
# for mime in (MIME"image/png", MIME"application/pdf", MIME"application/postscript")
#   @eval function Base.writemime(io::IO, ::$mime, plt::PlottingObject{PyPlotPackage})
#     finalizePlot(plt)
#     writemime(io, $mime(), getfig(plt.o))
#   end
# end

const _pyplot_mimeformats = @compat Dict(
    "application/eps"         => "eps",
    "image/eps"               => "eps",
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    # "image/svg+xml"           => "svg"
  )


for (mime, fmt) in _pyplot_mimeformats
  @eval function Base.writemime(io::IO, ::MIME{symbol($mime)}, plt::PlottingObject{PyPlotPackage})
    finalizePlot(plt)
    fig = getfig(plt.o)
    fig.o["canvas"][:print_figure](io,
                                   format=$fmt,
                                   bbox_inches="tight",
                                   facecolor = fig.o["get_facecolor"](),
                                   edgecolor = "none"
                                   # edgecolor = fig.o["get_edgecolor"]()
                                  )
  end
end

# function Base.writemime(io::IO, m::MIME"image/png", subplt::Subplot{PyPlotPackage})
#   finalizePlot(subplt)
#   writemime(io, m, getfig(subplt.o))
# end
