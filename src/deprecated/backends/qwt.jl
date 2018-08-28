
# https://github.com/tbreloff/Qwt.jl


supported_attrs(::QwtBackend) = merge_with_base_supported([
    :annotations,
    :linecolor,
    :fillrange,
    :fillcolor,
    :label,
    :legend,
    :seriescolor, :seriesalpha,
    :linestyle,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    :bins,
    :pos,
    :title,
    :window_title,
    :guide, :lims, :ticks, :scale,
  ])
supported_types(::QwtBackend) = [:path, :scatter, :hexbin, :bar]
supported_markers(::QwtBackend) = [:none, :auto, :rect, :circle, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :star8, :hexagon]
supported_scales(::QwtBackend) = [:identity, :log10]
is_subplot_supported(::QwtBackend) = true


# --------------------------------------------------------------------------------------

function _initialize_backend(::QwtBackend; kw...)
  @eval begin
    @warn("Qwt is no longer supported... many features will likely be broken.")
    import Qwt
    export Qwt
  end
end

# -------------------------------

const _qwtAliases = KW(
    :bins => :heatmap_n,
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

function fixcolors(plotattributes::KW)
  for (k,v) in plotattributes
    if typeof(v) <: ColorScheme
      plotattributes[k] = getColor(v)
    end
  end
end

function replaceQwtAliases(plotattributes, s)
  if haskey(_qwtAliases, plotattributes[s])
    plotattributes[s] = _qwtAliases[plotattributes[s]]
  end
end

function adjustQwtKeywords(plt::Plot{QwtBackend}, iscreating::Bool; kw...)
  plotattributes = KW(kw)
  st = plotattributes[:seriestype]
  if st == :scatter
    plotattributes[:seriestype] = :none
    if plotattributes[:markershape] == :none
      plotattributes[:markershape] = :circle
    end

  elseif st in (:hline, :vline)
    addLineMarker(plt, plotattributes)
    plotattributes[:seriestype] = :none
    plotattributes[:markershape] = :circle
    plotattributes[:markersize] = 1
    if st == :vline
      plotattributes[:x], plotattributes[:y] = plotattributes[:y], plotattributes[:x]
    end

  elseif !iscreating && st == :bar
    plotattributes = barHack(; kw...)
  elseif !iscreating && st == :histogram
    plotattributes = barHack(; histogramHack(; kw...)...)
  end

  replaceQwtAliases(plotattributes, :seriestype)
  replaceQwtAliases(plotattributes, :markershape)

  for k in keys(plotattributes)
    if haskey(_qwtAliases, k)
      plotattributes[_qwtAliases[k]] = plotattributes[k]
    end
  end

  plotattributes[:x] = collect(plotattributes[:x])
  plotattributes[:y] = collect(plotattributes[:y])

  plotattributes
end

# function _create_plot(pkg::QwtBackend, plotattributes::KW)
function _create_backend_figure(plt::Plot{QwtBackend})
  fixcolors(plt.attr)
  dumpdict(plt.attr,"\n\n!!! plot")
  o = Qwt.plot(zeros(0,0); plt.attr..., show=false)
  # plt = Plot(o, pkg, 0, plotattributes, KW[])
  # plt
end

# function _series_added(::QwtBackend, plt::Plot, plotattributes::KW)
function _series_added(plt::Plot{QwtBackend}, series::Series)
  plotattributes = adjustQwtKeywords(plt, false; series.plotattributes...)
  fixcolors(plotattributes)
  dumpdict(plotattributes,"\n\n!!! plot!")
  Qwt.oplot(plt.o; plotattributes...)
  # push!(plt.seriesargs, plotattributes)
  # plt
end


# ----------------------------------------------------------------

function updateLimsAndTicks(plt::Plot{QwtBackend}, plotattributes::KW, isx::Bool)
  lims = get(plotattributes, isx ? :xlims : :ylims, nothing)
  ticks = get(plotattributes, isx ? :xticks : :yticks, nothing)
  w = plt.o.widget
  axisid = Qwt.QWT.QwtPlot[isx ? :xBottom : :yLeft]

  if typeof(lims) <: Union{Tuple,AVec} && length(lims) == 2
    if isx
      plt.o.autoscale_x = false
    else
      plt.o.autoscale_y = false
    end
    w[:setAxisScale](axisid, lims...)
  end

  if typeof(ticks) <: AbstractRange
    if isx
      plt.o.autoscale_x = false
    else
      plt.o.autoscale_y = false
    end
    w[:setAxisScale](axisid, float(minimum(ticks)), float(maximum(ticks)), float(step(ticks)))
  elseif !(ticks in (nothing, :none, :auto))
    @warn("Only Range types are supported for Qwt xticks/yticks. typeof(ticks)=$(typeof(ticks))")
  end

  # change the scale
  scalesym = isx ? :xscale : :yscale
  if haskey(plotattributes, scalesym)
    scaletype = plotattributes[scalesym]
    scaletype == :identity  && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLinearScaleEngine())
    # scaletype == :log       && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLogScaleEngine(e))
    # scaletype == :log2      && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLogScaleEngine(2))
    scaletype == :log10     && w[:setAxisScaleEngine](axisid, Qwt.QWT.QwtLog10ScaleEngine())
    scaletype in supported_scales() || @warn("Unsupported scale type: ", scaletype)
  end

