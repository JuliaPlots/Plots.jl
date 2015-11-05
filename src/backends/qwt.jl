
# https://github.com/tbreloff/Qwt.jl


# -------------------------------

@compat const _qwtAliases = Dict(
    :nbins => :heatmap_n,
    :fillrange => :fillto,
    :linewidth => :width,
    :markershape => :marker,
    :hexbin => :heatmap,
    :path => :line,
    :steppost => :step,
    :steppre => :stepinverted,
    :star5 => :star1,
    :star8 => :star2,
  )

function fixcolors(d::Dict)
  for (k,v) in d
    if typeof(v) <: ColorScheme
      d[k] = getColor(v)
    end
  end
end

function replaceQwtAliases(d, s)
  if haskey(_qwtAliases, d[s])
    d[s] = _qwtAliases[d[s]]
  end
end

function adjustQwtKeywords(plt::Plot{QwtPackage}, iscreating::Bool; kw...)
  d = Dict(kw)
  lt = d[:linetype]
  if lt == :scatter
    d[:linetype] = :none
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  elseif lt in (:hline, :vline)
    addLineMarker(plt, d)
    d[:linetype] = :none
    d[:markershape] = :ellipse
    d[:markersize] = 1
    if lt == :vline
      d[:x], d[:y] = d[:y], d[:x]
    end

  elseif !iscreating && lt == :bar
    d = barHack(; kw...)
  elseif !iscreating && lt == :hist
    d = barHack(; histogramHack(; kw...)...)
  end

  replaceQwtAliases(d, :linetype)
  replaceQwtAliases(d, :markershape)

  for k in keys(d)
    if haskey(_qwtAliases, k)
      d[_qwtAliases[k]] = d[k]
    end
  end

  d[:x] = collect(d[:x])
  d[:y] = collect(d[:y])
  
  d
end

function plot(pkg::QwtPackage; kw...)
  d = Dict(kw)
  fixcolors(d)
  dumpdict(d,"\n\n!!! plot")
  o = Qwt.plot(zeros(0,0); d..., show=false)
  plt = Plot(o, pkg, 0, d, Dict[])
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  d = adjustQwtKeywords(plt, false; kw...)
  fixcolors(d)
  dumpdict(d,"\n\n!!! plot!")
  Qwt.oplot(plt.o; d...)
  push!(plt.seriesargs, d)
  plt
end


# ----------------------------------------------------------------

function updateLimsAndTicks(plt::Plot{QwtPackage}, d::Dict, isx::Bool)
  lims = get(d, isx ? :xlims : :ylims, nothing)
  ticks = get(d, isx ? :xticks : :yticks, nothing)
  w = plt.o.widget
  axisid = Qwt.QWT.QwtPlot[isx ? :xBottom : :yLeft] 
  
  if typeof(lims) <: @compat(Union{Tuple,AVec}) && length(lims) == 2
    if isx
      plt.o.autoscale_x = false
    else
      plt.o.autoscale_y = false
    end
    w[:setAxisScale](axisid, lims...)
  end

  if typeof(ticks) <: Range
    if isx
      plt.o.autoscale_x = false
    else
      plt.o.autoscale_y = false
    end
    w[:setAxisScale](axisid, float(minimum(ticks)), float(maximum(ticks)), float(step(ticks)))
  elseif !(ticks in (nothing, :none, :auto))
    warn("Only Range types are supported for Qwt xticks/yticks. typeof(ticks)=$(typeof(ticks))")
  end

  # change the scale
  scalesym = isx ? :xscale : :yscale
  if haskey(d, scalesym)
    scaletype = d[scalesym]
    scaletype == :identity  && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLinearScaleEngine())
    # scaletype == :log       && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLogScaleEngine(e))
    # scaletype == :log2      && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLogScaleEngine(2))
    scaletype == :log10     && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLog10ScaleEngine())
    scaletype in supportedScales() || warn("Unsupported scale type: ", scaletype)
  end

end


function _update_plot(plt::Plot{QwtPackage}, d::Dict)
  haskey(d, :title) && Qwt.title(plt.o, d[:title])
  haskey(d, :xlabel) && Qwt.xlabel(plt.o, d[:xlabel])
  haskey(d, :ylabel) && Qwt.ylabel(plt.o, d[:ylabel])
  updateLimsAndTicks(plt, d, true)
  updateLimsAndTicks(plt, d, false)
end

