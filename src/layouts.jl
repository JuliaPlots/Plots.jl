
# -----------------------------------------------------------
# GridLayout
# -----------------------------------------------------------

"Simple grid, indices are row-major."
immutable GridLayout <: SubplotLayout
    nr::Int
    nc::Int
end

Base.length(layout::GridLayout) = layout.nr * layout.nc
Base.start(layout::GridLayout) = 1
Base.done(layout::GridLayout, state) = state > length(layout)
function Base.next(layout::GridLayout, state)
  r = div(state-1, layout.nc) + 1
  c = mod1(state, layout.nc)
  (r,c), state + 1
end

nrows(layout::GridLayout) = layout.nr
ncols(layout::GridLayout) = layout.nc
ncols(layout::GridLayout, row::Int) = layout.nc

# get the plot index given row and column
Base.getindex(layout::GridLayout, r::Int, c::Int) = (r-1) * layout.nc + c

# -----------------------------------------------------------
# RowsLayout
# -----------------------------------------------------------

"Number of plots per row"
immutable RowsLayout <: SubplotLayout
    numplts::Int
    rowcounts::AbstractVector{Int}
end

Base.length(layout::RowsLayout) = layout.numplts
Base.start(layout::RowsLayout) = 1
Base.done(layout::RowsLayout, state) = state > length(layout)
function Base.next(layout::RowsLayout, state)
  r = 1
  c = 0
  for i = 1:state
    c += 1
    if c > layout.rowcounts[r]
      r += 1
      c = 1
    end
  end
  (r,c), state + 1
end

nrows(layout::RowsLayout) = length(layout.rowcounts)
ncols(layout::RowsLayout, row::Int) = row < 1 ? 0 : (row > nrows(layout) ? 0 : layout.rowcounts[row])

# get the plot index given row and column
Base.getindex(layout::RowsLayout, r::Int, c::Int) = sum(layout.rowcounts[1:r-1]) + c

# -----------------------------------------------------------
# FlexLayout
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

Base.length(layout::FlexLayout) = layout.n
Base.start(layout::FlexLayout) = 1
Base.done(layout::FlexLayout, state) = state > length(layout)
function Base.next(layout::FlexLayout, state)
    # TODO: change this method to return more info
    # TODO: might consider multiple iterator types.. some backends might have an easier time row-by-row for example
    error()
    r = 1
    c = 0
    for i = 1:state
        c += 1
        if c > layout.rowcounts[r]
            r += 1
            c = 1
        end
    end
    (r,c), state + 1
end

nrows(layout::FlexLayout)           = size(layout.grid, 1)
ncols(layout::FlexLayout, row::Int) = size(layout.grid, 2)

# get the plot index given row and column
Base.getindex(layout::FlexLayout, r::Int, c::Int) = layout.grid[r,c]

# -----------------------------------------------------------

# we're taking in a nested structure of some kind... parse it out and build a FlexLayout
function subplotlayout(mat::AbstractVecOrMat; widths = nothing, heights = nothing)
    n = 0
    nr, nc = size(mat)
    grid = Array(IntOrFlex, nr, nc)
    for i=1:nr, j=1:nc
        v = mat[i,j]

        if isa(v, Integer)
            grid[i,j] = Int(v)
            n += 1

        elseif isa(v, Tuple)
            warn("need to handle tuples somehow... (idx, sizepct)")
            grid[i,j] = nothing

        elseif v == nothing
            grid[i,j] = nothing

        elseif isa(v, AbstractVecOrMat)
            grid[i,j] = layout(v)
            n += grid[i,j].n

        else
            error("How do we process? $v")
        end
    end

    if widths == nothing
        widths = ones(nc) ./ nc
    end
    if heights == nothing
        heights = ones(nr) ./ nr
    end

    FlexLayout(n, grid, widths, heights)
end


function subplotlayout(sz::Tuple{Int,Int})
  GridLayout(sz...)
end

function subplotlayout(rowcounts::AVec{Int})
  RowsLayout(sum(rowcounts), rowcounts)
end

function subplotlayout(numplts::Int, nr::Int, nc::Int)

  # figure out how many rows/columns we need
  if nr == -1
    if nc == -1
      nr = round(Int, sqrt(numplts))
      nc = ceil(Int, numplts / nr)
    else
      nr = ceil(Int, numplts / nc)
    end
  else
    nc = ceil(Int, numplts / nr)
  end

  # if it's a perfect rectangle, just create a grid
  if numplts == nr * nc
    return GridLayout(nr, nc)
  end

  # create the rowcounts vector
  i = 0
  rowcounts = Int[]
  for r in 1:nr
    cnt = min(nc, numplts - i)
    push!(rowcounts, cnt)
    i += cnt
  end

  RowsLayout(numplts, rowcounts)
end