end


function _update_plot_object(plt::Plot{QwtBackend}, plotattributes::KW)
  haskey(plotattributes, :title) && Qwt.title(plt.o, plotattributes[:title])
  haskey(plotattributes, :xguide) && Qwt.xlabel(plt.o, plotattributes[:xguide])
  haskey(plotattributes, :yguide) && Qwt.ylabel(plt.o, plotattributes[:yguide])
  updateLimsAndTicks(plt, plotattributes, true)
  updateLimsAndTicks(plt, plotattributes, false)
end

function _update_plot_pos_size(plt::AbstractPlot{QwtBackend}, plotattributes::KW)
  haskey(plotattributes, :size) && Qwt.resizewidget(plt.o, plotattributes[:size]...)
  haskey(plotattributes, :pos) && Qwt.movewidget(plt.o, plotattributes[:pos]...)
end


# ----------------------------------------------------------------

        # curve.setPen(Qt.QPen(Qt.QColor(color), linewidth, self.getLineStyle(linestyle)))
function addLineMarker(plt::Plot{QwtBackend}, plotattributes::KW)
  for yi in plotattributes[:y]
    marker = Qwt.QWT.QwtPlotMarker()
    ishorizontal = (plotattributes[:seriestype] == :hline)
    marker[:setLineStyle](ishorizontal ? 1 : 2)
    marker[ishorizontal ? :setYValue : :setXValue](yi)
    qcolor = Qwt.convertRGBToQColor(getColor(plotattributes[:linecolor]))
    linestyle = plt.o.widget[:getLineStyle](string(plotattributes[:linestyle]))
    marker[:setLinePen](Qwt.QT.QPen(qcolor, plotattributes[:linewidth], linestyle))
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

function createQwtAnnotation(plt::Plot, x, y, val::AbstractString)
  marker = Qwt.QWT.QwtPlotMarker()
  marker[:setValue](x, y)
  marker[:setLabel](Qwt.QWT.QwtText(val))
  marker[:attach](plt.o.widget)
end

function _add_annotations(plt::Plot{QwtBackend}, anns::AVec{Tuple{X,Y,V}}) where {X,Y,V}
  for ann in anns
    createQwtAnnotation(plt, ann...)
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function getxy(plt::Plot{QwtBackend}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function setxy!(plt::Plot{QwtBackend}, xy::Tuple{X,Y}, i::Integer) where {X,Y}
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end


# -------------------------------

# -------------------------------

# # create the underlying object (each backend will do this differently)
# function _create_subplot(subplt::Subplot{QwtBackend}, isbefore::Bool)
#   isbefore && return false
#   i = 0
#   rows = Any[]
#   row = Any[]
#   for (i,(r,c)) in enumerate(subplt.layout)
#     push!(row, subplt.plts[i].o)
#     if c == ncols(subplt.layout, r)
#       push!(rows, Qwt.hsplitter(row...))
#       row = Any[]
#     end
#   end
#   # for rowcnt in subplt.layout.rowcounts
#   #   push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
#   #   i += rowcnt
#   # end
#   subplt.o = Qwt.vsplitter(rows...)
#   # Qwt.resizewidget(subplt.o, getattr(subplt,1)[:size]...)
#   # Qwt.moveToLastScreen(subplt.o)  # hack so it goes to my center monitor... sorry
#   true
# end

function _expand_limits(lims, plt::Plot{QwtBackend}, isx::Bool)
  for series in plt.o.lines
    _expand_limits(lims, isx ? series.x : series.y)
  end
end


function _remove_axis(plt::Plot{QwtBackend}, isx::Bool)
end


# ----------------------------------------------------------------

function Base.show(io::IO, ::MIME"image/png", plt::Plot{QwtBackend})
  Qwt.refresh(plt.o)
  Qwt.savepng(plt.o, "/tmp/dfskjdhfkh.png")
  write(io, readall("/tmp/dfskjdhfkh.png"))
end

# function Base.show(io::IO, ::MIME"image/png", subplt::Subplot{QwtBackend})
#   for plt in subplt.plts
#     Qwt.refresh(plt.o)
#   end
#   Qwt.savepng(subplt.o, "/tmp/dfskjdhfkh.png")
#   write(io, readall("/tmp/dfskjdhfkh.png"))
# end


function Base.display(::PlotsDisplay, plt::Plot{QwtBackend})
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

# function Base.display(::PlotsDisplay, subplt::Subplot{QwtBackend})
#   for plt in subplt.plts
#     Qwt.refresh(plt.o)
#   end
#   Qwt.showwidget(subplt.o)
# end
