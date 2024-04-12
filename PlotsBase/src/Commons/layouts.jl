make_measure_hor(n::Number) = n * Measures.w
make_measure_hor(m::Measure) = m

make_measure_vert(n::Number) = n * Measures.h
make_measure_vert(m::Measure) = m

"""
    bbox(x, y, w, h [,originargs...])
    bbox(layout)

Create a bounding box for plotting
"""
function bbox(x, y, w, h, oarg1::Symbol, originargs::Symbol...)
    oargs = vcat(oarg1, originargs...)
    orighor = :left
    origver = :top
    for oarg in oargs
        if oarg ≡ :center
            orighor = origver = oarg
        elseif oarg in (:left, :right, :hcenter)
            orighor = oarg
        elseif oarg in (:top, :bottom, :vcenter)
            origver = oarg
        else
            @warn "Unused origin arg in bbox construction: $oarg"
        end
    end
    bbox(x, y, w, h; h_anchor = orighor, v_anchor = origver)
end

# create a new bbox
function bbox(x, y, width, height; h_anchor = :left, v_anchor = :top)
    x, y = make_measure_hor(x), make_measure_vert(y)
    width, height = make_measure_hor(width), make_measure_vert(height)
    left = if h_anchor ≡ :left
        x
    elseif h_anchor in (:center, :hcenter)
        0.5w - 0.5width + x
    else
        1w - x - width
    end
    top = if v_anchor ≡ :top
        y
    elseif v_anchor in (:center, :vcenter)
        0.5h - 0.5height + y
    else
        1h - y - height
    end
    BoundingBox(left, top, width, height)
end

# NOTE: (0,0) is the top-left !!!
left(bbox::BoundingBox) = bbox.x0[1]
top(bbox::BoundingBox) = bbox.x0[2]
right(bbox::BoundingBox) = left(bbox) + width(bbox)
bottom(bbox::BoundingBox) = top(bbox) + height(bbox)
origin(bbox::BoundingBox) = left(bbox) + width(bbox) / 2, top(bbox) + height(bbox) / 2
Base.size(bbox::BoundingBox) = (width(bbox), height(bbox))

# -----------------------------------------------------------
# AbstractLayout

left(layout::AbstractLayout) = left(bbox(layout))
top(layout::AbstractLayout) = top(bbox(layout))
right(layout::AbstractLayout) = right(bbox(layout))
bottom(layout::AbstractLayout) = bottom(bbox(layout))
width(layout::AbstractLayout) = width(bbox(layout))
height(layout::AbstractLayout) = height(bbox(layout))

leftpad(::AbstractLayout)   = 0mm
toppad(::AbstractLayout)    = 0mm
rightpad(::AbstractLayout)  = 0mm
bottompad(::AbstractLayout) = 0mm

leftpad(pad)   = pad[1]
toppad(pad)    = pad[2]
rightpad(pad)  = pad[3]
bottompad(pad) = pad[4]

Base.show(io::IO, layout::AbstractLayout) = print(io, "$(typeof(layout))$(size(layout))")

# this is the available area for drawing everything in this layout... as percentages of total canvas
bbox(layout::AbstractLayout) = layout.bbox
bbox!(layout::AbstractLayout, bb::BoundingBox) = layout.bbox = bb

# layouts are recursive, tree-like structures, and most will have a parent field
Base.parent(layout::AbstractLayout) = layout.parent
parent_bbox(layout::AbstractLayout) = bbox(parent(layout))

# -----------------------------------------------------------
# RootLayout

# this is the parent of the top-level layout
struct RootLayout <: AbstractLayout end

Base.show(io::IO, layout::RootLayout) = Base.show_default(io, layout)
Base.parent(::RootLayout) = nothing
parent_bbox(::RootLayout) = DEFAULT_BBOX[]
bbox(::RootLayout) = DEFAULT_BBOX[]

# -----------------------------------------------------------
# EmptyLayout

# contains blank space
mutable struct EmptyLayout <: AbstractLayout
    parent::AbstractLayout
    bbox::BoundingBox
    attr::KW  # store label, width, and height for initialization
    # label  # this is the label that the subplot will take (since we create a layout before initialization)
end
EmptyLayout(parent = RootLayout(); kw...) = EmptyLayout(parent, DEFAULT_BBOX[], KW(kw))

Base.size(::EmptyLayout) = (0, 0)
Base.length(::EmptyLayout) = 0
Base.getindex(::EmptyLayout, ::Int, ::Int) = nothing

# -----------------------------------------------------------
# GridLayout

# nested, gridded layout with optional size percentages
mutable struct GridLayout <: AbstractLayout
    parent::AbstractLayout
    minpad::Tuple  # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox
    grid::Matrix{AbstractLayout}  # nested layouts. Each position is a AbstractLayout, which allows for arbitrary recursion
    widths::Vector{Measure}
    heights::Vector{Measure}
    attr::KW
end

leftpad(layout::GridLayout)   = leftpad(layout.minpad)
toppad(layout::GridLayout)    = toppad(layout.minpad)
rightpad(layout::GridLayout)  = rightpad(layout.minpad)
bottompad(layout::GridLayout) = bottompad(layout.minpad)

function GridLayout(
    dims...;
    parent = RootLayout(),
    heights = nothing,
    widths = nothing,
    kw...,
)
    # Check the values for heights and widths if values are provided
    if heights ≢ nothing && widths ≢ nothing
        sum(heights) == 1 || error("The sum of heights must be 1!")
        all(x -> 0 < x < 1, heights) ||
            error("Values for heights must be in the range (0, 1)!")
    else
        heights = zeros(dims[1])
    end
    if heights ≢ nothing && widths ≢ nothing
        sum(widths) == 1 || error("The sum of widths must be 1!")
        all(x -> 0 < x < 1, widths) ||
            error("Values for widths must be in the range (0, 1)!")
    else
        widths = zeros(dims[2])
    end
    grid = Matrix{AbstractLayout}(undef, dims...)
    layout = GridLayout(
        parent,
        DEFAULT_MINPAD[],
        DEFAULT_BBOX[],
        grid,
        Measure[w * pct for w in widths],
        Measure[h * pct for h in heights],
        KW(kw),
    )
    for i in eachindex(grid)
        grid[i] = EmptyLayout(layout)
    end
    layout
end

Base.size(layout::GridLayout) = size(layout.grid)
Base.length(layout::GridLayout) = length(layout.grid)
Base.getindex(layout::GridLayout, r::Int, c::Int) = layout.grid[r, c]
Base.setindex!(layout::GridLayout, v, r::Int, c::Int) = layout.grid[r, c] = v
Base.setindex!(layout::GridLayout, v, ci::CartesianIndex) = layout.grid[ci] = v
