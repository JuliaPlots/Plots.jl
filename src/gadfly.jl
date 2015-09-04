
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end


# create a blank Gadfly.Plot object
function plot(pkg::GadflyPackage; kw...)
  @eval import DataFrames
  plt = Gadfly.Plot()
  plt.mapping = Dict()
  plt.data_source = DataFrames.DataFrame()
  plt.layers = plt.layers[1:0]
  Plot(plt, pkg)
end



# note: currently only accepts lines and dots
function getGeomLine(linetype::Symbol)
  linetype == :line && return [Gadfly.Geom.line]
  linetype == :dots && return [Gadfly.Geom.point]
  error("linetype $linetype not currently supported with Gadfly")
end

# note: currently map any marker to point
function getGeomPoint(marker::Symbol)
  marker == :none && return []
  [Gadfly.Geom.point]
end

# plot one data series
function plot!(::GadflyPackage, plt::Plot; kw...)
  d = Dict(kw)

  gfargs = []

  append!(gfargs, getGeomLine(d[:linetype]))
  append!(gfargs, getGeomPoint(d[:marker]))


  # todo: 
  # linestyle
  # label
  
  # color
  if d[:color] == :auto
    color = convert(RGB{Float32}, autocolor(length(plt.o.layers)+1))
  end

  # legend
  # guides (x/y labels, title, background, ticks)

  append!(plt.o.layers, Gadfly.layer(unique(gfargs)...; x = d[:x], y = d[:y], color = [color]))
  plt
end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end


savepng(::GadflyPackage, plt::Plot, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt.o)


