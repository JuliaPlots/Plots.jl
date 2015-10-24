
# https://github.com/dcjones/Gadfly.jl

# ---------------------------------------------------------------------------


function createGadflyPlotObject(d::Dict)
  gplt = Gadfly.Plot()
  gplt.mapping = Dict()
  gplt.data_source = DataFrames.DataFrame()
  gplt.layers = gplt.layers[1:0]
  gplt.guides = Gadfly.GuideElement[Gadfly.Guide.xlabel(d[:xlabel]),
                                   Gadfly.Guide.ylabel(d[:ylabel]),
                                   Gadfly.Guide.title(d[:title])]
  gplt
end

# ---------------------------------------------------------------------------


function getLineGeom(d::Dict)
  lt = d[:linetype]
  xbins, ybins = maketuple(d[:nbins])
  if lt == :hexbin
    Gadfly.Geom.hexbin(xbincount = xbins, ybincount = ybins)
  elseif lt == :heatmap
    Gadfly.Geom.histogram2d(xbincount = xbins, ybincount = ybins)
  elseif lt == :hist
    Gadfly.Geom.histogram(bincount = xbins)
  elseif lt == :path
    Gadfly.Geom.path
  elseif lt in (:bar, :sticks)
    Gadfly.Geom.bar
  elseif lt == :steppost
    Gadfly.Geom.step
  elseif lt == :steppre
    Gadfly.Geom.step(direction = :vh)
  elseif lt == :hline
    Gadfly.Geom.hline(color = getColor(d[:color]), size = d[:linewidth] * Gadfly.px)
  elseif lt == :vline
    Gadfly.Geom.vline(color = getColor(d[:color]), size = d[:linewidth] * Gadfly.px)
  else
    nothing
  end
end

function getGadflyLineTheme(d::Dict)
  
  lc = getColor(d[:color])
  α = d[:lineopacity]
  if α != nothing
    lc = RGBA(lc, α)
  end

  fc = getColor(d[:fillcolor])
  α = d[:fillopacity]
  if α != nothing
    fc = RGBA(fc, α)
  end

  Gadfly.Theme(;
      default_color = lc,
      line_width = (d[:linetype] == :sticks ? 1 : d[:linewidth]) * Gadfly.px,
      line_style = Gadfly.get_stroke_vector(d[:linestyle]),
      lowlight_color = x->RGB(fc),  # fill/ribbon
      lowlight_opacity = alpha(fc), # fill/ribbon
      bar_highlight = RGB(lc),      # bars
    )
end

