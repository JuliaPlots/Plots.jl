
# https://github.com/jheinen/GR.jl

const gr_linetype = Dict(
  :auto => 1, :solid => 1, :dash => 2, :dot => 3, :dashdot => 4,
  :dashdotdot => -1 )

const gr_markertype = Dict(
  :auto => 1, :none => 1, :ellipse => -1, :rect => -7, :diamond => -13,
  :utriangle => -3, :dtriangle => -5, :pentagon => -14, :hexagon => 3,
  :cross => 2, :xcross => 5, :star5 => 3 )

const gr_halign = Dict(:left => 1, :hcenter => 2, :right => 3)
const gr_valign = Dict(:top => 1, :vcenter => 3, :bottom => 5)

const gr_font_family = Dict(
  "times" => 1, "helvetica" => 5, "courier" => 9, "bookman" => 14,
  "newcenturyschlbk" => 18, "avantgarde" => 22, "palatino" => 26)

function gr_getcolorind(v)
  c = getColor(v)
  return convert(Int, GR.inqcolorfromrgb(c.r, c.g, c.b))
end

function gr_display(plt::Plot{GRPackage})
  d = plt.plotargs

  GR.clearws()

  mwidth, mheight, width, height = GR.inqdspsize()
  w, h = d[:size]
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
    if p[:linetype] == :hist
      x, y = Base.hist(p[:y])
    else
      x, y = p[:x], p[:y]
    end
    xmin = min(minimum(x), xmin)
    xmax = max(maximum(x), xmax)
    # catch exception for OHLC vectors
    try
      ymin = min(minimum(y), ymin)
      ymax = max(maximum(y), ymax)
    catch MethodError
      ymin, ymax = 0, 1
    end
  end

  scale = d[:scale]
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
  if haskey(d, :background_color)
    GR.savestate()
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(gr_getcolorind(d[:background_color]))
    GR.fillrect(xmin, xmax, ymin, ymax)
    GR.restorestate()
  end
  GR.setscale(scale)

  charheight = 0.03 * (viewport[4] - viewport[3])
  GR.setcharheight(charheight)
  GR.grid(xtick, ytick, 0, 0, majorx, majory)
  ticksize = 0.0125 * (viewport[2] - viewport[1])
  GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
  GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, -majory, -ticksize)

  if get(d, :title, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.text(0.5, min(ratio, 1), d[:title])
    GR.restorestate()
  end
  if get(d, :xlabel, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
    GR.text(0.5, 0, d[:xlabel])
    GR.restorestate()
  end
  if get(d, :ylabel, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    GR.text(0, 0.5 * (viewport[3] + viewport[4]), d[:ylabel])
    GR.restorestate()
  end

  GR.savestate()
  haskey(d, :linewidth) && GR.setlinewidth(d[:linewidth])
  GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)

  legend = false

  for p in plt.seriesargs
    if p[:linetype] == :path
      if haskey(p, :fillcolor)
        GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
      end
      haskey(p, :linecolor) && GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
      haskey(p, :linestyle) && GR.setlinetype(gr_linetype[p[:linestyle]])
      if p[:fillrange] != nothing
        GR.fillarea([p[:x][1]; p[:x]; p[:x][length(p[:x])]], [p[:fillrange]; p[:y]; p[:fillrange]])
      end
      GR.polyline(p[:x], p[:y])
      legend = true
    end
    if p[:linetype] == :scatter || p[:markershape] != :none
      haskey(p, :markercolor) && GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
      haskey(p, :markershape) && GR.setmarkertype(gr_markertype[p[:markershape]])
      if haskey(d, :markersize)
        if typeof(d[:markersize]) <: Number
          GR.setmarkersize(d[:markersize] / 4.0)
          GR.polymarker(p[:x], p[:y])
        else
          c = p[:markercolor]
          GR.setcolormap(-GR.COLORMAP_GLOWING)
          for i = 1:length(p[:x])
            if isa(c, ColorGradient) && p[:zcolor] != nothing
              ci = round(Int, 1000 + p[:zcolor][i] * 255)
              GR.setmarkercolorind(ci)
            end
            GR.setmarkersize(d[:markersize][i] / 4.0)
            GR.polymarker([p[:x][i]], [p[:y][i]])
          end
        end
      else
        GR.polymarker(p[:x], p[:y])
      end
      legend = true
    elseif p[:linetype] == :hist
      h = Base.hist(p[:y])
      x, y = float(collect(h[1])), float(h[2])
      for i = 2:length(y)
        GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.fillrect(x[i-1], x[i], ymin, y[i])
        GR.setfillcolorind(1)
        GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        GR.fillrect(x[i-1], x[i], ymin, y[i])
      end
    elseif p[:linetype] in [:line, :steppre, :steppost, :sticks,
                            :heatmap, :hexbin, :density, :bar, :hline, :vline,
                            :contour, :path3d, :scatter3d, :surface,
                            :wireframe, :ohlc, :pie]
      println("TODO: add support for linetype $(p[:linetype])")
    end
  end

  if d[:legend] && legend
    GR.selntran(0)
    GR.setscale(0)
    w = 0
    i = 0
    for p in plt.seriesargs
      if typeof(p[:label]) <: Array
        i += 1
        lab = p[:label][i]
      else
        lab = p[:label]
      end
      tbx, tby = GR.inqtext(0, 0, lab)
      w = max(w, tbx[3])
    end
    px = viewport[2] - 0.05 - w
    py = viewport[4] - 0.06
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(0)
    GR.fillrect(px - 0.06, px + w + 0.02, py + 0.03, py - 0.03 * length(plt.seriesargs))
    GR.setlinetype(1)
    GR.setlinecolorind(1)
    GR.setlinewidth(1)
    GR.drawrect(px - 0.06, px + w + 0.02, py + 0.03, py - 0.03 * length(plt.seriesargs))
    haskey(d, :linewidth) && GR.setlinewidth(d[:linewidth])
    i = 0
    for p in plt.seriesargs
      if p[:linetype] == :path
        haskey(p, :linecolor) && GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
        haskey(p, :linestyle) && GR.setlinetype(gr_linetype[p[:linestyle]])
        GR.polyline([px - 0.05, px - 0.01], [py, py])
      end
      if p[:linetype] == :scatter || p[:markershape] != :none
        haskey(p, :markercolor) && GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
        haskey(p, :markershape) && GR.setmarkertype(gr_markertype[p[:markershape]])
        GR.polymarker([px - 0.04, px - 0.02], [py, py])
      end
      if typeof(p[:label]) <: Array
        i += 1
        lab = p[:label][i]
      else
        lab = p[:label]
      end
      GR.text(px, py, lab)
      py -= 0.03
    end
    GR.selntran(1)
  end
  GR.restorestate()

  if haskey(d, :anns)
    GR.savestate()
    for ann in d[:anns]
      x, y, val = ann
      x, y = GR.wctondc(x, y)
      alpha = val.font.rotation
      family = lowercase(val.font.family)
      GR.setcharheight(0.7 * val.font.pointsize / d[:size][2])
      GR.setcharup(sin(val.font.rotation), cos(val.font.rotation))
      if haskey(gr_font_family, family)
        GR.settextfontprec(100 + gr_font_family[family], GR.TEXT_PRECISION_STRING)
      end
      GR.settextcolorind(gr_getcolorind(val.font.color))
      GR.settextalign(gr_halign[val.font.halign], gr_valign[val.font.valign])
      GR.text(x, y, val.str)
    end
    GR.restorestate()
  end

  GR.updatews()
end

function _create_plot(pkg::GRPackage; kw...)
  isijulia() && GR.inline("png")
  d = Dict(kw)
  Plot(nothing, pkg, 0, d, Dict[])
end

function _add_series(::GRPackage, plt::Plot; kw...)
  d = Dict(kw)
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GRPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  if haskey(plt.plotargs, :anns)
    append!(plt.plotargs[:anns], anns)
  else
    plt.plotargs[:anns] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GRPackage})
