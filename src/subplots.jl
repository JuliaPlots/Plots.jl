

Base.size(layout::EmptyLayout) = (0,0)
Base.length(layout::EmptyLayout) = 0
Base.getindex(layout::EmptyLayout, r::Int, c::Int) = nothing


Base.size(layout::RootLayout) = (1,1)
Base.length(layout::RootLayout) = 1
# Base.getindex(layout::RootLayout, r::Int, c::Int) = layout.child

Base.size(subplot::Subplot) = (1,1)
Base.length(subplot::Subplot) = 1
Base.getindex(subplot::Subplot, r::Int, c::Int) = subplot


Base.size(layout::GridLayout) = size(layout.grid)
Base.length(layout::GridLayout) = length(layout.grid)
Base.getindex(layout::GridLayout, r::Int, c::Int) = layout.grid[r,c]


# Base.start(layout::GridLayout) = 1
# Base.done(layout::GridLayout, state) = state > length(layout)
# function Base.next(layout::GridLayout, state)
#     # TODO: change this method to return more info
#     # TODO: might consider multiple iterator types.. some backends might have an easier time row-by-row for example
#     error()
#     r = 1
#     c = 0
#     for i = 1:state
#         c += 1
#         if c > layout.rowcounts[r]
#             r += 1
#             c = 1
#         end
#     end
#     (r,c), state + 1
# end

# nrows(layout::GridLayout) = size(layout, 1)
# ncols(layout::GridLayout) = size(layout, 2)

# get the plot index given row and column

# -----------------------------------------------------------

# # we're taking in a nested structure of some kind... parse it out and build a GridLayout
# function subplotlayout(mat::AbstractVecOrMat; widths = nothing, heights = nothing)
#     n = 0
#     nr, nc = size(mat)
#     grid = Array(IntOrFlex, nr, nc)
#     for i=1:nr, j=1:nc
#         v = mat[i,j]
#
#         if isa(v, Integer)
#             grid[i,j] = Int(v)
#             n += 1
#
#         elseif isa(v, Tuple)
#             warn("need to handle tuples somehow... (idx, sizepct)")
#             grid[i,j] = nothing
#
#         elseif v == nothing
#             grid[i,j] = nothing
#
#         elseif isa(v, AbstractVecOrMat)
#             grid[i,j] = layout(v)
#             n += grid[i,j].n
#
#         else
#             error("How do we process? $v")
#         end
#     end
#
#     if widths == nothing
#         widths = ones(nc) ./ nc
#     end
#     if heights == nothing
#         heights = ones(nr) ./ nr
#     end
#
#     GridLayout(n, grid, widths, heights)
# end
#
#
# function subplotlayout(sz::Tuple{Int,Int})
#   GridLayout(sz...)
# end
#
# function subplotlayout(rowcounts::AVec{Int})
#   RowsLayout(sum(rowcounts), rowcounts)
# end
#
# function subplotlayout(numplts::Int, nr::Int, nc::Int)
#
#   # figure out how many rows/columns we need
#   if nr == -1
#     if nc == -1
#       nr = round(Int, sqrt(numplts))
#       nc = ceil(Int, numplts / nr)
#     else
#       nr = ceil(Int, numplts / nc)
#     end
#   else
#     nc = ceil(Int, numplts / nr)
#   end
#
#   # if it's a perfect rectangle, just create a grid
#   if numplts == nr * nc
#     return GridLayout(nr, nc)
#   end
#
#   # create the rowcounts vector
#   i = 0
#   rowcounts = Int[]
#   for r in 1:nr
#     cnt = min(nc, numplts - i)
#     push!(rowcounts, cnt)
#     i += cnt
#   end
#
#   RowsLayout(numplts, rowcounts)
# end
