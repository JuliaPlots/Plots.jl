
# https://github.com/jheinen/GR.jl

function _initialize_backend(::GRBackend; kw...)
  @eval begin
    import GR
    export GR
  end
end

const gr_linetype = KW(
  :auto => 1, :solid => 1, :dash => 2, :dot => 3, :dashdot => 4,
  :dashdotdot => -1 )

const gr_markertype = KW(
  :auto => 1, :none => -1, :ellipse => -1, :rect => -7, :diamond => -13,
  :utriangle => -3, :dtriangle => -5, :pentagon => -21, :hexagon => -22,
  :heptagon => -23, :octagon => -24, :cross => 2, :xcross => 5,
  :star4 => -25, :star5 => -26, :star6 => -27, :star7 => -28, :star8 => -29,
  :vline => -30, :hline => -31 )

const gr_halign = KW(:left => 1, :hcenter => 2, :right => 3)
const gr_valign = KW(:top => 1, :vcenter => 3, :bottom => 5)

const gr_font_family = Dict(
  "times" => 1, "helvetica" => 5, "courier" => 9, "bookman" => 14,
  "newcenturyschlbk" => 18, "avantgarde" => 22, "palatino" => 26)

function gr_getcolorind(v)
  c = getColor(v)
  return convert(Int, GR.inqcolorfromrgb(c.r, c.g, c.b))
end

function gr_getaxisind(p)
  axis = get(p, :axis, :none)
  if axis in [:none, :left]
    return 1
  else
    return 2
  end
end

function gr_setmarkershape(p)
  if haskey(p, :markershape)
    shape = p[:markershape]
    if isa(shape, Shape)
      p[:vertices] = shape.vertices
    else
      GR.setmarkertype(gr_markertype[shape])
      p[:vertices] = :none
    end
  end
end

function gr_polymarker(p, x, y)
  if p[:vertices] != :none
    vertices= p[:vertices]
    dx = Float64[el[1] for el in vertices] * 0.01
    dy = Float64[el[2] for el in vertices] * 0.01
    GR.selntran(0)
    GR.setfillcolorind(gr_getcolorind(p[:markercolor]))
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    for i = 1:length(x)
      xn, yn = GR.wctondc(x[i], y[i])
      GR.fillarea(xn + dx, yn + dy)
    end
    GR.selntran(1)
  else
    GR.polymarker(x, y)
  end
end

function gr_polyline(x, y)
  if NaN in x || NaN in y
    i = 1
    j = 1
    n = length(x)
    while i < n
      while j < n && x[j] != Nan && y[j] != NaN
        j += 1
      end
      if i < j
        GR.polyline(x[i:j], y[i:j])
      end
      i = j + 1
    end
  else
    GR.polyline(x, y)
  end
end

