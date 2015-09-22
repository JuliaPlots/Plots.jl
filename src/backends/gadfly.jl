
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

export gadfly!
gadfly!() = plotter!(:gadfly)


supportedArgs(::GadflyPackage) = setdiff(_allArgs, [:heatmap_c, :pos])
supportedAxes(::GadflyPackage) = setdiff(_allAxes, [:right])
supportedTypes(::GadflyPackage) = [:none, :line, :path, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline, :ohlc]
supportedStyles(::GadflyPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GadflyPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon, :octagon]


include("gadfly_shapes.jl")

function createGadflyPlotObject(d::Dict)
  @eval import DataFrames

  gplt = Gadfly.Plot()
  gplt.mapping = Dict()
  gplt.data_source = DataFrames.DataFrame()
  gplt.layers = gplt.layers[1:0]
  
  # add the title, axis labels, and theme

  gplt.guides = Gadfly.GuideElement[Gadfly.Guide.xlabel(d[:xlabel]),
                                   Gadfly.Guide.ylabel(d[:ylabel]),
                                   Gadfly.Guide.title(d[:title])]

  # add the legend?
  if d[:legend]
    unshift!(gplt.guides, Gadfly.Guide.manual_color_key("", AbstractString[], Color[]))
  end

  gplt.theme = Gadfly.Theme(background_color = d[:background_color])
  gplt
end


# function getGeoms(linetype::Symbol, marker::Symbol, markercolor::Colorant, nbins::Int)
function getLineGeoms(d::Dict)
  lt = d[:linetype]
  lt in (:heatmap,:hexbin) && return [Gadfly.Geom.hexbin(xbincount = d[:nbins], ybincount = d[:nbins])]
  lt == :hist && return [Gadfly.Geom.histogram(bincount = d[:nbins])]
  # lt == :none && return [Gadfly.Geom.path]
  lt == :path && return [Gadfly.Geom.path]
  lt == :scatter && return [Gadfly.Geom.point]
  lt == :bar && return [Gadfly.Geom.bar]
  lt == :steppost && return [Gadfly.Geom.step]

  # NOTE: we won't actually show this (we'll set width to 0 later), but we need a geom so that Gadfly doesn't complain
  if lt in (:none, :ohlc)
    return [Gadfly.Geom.path]
  end

  # lt == :sticks && return [Gadfly.Geom.bar]
  error("linetype $lt not currently supported with Gadfly")
end



# serious hack (I think?) to draw my own shapes as annotations... will it work? who knows...
function getMarkerGeomsAndGuides(d::Dict)
  marker = d[:marker]
  if marker == :none && d[:linetype] != :ohlc
    return [],[]
  end
  return [], [createGadflyAnnotation(d)]
end



function addGadflyFixedLines!(gplt, d::Dict, theme)
  
  sz = d[:width] * Gadfly.px
  c = d[:color]

  if d[:linetype] == :hline
    geom = Gadfly.Geom.hline(color=c, size=sz)
    layer = Gadfly.layer(yintercept = d[:y], geom, theme)
  else
    geom = Gadfly.Geom.vline(color=c, size=sz)
    layer = Gadfly.layer(xintercept = d[:y], geom, theme)
  end
  
  prepend!(gplt.layers, layer)
end


function getGadflyStrokeVector(linestyle::Symbol)
  dash = 12 * Compose.mm
  dot = 3 * Compose.mm
  gap = 2 * Compose.mm
  linestyle == :solid && return nothing
  linestyle == :dash && return [dash, gap]
  linestyle == :dot && return [dot, gap]
  linestyle == :dashdot && return [dash, gap, dot, gap]
  linestyle == :dashdotdot && return [dash, gap, dot, gap, dot, gap]
  error("unsupported linestyle: ", linestyle)
end



function addGadflySeries!(gplt, d::Dict, initargs::Dict)

  gfargs = []

  # if my PR isn't present, don't set the line_style
  local extra_theme_args
  try
    Gadfly.getStrokeVector(:solid)
    extra_theme_args = [(:line_style, getGadflyStrokeVector(d[:linestyle]))]
  catch
    extra_theme_args = []
  end
  # extra_theme_args = Gadfly.isdefined(:getStrokeVector) ? [(:line_style, getGadflyStrokeVector(d[:linestyle]))] : []
  # line_style = getGadflyStrokeVector(d[:linestyle])
  
  # set theme: color, line width, and point size
  line_width = d[:width] * (d[:linetype] in (:none, :ohlc) ? 0 : 1) * Gadfly.px  # 0 width when we don't show a line
  # fg = initargs[:foreground_color]
  theme = Gadfly.Theme(; default_color = d[:color],
                       line_width = line_width,
                       default_point_size = 0.5 * d[:markersize] * Gadfly.px,
                       # grid_color = fg,
                       # minor_label_color = fg,
                       # major_label_color = fg,
                       # key_title_color = fg,
                       # key_label_color = fg,
                       extra_theme_args...)
                       # line_style = line_style)
  push!(gfargs, theme)

  # first things first... lets so the sticks hack
  if d[:linetype] == :sticks
    d, dScatter = sticksHack(;d...)

    # add the annotation
    if dScatter[:marker] != :none
      push!(gplt.guides, createGadflyAnnotation(dScatter))
    end

  elseif d[:linetype] in (:hline, :vline)
    addGadflyFixedLines!(gplt, d, theme)
    return

  end

  # add the Geoms
  append!(gfargs, getLineGeoms(d))

  # fillto
  if d[:fillto] != nothing
    fillto = makevec(d[:fillto])
    n = length(fillto)
    push!(d[:kwargs], (:ymin, Float64[min(y, fillto[mod1(i,n)]) for (i,y) in enumerate(d[:y])]))
    push!(d[:kwargs], (:ymax, Float64[max(y, fillto[mod1(i,n)]) for (i,y) in enumerate(d[:y])]))
    # push!(d[:kwargs], (:ymax, Float64[max(y, fillto) for y in d[:y]]))
    push!(gfargs, Gadfly.Geom.ribbon)
  end
  
  # handle markers
  geoms, guides = getMarkerGeomsAndGuides(d)
  append!(gfargs, geoms)
  append!(gplt.guides, guides)

  # add a regression line?
  if d[:reg]
    push!(gfargs, Gadfly.Geom.smooth(method=:lm))
  end

  # add to the legend
  if length(gplt.guides) > 0 && isa(gplt.guides[1], Gadfly.Guide.ManualColorKey)
    push!(gplt.guides[1].labels, d[:label])
    push!(gplt.guides[1].colors, d[:marker] == :none ? d[:color] : d[:markercolor])
  end


  # for histograms, set x=y
  x = d[d[:linetype] == :hist ? :y : :x]

  if d[:axis] != :left
    warn("Gadly only supports one y axis")
  end


  # add the layer to the Gadfly.Plot
  # prepend!(gplt.layers, Gadfly.layer(unique(gfargs)..., d[:args]...; x = x, y = d[:y], d[:kwargs]...))
  prepend!(gplt.layers, Gadfly.layer(unique(gfargs)...; x = x, y = d[:y]))
  nothing
