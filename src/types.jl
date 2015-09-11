
typealias AVec AbstractVector
typealias AMat AbstractMatrix

abstract PlottingObject
abstract PlottingPackage

type Plot <: PlottingObject
  o  # the underlying object
  plotter::PlottingPackage
  n::Int # number of series
end


type SubplotLayout
  numplts::Int
  rowcounts::AbstractVector{Int}
end


type Subplot <: PlottingObject
  o                           # the underlying object
  plts::Vector{Plot}          # the individual plots
  plotter::PlottingPackage
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::SubplotLayout
end