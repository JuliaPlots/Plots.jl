
typealias AVec AbstractVector
typealias AMat AbstractMatrix

immutable PlotsDisplay <: Display end

abstract PlottingPackage
abstract PlottingObject{T<:PlottingPackage}

# -----------------------------------------------------------
# Plot
# -----------------------------------------------------------

type Plot{T<:PlottingPackage} <: PlottingObject{T}
    o                        # the backend's plot object
    backend::T               # the backend type
    n::Int                   # number of series
    plotargs::Dict           # arguments for the whole plot
    seriesargs::Vector{Dict} # arguments for each series
end

# -----------------------------------------------------------
# Layouts
# -----------------------------------------------------------

abstract SubplotLayout

# -----------------------------------------------------------

"Simple grid, indices are row-major."
immutable GridLayout <: SubplotLayout
    nr::Int
    nc::Int
end

# -----------------------------------------------------------

"Number of plots per row"
immutable RowsLayout <: SubplotLayout
    numplts::Int
    rowcounts::AbstractVector{Int}
end

# -----------------------------------------------------------

"Flexible, nested layout with optional size percentages."
immutable FlexLayout <: SubplotLayout
    n::Int
    grid::Matrix # Nested layouts. Each position
                 # can be a plot index or another FlexLayout
    widths::Vector{Float64}
    heights::Vector{Float64}
end

typealias IntOrFlex Union{Int,FlexLayout}

# -----------------------------------------------------------
# Subplot
# -----------------------------------------------------------

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