function _update_plot_pos_size(plt::PlottingObject{QwtPackage}, d::Dict)
  haskey(d, :size) && Qwt.resizewidget(plt.o, d[:size]...)
  haskey(d, :pos) && Qwt.movewidget(plt.o, d[:pos]...)
end


# ----------------------------------------------------------------

        # curve.setPen(Qt.QPen(Qt.QColor(color), linewidth, self.getLineStyle(linestyle)))
function addLineMarker(plt::Plot{QwtPackage}, d::Dict)
  for yi in d[:y]
    marker = Qwt.QWT.QwtPlotMarker()
    ishorizontal = (d[:linetype] == :hline)
    marker[:setLineStyle](ishorizontal ? 1 : 2)
    marker[ishorizontal ? :setYValue : :setXValue](yi)
    qcolor = Qwt.convertRGBToQColor(getColor(d[:color]))
    linestyle = plt.o.widget[:getLineStyle](string(d[:linestyle]))
    marker[:setLinePen](Qwt.QT.QPen(qcolor, d[:linewidth], linestyle))
    marker[:attach](plt.o.widget)
  end

  # marker[:setValue](x, y)
  # marker[:setLabel](Qwt.QWT.QwtText(val))
  # marker[:attach](plt.o.widget)
end

function createQwtAnnotation(plt::Plot, x, y, val::PlotText)
  marker = Qwt.QWT.QwtPlotMarker()
  marker[:setValue](x, y)
  qwttext = Qwt.QWT.QwtText(val.str)
  qwttext[:setFont](Qwt.QT.QFont(val.font.family, val.font.pointsize))
  qwttext[:setColor](Qwt.convertRGBToQColor(getColor(val.font.color)))
  marker[:setLabel](qwttext)
  marker[:attach](plt.o.widget)
end

function createQwtAnnotation(plt::Plot, x, y, val::@compat(AbstractString))
  marker = Qwt.QWT.QwtPlotMarker()
  marker[:setValue](x, y)
  marker[:setLabel](Qwt.QWT.QwtText(val))
  marker[:attach](plt.o.widget)
end

function _add_annotations{X,Y,V}(plt::Plot{QwtPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    createQwtAnnotation(plt, ann...)
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{QwtPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{QwtPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end


# -------------------------------

# savepng(::QwtPackage, plt::PlottingObject, fn::@compat(AbstractString), args...) = Qwt.savepng(plt.o, fn)

# -------------------------------

# create the underlying object (each backend will do this differently)
function _create_subplot(subplt::Subplot{QwtPackage}, isbefore::Bool)
  isbefore && return false
  i = 0
  rows = Any[]
  row = Any[]
  for (i,(r,c)) in enumerate(subplt.layout)
    push!(row, subplt.plts[i].o)
    if c == ncols(subplt.layout, r)
      push!(rows, Qwt.hsplitter(row...))
      row = Any[]
    end
  end
  # for rowcnt in subplt.layout.rowcounts
  #   push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
  #   i += rowcnt
  # end
  subplt.o = Qwt.vsplitter(rows...)
  # Qwt.resizewidget(subplt.o, getinitargs(subplt,1)[:size]...)
  # Qwt.moveToLastScreen(subplt.o)  # hack so it goes to my center monitor... sorry
  true
end

function _expand_limits(lims, plt::Plot{QwtPackage}, isx::Bool)
  for series in plt.o.lines
    _expand_limits(lims, isx ? series.x : series.y)
  end
end


function _remove_axis(plt::Plot{QwtPackage}, isx::Bool)
end


# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::Plot{QwtPackage})
  Qwt.refresh(plt.o)
  Qwt.savepng(plt.o, "/tmp/dfskjdhfkh.png")
  write(io, readall("/tmp/dfskjdhfkh.png"))
end

function Base.writemime(io::IO, ::MIME"image/png", subplt::Subplot{QwtPackage})
  for plt in subplt.plts
    Qwt.refresh(plt.o)
  end
  Qwt.savepng(subplt.o, "/tmp/dfskjdhfkh.png")
  write(io, readall("/tmp/dfskjdhfkh.png"))
end


function Base.display(::PlotsDisplay, plt::Plot{QwtPackage})
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

function Base.display(::PlotsDisplay, subplt::Subplot{QwtPackage})
  for plt in subplt.plts
    Qwt.refresh(plt.o)
  end
  # iargs = getinitargs(subplt,1)
  # # iargs = subplt.initargs
  # Qwt.resizewidget(subplt.o, iargs[:size]...)
  # Qwt.movewidget(subplt.o, iargs[:pos]...)
  Qwt.showwidget(subplt.o)
end

