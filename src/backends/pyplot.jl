
# https://github.com/stevengj/PyPlot.jl

function _initialize_backend(::PyPlotPackage)
  @eval begin
    import PyPlot
    export PyPlot
    const pycolors = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colors"))
    const pypath = PyPlot.pywrap(PyPlot.pyimport("matplotlib.path"))
    const mplot3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d"))
    # const pycolorbar = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colorbar"))
  end

  if !isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
    PyPlot.ioff()  # stops wierd behavior of displaying incomplete graphs in IJulia

    # # TODO: how the hell can I use PyQt4??
    # "pyqt4"=>:qt_pyqt4
    # PyPlot.backend[1] = "pyqt4"
    # PyPlot.gui[1] = :qt_pyqt4
    # PyPlot.switch_backend("Qt4Agg")

    # only turn on the gui if we want it
    if PyPlot.gui != :none
      PyPlot.pygui(true)
    end
  end
end

# -------------------------------

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant, α=nothing) = map(f->float(f(convertColor(c,α))), (red, green, blue, alpha))
getPyPlotColor(cvec::ColorVector, α=nothing) = map(getPyPlotColor, convertColor(cvec, α).v)
getPyPlotColor(scheme::ColorScheme, α=nothing) = getPyPlotColor(convertColor(getColor(scheme), α))
getPyPlotColor(c, α=nothing) = getPyPlotColor(convertColor(c, α))
# getPyPlotColor(c, alpha) = getPyPlotColor(colorscheme(c, alpha))

function getPyPlotColorMap(c::ColorGradient, α=nothing)
  # c = ColorGradient(c.colors, c.values, alpha=α)
  # pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", map(getPyPlotColor, getColorVector(c)))
  # pyvals = [(c.values[i], getPyPlotColor(c.colors[i], α)) for i in 1:length(c.colors)]
  pyvals = [(v, getPyPlotColor(getColorZ(c, v), α)) for v in c.values]
  # @show c α pyvals
  pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", pyvals)
end

# anything else just gets a bluesred gradient
getPyPlotColorMap(c, α=nothing) = getPyPlotColorMap(ColorGradient(:bluesreds), α)

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

# getPyPlotMarker(markers::AVec) = map(getPyPlotMarker, markers)
function getPyPlotMarker(markers::AVec)
  warn("Vectors of markers are currently unsupported in PyPlot: $markers")
  getPyPlotMarker(markers[1])
end

# pass through
function getPyPlotMarker(marker::AbstractString)
  @assert length(marker) == 1
  marker
end

function getPyPlotStepStyle(linetype::Symbol)
  linetype == :steppost && return "steps-post"
  linetype == :steppre && return "steps-pre"
  return "default"
end


# immutable PyPlotFigWrapper
#   fig
#   kwargs  # for add_subplot
# end

type PyPlotAxisWrapper
  ax
  rightax
  fig
  kwargs  # for add_subplot
end

# getfig(wrap::@compat(Union{PyPlotAxisWrapper,PyPlotFigWrapper})) = wrap.fig
getfig(wrap::PyPlotAxisWrapper) = wrap.fig



# get a reference to the correct axis
function getLeftAxis(wrap::PyPlotAxisWrapper)
  if wrap.ax == nothing
    axes = wrap.fig.o[:axes]
    if isempty(axes)
      return wrap.fig.o[:add_subplot](111; wrap.kwargs...)
    end
    axes[1]
  else
    wrap.ax
  end
end
# getLeftAxis(wrap::PyPlotAxisWrapper) = wrap.ax
# getRightAxis(x) = getLeftAxis(x)[:twinx]()

function getRightAxis(wrap::PyPlotAxisWrapper)
  if wrap.rightax == nothing
    wrap.rightax = getLeftAxis(wrap)[:twinx]()
  end
  wrap.rightax
end

getLeftAxis(plt::Plot{PyPlotPackage}) = getLeftAxis(plt.o)
getRightAxis(plt::Plot{PyPlotPackage}) = getRightAxis(plt.o)
getAxis(plt::Plot{PyPlotPackage}, axis::Symbol) = (axis == :right ? getRightAxis : getLeftAxis)(plt)

