
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

export gadfly
gadfly() = backend(:gadfly)


# supportedArgs(::GadflyPackage) = setdiff(_allArgs, [:heatmap_c, :pos, :screen, :yrightlabel])
supportedArgs(::GadflyPackage) = [
    :annotation,
    # :args,
    # :axis,
    :background_color,
    :color,
    :color_palette,
    :fillrange,
    :fillcolor,
    # :foreground_color,
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
    :reg,
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
    # :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
  ]
supportedAxes(::GadflyPackage) = [:auto, :left]
supportedTypes(::GadflyPackage) = [:none, :line, :path, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline, :ohlc]
supportedStyles(::GadflyPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GadflyPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon, :octagon]
supportedScales(::GadflyPackage) = [:identity, :log, :log2, :log10, :asinh, :sqrt]


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
    unshift!(gplt.guides, Gadfly.Guide.manual_color_key("", @compat(AbstractString)[], Color[]))
  end

  gplt.theme = Gadfly.Theme(background_color = getColor(d[:background_color]))
  gplt
end


function getLineGeoms(d::Dict)
  lt = d[:linetype]
  xbins, ybins = maketuple(d[:nbins])
  lt == :hexbin && return [Gadfly.Geom.hexbin(xbincount = xbins, ybincount = ybins)]
  lt == :heatmap && return [Gadfly.Geom.histogram2d(xbincount = xbins, ybincount = ybins)]
  lt == :hist && return [Gadfly.Geom.histogram(bincount = xbins)]
  # lt == :none && return [Gadfly.Geom.path]
  lt == :path && return [Gadfly.Geom.path]
  # lt == :scatter && return [Gadfly.Geom.point]
  lt == :bar && return [Gadfly.Geom.bar]
  lt == :steppost && return [Gadfly.Geom.step]

  # NOTE: we won't actually show this (we'll set linewidth to 0 later), but we need a geom so that Gadfly doesn't complain
  if lt in (:none, :ohlc, :scatter)
    return [Gadfly.Geom.path]
  end

  # lt == :sticks && return [Gadfly.Geom.bar]
  error("linetype $lt not currently supported with Gadfly")
end



# serious hack (I think?) to draw my own shapes as annotations... will it work? who knows...
function getMarkerGeomsAndGuides(d::Dict, initargs::Dict)
  marker = d[:markershape]
  if marker == :none && d[:linetype] != :ohlc
    return Any[], Any[]
  end
  return Any[], [createGadflyAnnotation(d, initargs)]
end



function addGadflyFixedLines!(gplt, d::Dict, theme)
  
  sz = d[:linewidth] * Gadfly.px
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


