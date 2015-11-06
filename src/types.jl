
typealias AVec AbstractVector
typealias AMat AbstractMatrix

immutable PlotsDisplay <: Display end
  
abstract PlottingPackage
abstract PlottingObject{T<:PlottingPackage}

type Plot{T<:PlottingPackage} <: PlottingObject{T}
  o  # the underlying object
  backend::T
  n::Int  # number of series

  # store these just in case
  plotargs::Dict
  seriesargs::Vector{Dict} # args for each series
end


abstract SubplotLayout

immutable GridLayout <: SubplotLayout
  nr::Int
  nc::Int
end

immutable FlexLayout <: SubplotLayout
  numplts::Int
  rowcounts::AbstractVector{Int}
end


type Subplot{T<:PlottingPackage, L<:SubplotLayout} <: PlottingObject{T}
  o                           # the underlying object
  plts::Vector{Plot{T}}          # the individual plots
  backend::T
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::L
  # plotargs::Vector{Dict}
  plotargs::Dict
  initialized::Bool
  linkx::Bool
  linky::Bool
  linkfunc::Function # maps (row,column) -> (BoolOrNothing, BoolOrNothing)... if xlink/ylink are nothing, then use subplt.linkx/y
end

# -----------------------------------------------------------------------