function gr_display(plt::Plot{GRBackend}, clear=true, update=true,
                    subplot=[0, 1, 0, 1])
  d = plt.plotargs

  clear && GR.clearws()

  mwidth, mheight, width, height = GR.inqdspsize()
  w, h = d[:size]
  viewport = zeros(4)
  vp = float(subplot)
  if w > h
    ratio = float(h) / w
    msize = mwidth * w / width
    GR.setwsviewport(0, msize, 0, msize * ratio)
    GR.setwswindow(0, 1, 0, ratio)
    vp[3] *= ratio
    vp[4] *= ratio
  else
    ratio = float(w) / h
    msize = mheight * h / height
    GR.setwsviewport(0, msize * ratio, 0, msize)
    GR.setwswindow(0, ratio, 0, 1)
    vp[1] *= ratio
    vp[2] *= ratio
  end
  viewport[1] = vp[1] + 0.125 * (vp[2] - vp[1])
  viewport[2] = vp[1] + 0.95  * (vp[2] - vp[1])
  viewport[3] = vp[3] + 0.125 * (vp[4] - vp[3])
  if w > h
    viewport[3] += (1 - (subplot[4] - subplot[3])^2) * 0.02
  end
  viewport[4] = vp[3] + 0.95  * (vp[4] - vp[3])

  if haskey(d, :background_color)
    GR.savestate()
    GR.selntran(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(gr_getcolorind(d[:background_color]))
    GR.fillrect(vp[1], vp[2], vp[3], vp[4])
    GR.selntran(1)
    GR.restorestate()
    c = getColor(d[:background_color])
    if 0.21 * c.r + 0.72 * c.g + 0.07 * c.b < 0.9
      fg = convert(Int, GR.inqcolorfromrgb(1-c.r, 1-c.g, 1-c.b))
    else
      fg = 1
    end
  else
    fg = 1
  end

  extrema = zeros(2, 4)
  num_axes = 1
  cmap = false
  axes_2d = true
  grid_flag = get(d, :grid, true)
  outside_ticks = false

  for axis = 1:2
    xmin = ymin = typemax(Float64)
    xmax = ymax = typemin(Float64)
    for p in plt.seriesargs
      if axis == gr_getaxisind(p)
        if axis == 2
          num_axes = 2
        end
        if p[:linetype] == :bar
          x, y = 1:length(p[:y]), p[:y]
        elseif p[:linetype] == :ohlc
          x, y = 1:size(p[:y], 1), p[:y]
        elseif p[:linetype] in [:hist, :density]
          x, y = Base.hist(p[:y])
        elseif p[:linetype] in [:hist2d, :hexbin]
          E = zeros(length(p[:x]),2)
          E[:,1] = p[:x]
          E[:,2] = p[:y]
          if isa(p[:nbins], Tuple)
            xbins, ybins = p[:nbins]
          else
            xbins = ybins = p[:nbins]
          end
          cmap = true
          x, y, H = Base.hist2d(E, xbins, ybins)
        elseif p[:linetype] == :pie
          axes_2d = false
          xmin, xmax, ymin, ymax = 0, 1, 0, 1
          x, y = p[:x], p[:y]
        else
          if p[:linetype] in [:contour, :surface, :heatmap]
            cmap = true
          end
          if p[:linetype] in [:surface, :wireframe, :path3d, :scatter3d]
            axes_2d = false
          end
          if p[:linetype] == :heatmap
            outside_ticks = true
          end
          x, y = p[:x], p[:y]
        end
        if p[:linetype] != :pie
          xmin = min(minimum(x), xmin)
          xmax = max(maximum(x), xmax)
          if p[:linetype] == :ohlc
            for val in y
              ymin = min(val.open, val.high, val.low, val.close, ymin)
              ymax = max(val.open, val.high, val.low, val.close, ymax)
            end
          else
            ymin = min(minimum(y), ymin)
            ymax = max(maximum(y), ymax)
          end
        end
      end
    end
    if d[:xlims] != :auto
      xmin, xmax = d[:xlims]
    end
    if d[:ylims] != :auto
      ymin, ymax = d[:ylims]
    end
    if xmax <= xmin
      xmax = xmin + 1
    end
    if ymax <= ymin
      ymax = ymin + 1
    end
    extrema[axis,:] = [xmin, xmax, ymin, ymax]
  end

  if num_axes == 2 || !axes_2d
    viewport[2] -= 0.0525
  end
  if cmap
    viewport[2] -= 0.1
  end
  GR.setviewport(viewport[1], viewport[2], viewport[3], viewport[4])

  scale = 0
  d[:xscale] == :log10 && (scale |= GR.OPTION_X_LOG)
  d[:yscale] == :log10 && (scale |= GR.OPTION_Y_LOG)
  get(d, :xflip, false) && (scale |= GR.OPTION_FLIP_X)
  get(d, :yflip, false) && (scale |= GR.OPTION_FLIP_Y)

  for axis = 1:num_axes
    xmin, xmax, ymin, ymax = extrema[axis,:]
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

    GR.setwindow(xmin, xmax, ymin, ymax)
    GR.setscale(scale)

    diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
    charheight = max(0.018 * diag, 0.01)
    GR.setcharheight(charheight)
    GR.settextcolorind(fg)

    if axes_2d
      GR.setlinewidth(1)
      GR.setlinecolorind(fg)
      ticksize = 0.0075 * diag
      if outside_ticks
        ticksize = -ticksize
      end
      if grid_flag && fg == 1
        GR.grid(xtick, ytick, 0, 0, majorx, majory)
      end
      if num_axes == 1
        GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
        GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, -majory, -ticksize)
      elseif axis == 1
        GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
      else
        GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, majory, -ticksize)
      end
    end
  end

  if get(d, :title, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.settextcolorind(fg)
    GR.text(0.5 * (viewport[1] + viewport[2]), vp[4], d[:title])
    GR.restorestate()
  end
  if get(d, :xlabel, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
    GR.settextcolorind(fg)
    GR.text(0.5 * (viewport[1] + viewport[2]), vp[3], d[:xlabel])
    GR.restorestate()
  end
  if get(d, :ylabel, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    GR.settextcolorind(fg)
    GR.text(vp[1], 0.5 * (viewport[3] + viewport[4]), d[:ylabel])
    GR.restorestate()
  end
  if get(d, :yrightlabel, "") != ""
    GR.savestate()
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(1, 0)
    GR.settextcolorind(fg)
    GR.text(vp[2], 0.5 * (viewport[3] + viewport[4]), d[:yrightlabel])
    GR.restorestate()
  end

  legend = false

  for p in plt.seriesargs
    GR.savestate()
    xmin, xmax, ymin, ymax = extrema[gr_getaxisind(p),:]
    GR.setwindow(xmin, xmax, ymin, ymax)
    if p[:linetype] in [:path, :line, :steppre, :steppost, :sticks, :hline, :vline, :ohlc]
      haskey(p, :linestyle) && GR.setlinetype(gr_linetype[p[:linestyle]])
      haskey(p, :linewidth) && GR.setlinewidth(p[:linewidth])
      haskey(p, :linecolor) && GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
    end
    if p[:linetype] == :path
      if haskey(p, :fillcolor)
        GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
      end
      if length(p[:x]) > 1
        if p[:fillrange] != nothing
          GR.fillarea([p[:x][1]; p[:x]; p[:x][length(p[:x])]], [p[:fillrange]; p[:y]; p[:fillrange]])
        end
        GR.polyline(p[:x], p[:y])
      end
      legend = true
    end
    if p[:linetype] == :line
      if length(p[:x]) > 1
        gr_polyline(p[:x], p[:y])
      end
      legend = true
    elseif p[:linetype] in [:steppre, :steppost]
      n = length(p[:x])
      x = zeros(2*n + 1)
      y = zeros(2*n + 1)
      x[1], y[1] = p[:x][1], p[:y][1]
      j = 2
      for i = 2:n
        if p[:linetype] == :steppre
          x[j], x[j+1] = p[:x][i-1], p[:x][i]
          y[j], y[j+1] = p[:y][i],   p[:y][i]
        else
          x[j], x[j+1] = p[:x][i],   p[:x][i]
          y[j], y[j+1] = p[:y][i-1], p[:y][i]
        end
        j += 2
      end
      if n > 1
        GR.polyline(x, y)
      end
      legend = true
    elseif p[:linetype] == :sticks
      x, y = p[:x], p[:y]
      for i = 1:length(y)
        GR.polyline([x[i], x[i]], [ymin, y[i]])
      end
      legend = true
    elseif p[:linetype] == :scatter || (p[:markershape] != :none && axes_2d)
      haskey(p, :markercolor) && GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
      gr_setmarkershape(p)
      if haskey(d, :markersize)
        if typeof(d[:markersize]) <: Number
          GR.setmarkersize(d[:markersize] / 4.0)
          if length(p[:x]) > 0
            gr_polymarker(p, p[:x], p[:y])
          end
        else
          c = p[:markercolor]
          GR.setcolormap(-GR.COLORMAP_GLOWING)
          for i = 1:length(p[:x])
            if isa(c, ColorGradient) && p[:zcolor] != nothing
              ci = round(Int, 1000 + p[:zcolor][i] * 255)
              GR.setmarkercolorind(ci)
            end
            GR.setmarkersize(d[:markersize][i] / 4.0)
            gr_polymarker(p, [p[:x][i]], [p[:y][i]])
          end
        end
      else
        if length(p[:x]) > 0
          gr_polymarker(p, p[:x], p[:y])
        end
      end
      legend = true
    elseif p[:linetype] == :bar
      y = p[:y]
      for i = 1:length(y)
        GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.fillrect(i-0.4, i+0.4, max(0, ymin), y[i])
        GR.setfillcolorind(1)
        GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        GR.fillrect(i-0.4, i+0.4, max(0, ymin), y[i])
      end
    elseif p[:linetype] in [:hist, :density]
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
    elseif p[:linetype] in [:hline, :vline]
      for xy in p[:y]
        if p[:linetype] == :hline
          GR.polyline([xmin, xmax], [xy, xy])
        else
          GR.polyline([xy, xy], [ymin, ymax])
        end
      end
    elseif p[:linetype] in [:hist2d, :hexbin]
      E = zeros(length(p[:x]),2)
      E[:,1] = p[:x]
      E[:,2] = p[:y]
      if isa(p[:nbins], Tuple)
        xbins, ybins = p[:nbins]
      else
        xbins = ybins = p[:nbins]
      end
      x, y, H = Base.hist2d(E, xbins, ybins)
      counts = round(Int32, 1000 + 255 * H / maximum(H))
      n, m = size(counts)
      GR.setcolormap(GR.COLORMAP_COOLWARM)
      GR.cellarray(xmin, xmax, ymin, ymax, n, m, counts)
      GR.setviewport(viewport[2] + 0.02, viewport[2] + 0.05,
                     viewport[3], viewport[4])
      GR.setspace(0, maximum(counts), 0, 90)
      diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
      charheight = max(0.016 * diag, 0.01)
      GR.setcharheight(charheight)
      GR.colormap()
    elseif p[:linetype] == :contour
      x, y, z = p[:x], p[:y], p[:z].surf
      zmin, zmax = minimum(z), maximum(z)
      if typeof(p[:levels]) <: Array
        h = p[:levels]
      else
        h = linspace(zmin, zmax, p[:levels])
      end
      GR.setspace(zmin, zmax, 0, 90)
      GR.setcolormap(GR.COLORMAP_COOLWARM)
      GR.contour(x, y, h, reshape(z, length(x) * length(y)), 1000)
      GR.setviewport(viewport[2] + 0.02, viewport[2] + 0.05,
                     viewport[3], viewport[4])
      l = round(Int32, 1000 + (h - minimum(h)) / (maximum(h) - minimum(h)) * 255)
      GR.setwindow(xmin, xmax, zmin, zmax)
      GR.cellarray(xmin, xmax, zmax, zmin, 1, length(l), l)
      ztick = 0.5 * GR.tick(zmin, zmax)
      diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
      charheight = max(0.016 * diag, 0.01)
      GR.setcharheight(charheight)
      GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)
    elseif p[:linetype] in [:surface, :wireframe]
      x, y, z = p[:x], p[:y], p[:z].surf
      zmin, zmax = GR.adjustrange(minimum(z), maximum(z))
      GR.setspace(zmin, zmax, 40, 70)
      xtick = GR.tick(xmin, xmax) / 2
      ytick = GR.tick(ymin, ymax) / 2
      ztick = GR.tick(zmin, zmax) / 2
      diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
      charheight = max(0.018 * diag, 0.01)
      ticksize = 0.01 * (viewport[2] - viewport[1])
      GR.setlinewidth(1)
      if grid_flag
        GR.grid3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2)
        GR.grid3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0)
      end
      z = reshape(z, length(x) * length(y))
      if p[:linetype] == :surface
        GR.setcolormap(GR.COLORMAP_COOLWARM)
        GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
      else
        GR.setfillcolorind(0)
        GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
      end
      GR.setlinewidth(1)
      GR.setcharheight(charheight)
      GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
      GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)
      if cmap
        GR.setviewport(viewport[2] + 0.07, viewport[2] + 0.1,
                       viewport[3], viewport[4])
        GR.colormap()
      end
    elseif p[:linetype] == :heatmap
      x, y, z = p[:x], p[:y], p[:z].surf
      zmin, zmax = GR.adjustrange(minimum(z), maximum(z))
      GR.setspace(zmin, zmax, 0, 90)
      GR.setcolormap(GR.COLORMAP_COOLWARM)
      z = reshape(z, length(x) * length(y))
      GR.surface(x, y, z, GR.OPTION_CELL_ARRAY)
      if cmap
        GR.setviewport(viewport[2] + 0.02, viewport[2] + 0.05,
                       viewport[3], viewport[4])
        GR.colormap()
      end
    elseif p[:linetype] in [:path3d, :scatter3d]
      x, y, z = p[:x], p[:y], p[:z]
      zmin, zmax = GR.adjustrange(minimum(z), maximum(z))
      GR.setspace(zmin, zmax, 40, 70)
      xtick = GR.tick(xmin, xmax) / 2
      ytick = GR.tick(ymin, ymax) / 2
      ztick = GR.tick(zmin, zmax) / 2
      diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
      charheight = max(0.018 * diag, 0.01)
      ticksize = 0.01 * (viewport[2] - viewport[1])
      GR.setlinewidth(1)
      if grid_flag && p[:linetype] == :path3d
        GR.grid3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2)
        GR.grid3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0)
      end
      if p[:linetype] == :scatter3d
        haskey(p, :markercolor) && GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
        gr_setmarkershape(p)
        for i = 1:length(z)
          px, py = GR.wc3towc(x[i], y[i], z[i])
          gr_polymarker(p, [px], [py])
        end
      else
        haskey(p, :linewidth) && GR.setlinewidth(p[:linewidth])
        if length(x) > 0
          GR.polyline3d(x, y, z)
        end
      end
      GR.setlinewidth(1)
      GR.setcharheight(charheight)
      GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
      GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)
    elseif p[:linetype] == :ohlc
      y = p[:y]
      n = size(y, 1)
      ticksize = 0.5 * (xmax - xmin) / n
      for i in 1:n
        GR.polyline([i-ticksize, i], [y[i].open, y[i].open])
        GR.polyline([i, i], [y[i].low, y[i].high])
        GR.polyline([i, i+ticksize], [y[i].close, y[i].close])
      end
    elseif p[:linetype] == :pie
      GR.selntran(0)
      GR.setfillintstyle(GR.INTSTYLE_SOLID)
      xmin, xmax, ymin, ymax = viewport
      ymax -= 0.05 * (xmax - xmin)
      xcenter = 0.5 * (xmin + xmax)
      ycenter = 0.5 * (ymin + ymax)
      if xmax - xmin > ymax - ymin
        r = 0.5 * (ymax - ymin)
        xmin, xmax = xcenter - r, xcenter + r
      else
        r = 0.5 * (xmax - xmin)
        ymin, ymax = ycenter - r, ycenter + r
      end
      labels, slices = p[:x], p[:y]
      numslices = length(slices)
      total = sum(slices)
      a1 = 0
      x = zeros(3)
      y = zeros(3)
      for i in 1:numslices
        a2 = round(Int, a1 + (slices[i] / total) * 360.0)
        GR.setfillcolorind(980 + (i-1) % 20)
        GR.fillarc(xmin, xmax, ymin, ymax, a1, a2)
        alpha = 0.5 * (a1 + a2)
        cosf = r * cos(alpha * pi / 180)
        sinf = r * sin(alpha * pi / 180)
        x[1] = xcenter + cosf
        y[1] = ycenter + sinf
        x[2] = x[1] + 0.1 * cosf
        y[2] = y[1] + 0.1 * sinf
        y[3] = y[2]
        if 90 <= alpha < 270
          x[3] = x[2] - 0.05
          GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
          GR.text(x[3] - 0.01, y[3], string(labels[i]))
        else
          x[3] = x[2] + 0.05
          GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
          GR.text(x[3] + 0.01, y[3], string(labels[i]))
        end
        GR.polyline(x, y)
        a1 = a2
      end
      GR.selntran(1)
    end
    GR.restorestate()
  end

  if d[:legend] != :none && legend
    GR.savestate()
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
    dy = 0.03 * sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(0)
    GR.fillrect(px - 0.08, px + w + 0.02, py + dy, py - dy * length(plt.seriesargs))
    GR.setlinetype(1)
    GR.setlinewidth(1)
    GR.drawrect(px - 0.08, px + w + 0.02, py + dy, py - dy * length(plt.seriesargs))
    haskey(d, :linewidth) && GR.setlinewidth(d[:linewidth])
    i = 0
    for p in plt.seriesargs
      if p[:linetype] in [:path, :line, :steppre, :steppost, :sticks]
        haskey(p, :linecolor) && GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
        haskey(p, :linestyle) && GR.setlinetype(gr_linetype[p[:linestyle]])
        GR.polyline([px - 0.07, px - 0.01], [py, py])
      end
      if p[:linetype] == :scatter || p[:markershape] != :none
        haskey(p, :markercolor) && GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
        gr_setmarkershape(p)
        if p[:linetype] in [:path, :line, :steppre, :steppost, :sticks]
          gr_polymarker(p, [px - 0.06, px - 0.02], [py, py])
        else
          gr_polymarker(p, [px - 0.06, px - 0.04, px - 0.02], [py, py, py])
        end
      end
      if typeof(p[:label]) <: Array
        i += 1
        lab = p[:label][i]
      else
        lab = p[:label]
      end
      GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
      GR.settextcolorind(1)
      GR.text(px, py, lab)
      py -= dy
    end
    GR.selntran(1)
    GR.restorestate()
  end

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

  update && GR.updatews()
