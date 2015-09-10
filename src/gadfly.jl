
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end


# create a blank Gadfly.Plot object
function plot(pkg::GadflyPackage; kw...)
  @eval import DataFrames

  plt = Gadfly.Plot()
  plt.mapping = Dict()
  plt.data_source = DataFrames.DataFrame()
  plt.layers = plt.layers[1:0]
  
  # add the title, axis labels, and theme
  d = Dict(kw)

  plt.guides = Gadfly.GuideElement[Gadfly.Guide.xlabel(d[:xlabel]),
                                   Gadfly.Guide.ylabel(d[:ylabel]),
                                   Gadfly.Guide.title(d[:title])]

  # add the legend?
  if d[:legend]
    unshift!(plt.guides, Gadfly.Guide.manual_color_key("", AbstractString[], Color[]))
  end

  plt.theme = Gadfly.Theme(background_color = (haskey(d, :background_color) ? d[:background_color] : colorant"white"))
  
  Plot(plt, pkg, 0)
end

function getGeomFromLineType(linetype::Symbol)
  linetype == :line && return Gadfly.Geom.line
  linetype == :dots && return Gadfly.Geom.point
  linetype == :bar && return Gadfly.Geom.bar
  linetype == :step && return Gadfly.Geom.step
  linetype == :hist && return Gadfly.Geom.hist
  linetype == :none && return Gadfly.Geom.point  # change this? are we usually pairing no line with scatterplots?
  error("linetype $linetype not currently supported with Gadfly")
end

function getGeoms(linetype::Symbol, marker::Symbol, nbins::Int)
  geoms = []

  # handle heatmaps (hexbins) specially
  if linetype in (:heatmap,:hexbin)
    push!(geoms, Gadfly.Geom.hexbin(xbincount=nbins, ybincount=nbins))
  else

    # for other linetypes, get the correct Geom
    push!(geoms, getGeomFromLineType(linetype))

    # for any marker, add Geom.point
    if marker != :none
      push!(geoms, Gadfly.Geom.point)
    end
  end

  geoms
end


# plot one data series
function plot!(::GadflyPackage, plt::Plot; kw...)
  d = Dict(kw)

  gfargs = []

  # add the Geoms
  append!(gfargs, getGeoms(d[:linetype], d[:marker], d[:nbins]))

  # set color, line width, and point size
  theme = Gadfly.Theme(default_color = d[:color],
                       line_width = d[:width] * Gadfly.px,
                       default_point_size = d[:markersize] * Gadfly.px)
  push!(gfargs, theme)

  # add a regression line?
  if d[:reg]
    push!(gfargs, Gadfly.Geom.smooth(method=:lm))
  end

  # for histograms, set x=y
  x = d[d[:linetype] == :hist ? :y : :x]

  # add to the legend
  if length(plt.o.guides) > 0 && isa(plt.o.guides[1], Gadfly.Guide.ManualColorKey)
    push!(plt.o.guides[1].labels, d[:label])
    push!(plt.o.guides[1].colors, d[:color])
  end

  if d[:axis] != :left
    warn("Gadly only supports one y axis")
  end

  # add the layer to the Gadfly.Plot
  append!(plt.o.layers, Gadfly.layer(unique(gfargs)...; x = x, y = d[:y]))
  plt
end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end


function savepng(::GadflyPackage, plt::Plot, fn::String;
                                    w = 6 * Gadfly.inch,
                                    h = 4 * Gadfly.inch)
  Gadfly.draw(Gadfly.PNG(fn, w, h), plt.o)
end


