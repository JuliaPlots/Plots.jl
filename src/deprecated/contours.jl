

# TODO:
"""
- load Contours.jl similar to DataFrames
- method to build grid from x/y/z vectors
- method to wrap contours creation
- method to plot contours as custom shapes (TODO: create Stroke and Fill types and add markerstroke/markerfill args)

"""



# # ----------------------------------------------------------
# # ----------------------------------------------------------


# immutable Vertex
#   x::Float64
#   y::Float64
#   z::Float64
# end

# immutable Edge
#   v::Vertex
#   u::Vertex
# end

# # ----------------------------------------------------------

# # one rectangle's z-values and the center vertex
# # z is ordered: topleft, topright, bottomright, bottomleft
# immutable GridRect
#   z::Vector{Float64}
#   center::Vertex
#   data::Vector{Vertex}
# end



# type Grid
#   xs::Vector{Float64}
#   ys::Vector{Float64}
#   rects::Matrix{GridRect}
# end

# function splitDataEvenly(v::AbstractVector{Float64}, n::Int)
#   vs = sort(v)
  
# end

# # the goal here is to create the vertical and horizontal partitions
# # which define the grid, so that the data is somewhat evenly split
# function bucketData(x, y, z)

# end


# function buildGrid(x, y, z)
#   # create 
# end