end

function gr_display(subplt::Subplot{GRBackend})
  clear = true
  update = false
  l = enumerate(subplt.layout)
  nr = nrows(subplt.layout)
  for (i, (r, c)) in l
    nc = ncols(subplt.layout, r)
    if i == length(l)
      update = true
    end
    subplot = [(c-1)/nc, c/nc, 1-r/nr, 1-(r-1)/nr]
    gr_display(subplt.plts[i], clear, update, subplot)
    clear = false
  end
end

function _create_plot(pkg::GRBackend; kw...)
  d = KW(kw)
  Plot(nothing, pkg, 0, d, KW[])
end

function _add_series(::GRBackend, plt::Plot; kw...)
  d = KW(kw)
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GRBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  if haskey(plt.plotargs, :anns)
    append!(plt.plotargs[:anns], anns)
  else
    plt.plotargs[:anns] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GRBackend})
end

function _update_plot(plt::Plot{GRBackend}, d::KW)
  for k in (:title, :xlabel, :ylabel)
    haskey(d, k) && (plt.plotargs[k] = d[k])
  end
end

function _update_plot_pos_size(plt::AbstractPlot{GRBackend}, d::KW)
end

# ----------------------------------------------------------------

function getxy(plt::Plot{GRBackend}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function setxy!{X,Y}(plt::Plot{GRBackend}, xy::Tuple{X,Y}, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GRBackend}, isbefore::Bool)
  true