# left axis is PyPlot.<func>, right axis is "f.axes[0].twinx().<func>"
function getPyPlotFunction(plt::Plot, axis::Symbol, linetype::Symbol)

  # # need to access mplot3d functions differently
  # if linetype == :surface
  #   return mplot3d.pymember("Axes3D")[:plot_surface]
  # end

  # in the 2-axis case we need to get: <rightaxis>[:<func>]
  ax = getAxis(plt, axis)
  # ax[:set_ylabel](plt.plotargs[:yrightlabel])
  fmap = @compat Dict(
      :hist       => :hist,
      :density    => :hist,
      :sticks     => :bar,
      :bar        => :bar,
      :heatmap    => :hexbin,
      :hexbin     => :hexbin,
      :scatter    => :scatter,
      :contour    => :contour,
      :scatter3d  => :scatter,
      :surface    => :plot_surface,
      :wireframe  => :plot_wireframe,
      # :surface    => pycolors.pymember("LinearSegmentedColormap")[:from_list]
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


function handleSmooth(plt::Plot{PyPlotPackage}, ax, d::Dict, smooth::Bool)
  if smooth
    xs, ys = regressionXY(d[:x], d[:y])
    ax[:plot](xs, ys,
              # linestyle = getPyPlotLineStyle(:path, :dashdot),
              color = getPyPlotColor(d[:linecolor]),
              linewidth = 2
             )
  end
end
handleSmooth(plt::Plot{PyPlotPackage}, ax, d::Dict, smooth::Real) = handleSmooth(plt, ax, d, true)




# makePyPlotCurrent(wrap::PyPlotFigWrapper) = PyPlot.figure(wrap.fig.o[:number])
# makePyPlotCurrent(wrap::PyPlotAxisWrapper) = nothing #PyPlot.sca(wrap.ax.o)
makePyPlotCurrent(wrap::PyPlotAxisWrapper) = wrap.ax == nothing ? PyPlot.figure(wrap.fig.o[:number]) : nothing
makePyPlotCurrent(plt::Plot{PyPlotPackage}) = plt.o == nothing ? nothing : makePyPlotCurrent(plt.o)


function _before_add_series(plt::Plot{PyPlotPackage})
  makePyPlotCurrent(plt)
end


# ------------------------------------------------------------------

function pyplot_figure(plotargs::Dict)
  w,h = map(px2inch, plotargs[:size])
  bgcolor = getPyPlotColor(plotargs[:background_color])

  # reuse the current figure?
  fig = if plotargs[:overwrite_figure]
    PyPlot.gcf()
  else
    PyPlot.figure()
  end

  # update the specs
  # fig[:set_size_inches](w,h, (isijulia() ? [] : [true])...)
  fig[:set_size_inches](w, h, forward = true)
  fig[:set_facecolor](bgcolor)
  fig[:set_dpi](DPI)
  fig[:set_tight_layout](true)

  # clear the figure
  PyPlot.clf()

  # resize the window
  PyPlot.plt[:get_current_fig_manager]()[:resize](plotargs[:size]...)
  fig
end

function pyplot_3d_setup!(wrap, d)
  # 3D?
  # if haskey(d, :linetype) && first(d[:linetype]) in _3dTypes # && isa(plt.o, PyPlotFigWrapper)
  if trueOrAllTrue(lt -> lt in _3dTypes, get(d, :linetype, :none))
    push!(wrap.kwargs, (:projection, "3d"))
  end
end


# TODO:
# fillto   # might have to use barHack/histogramHack??
# reg             # true or false, add a regression line for each line
# pos             # (Int,Int), move the enclosing window to this position
# windowtitle     # string or symbol, set the title of the enclosing windowtitle
# screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)
# show            # true or false, show the plot (in case you don't want the window to pop up right away)

function _create_plot(pkg::PyPlotPackage; kw...)
  # create the figure
  d = Dict(kw)

  # standalone plots will create a figure, but not if part of a subplot (do it later)
  if haskey(d, :subplot)
    wrap = nothing
  else
    wrap = PyPlotAxisWrapper(nothing, nothing, pyplot_figure(d), [])
    # wrap = PyPlotAxisWrapper(nothing, nothing, PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = DPI, tight_layout = true), [])

    # if haskey(d, :linetype) && first(d[:linetype]) in _3dTypes # && isa(plt.o, PyPlotFigWrapper)
    #   push!(wrap.kwargs, (:projection, "3d"))
    # end
    pyplot_3d_setup!(wrap, d)
  end

  plt = Plot(wrap, pkg, 0, d, Dict[])
  plt
end


function _add_series(pkg::PyPlotPackage, plt::Plot; kw...)
  d = Dict(kw)

  # 3D plots have a different underlying Axes object in PyPlot
  lt = d[:linetype]
  if lt in _3dTypes && isempty(plt.o.kwargs)
    push!(plt.o.kwargs, (:projection, "3d"))
  end

  # handle mismatched x/y sizes, as PyPlot doesn't like that
  x, y = d[:x], d[:y]
  nx, ny = map(length, (x,y))
  if nx < ny
    d[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
  else
    d[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
  end

  ax = getAxis(plt, d[:axis])
  if !(lt in supportedTypes(pkg))
    error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
  end

  color = getPyPlotColor(d[:linecolor], d[:linealpha])


  if lt == :sticks
    d,_ = sticksHack(;d...)

  elseif lt in (:scatter, :scatter3d)
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  elseif lt in (:hline,:vline)
    linewidth = d[:linewidth]
    linecolor = color
    linestyle = getPyPlotLineStyle(lt, d[:linestyle])
    for yi in d[:y]
      func = ax[lt == :hline ? :axhline : :axvline]
      func(yi, linewidth=d[:linewidth], color=linecolor, linestyle=linestyle)
    end

  end

  # lt = d[:linetype]
  extra_kwargs = Dict()

  plotfunc = getPyPlotFunction(plt, d[:axis], lt)

  # we have different args depending on plot type
  if lt in (:hist, :density, :sticks, :bar)

    # NOTE: this is unsupported because it does the wrong thing... it shifts the whole axis
    # extra_kwargs[:bottom] = d[:fill]

    if ishistlike(lt)
      extra_kwargs[:bins] = d[:nbins]
      extra_kwargs[:normed] = lt == :density
    else
      extra_kwargs[:linewidth] = (lt == :sticks ? 0.1 : 0.9)
    end

  elseif lt in (:heatmap, :hexbin)
    extra_kwargs[:gridsize] = d[:nbins]
    extra_kwargs[:cmap] = getPyPlotColorMap(d[:linecolor])

  elseif lt == :contour
    extra_kwargs[:cmap] = getPyPlotColorMap(d[:linecolor])
    extra_kwargs[:linewidths] = d[:linewidth]
    extra_kwargs[:linestyles] = getPyPlotLineStyle(lt, d[:linestyle])
    # TODO: will need to call contourf to fill in the contours

  elseif lt in (:surface, :wireframe)
    if lt == :surface
      extra_kwargs[:cmap] = getPyPlotColorMap(d[:fillcolor], d[:fillalpha])
    end
    extra_kwargs[:rstride] = 1
    extra_kwargs[:cstride] = 1
    extra_kwargs[:linewidth] = d[:linewidth]
    extra_kwargs[:edgecolor] = getPyPlotColor(d[:linecolor], d[:linealpha])

  else

    extra_kwargs[:linestyle] = getPyPlotLineStyle(lt, d[:linestyle])
    extra_kwargs[:marker] = getPyPlotMarker(d[:markershape])

    if lt in (:scatter, :scatter3d)
      extra_kwargs[:s] = d[:markersize].^2
      c = d[:markercolor]
      if d[:zcolor] != nothing
        if !isa(c, ColorGradient)
          c = colorscheme(:bluesreds)
        end
        extra_kwargs[:c] = convert(Vector{Float64}, d[:zcolor])
        extra_kwargs[:cmap] = getPyPlotColorMap(c, d[:markeralpha])
      else
        # extra_kwargs[:c] = getPyPlotColor(c, d[:markeralpha])
        ppc = getPyPlotColor(c, d[:markeralpha])

        # total hack due to PyPlot bug (see issue #145).
        # hack: duplicate the color vector when the total rgba fields is the same as the series length
        if (typeof(ppc) <: AbstractArray && length(ppc)*4 == length(x)) ||
                (typeof(ppc) <: Tuple && length(x) == 4)
          ppc = vcat(ppc, ppc)
        end
        extra_kwargs[:c] = ppc

      end
      # if d[:markeralpha] != nothing
      #   extra_kwargs[:alpha] = d[:markeralpha]
      # end
      extra_kwargs[:edgecolors] = getPyPlotColor(d[:markerstrokecolor], d[:markerstrokealpha])
      extra_kwargs[:linewidths] = d[:markerstrokewidth]
    else
      extra_kwargs[:markersize] = d[:markersize]
      extra_kwargs[:markerfacecolor] = getPyPlotColor(d[:markercolor], d[:markeralpha])
      extra_kwargs[:markeredgecolor] = getPyPlotColor(d[:markerstrokecolor], d[:markerstrokealpha])
      extra_kwargs[:markeredgewidth] = d[:markerstrokewidth]
      extra_kwargs[:drawstyle] = getPyPlotStepStyle(lt)
    end
  end

  # if d[:markeralpha] != nothing
  #   extra_kwargs[:alpha] = d[:markeralpha]
  # elseif d[:linealpha] != nothing
  #   extra_kwargs[:alpha] = d[:linealpha]
  # end

  # set these for all types
  if !(lt in (:contour,:surface,:wireframe))
    if !(lt in (:scatter, :scatter3d))
      extra_kwargs[:color] = color
      extra_kwargs[:linewidth] = d[:linewidth]
    end
    extra_kwargs[:label] = d[:label]
    extra_kwargs[:zorder] = plt.n
  end

  # do the plot
  d[:serieshandle] = if ishistlike(lt)
    plotfunc(d[:y]; extra_kwargs...)[1]

  elseif lt == :contour
    x, y = d[:x], d[:y]
    surf = d[:z].surf'
    levels = d[:levels]
    if isscalar(levels)
      extra_args = (levels)
    elseif isvector(levels)
      extra_args = ()
      extra_kwargs[:levels] = levels
    else
      error("Only numbers and vectors are supported with levels keyword")
    end
    handle = plotfunc(x, y, surf, extra_args...; extra_kwargs...)
    if d[:fillrange] != nothing
      extra_kwargs[:cmap] = getPyPlotColorMap(d[:fillcolor], d[:fillalpha])
      delete!(extra_kwargs, :linewidths)
      handle = ax[:contourf](x, y, surf, extra_args...; extra_kwargs...)
    end
    handle

  elseif lt in (:surface,:wireframe)
    x, y, z = d[:x], d[:y], Array(d[:z])
    if !ismatrix(x) || !ismatrix(y)
      x = repmat(x', length(y), 1)
      y = repmat(y, 1, length(d[:x]))
      z = z'
    end
    plotfunc(x, y, z; extra_kwargs...)
  elseif lt in _3dTypes
    plotfunc(d[:x], d[:y], d[:z]; extra_kwargs...)
  elseif lt in (:scatter, :heatmap, :hexbin)
    plotfunc(d[:x], d[:y]; extra_kwargs...)
  else
    plotfunc(d[:x], d[:y]; extra_kwargs...)[1]
  end

  handleSmooth(plt, ax, d, d[:smooth])

  # add the colorbar legend
  if plt.plotargs[:colorbar] != :none && haskey(extra_kwargs, :cmap)
    PyPlot.colorbar(d[:serieshandle], ax=ax)
  end

  # @show extra_kwargs

  # this sets the bg color inside the grid
  ax[:set_axis_bgcolor](getPyPlotColor(plt.plotargs[:background_color]))

  fillrange = d[:fillrange]
  if fillrange != nothing && lt != :contour
    fillcolor = getPyPlotColor(d[:fillcolor], d[:fillalpha])
    if typeof(fillrange) <: @compat(Union{Real, AVec})
      ax[:fill_between](d[:x], fillrange, d[:y], facecolor = fillcolor, zorder = plt.n)
    else
      ax[:fill_between](d[:x], fillrange..., facecolor = fillcolor, zorder = plt.n)
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
end

function minmaxseries(ds, vec, axis)
  lo, hi = Inf, -Inf
  for d in ds
    d[:axis] == axis || continue
    v = d[vec]
    if length(v) > 0
      vlo, vhi = extrema(v)
      lo = min(lo, vlo)
      hi = max(hi, vhi)
    end
  end
  if lo == hi
    hi = if lo == 0
      1e-6
    else
      hi + min(abs(1e-2hi), 1e-6)
    end
  end
  lo, hi
end

# TODO: this needs to handle one-sided fixed limits
function set_lims!(plt::Plot{PyPlotPackage}, axis::Symbol)
  ax = getAxis(plt, axis)
  if plt.plotargs[:xlims] == :auto
    ax[:set_xlim](minmaxseries(plt.seriesargs, :x, axis)...)
  end
  if plt.plotargs[:ylims] == :auto
    ax[:set_ylim](minmaxseries(plt.seriesargs, :y, axis)...)
  end
end

function Base.setindex!{X,Y}(plt::Plot{PyPlotPackage}, xy::Tuple{X,Y}, i::Integer)
  d = plt.seriesargs[i]
  series = d[:serieshandle]
  x, y = xy
  d[:x], d[:y] = x, y
  try
    series[:set_data](x, y)
  catch
    series[:set_offsets](hcat(x, y))
  end

  set_lims!(plt, d[:axis])
  plt
end

function Base.setindex!{X,Y,Z}(plt::Plot{PyPlotPackage}, xyz::Tuple{X,Y,Z}, i::Integer)
  warn("setindex not implemented for xyz")
  plt
end

# -----------------------------------------------------------------

function addPyPlotLims(ax, lims, isx::Bool)
  lims == :auto && return
  ltype = limsType(lims)
  if ltype == :limits
    if isx
      isfinite(lims[1]) && ax[:set_xlim](left = lims[1])
      isfinite(lims[2]) && ax[:set_xlim](right = lims[2])
    else
      isfinite(lims[1]) && ax[:set_ylim](bottom = lims[1])
      isfinite(lims[2]) && ax[:set_ylim](top = lims[2])
    end
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
    ax[isx ? :set_xticks : :set_yticks](ticks[1])
    ax[isx ? :set_xticklabels : :set_yticklabels](ticks[2])
  else
    error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
  end
end

usingRightAxis(plt::Plot{PyPlotPackage}) = any(args -> args[:axis] in (:right,:auto), plt.seriesargs)

function _update_plot(plt::Plot{PyPlotPackage}, d::Dict)
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
    sz = get(d, :guidefont, plt.plotargs[:guidefont]).pointsize
    ax[:title][:set_fontsize](sz)
    ax[:xaxis][:label][:set_fontsize](sz)
    ax[:yaxis][:label][:set_fontsize](sz)

    # ticks
    sz = get(d, :tickfont, plt.plotargs[:tickfont]).pointsize
    for sym in (:get_xticklabels, :get_yticklabels)
      for lab in ax[sym]()
        lab[:set_fontsize](sz)
      end
    end

    # grid
    if get(d, :grid, false)
      ax[:xaxis][:grid](true)
      ax[:yaxis][:grid](true)
      ax[:set_axisbelow](true)
    end
  end

end

function applyPyPlotScale(ax, scaleType::Symbol, isx::Bool)
  func = ax[isx ? :set_xscale : :set_yscale]
  scaleType == :identity && return func("linear")
  scaleType == :ln && return func("log", basex = e, basey = e)
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

function _add_annotations{X,Y,V}(plt::Plot{PyPlotPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    createPyPlotAnnotationObject(plt, ann...)
  end
end

# -----------------------------------------------------------------

# NOTE: pyplot needs to build before
function _create_subplot(subplt::Subplot{PyPlotPackage}, isbefore::Bool)
  l = subplt.layout

  # w,h = map(px2inch, getplotargs(subplt,1)[:size])
  # bgcolor = getPyPlotColor(getplotargs(subplt,1)[:background_color])
  # fig = PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = DPI, tight_layout = true)
  plotargs = getplotargs(subplt, 1)
  fig = pyplot_figure(plotargs)

  nr = nrows(l)
  for (i,(r,c)) in enumerate(l)

    # add the plot to the figure
    nc = ncols(l, r)
    fakeidx = (r-1) * nc + c
    ax = fig[:add_subplot](nr, nc, fakeidx)

    subplt.plts[i].o = PyPlotAxisWrapper(ax, nothing, fig, [])
    pyplot_3d_setup!(subplt.plts[i].o, plotargs)
  end

  # subplt.o = PyPlotFigWrapper(fig, [])
  subplt.o = PyPlotAxisWrapper(nothing, nothing, fig, [])
  pyplot_3d_setup!(subplt.o, plotargs)
  true
end

# this will be called internally, when creating a subplot from existing plots
# NOTE: if I ever need to "Rebuild a "ubplot from individual Plot's"... this is what I should use!
function subplot(plts::AVec{Plot{PyPlotPackage}}, layout::SubplotLayout, d::Dict)
  validateSubplotSupported()

  p = length(layout)
  n = sum([plt.n for plt in plts])

  pkg = PyPlotPackage()
  newplts = Plot{PyPlotPackage}[_create_plot(pkg; subplot=true, plt.plotargs...) for plt in plts]

  subplt = Subplot(nothing, newplts, PyPlotPackage(), p, n, layout, d, true, false, false, (r,c) -> (nothing,nothing))

  _preprocess_subplot(subplt, d)
  _create_subplot(subplt, true)

  for (i,plt) in enumerate(plts)
    for seriesargs in plt.seriesargs
      _add_series_subplot(newplts[i]; seriesargs...)
    end
  end

  _postprocess_subplot(subplt, d)

  subplt
end


function _remove_axis(plt::Plot{PyPlotPackage}, isx::Bool)
  if isx
    plot!(plt, xticks=zeros(0), xlabel="")
  else
    plot!(plt, yticks=zeros(0), ylabel="")
  end
end

function _expand_limits(lims, plt::Plot{PyPlotPackage}, isx::Bool)
  pltlims = plt.o.ax[isx ? :get_xbound : :get_ybound]()
  _expand_limits(lims, pltlims)
end

# -----------------------------------------------------------------

const _pyplot_legend_pos = Dict(
    :right => "right",
    :left => "center left",
    :top => "upper center",
    :bottom => "lower center"
  )

# function addPyPlotLegend(plt::Plot)
function addPyPlotLegend(plt::Plot, ax)
  leg = plt.plotargs[:legend]
  if leg != :none
    # gotta do this to ensure both axes are included
    args = filter(x -> !(x[:linetype] in (:hist,:density,:hexbin,:heatmap,:hline,:vline,:contour, :surface, :wireframe, :path3d, :scatter3d)), plt.seriesargs)
    args = filter(x -> x[:label] != "", args)
    if length(args) > 0
      leg = ax[:legend]([d[:serieshandle] for d in args],
                  [d[:label] for d in args],
                  loc = get(_pyplot_legend_pos, leg, "best"),
                  fontsize = plt.plotargs[:legendfont].pointsize
                  # framealpha = 0.6
                 )
      leg[:set_zorder](1000)
    end
  end
end

function finalizePlot(plt::Plot{PyPlotPackage})
  ax = getLeftAxis(plt)
  addPyPlotLegend(plt, ax)
  updateAxisColors(ax, getPyPlotColor(plt.plotargs[:foreground_color]))
  PyPlot.draw()
end

function finalizePlot(subplt::Subplot{PyPlotPackage})
  fig = subplt.o.fig
  for (i,plt) in enumerate(subplt.plts)
    ax = getLeftAxis(plt)
    addPyPlotLegend(plt, ax)
    updateAxisColors(ax, getPyPlotColor(plt.plotargs[:foreground_color]))
  end
  # fig[:tight_layout]()
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
    # # PyPlot.ion()
    # PyPlot.figure(getfig(plt.o).o[:number])
    # PyPlot.draw_if_interactive()
    # # PyPlot.ioff()
  end
  # PyPlot.plt[:show](block=false)
  getfig(plt.o)[:show]()
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
    "image/svg+xml"           => "svg"
  )


for (mime, fmt) in _pyplot_mimeformats
  @eval function Base.writemime(io::IO, ::MIME{symbol($mime)}, plt::PlottingObject{PyPlotPackage})
    finalizePlot(plt)
    fig = getfig(plt.o)
    fig.o["canvas"][:print_figure](io,
                                   format=$fmt,
                                   # bbox_inches = "tight",
                                   # figsize = map(px2inch, plt.plotargs[:size]),
                                   facecolor = fig.o["get_facecolor"](),
                                   edgecolor = "none",
                                   dpi = DPI
                                  )
  end
end


# function Base.writemime(io::IO, m::MIME"image/png", subplt::Subplot{PyPlotPackage})
#   finalizePlot(subplt)
#   writemime(io, m, getfig(subplt.o))
# end
