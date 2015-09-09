
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end


# create a blank Gadfly.Plot object
function plot(pkg::GadflyPackage; kw...)
  @eval import DataFrames
  plt = Gadfly.Plot()
  plt.mapping = Dict()
  plt.data_source = DataFrames.DataFrame()
  plt.layers = plt.layers[1:0]
  Plot(plt, pkg, 0)
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
  
  # # color
  # c = d[:color]
  # if isa(c, Symbol)
  #   c = string(c)
  # end
  # if isa(c, String)
  #   c = parse(Colorant, c)
  # end
  # @assert isa(c, RGB)
  push!(gfargs, Gadfly.Theme(default_color = d[:color]))

  # legend
  # guides (x/y labels, title, background, ticks)

  append!(plt.o.layers, Gadfly.layer(unique(gfargs)...; x = d[:x], y = d[:y]))
  plt
end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end


savepng(::GadflyPackage, plt::Plot, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt.o)