end

function _expand_limits(lims, plt::Plot{GRBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GRBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, m::MIME"image/png", plt::AbstractPlot{GRBackend})
  GR.emergencyclosegks()
  ENV["GKS_WSTYPE"] = "png"
  gr_display(plt)
  GR.emergencyclosegks()
  write(io, readall("gks.png"))
end

function Base.writemime(io::IO, m::MIME"image/svg+xml", plt::AbstractPlot{GRBackend})
  GR.emergencyclosegks()
  ENV["GKS_WSTYPE"] = "svg"
  gr_display(plt)
  GR.emergencyclosegks()
  write(io, readall("gks.svg"))
end

function Base.writemime(io::IO, m::MIME"text/html", plt::AbstractPlot{GRBackend})
  writemime(io, MIME("image/svg+xml"), plt)
end

function Base.writemime(io::IO, m::MIME"application/pdf", plt::AbstractPlot{GRBackend})
  GR.emergencyclosegks()
  ENV["GKS_WSTYPE"] = "pdf"
  gr_display(plt)
  GR.emergencyclosegks()
  write(io, readall("gks.pdf"))
end

function Base.writemime(io::IO, m::MIME"application/postscript", plt::AbstractPlot{GRBackend})
  GR.emergencyclosegks()
  ENV["GKS_WSTYPE"] = "ps"
  gr_display(plt)
  GR.emergencyclosegks()
  write(io, readall("gks.ps"))
end

function Base.display(::PlotsDisplay, plt::Plot{GRBackend})
  gr_display(plt)
end

function Base.display(::PlotsDisplay, plt::Subplot{GRBackend})
  gr_display(plt)
  true
end
