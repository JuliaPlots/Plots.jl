


# ----------------------------------------------------------------------

# this is the available area for drawing everything in this layout... as percentages of total canvas
bbox(layout::AbstractLayout) = layout.bbox
bbox!(layout::AbstractLayout, bb::BoundingBox) = (layout.bbox = bb)

# layouts are recursive, tree-like structures, and most will have a parent field
Base.parent(layout::AbstractLayout) = layout.parent
parent_bbox(layout::AbstractLayout) = bbox(parent(layout))

# this is a calculation of the percentage of free space available in the canvas
# after accounting for the size of guides and axes
free_size(layout::AbstractLayout) = (free_width(layout), free_height(layout))
free_width(layout::AbstractLayout) = width(layout.bbox) - used_width(layout)
free_height(layout::AbstractLayout) = height(layout.bbox) - used_height(layout)

used_size(layout::AbstractLayout) = (used_width(layout), used_height(layout))

# # compute the area which is available to this layout
# function bbox_pct(layout::AbstractLayout)
#
# end

update_position!(layout::AbstractLayout) = nothing
upadte_child_bboxes!(layout::AbstractLayout) = nothing

# ----------------------------------------------------------------------

Base.size(layout::EmptyLayout) = (0,0)
Base.length(layout::EmptyLayout) = 0
Base.getindex(layout::EmptyLayout, r::Int, c::Int) = nothing

used_width(layout::EmptyLayout) = 0pct
used_height(layout::EmptyLayout) = 0pct


# ----------------------------------------------------------------------

Base.parent(::RootLayout) = nothing
parent_bbox(::RootLayout) = defaultbox
bbox(::RootLayout) = defaultbox

# Base.size(layout::RootLayout) = (1,1)
# Base.length(layout::RootLayout) = 1
# Base.getindex(layout::RootLayout, r::Int, c::Int) = layout.child

# ----------------------------------------------------------------------

Base.size(sp::Subplot) = (1,1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp


used_width(sp::Subplot) = yaxis_width(sp)
used_height(sp::Subplot) = xaxis_height(sp) + title_height(sp)

# used_width(subplot::Subplot) = error("used_width(::Subplot) must be implemented by each backend")
# used_height(subplot::Subplot) = error("used_height(::Subplot) must be implemented by each backend")

# # this should return a bounding box (relative to the canvas) for the plot area (inside the spines/ticks)
# plotarea_bbox(subplot::Subplot) = error("plotarea_bbox(::Subplot) must be implemented by each backend")

# bounding box (relative to canvas) for plot area
# note: we assume the x axis is on the left, and y axis is on the bottom
function plotarea_bbox(sp::Subplot)
    xh = xaxis_height(sp)
    yw = yaxis_width(sp)
    crop(bbox(sp), BoundingBox(yw, xh, width(sp) - yw,
                               height(sp) - xh - title_height(sp)))
end

# NOTE: this is unnecessary I think as it is the same as bbox(::Subplot)
# # this should return a bounding box (relative to the canvas) for the whole subplot (plotarea, ticks, and guides)
# subplot_bbox(subplot::Subplot) = error("subplot_bbox(::Subplot) must be implemented by each backend")

# ----------------------------------------------------------------------

Base.size(layout::GridLayout) = size(layout.grid)
Base.length(layout::GridLayout) = length(layout.grid)
Base.getindex(layout::GridLayout, r::Int, c::Int) = layout.grid[r,c]
function Base.setindex!(layout::GridLayout, v, r::Int, c::Int)
    layout.grid[r,c] = v
end

function used_width(layout::GridLayout)
    w = 0mm
    nr,nc = size(layout)
    for c=1:nc
        @show w
        w += maximum([used_width(layout[r,c]) for r=1:nr])
        for r=1:nr
            @show used_width(layout[r,c])
        end
        @show w
    end
    w
end

function used_height(layout::GridLayout)
    h = 0mm
    nr,nc = size(layout)
    for r=1:nr
        h += maximum([used_height(layout[r,c]) for c=1:nc])
    end
    h
end

update_position!(layout::GridLayout) = map(update_position!, layout.grid)

# a recursive method to first compute the free space by bubbling the free space
# up the tree, then assigning bounding boxes according to height/width percentages
# note: this should be called after all axis objects are updated to re-compute the
# bounding boxes for the layout tree
function upadte_child_bboxes!(layout::GridLayout) #, parent_bbox::BoundingBox = defaultbox)
    # initialize the free space (per child!)
    nr, nc = size(layout)
    freew, freeh = free_size(layout)
    @show freew, freeh
    freew /= sum(layout.widths)
    freeh /= sum(layout.heights)
    @show freew, freeh

    @show layout.bbox

    # TODO: this should really track used/free space for each row/column so that we can align plot areas properly

    # l, b = 0.0, 0.0
    rights = Measure[0mm for i=1:nc] #zeros(nc) .* pct
    bottoms = Measure[1pct for i=1:nr] # ones(nr) .* pct
    for r=1:nr, c=1:nc
        # compute the child's bounding box relative to the parent
        child = layout[r,c]
        usedw, usedh = used_size(child)
        @show r,c, usedw, usedh

        plot_l = (c == 1 ? 0mm : rights[c-1])
        plot_t = (r == 1 ? height(layout) : bottoms[r-1])
        # bottom = (r == 1 ? 0 : bottoms[r-1])
        plot_w = freew * layout.widths[c]
        plot_h = freeh * layout.heights[r]
        right = plot_l + usedw + plot_w
        bottom = plot_t - usedh - plot_h
        # plot_t = bottom + usedh + freeh * layout.heights[r]
        child_bbox = BoundingBox(plot_l, bottom, plot_w, plot_h)
        @show child_bbox

        rights[c] = right
        bottoms[r] = bottom

        # then compute the bounding box relative to the canvas, and cache it in the child object
        bbox!(child, crop(bbox(layout), child_bbox))
        @show child.bbox

        # now recursively update the child
        upadte_child_bboxes!(child)
    end
end

# ----------------------------------------------------------------------

# return the top-level layout, a list of subplots, and a SubplotMap
function build_layout(d::KW)
    l = get(d, :layout, :auto)
    n = get(d, :num_subplots, -1)
    nr = get(d, :num_rows, -1)
    nc = get(d, :num_cols, -1)

    l == :auto || error() # TODO: handle anything else

    nr, nc = compute_gridsize(n, nr, nc)
    layout = GridLayout(nr, nc)
    subplots = Subplot[]
    spmap = SubplotMap()
    i = 1
    for r=1:nr, c=1:nc
        i > n && break  # only add n subplots
        sp = Subplot(backend(), parent=layout)
        layout[r,c] = sp
        push!(subplots, sp)
        spmap[(r,c)] = sp
        i += 1
    end
    layout, subplots, spmap
end



function compute_gridsize(numplts::Int, nr::Int, nc::Int)
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
    nr, nc
end

# ----------------------------------------------------------------------

get_subplot(plt::Plot, sp::Subplot) = sp
get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
get_subplot(plt::Plot, k) = plt.spmap[k]
get_subplot(series::Series) = series.d[:subplot]

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------

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