end

# ---------------------------------------------------------------------------

# create a blank Gadfly.Plot object
function plot(pkg::GadflyPackage; kw...)
  d = Dict(kw)
  gplt = createGadflyPlotObject(d)
  Plot(gplt, pkg, 0, d, Dict[])
end


# plot one data series
function plot!(::GadflyPackage, plt::Plot; kw...)
  d = Dict(kw)
  addGadflySeries!(plt.o, d, plt.initargs)
  push!(plt.seriesargs, d)
  plt
end


function findGuideAndSet(gplt, t::DataType, s::AbstractString)
  for (i,guide) in enumerate(gplt.guides)
    if isa(guide, t)
      gplt.guides[i] = t(s)
      # guide.label = s
    end
  end
end

function updateGadflyGuides(gplt, d::Dict)
  haskey(d, :title) && findGuideAndSet(gplt, Gadfly.Guide.title, d[:title])
  haskey(d, :xlabel) && findGuideAndSet(gplt, Gadfly.Guide.xlabel, d[:xlabel])
  haskey(d, :ylabel) && findGuideAndSet(gplt, Gadfly.Guide.ylabel, d[:ylabel])
end

function updatePlotItems(plt::Plot{GadflyPackage}, d::Dict)
  updateGadflyGuides(plt.o, d)
end

# ----------------------------------------------------------------


# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{GadflyPackage})
  subplt.o = nothing
end

# ----------------------------------------------------------------


getGadflyContext(::GadflyPackage, plt::Plot) = plt.o
getGadflyContext(::GadflyPackage, subplt::Subplot) = buildGadflySubplotContext(subplt)

# create my Compose.Context grid by hstacking and vstacking the Gadfly.Plot objects
function buildGadflySubplotContext(subplt::Subplot)
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Gadfly.hstack([getGadflyContext(plt.plotter, plt) for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  Gadfly.vstack(rows...)
end

function setGadflyDisplaySize(w,h)
  Compose.set_default_graphic_size(w * Compose.px, h * Compose.px)
end

function Base.writemime(io::IO, ::MIME"image/png", plt::Plot{GadflyPackage})
  gplt = getGadflyContext(plt.plotter, plt)
  setGadflyDisplaySize(plt.initargs[:size]...)
  Gadfly.draw(Gadfly.PNG(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end


function Base.display(::PlotsDisplay, plt::Plot{GadflyPackage})
  setGadflyDisplaySize(plt.initargs[:size]...)
  display(plt.o)
end



function Base.writemime(io::IO, ::MIME"image/png", plt::Subplot{GadflyPackage})
  gplt = getGadflyContext(plt.plotter, plt)
  setGadflyDisplaySize(plt.initargs[1][:size]...)
  Gadfly.draw(Gadfly.PNG(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end

function Base.display(::PlotsDisplay, subplt::Subplot{GadflyPackage})
  setGadflyDisplaySize(subplt.initargs[1][:size]...)
  ctx = buildGadflySubplotContext(subplt)


  # taken from Gadfly since I couldn't figure out how to do it directly

  filename = string(Gadfly.tempname(), ".html")
  output = open(filename, "w")

  plot_output = IOBuffer()
  Gadfly.draw(Gadfly.SVGJS(plot_output, Compose.default_graphic_width,
             Compose.default_graphic_height, false), ctx)
  plotsvg = takebuf_string(plot_output)

  write(output,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Gadfly Plot</title>
          <meta charset="utf-8">
        </head>
          <body>
          <script charset="utf-8">
              $(readall(Compose.snapsvgjs))
          </script>
          <script charset="utf-8">
              $(readall(Gadfly.gadflyjs))
          </script>
          $(plotsvg)
        </body>
      </html>
      """)
  close(output)
  Gadfly.open_file(filename)

  # display(buildGadflySubplotContext(subplt))
end
