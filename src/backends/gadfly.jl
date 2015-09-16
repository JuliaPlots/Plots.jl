
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

gadfly!() = plotter!(:gadfly)


supportedAxes(::GadflyPackage) = [:left]
supportedTypes(::GadflyPackage) = setdiff(TYPES, [:stepinverted])
supportedStyles(::GadflyPackage) = [:solid]
supportedMarkers(::GadflyPackage) = [:rect, :ellipse, :diamond, :cross]


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

  gplt.theme = Gadfly.Theme(background_color = (haskey(d, :background_color) ? d[:background_color] : colorant"white"))
  gplt
end


# function getGeoms(linetype::Symbol, marker::Symbol, markercolor::Colorant, nbins::Int)
function getLineGeoms(d::Dict)
  lt = d[:linetype]
  lt in (:heatmap,:hexbin) && return [Gadfly.Geom.hexbin(xbincount = d[:nbins], ybincount = d[:nbins])]
  lt == :hist && return [Gadfly.Geom.histogram(bincount = d[:nbins])]
  lt == :none && return [Gadfly.Geom.path]
  lt == :line && return [Gadfly.Geom.path]
  # lt == :dots && return [Gadfly.Geom.point]
  lt == :bar && return [Gadfly.Geom.bar]
  lt == :step && return [Gadfly.Geom.step]
  # lt == :sticks && return [Gadfly.Geom.bar]
  error("linetype $lt not currently supported with Gadfly")
end


# function createGadflyAnnotation(d::Dict)
  
#   if d[:marker] == :rect
#     # get the width/height of the square (both are sz)
#     sz = d[:markersize] * Gadfly.px
#     halfsz = sz/2

#     # remap x/y to the corner position of the squares
#     xs = map(z -> Gadfly.Compose.Measure(;cx=z) - halfsz, float(d[:x]))
#     ys = map(z -> Gadfly.Compose.Measure(;cy=z) + halfsz, float(d[:y]))

#     # return an Annotation which will add those shapes to each point in the series 
#     return Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), Gadfly.rectangle(xs,ys,[sz],[sz]), Gadfly.fill(d[:markercolor]), Gadfly.stroke(nothing)))

#   else
#     # make circles
#     sz = 0.5 * d[:markersize] * Gadfly.px
#     xs = collect(float(d[:x]))
#     ys = collect(float(d[:y]))

#     # return an Annotation which will add those shapes to each point in the series 
#     return Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), Gadfly.circle(xs,ys,[sz]), Gadfly.fill(d[:markercolor]), Gadfly.stroke(nothing)))

#   end
# end


# serious hack (I think?) to draw my own shapes as annotations... will it work? who knows...
function getMarkerGeomsAndGuides(d::Dict)
  marker = d[:marker]
  if marker == :none
    return [],[]
  end
  return [], [createGadflyAnnotation(d)]
end

  # # special handling for other marker shapes... gotta create Compose contexts and map them to series points using Guide.Annotation
  # elseif marker == :rect
  #   # get the width/height of the square (both are sz)
  #   sz = d[:markersize] * Gadfly.px
  #   halfsz = sz/2

  #   # remap x/y to the corner position of the squares
  #   xs = map(z -> Gadfly.Compose.Measure(;cx=z) - halfsz, float(d[:x]))
  #   ys = map(z -> Gadfly.Compose.Measure(;cy=z) + halfsz, float(d[:y]))

  #   # return an Annotation which will add those shapes to each point in the series 
  #   return [], [Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), Gadfly.rectangle(xs,ys,[sz],[sz]), Gadfly.fill(d[:markercolor]), Gadfly.stroke(nothing)))]

  # else
  #   # make circles
  #   sz = 0.5 * d[:markersize] * Gadfly.px
  #   xs = collect(float(d[:x]))
  #   ys = collect(float(d[:y]))

  #   # return an Annotation which will add those shapes to each point in the series 
  #   return [], [Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), Gadfly.circle(xs,ys,[sz]), Gadfly.fill(d[:markercolor]), Gadfly.stroke(nothing)))]

  # end

  # otherwise just return a Geom.point
  # [Gadfly.Geom.point], []
# end


function addGadflySeries!(gplt, d::Dict)

  # first things first... lets so the sticks hack
  if d[:linetype] == :sticks
    d, dScatter = sticksHack(;d...)

    # add the annotation
    if dScatter[:marker] != :none
      push!(gplt.guides, createGadflyAnnotation(dScatter))
    end
  end

  gfargs = []

  # add the Geoms
  append!(gfargs, getLineGeoms(d))
  
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


  # # if we haven't added any geoms, we're probably just going to use annotations?
  # isempty(gfargs) && return


  # set theme: color, line width, and point size
  line_width = d[:width] * (d[:linetype] == :none ? 0 : 1) * Gadfly.px  # 0 width when we don't show a line
  theme = Gadfly.Theme(default_color = d[:color],
                       line_width = line_width,
                       default_point_size = 0.5 * d[:markersize] * Gadfly.px)
  push!(gfargs, theme)

  # for histograms, set x=y
  x = d[d[:linetype] == :hist ? :y : :x]

  if d[:axis] != :left
    warn("Gadly only supports one y axis")
  end


  # add the layer to the Gadfly.Plot
  prepend!(gplt.layers, Gadfly.layer(unique(gfargs)..., d[:args]...; x = x, y = d[:y], d[:kwargs]...))
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
  addGadflySeries!(plt.o, d)
  push!(plt.seriesargs, d)
  plt
end


function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end

# -------------------------------

function savepng(::GadflyPackage, plt::PlottingObject, fn::String;
                                    w = 6 * Gadfly.inch,
                                    h = 4 * Gadfly.inch)
  o = getGadflyContext(plt.plotter, plt)
  Gadfly.draw(Gadfly.PNG(fn, w, h), o)
end


# -------------------------------

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

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::GadflyPackage, subplt::Subplot)
  subplt.o = nothing
end


function Base.display(::GadflyPackage, subplt::Subplot)
  display(buildGadflySubplotContext(subplt))
end
