
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

export qwt
qwt() = backend(:qwt)

# supportedArgs(::QwtPackage) = setdiff(_allArgs, [:xlims, :ylims, :xticks, :yticks])
supportedArgs(::QwtPackage) = [
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
    :heatmap_c,
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
    :pos,
    :reg,
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
supportedTypes(::QwtPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline]
supportedMarkers(::QwtPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon]
supportedScales(::QwtPackage) = [:identity, :log10]

# -------------------------------

const _qwtAliases = Dict(
    :nbins => :heatmap_n,
    :fillrange => :fillto,
    :linewidth => :width,
    :markershape => :marker,
    :hexbin => :heatmap,
    :path => :line,
    :steppost => :step,
    :steppre => :stepinverted,
  )


function fixcolors(d::Dict)
  for (k,v) in d
    if typeof(v) <: ColorScheme
      d[k] = getColor(v)
    end
  end
end

function replaceLinetypeAlias(d)
  if haskey(_qwtAliases, d[:linetype])
    d[:linetype] = _qwtAliases[d[:linetype]]
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

  replaceLinetypeAlias(d)

  for k in keys(d)
    if haskey(_qwtAliases, k)
      d[_qwtAliases[k]] = d[k]
    end
  end
  
  d
end

function plot(pkg::QwtPackage; kw...)
  d = Dict(kw)
  fixcolors(d)
  o = Qwt.plot(zeros(0,0); d..., show=false)
  plt = Plot(o, pkg, 0, d, Dict[])
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  d = adjustQwtKeywords(plt, false; kw...)
  fixcolors(d)
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
  
  if typeof(lims) <: Tuple
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
  elseif ticks != nothing
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


function updatePlotItems(plt::Plot{QwtPackage}, d::Dict)
  haskey(d, :title) && Qwt.title(plt.o, d[:title])
  haskey(d, :xlabel) && Qwt.xlabel(plt.o, d[:xlabel])
  haskey(d, :ylabel) && Qwt.ylabel(plt.o, d[:ylabel])
  updateLimsAndTicks(plt, d, true)
  updateLimsAndTicks(plt, d, false)
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

function createQwtAnnotation(plt::Plot, x, y, val::AbstractString)
  marker = Qwt.QWT.QwtPlotMarker()
  marker[:setValue](x, y)
  marker[:setLabel](Qwt.QWT.QwtText(val))
  marker[:attach](plt.o.widget)
end

function addAnnotations{X,Y,V}(plt::Plot{QwtPackage}, anns::AVec{Tuple{X,Y,V}})
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

# savepng(::QwtPackage, plt::PlottingObject, fn::AbstractString, args...) = Qwt.savepng(plt.o, fn)

# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{QwtPackage})
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  subplt.o = Qwt.vsplitter(rows...)
  Qwt.resizewidget(subplt.o, subplt.initargs[1][:size]...)
  Qwt.moveToLastScreen(subplt.o)  # hack so it goes to my center monitor... sorry
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{QwtPackage})
  Qwt.savepng(plt.o, "/tmp/dfskjdhfkh.png")
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

  Qwt.showwidget(subplt.o)
end