end

function _update_plot(plt::Plot{GRPackage}, d::Dict)
  scale = 0
  d[:xscale] == :log10 && (scale |= GR.OPTION_X_LOG)
  d[:yscale] == :log10 && (scale |= GR.OPTION_Y_LOG)
  get(d, :xflip, false) && (scale |= GR.OPTION_FLIP_X)
  get(d, :yflip, false) && (scale |= GR.OPTION_FLIP_Y)
  plt.plotargs[:scale] = scale

  for k in (:title, :xlabel, :ylabel)
    haskey(d, k) && (plt.plotargs[k] = d[k])
  end
end

function _update_plot_pos_size(plt::PlottingObject{GRPackage}, d::Dict)
end

# ----------------------------------------------------------------

function Base.getindex(plt::Plot{GRPackage}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function Base.setindex!(plt::Plot{GRPackage}, xy::Tuple, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GRPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{GRPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GRPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, m::MIME"image/png", plt::PlottingObject{GRPackage})
  isijulia() || return
  gr_display(plt)
  GR.emergencyclosegks()
  write(io, readall("gks.png"))
end

function Base.display(::PlotsDisplay, plt::Plot{GRPackage})
  gr_display(plt)
end

function Base.display(::PlotsDisplay, plt::Subplot{GRPackage})
  # TODO: display/show the subplot
end