createSegments(z) = collect(repmat(z',2,1))[2:end]
Base.first(c::Colorant) = c

function addGadflySeries!(gplt, d::Dict, initargs::Dict)

  gfargs = Any[]

  # if my PR isn't present, don't set the line_style
  local extra_theme_args
  try
    extra_theme_args = [(:line_style, Gadfly.get_stroke_vector(d[:linestyle]))]
  catch
    extra_theme_args = Any[]
  end
  
  # set theme: color, line linewidth, and point size
  line_width = d[:linewidth] * (d[:linetype] in (:none, :ohlc, :scatter) ? 0 : 1) * Gadfly.px  # 0 linewidth when we don't show a line
  # line_color = isa(d[:color], AbstractVector) ? colorant"black" : d[:color]
  line_color = getColor(d[:color])
  fillcolor = getColor(d[:fillcolor])
  # @show fillcolor
  # fg = initargs[:foreground_color]
  theme = Gadfly.Theme(; default_color = line_color,
                       line_width = line_width,
                       default_point_size = d[:markersize] * Gadfly.px,
                       # grid_color = fg,
                       # minor_label_color = fg,
                       # major_label_color = fg,
                       # key_title_color = fg,
                       # key_label_color = fg,
                       lowlight_color = x->RGB(fillcolor),
                       lowlight_opacity = alpha(fillcolor),
                       bar_highlight = RGB(line_color),
                       extra_theme_args...)
  push!(gfargs, theme)

  # first things first... lets do the sticks hack
  if d[:linetype] == :sticks
    d, dScatter = sticksHack(;d...)

    # add the annotation
    if dScatter[:markershape] != :none
      push!(gplt.guides, createGadflyAnnotation(dScatter, initargs))
    end

  elseif d[:linetype] in (:hline, :vline)
    addGadflyFixedLines!(gplt, d, theme)
    return

  end

  if d[:linetype] == :scatter
    d[:linetype] = :none
    if d[:markershape] in (:none,:ellipse)
      push!(gfargs, Gadfly.Geom.point)
      d[:markershape] = :none
    # if d[:markershape] == :none
    #   d[:markershape] = :ellipse
    end
  end

  # add the Geoms
  append!(gfargs, getLineGeoms(d))

  # colorgroup
  z = d[:z]

  # handle line segments of different colors
  cscheme = d[:color]
  if isa(cscheme, ColorVector)
    # create a color scale, and set the color group to the index of the color
    push!(gplt.scales, Gadfly.Scale.color_discrete_manual(cscheme.v...))

    # this is super weird, but... oh well... for some reason this creates n separate line segments...
    # create a list of vertices that go: [x1,x2,x2,x3,x3, ... ,xi,xi, ... xn,xn] (same for y)
    # then the vector passed to the "color" keyword should be a vector: [1,1,2,2,3,3,4,4, ..., i,i, ... , n,n]
    csindices = Int[mod1(i,length(cscheme.v)) for i in 1:length(d[:y])]
    cs = collect(repmat(csindices', 2, 1))[1:end-1]
    grp = collect(repmat((1:length(d[:y]))', 2, 1))[1:end-1]
    d[:x], d[:y] = map(createSegments, (d[:x], d[:y]))
    colorgroup = [(:color, cs), (:group, grp)]

  # handle continuous color scales for the markers
  elseif z != nothing && typeof(z) <: AVec
    colorgroup = [(:color, z)]
    # minz, maxz = minimum(z), maximum(z)
    if !isa(d[:markercolor], ColorGradient)
      d[:markercolor] = colorscheme(:bluesreds)
    end
    push!(gplt.scales, Gadfly.Scale.ContinuousColorScale(p -> RGB(getColorZ(d[:markercolor], p)))) # minz + p * (maxz - minz))))
    
  # nothing special...
  else
    colorgroup = Any[]
  end

  # fills/ribbons
  yminmax = Any[]
  if d[:fillrange] != nothing
    fillmin, fillmax = map(makevec, maketuple(d[:fillrange]))
    nmin, nmax = length(fillmin), length(fillmax)
    push!(yminmax, (:ymin, Float64[min(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]))
    push!(yminmax, (:ymax, Float64[max(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]))
    push!(gfargs, Gadfly.Geom.ribbon)
  end

  # # fillto and ribbon
  # yminmax = Any[]
  # fillto, ribbon = d[:fill], d[:ribbon]
  
  # if fillto != nothing
  #   if ribbon != nothing
  #     warn("Ignoring ribbon arg since fillto is set!")
  #   end
  #   fillto = makevec(fillto)
  #   n = length(fillto)
  #   push!(yminmax, (:ymin, Float64[min(y, fillto[mod1(i,n)]) for (i,y) in enumerate(d[:y])]))
  #   push!(yminmax, (:ymax, Float64[max(y, fillto[mod1(i,n)]) for (i,y) in enumerate(d[:y])]))
  #   push!(gfargs, Gadfly.Geom.ribbon)
  
  # elseif ribbon != nothing
  #   ribbon = makevec(ribbon)
  #   n = length(ribbon)
  #   @show ribbon
  #   push!(yminmax, (:ymin, Float64[y - ribbon[mod1(i,n)] for (i,y) in enumerate(d[:y])]))
  #   push!(yminmax, (:ymax, Float64[y + ribbon[mod1(i,n)] for (i,y) in enumerate(d[:y])]))
  #   push!(gfargs, Gadfly.Geom.ribbon)

  # end
  
  # handle markers
  geoms, guides = getMarkerGeomsAndGuides(d, initargs)
  append!(gfargs, geoms)
  append!(gplt.guides, guides)

  # add a regression line?
  if d[:reg]
    push!(gfargs, Gadfly.Geom.smooth(method=:lm))
  end

  # add to the legend, but only without the continuous scale
  # if d[:z] == nothing
    for guide in gplt.guides
      if isa(guide, Gadfly.Guide.ManualColorKey)
        # TODO: there's a BUG in gadfly if you pass in the same color more than once,
        # since gadfly will call unique(colors), but doesn't also merge the rows that match
        # Should ensure from this side that colors which are the same are merged together

        push!(guide.labels, d[:label])
        push!(guide.colors, getColor(d[d[:markershape] == :none ? :color : :markercolor]))
      end
    # end
  end

  # for histograms, set x=y
  x = d[d[:linetype] == :hist ? :y : :x]

  if d[:axis] != :left
    warn("Gadfly only supports one y axis")
  end


  # add the layer to the Gadfly.Plot
  prepend!(gplt.layers, Gadfly.layer(unique(gfargs)...; x = x, y = d[:y], colorgroup..., yminmax...))
  nothing
end

function replaceType(vec, val)
  filter!(x -> !isa(x, typeof(val)), vec)
  push!(vec, val)
end

function addGadflyTicksGuide(gplt, ticks, isx::Bool)
  ticks == :auto && return
  ttype = ticksType(ticks)
  if ttype == :ticks
    gtype = isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks
    replaceType(gplt.guides, gtype(ticks = collect(ticks)))
  elseif ttype == :ticks_and_labels
    gtype = isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks
    replaceType(gplt.guides, gtype(ticks = collect(ticks[1])))

    # TODO add xtick_label function (given tick, return label??) 
    # Scale.x_discrete(; labels=nothing, levels=nothing, order=nothing)
    filterGadflyScale(gplt, isx)
    gfunc = isx ? Gadfly.Scale.x_discrete : Gadfly.Scale.y_discrete
    labelmap = Dict(zip(ticks...))
    labelfunc = val -> labelmap[val]
    push!(gplt.scales, gfunc(levels = ticks[1], labels = labelfunc))
  else
    error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
  end
end

continuousAndSameAxis(scale, isx::Bool) = isa(scale, Gadfly.Scale.ContinuousScale) && scale.vars[1] == (isx ? :x : :y)
# filterGadflyScale(gplt, isx::Bool) = filter!(scale -> scale.vars[1] != (isx ? :x : :y), gplt.scales)
filterGadflyScale(gplt, isx::Bool) = filter!(scale -> !continuousAndSameAxis(scale, isx), gplt.scales)


function getGadflyScaleFunction(d::Dict, isx::Bool)
  scalekey = isx ? :xscale : :yscale
  hasScaleKey = haskey(d, scalekey)
  if hasScaleKey
    scale = d[scalekey]
    scale == :log && return isx ? Gadfly.Scale.x_log : Gadfly.Scale.y_log, hasScaleKey
    scale == :log2 && return isx ? Gadfly.Scale.x_log2 : Gadfly.Scale.y_log2, hasScaleKey
    scale == :log10 && return isx ? Gadfly.Scale.x_log10 : Gadfly.Scale.y_log10, hasScaleKey
    scale == :asinh && return isx ? Gadfly.Scale.x_asinh : Gadfly.Scale.y_asinh, hasScaleKey
    scale == :sqrt && return isx ? Gadfly.Scale.x_sqrt : Gadfly.Scale.y_sqrt, hasScaleKey
  end
  isx ? Gadfly.Scale.x_continuous : Gadfly.Scale.y_continuous, hasScaleKey
end


function addGadflyLimitsScale(gplt, d::Dict, isx::Bool)

  # get the correct scale function
  gfunc, hasScaleKey = getGadflyScaleFunction(d, isx)
  # @show d gfunc hasScaleKey

  # do we want to add min/max limits for the axis?
  limsym = isx ? :xlims : :ylims
  limargs = Any[]
  if haskey(d, limsym)
    lims = d[limsym]
    lims == :auto && return
    if limsType(lims) == :limits
      # remove any existing scales, then add a new one
      # filterGadflyScale(gplt, isx)
      # gfunc = isx ? Gadfly.Scale.x_continuous : Gadfly.Scale.y_continuous
      # filter!(scale -> !isContinuousScale(scale,isx), gplt.scales)
      # push!(gplt.scales, gfunc(minvalue = min(lims...), maxvalue = max(lims...)))
      push!(limargs, (:minvalue, min(lims...)))
      push!(limargs, (:maxvalue, max(lims...)))
    else
      error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
    end
  end
  # @show limargs

  # replace any current scales with this one
  if hasScaleKey || !isempty(limargs)
    filterGadflyScale(gplt, isx)
    push!(gplt.scales, gfunc(; limargs...))
  end
  # @show gplt.scales
  return
end

function updateGadflyAxisFlips(gplt, d::Dict)
  if isa(gplt.coord, Gadfly.Coord.Cartesian)
    gplt.coord = Gadfly.Coord.cartesian(
        gplt.coord.xvars,
        gplt.coord.yvars;
        xmin = gplt.coord.xmin,
        xmax = gplt.coord.xmax,
        ymin = gplt.coord.ymin,
        ymax = gplt.coord.ymax,
        xflip = get(d, :xflip, gplt.coord.xflip),
        yflip = get(d, :yflip, gplt.coord.yflip),
        fixed = gplt.coord.fixed,
        aspect_ratio = gplt.coord.aspect_ratio,
        raster = gplt.coord.raster
      )
  else
    gplt.coord = Gadfly.Coord.Cartesian(
        xflip = get(d, :xflip, false),
        yflip = get(d, :yflip, false)
      )
  end
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


function findGuideAndSet(gplt, t::DataType, s::@compat(AbstractString))
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

  addGadflyLimitsScale(gplt, d, true)
  addGadflyLimitsScale(gplt, d, false)

  haskey(d, :xticks) && addGadflyTicksGuide(gplt, d[:xticks], true)
  haskey(d, :yticks) && addGadflyTicksGuide(gplt, d[:yticks], false)

  updateGadflyAxisFlips(gplt, d)
end

function updatePlotItems(plt::Plot{GadflyPackage}, d::Dict)
  updateGadflyGuides(plt.o, d)
end

# ----------------------------------------------------------------


function createGadflyAnnotationObject(x, y, val::@compat(AbstractString))
  Gadfly.Guide.annotation(Compose.compose(
                              Compose.context(), 
                              Compose.text(x, y, val)
                            ))
end

function addAnnotations{X,Y,V}(plt::Plot{GadflyPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    push!(plt.o.guides, createGadflyAnnotationObject(ann...))
  end
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
  rows = Any[]
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Gadfly.hstack([getGadflyContext(plt.backend, plt) for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  Gadfly.vstack(rows...)
end

function setGadflyDisplaySize(w,h)
  Compose.set_default_graphic_size(w * Compose.px, h * Compose.px)
end

function Base.writemime(io::IO, ::MIME"image/png", plt::Plot{GadflyPackage})
  gplt = getGadflyContext(plt.backend, plt)
  setGadflyDisplaySize(plt.initargs[:size]...)
  Gadfly.draw(Gadfly.PNG(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end


function Base.display(::PlotsDisplay, plt::Plot{GadflyPackage})
  setGadflyDisplaySize(plt.initargs[:size]...)
  display(plt.o)
end



function Base.writemime(io::IO, ::MIME"image/png", plt::Subplot{GadflyPackage})
  gplt = getGadflyContext(plt.backend, plt)
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
