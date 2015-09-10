
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
  plt.guides = Gadfly.GuideElement[Gadfly.Guide.xlabel(d[:xlabel]), Gadfly.Guide.ylabel(d[:ylabel]), Gadfly.Guide.title(d[:title])]
  plt.theme = Gadfly.Theme(background_color = (haskey(d, :background_color) ? d[:background_color] : colorant"white"))
                       # key_position = (d[:legend] ? :bottom : :none))
  
  Plot(plt, pkg, 0)
end

function getGeoms(linetype::Symbol, marker::Symbol, heatmap_n::Int)
  geoms = []
  if linetype in (:heatmap,:hexbin)
    push!(geoms, Gadfly.Geom.hexbin(xbincount=heatmap_n, ybincount=heatmap_n))
  else
    if linetype == :line
      push!(geoms, Gadfly.Geom.line)
    elseif linetype == :dots
      push!(geoms, Gadfly.Geom.point)
    else
      error("linetype $linetype not currently supported with Gadfly")
    end

    if marker != :none
      push!(geoms, Gadfly.Geom.point)
    end
  end
end

# # note: currently only accepts lines and dots
# function getGeomLine(linetype::Symbol, heatmap_n::Int)
#   linetype == :line && return [Gadfly.Geom.line]
#   linetype == :dots && return [Gadfly.Geom.point]
#   linetype in (:heatmap, :hexbin) && return [Gadfly.Geom.hexbin(xbincount=heatmap_n, ybincount=heatmap_n)]
#   error("linetype $linetype not currently supported with Gadfly")
# end

# # note: currently map any marker to point
# function getGeomPoint(linetype::Syombol, marker::Symbol)
#   if marker == :none || linetype in (:heatmap, :hexbin) 
#     return []
#   end
#   [Gadfly.Geom.point]
# end

# plot one data series
function plot!(::GadflyPackage, plt::Plot; kw...)
  d = Dict(kw)

  gfargs = []
  # append!(gfargs, getGeomLine(d[:linetype], d[:heatmap_n]))
  # append!(gfargs, getGeomPoint(d[:marker]))
  append!(gfargs, getGeoms(d[:linetype], d[:marker], d[:heatmap_n]))

  theme = Gadfly.Theme(default_color = d[:color],
                       line_width = d[:width] * Gadfly.px,
                       default_point_size = d[:markersize] * Gadfly.px)
  push!(gfargs, theme)


  append!(plt.o.layers, Gadfly.layer(unique(gfargs)...; x = d[:x], y = d[:y]))
  plt
end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end


savepng(::GadflyPackage, plt::Plot, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt.o)


