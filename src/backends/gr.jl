
# https://github.com/jheinen/GR.jl

fig = Dict()

fig[:size] = [500, 500]

const gr_linetype = Dict(
  :auto => 0, :solid => 1, :dash => 2, :dot => 3, :dashdot => 4,
  :dashdotdot => -1 )

const gr_markertype = Dict(
  :none => 1, :ellipse => -1, :rect => -7, :diamond => -13,
  :utriangle => -3, :dtriangle => -5, :pentagon => -14,
  :cross => 2, :xcross => 5, :star5 => 3 )

function _create_plot(pkg::GRPackage; kw...)
  global fig
  d = Dict(kw)
  fig[:size] = d[:size]
  Plot(nothing, pkg, 0, d, Dict[])
end

function _add_series(::GRPackage, plt::Plot; kw...)
  d = Dict(kw)
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GRPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GRPackage})
end

function _update_plot(plt::Plot{GRPackage}, d::Dict)
  global fig

  GR.clearws()

  mwidth, mheight, width, height = GR.inqdspsize()
  w, h = fig[:size]
  if w > h
    ratio = float(h) / w
    size = mwidth * w / width
    GR.setwsviewport(0, size, 0, size * ratio)
    GR.setwswindow(0, 1, 0, ratio)
    viewport = [0.1, 0.95, 0.1 * ratio, 0.95 * ratio]
  else
    ratio = float(w) / h
    size = mheight * h / height
    GR.setwsviewport(0, size * ratio, 0, size)
    GR.setwswindow(0, ratio, 0, 1)
    viewport = [0.1 * ratio, 0.95 * ratio, 0.1, 0.95]
  end

  xmin = ymin = typemax(Float64)
  xmax = ymax = typemin(Float64)
  for p in plt.seriesargs
    x, y = p[:x], p[:y]
    xmin = min(minimum(x), xmin)
    xmax = max(maximum(x), xmax)
    ymin = min(minimum(y), ymin)
    ymax = max(maximum(y), ymax)
  end

  scale = 0
  d[:xscale] == :log10 && (scale |= GR.OPTION_X_LOG)
  d[:yscale] == :log10 && (scale |= GR.OPTION_Y_LOG)
  get(d, :xflip, false) && (scale |= GR.OPTION_FLIP_X)
  get(d, :yflip, false) && (scale |= GR.OPTION_FLIP_Y)

  if scale & GR.OPTION_X_LOG == 0
    xmin, xmax = GR.adjustlimits(xmin, xmax)
    majorx = 5
    xtick = GR.tick(xmin, xmax) / majorx
  else
    xtick = majorx = 1
  end
  if scale & GR.OPTION_Y_LOG == 0
    ymin, ymax = GR.adjustlimits(ymin, ymax)
    majory = 5
    ytick = GR.tick(ymin, ymax) / majory
  else
    ytick = majory = 1
  end
  if scale & GR.OPTION_FLIP_X == 0
    xorg = (xmin, xmax)
  else
    xorg = (xmax, xmin)
  end
  if scale & GR.OPTION_FLIP_Y == 0
    yorg = (ymin, ymax)
  else
    yorg = (ymax, ymin)
  end

  GR.setviewport(viewport[1], viewport[2], viewport[3], viewport[4])
  GR.setwindow(xmin, xmax, ymin, ymax)
  GR.setscale(scale)

  charheight = 0.03 * (viewport[4] - viewport[3])
  GR.setcharheight(charheight)
  GR.grid(xtick, ytick, 0, 0, majorx, majory)
  ticksize = 0.0125 * (viewport[2] - viewport[1])
  GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
  GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, -majory, -ticksize)

  if haskey(d, :title)
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.text(0.5, min(ratio, 1), d[:title])
    GR.restorestate()
  end
  if haskey(d, :xlabel)
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
    GR.text(0.5, 0, d[:xlabel])
    GR.restorestate()
  end
  if haskey(d, :ylabel)
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    GR.text(0, 0.5 * (viewport[3] + viewport[4]), d[:ylabel])
    GR.restorestate()
  end

  GR.savestate()
  haskey(d, :linewidth) && GR.setlinewidth(d[:linewidth])
  haskey(d, :linestyle) && GR.setlinetype(gr_linetype[d[:linestyle]])
  haskey(d, :markersize) && GR.setmarkersize(d[:markersize])
  haskey(d, :markershape) && GR.setmarkertype(gr_markertype[d[:markershape]])
  GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)

  for p in plt.seriesargs
    GR.uselinespec("")
    if p[:linetype] == :path
      GR.polyline(p[:x], p[:y])
    elseif p[:linetype] == :scatter
      GR.polymarker(p[:x], p[:y])
    end
  end

  if plt.plotargs[:legend]
    GR.selntran(0)
    GR.setscale(0)
    w = 0
    for p in plt.seriesargs
      tbx, tby = GR.inqtext(0, 0, p[:label])
      w = max(w, tbx[3])
    end
    px = viewport[2] - 0.05 - w
    py = viewport[4] - 0.06
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(0)
    GR.fillrect(px - 0.06, px + w + 0.02, py + 0.03, py - 0.03 * length(plt.seriesargs))
    GR.setlinecolorind(1)
    GR.setlinewidth(1)
    GR.drawrect(px - 0.06, px + w + 0.02, py + 0.03, py - 0.03 * length(plt.seriesargs))
    haskey(d, :linewidth) && GR.setlinewidth(d[:linewidth])
    for p in plt.seriesargs
      GR.uselinespec("")
      if p[:linetype] == :path
        GR.polyline([px - 0.05, px - 0.01], [py, py])
      elseif p[:linetype] == :scatter
        GR.polymarker([px - 0.05, px - 0.01], [py, py])
      end
      GR.text(px, py, p[:label])
      py -= 0.03
    end
    GR.selntran(1)
  end

  GR.restorestate()
  GR.updatews()
end

function _update_plot_pos_size(plt::PlottingObject{GRPackage}, d::Dict)
  global fig
  if haskey(d, :size)
    fig[:size] = d[:size]
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{GRPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end
 
function Base.setindex!(plt::Plot{GRPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GRPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{GRPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GRPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{GRPackage})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{GRPackage})
  # TODO: display/show the plot
end

function Base.display(::PlotsDisplay, plt::Subplot{GRPackage})
  # TODO: display/show the subplot
end
