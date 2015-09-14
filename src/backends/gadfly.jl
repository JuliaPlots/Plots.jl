
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

gadfly!() = plotter!(:gadfly)



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


function getGeomsFromLineType(linetype::Symbol)
  linetype == :line && return [Gadfly.Geom.path]
  linetype == :dots && return [Gadfly.Geom.point]
  linetype == :bar && return [Gadfly.Geom.bar]
  linetype == :step && return [Gadfly.Geom.step]
  # linetype == :hist && return [Gadfly.Geom.histogram(bincount=nbins)]
  # linetype == :none && return [Gadfly.Geom.point]  # change this? are we usually pairing no line with scatterplots?
  linetype == :none && return []
  linetype == :sticks && return [Gadfly.Geom.bar]
  error("linetype $linetype not currently supported with Gadfly")
end

# function getGeoms(linetype::Symbol, marker::Symbol, markercolor::Colorant, nbins::Int)
function getLineGeoms(d::Dict)
  lt = d[:linetype]
  lt in (:heatmap,:hexbin) && return [Gadfly.Geom.hexbin(xbincount = d[:nbins], ybincount = d[:nbins])]
  lt == :hist && return [Gadfly.Geom.histogram(bincount = d[:nbins])]
  lt == :none && return []
  lt == :line && return [Gadfly.Geom.path]
  lt == :dots && return [Gadfly.Geom.point]
  lt == :bar && return [Gadfly.Geom.bar]
  lt == :step && return [Gadfly.Geom.step]
  lt == :sticks && return [Gadfly.Geom.bar]
  error("linetype $lt not currently supported with Gadfly")

  # else
  #   geoms = []

  #   # for other linetypes, get the correct Geom
  #   append!(geoms, getGeomFromLineType(lt, nbins))

  #   # # for any marker, add Geom.point
  #   # if marker != :none
  #   #   # push!(geoms, Gadfly.Geom.default_point_size)
  #   #   push!(geoms, getGadflyMarker(marker, markercolor))
  #   # end
  # end

  # geoms
end



# serious hack (I think?) to draw my own shapes as annotations... will it work? who knows...
function getMarkerGeomsAndGuides(d::Dict)
  marker = d[:marker]
  if marker == :none
    return [],[]
  elseif marker == :rect
    sz = d[:markersize] * Gadfly.px
    # primitive = Gadfly.Compose.PolygonPrimitive()

    xs = [xi * Gadfly.mm - sz/2 for xi in d[:x]]
    ys = [yi * Gadfly.mm - sz/2 for yi in d[:y]]
    # xs = collect(d[:x]) - sz/2
    # ys = collect(d[:y]) - sz/2
    # w = [d[:markersize] * Gadfly.px]
    # h = [d[:markersize] * Gadfly.px]
    return [], [Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), Gadfly.rectangle(xs,ys,sz,sz), Gadfly.fill(d[:markercolor]), Gadfly.stroke(nothing)))]
  end
  [Gadfly.Geom.point], []
end


function addGadflySeries!(gplt, d::Dict)
  gfargs = []

  # add the Geoms
  append!(gfargs, getLineGeoms(d)) #[:linetype], d[:marker], d[:markercolor], d[:nbins]))
  
  # handle markers
  geoms, guides = getMarkerGeomsAndGuides(d)
  append!(gfargs, geoms)
  append!(gplt.guides, guides)

  # add a regression line?
  if d[:reg]
    push!(gfargs, Gadfly.Geom.smooth(method=:lm))
  end


  # if we haven't added any geoms, we're probably just going to use annotations?
  isempty(gfargs) && return


  # set theme: color, line width, and point size
  theme = Gadfly.Theme(default_color = d[:color],
                       line_width = d[:width] * Gadfly.px,
                       default_point_size = d[:markersize] * Gadfly.px)
  push!(gfargs, theme)

  # for histograms, set x=y
  x = d[d[:linetype] == :hist ? :y : :x]

  # add to the legend
  if length(gplt.guides) > 0 && isa(gplt.guides[1], Gadfly.Guide.ManualColorKey)
    push!(gplt.guides[1].labels, d[:label])
    push!(gplt.guides[1].colors, d[:color])
  end

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

# # plot one data series
# function plot!(::GadflyPackage, plt::Plot; kw...)
#   d = Dict(kw)

#   gfargs = []

#   # add the Geoms
#   append!(gfargs, getGeoms(d[:linetype], d[:marker], d[:nbins]))

#   # set color, line width, and point size
#   theme = Gadfly.Theme(default_color = d[:color],
#                        line_width = d[:width] * Gadfly.px,
#                        default_point_size = d[:markersize] * Gadfly.px)
#   push!(gfargs, theme)

#   # add a regression line?
#   if d[:reg]
#     push!(gfargs, Gadfly.Geom.smooth(method=:lm))
#   end

#   # for histograms, set x=y
#   x = d[d[:linetype] == :hist ? :y : :x]

#   # add to the legend
#   if length(plt.o.guides) > 0 && isa(plt.o.guides[1], Gadfly.Guide.ManualColorKey)
#     push!(plt.o.guides[1].labels, d[:label])
#     push!(plt.o.guides[1].colors, d[:color])
#   end

#   if d[:axis] != :left
#     warn("Gadly only supports one y axis")
#   end

#   # save the kw args
#   push!(plt.seriesargs, d)

#   # add the layer to the Gadfly.Plot
#   prepend!(plt.o.layers, Gadfly.layer(unique(gfargs)..., d[:args]...; x = x, y = d[:y], d[:kwargs]...))
#   plt
# end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end

# -------------------------------

function savepng(::GadflyPackage, plt::PlottingObject, fn::String;
                                    w = 6 * Gadfly.inch,
                                    h = 4 * Gadfly.inch)
  Gadfly.draw(Gadfly.PNG(fn, w, h), plt.o)
end


# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::GadflyPackage, subplt::Subplot)
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Gadfly.hstack([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  subplt.o = Gadfly.vstack(rows...)
end


function Base.display(::GadflyPackage, subplt::Subplot)
  display(subplt.o)
end
