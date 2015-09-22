
typealias AVec AbstractVector
typealias AMat AbstractMatrix

immutable PlotsDisplay <: Display end
  
abstract PlottingPackage
abstract PlottingObject{T<:PlottingPackage}

type Plot{T<:PlottingPackage} <: PlottingObject{T}
  o  # the underlying object
  plotter::T
  n::Int  # number of series

  # store these just in case
  initargs::Dict
  seriesargs::Vector{Dict} # args for each series
end


type SubplotLayout
  numplts::Int
  rowcounts::AbstractVector{Int}
end


type Subplot{T<:PlottingPackage} <: PlottingObject{T}
  o                           # the underlying object
  plts::Vector{Plot}          # the individual plots
  plotter::T
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::SubplotLayout
  initargs::Vector{Dict}
  initialized::Bool
end



type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end