# add a line as a new layer
function addGadflyLine!(plt::Plot, d::Dict, geoms...)
  gplt = getGadflyContext(plt)
  gfargs = vcat(geoms...,
                getGadflyLineTheme(d))
  kwargs = Dict()

  # add a fill?
  if d[:fillrange] != nothing
    fillmin, fillmax = map(makevec, maketuple(d[:fillrange]))
    nmin, nmax = length(fillmin), length(fillmax)
    kwargs[:ymin] = Float64[min(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]
    kwargs[:ymax] = Float64[max(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]
    push!(gfargs, Gadfly.Geom.ribbon)
  end

  # h/vlines
  lt = d[:linetype]
  if lt == :hline
    kwargs[:yintercept] = d[:y]
  elseif lt == :vline
    kwargs[:xintercept] = d[:y]
  elseif lt == :sticks
    w = 0.01 * mean(diff(d[:x]))
    kwargs[:xmin] = d[:x] - w
    kwargs[:xmax] = d[:x] + w
  end
  
  # add the layer
  x = d[d[:linetype] == :hist ? :y : :x]
  Gadfly.layer(gfargs...; x = x, y = d[:y], kwargs...)
end


# ---------------------------------------------------------------------------


function getMarkerGeom(d::Dict)
  shape = d[:markershape]
  gadflyshape(isa(shape, Shape) ? shape : _shapes[shape])
end


function getGadflyMarkerTheme(d::Dict, initargs::Dict)
  c = getColor(d[:markercolor])
  α = d[:markeropacity]
  if α != nothing
    c = RGBA(RGB(c), α)
  end

  fg = getColor(initargs[:foreground_color])
  Gadfly.Theme(
      default_color = c,
      default_point_size = d[:markersize] * Gadfly.px,
      discrete_highlight_color = c -> fg,
      highlight_width = d[:linewidth] * Gadfly.px,
    )
end

function addGadflyMarker!(plt::Plot, d::Dict, initargs::Dict, geoms...)
  gfargs = vcat(geoms...,
                getGadflyMarkerTheme(d, initargs),
                getMarkerGeom(d))
  kwargs = Dict()

  # handle continuous color scales for the markers
  z = d[:z]
  if z != nothing && typeof(z) <: AVec
    kwargs[:color] = z
    if !isa(d[:markercolor], ColorGradient)
      d[:markercolor] = colorscheme(:bluesreds)
    end
    push!(getGadflyContext(plt).scales, Gadfly.Scale.ContinuousColorScale(p -> RGB(getColorZ(d[:markercolor], p))))
  end

  Gadfly.layer(gfargs...; x = d[:x], y = d[:y], kwargs...)
end


# ---------------------------------------------------------------------------

function addToGadflyLegend(plt::Plot, d::Dict)

  # add the legend?
  if plt.initargs[:legend]
    gplt = getGadflyContext(plt)

    # add the legend if needed
    if all(g -> !isa(g, Gadfly.Guide.ManualColorKey), gplt.guides)
      unshift!(gplt.guides, Gadfly.Guide.manual_color_key("", @compat(AbstractString)[], Color[]))
    end

    # now add the series to the legend
    for guide in gplt.guides
      if isa(guide, Gadfly.Guide.ManualColorKey)
        # TODO: there's a BUG in gadfly if you pass in the same color more than once,
        # since gadfly will call unique(colors), but doesn't also merge the rows that match
        # Should ensure from this side that colors which are the same are merged together

        c = getColor(d[d[:markershape] == :none ? :color : :markercolor])
        foundit = false
        
        # extend the label if we found this color
        for i in 1:length(guide.colors)
          if c == guide.colors[i]
            guide.labels[i] *= ", " * d[:label]
            foundit = true
          end
        end

        # didn't find the color, so add a new entry into the legend
        if !foundit
          push!(guide.labels, d[:label])
          push!(guide.colors, c)
        end
      end
    end

  end

end

getGadflySmoothing(smooth::Bool) = smooth ? [Gadfly.Geom.smooth(method=:lm)] : Any[]
getGadflySmoothing(smooth::Real) = [Gadfly.Geom.smooth(method=:loess, smoothing=float(smooth))]


function addGadflySeries!(plt::Plot, d::Dict)

  layers = Gadfly.Layer[]

  # add a regression line?
  # TODO: make more flexible
  smooth = getGadflySmoothing(d[:smooth])

  # lines
  geom = getLineGeom(d)
  if geom != nothing
    prepend!(layers, addGadflyLine!(plt, d, geom, smooth...))

    # don't add a regression for markers too
    smooth = Any[]
  end

  # special handling for ohlc and scatter
  lt = d[:linetype]
  if lt == :ohlc
    error("Haven't re-implemented after refactoring")
  elseif lt == :scatter && d[:markershape] == :none
    d[:markershape] = :ellipse
  end

  # markers
  if d[:markershape] != :none
    prepend!(layers, addGadflyMarker!(plt, d, plt.initargs, smooth...))
  end

  lt in (:hist, :heatmap, :hexbin) || addToGadflyLegend(plt, d)

  # now save the layers that apply to this series
  d[:gadflylayers] = layers
  prepend!(getGadflyContext(plt).layers, layers)
end


# ---------------------------------------------------------------------------

# NOTE: I'm leaving this here and commented out just in case I want to implement again... it was hacky code to create multi-colored line segments

#   # colorgroup
#   z = d[:z]

#   # handle line segments of different colors
#   cscheme = d[:color]
#   if isa(cscheme, ColorVector)
#     # create a color scale, and set the color group to the index of the color
#     push!(gplt.scales, Gadfly.Scale.color_discrete_manual(cscheme.v...))

#     # this is super weird, but... oh well... for some reason this creates n separate line segments...
#     # create a list of vertices that go: [x1,x2,x2,x3,x3, ... ,xi,xi, ... xn,xn] (same for y)
#     # then the vector passed to the "color" keyword should be a vector: [1,1,2,2,3,3,4,4, ..., i,i, ... , n,n]
#     csindices = Int[mod1(i,length(cscheme.v)) for i in 1:length(d[:y])]
#     cs = collect(repmat(csindices', 2, 1))[1:end-1]
#     grp = collect(repmat((1:length(d[:y]))', 2, 1))[1:end-1]
#     d[:x], d[:y] = map(createSegments, (d[:x], d[:y]))
#     colorgroup = [(:color, cs), (:group, grp)]


# ---------------------------------------------------------------------------


function addGadflyTicksGuide(gplt, ticks, isx::Bool)
  ticks == :auto && return

  # remove the ticks?
  if ticks in (:none, false, nothing)
    return addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
  end

  ttype = ticksType(ticks)

  # just the values... put ticks here, but use standard labels
  if ttype == :ticks
    gtype = isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks
    replaceType(gplt.guides, gtype(ticks = collect(ticks)))

  # set the ticks and the labels
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
  
  # do we want to add min/max limits for the axis?
  limsym = isx ? :xlims : :ylims
  limargs = Any[]
  lims = get(d, limsym, :auto)
  lims == :auto && return

  if limsType(lims) == :limits
    push!(limargs, (:minvalue, min(lims...)))
    push!(limargs, (:maxvalue, max(lims...)))
  else
    error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
  end

  # replace any current scales with this one
  if hasScaleKey || !isempty(limargs)
    filterGadflyScale(gplt, isx)
    push!(gplt.scales, gfunc(; limargs...))
  end

  lims
end

function updateGadflyAxisFlips(gplt, d::Dict, xlims, ylims)
  if isa(gplt.coord, Gadfly.Coord.Cartesian)
    gplt.coord = Gadfly.Coord.cartesian(
        gplt.coord.xvars,
        gplt.coord.yvars;
        xmin = xlims == nothing ? gplt.coord.xmin : minimum(xlims),
        xmax = xlims == nothing ? gplt.coord.xmax : maximum(xlims),
        ymin = ylims == nothing ? gplt.coord.ymin : minimum(ylims),
        ymax = ylims == nothing ? gplt.coord.ymax : maximum(ylims),
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


function findGuideAndSet(gplt, t::DataType, args...; kw...) #s::@compat(AbstractString))
  for (i,guide) in enumerate(gplt.guides)
    if isa(guide, t)
      gplt.guides[i] = t(args...; kw...)
    end
  end
end

function updateGadflyGuides(plt::Plot, d::Dict)
  gplt = getGadflyContext(plt)
  haskey(d, :title) && findGuideAndSet(gplt, Gadfly.Guide.title, d[:title])
  haskey(d, :xlabel) && findGuideAndSet(gplt, Gadfly.Guide.xlabel, d[:xlabel])
  haskey(d, :ylabel) && findGuideAndSet(gplt, Gadfly.Guide.ylabel, d[:ylabel])

  xlims = addGadflyLimitsScale(gplt, d, true)
  ylims = addGadflyLimitsScale(gplt, d, false)

  ticks = get(d, :xticks, :auto)
  if ticks == :none
    handleLinkInner(plt, true)
  else
    addGadflyTicksGuide(gplt, ticks, true)
  end
  ticks = get(d, :yticks, :auto)
  if ticks == :none
    handleLinkInner(plt, false)
  else
    addGadflyTicksGuide(gplt, ticks, false)
  end
  # haskey(d, :yticks) && addGadflyTicksGuide(gplt, d[:yticks], false)

  updateGadflyAxisFlips(gplt, d, xlims, ylims)
end

function updateGadflyPlotTheme(plt::Plot, d::Dict)
  kwargs = Dict()

  # get the full initargs, overriding any new settings
  # TODO: should this be part of the main `plot` command in plot.jl???
  d = merge!(plt.initargs, d)

  # hide the legend?
  if !get(d, :legend, true)
    kwargs[:key_position] = :none
  end

  if !get(d, :grid, true)
    kwargs[:grid_color] = getColor(d[:background_color])
  end

  # fonts
  tfont, gfont, lfont = d[:tickfont], d[:guidefont], d[:legendfont]

  fg = getColor(d[:foreground_color])
  getGadflyContext(plt).theme = Gadfly.Theme(;
          background_color = getColor(d[:background_color]),
          minor_label_color = fg,
          minor_label_font = tfont.family,
          minor_label_font_size = tfont.pointsize * Gadfly.pt,
          major_label_color = fg,
          major_label_font = gfont.family,
          major_label_font_size = gfont.pointsize * Gadfly.pt,
          key_title_color = fg,
          key_title_font = gfont.family,
          key_title_font_size = gfont.pointsize * Gadfly.pt,
          key_label_color = fg,
          key_label_font = lfont.family,
          key_label_font_size = lfont.pointsize * Gadfly.pt,
          plot_padding = 1 * Gadfly.mm,
          kwargs...
        )
end

# ----------------------------------------------------------------


function createGadflyAnnotationObject(x, y, val::@compat(AbstractString))
  Gadfly.Guide.annotation(Compose.compose(
                              Compose.context(), 
                              Compose.text(x, y, val)
                            ))
end

function createGadflyAnnotationObject(x, y, txt::PlotText)
  halign = (txt.font.halign == :hcenter ? Compose.hcenter : (txt.font.halign == :left ? Compose.hleft : Compose.hright))
  valign = (txt.font.valign == :vcenter ? Compose.vcenter : (txt.font.valign == :top ? Compose.vtop : Compose.vbottom))
  rotations = (txt.font.rotation == 0.0 ? [] : [Compose.Rotation(txt.font.rotation, Compose.Point(Compose.x_measure(x), Compose.y_measure(y)))])
  Gadfly.Guide.annotation(Compose.compose(
                              Compose.context(), 
                              Compose.text(x, y, txt.str, halign, valign, rotations...),
                              Compose.font(string(txt.font.family)),
                              Compose.fontsize(txt.font.pointsize * Gadfly.pt),
                              Compose.stroke(txt.font.color),
                              Compose.fill(txt.font.color)
                            ))
end

function addAnnotations{X,Y,V}(plt::Plot{GadflyPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    push!(plt.o.guides, createGadflyAnnotationObject(ann...))
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
  addGadflySeries!(plt, d)
  push!(plt.seriesargs, d)
  plt
end



function updatePlotItems(plt::Plot{GadflyPackage}, d::Dict)
  updateGadflyGuides(plt, d)
  updateGadflyPlotTheme(plt, d)
end


# ----------------------------------------------------------------

# accessors for x/y data

# TODO: need to save all the layer indices which apply to this series
function getGadflyMappings(plt::Plot, i::Integer)
  @assert i > 0 && i <= plt.n
  mappings = [l.mapping for l in plt.seriesargs[i][:gadflylayers]]
end

function Base.getindex(plt::Plot{GadflyPackage}, i::Integer)
  mapping = getGadflyMappings(plt, i)[1]
  mapping[:x], mapping[:y]
end

function Base.setindex!(plt::Plot{GadflyPackage}, xy::Tuple, i::Integer)
  for mapping in getGadflyMappings(plt, i)
    mapping[:x], mapping[:y] = xy
  end
  plt
end

# ----------------------------------------------------------------


# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{GadflyPackage}, isbefore::Bool)
  isbefore && return false # wait until after plotting to create the subplots
  subplt.o = nothing
  true
end


function handleLinkInner(plt::Plot{GadflyPackage}, isx::Bool)
  gplt = getGadflyContext(plt)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xlabel : Gadfly.Guide.ylabel, "")
end

function expandLimits!(lims, plt::Plot{GadflyPackage}, isx::Bool)
  for l in getGadflyContext(plt).layers
    expandLimits!(lims, l.mapping[isx ? :x : :y])
  end
end


# ----------------------------------------------------------------


getGadflyContext(plt::Plot{GadflyPackage}) = plt.o
getGadflyContext(subplt::Subplot{GadflyPackage}) = buildGadflySubplotContext(subplt)

# create my Compose.Context grid by hstacking and vstacking the Gadfly.Plot objects
function buildGadflySubplotContext(subplt::Subplot)
  rows = Any[]
  row = Any[]
  for (i,(r,c)) in enumerate(subplt.layout)

    # add the Plot object to the row
    push!(row, getGadflyContext(subplt.plts[i]))

    # add the row
    if c == ncols(subplt.layout, r)
      push!(rows, Gadfly.hstack(row...))
      row = Any[]
    end
  end

  # stack the rows
  Gadfly.vstack(rows...)
end

setGadflyDisplaySize(w,h) = Compose.set_default_graphic_size(w * Compose.px, h * Compose.px)
setGadflyDisplaySize(plt::Plot) = setGadflyDisplaySize(plt.initargs[:size]...)
setGadflyDisplaySize(subplt::Subplot) = setGadflyDisplaySize(getinitargs(subplt, 1)[:size]...)
# -------------------------------------------------------------------------


function dowritemime{P<:GadflyOrImmerse}(io::IO, func, plt::PlottingObject{P})
  gplt = getGadflyContext(plt)
  setGadflyDisplaySize(plt)
  Gadfly.draw(func(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end

getGadflyWriteFunc(::MIME"image/png") = Gadfly.PNG
getGadflyWriteFunc(::MIME"image/svg+xml") = Gadfly.SVG
# getGadflyWriteFunc(::MIME"text/html") = Gadfly.SVGJS
getGadflyWriteFunc(::MIME"application/pdf") = Gadfly.PDF
getGadflyWriteFunc(::MIME"application/postscript") = Gadfly.PS
getGadflyWriteFunc(m::MIME) = error("Unsupported in Gadfly/Immerse: ", m)

for mime in (MIME"image/png", MIME"image/svg+xml", MIME"application/pdf", MIME"application/postscript")
  @eval function Base.writemime{P<:GadflyOrImmerse}(io::IO, ::$mime, plt::PlottingObject{P})
    func = getGadflyWriteFunc($mime())
    dowritemime(io, func, plt)
  end
end



function Base.display(::PlotsDisplay, plt::Plot{GadflyPackage})
  setGadflyDisplaySize(plt.initargs[:size]...)
  display(plt.o)
end



function Base.display(::PlotsDisplay, subplt::Subplot{GadflyPackage})
  setGadflyDisplaySize(getinitargs(subplt,1)[:size]...)
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
end
