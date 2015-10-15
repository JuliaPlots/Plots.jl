
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
  initargs::Dict
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
  plts::Vector{Plot}          # the individual plots
  backend::T
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::L
  initargs::Vector{Dict}
  initialized::Bool
  linkx::Bool
  linky::Bool
  linkfunc::Function # maps (row,column) -> (BoolOrNothing, BoolOrNothing)... if xlink/ylink are nothing, then use subplt.linkx/y
end

# -----------------------------------------------------------------------

immutable Shape
  vertices::AVec
end

# const _square = Shape(@compat(Tuple{Float64,Float64})[
#     ( 1.0, -1.0),
#     ( 1.0,  1.0),
#     (-1.0,  1.0),
#     (-1.0, -1.0)
#   ])

# const _diamond = Shape(@compat(Tuple{Float64,Float64})[
#     ( 0.0, -1.0),
#     ( 1.0,  0.0),
#     ( 0.0,  1.0),
#     (-1.0,  0.0)
#   ])

# const _cross = Shape(@compat(Tuple{Float64,Float64})[
#     (-1.0, -0.4), (-1.0,  0.4), # L edge
#     (-0.4,  0.4),               # BL inside
#     (-0.4,  1.0), ( 0.4,  1.0), # B edge
#     ( 0.4,  0.4),               # BR inside
#     ( 1.0,  0.4), ( 1.0, -0.4), # R edge
#     ( 0.4, -0.4),               # TR inside
#     ( 0.4, -1.0), (-0.4, -1.0), # T edge
#     (-0.4, -0.4)                # TL inside
#   ])

# const _xcross = Shape(@compat(Tuple{Float64,Float64})[
#     (x, y - u), (x + u, y - 2u), (x + 2u, y - u),
#     (x + u, y), (x + 2u, y + u), (x + u, y + 2u),
#     (x, y + u), (x - u, y + 2u), (x - 2u, y + u),
#     (x - u, y), (x - 2u, y - u), (x - u, y - 2u)
#   ]


# function xcross(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   s = 1/sqrt(5)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = s*r
#     polys[i] = [
#       (x, y - u), (x + u, y - 2u), (x + 2u, y - u),
#       (x + u, y), (x + 2u, y + u), (x + u, y + 2u),
#       (x, y + u), (x - u, y + 2u), (x - 2u, y + u),
#       (x - u, y), (x - 2u, y - u), (x - u, y - 2u)
#     ]
#   end

#   return Gadfly.polygon(polys)
# end


# const _utriangle = Shape(@compat(Tuple{Float64,Float64})[
#     (x - r, y + u),
#     (x + r, y + u),
#     (x, y - u)
#   ]

# function utriangle(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   s = 0.8
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = 0.8 * scalar * r
#     polys[i] = [
#       (x - r, y + u),
#       (x + r, y + u),
#       (x, y - u)
#     ]
#   end

#   return Gadfly.polygon(polys)
# end

"get an array of tuples of points on a circle with radius `r`"
function partialcircle(start_θ, end_θ, n = 20, r=1)
  @compat(Tuple{Float64,Float64})[(r*cos(u),r*sin(u)) for u in linspace(start_θ, end_θ, n)]
end

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x,y; ordering = Vector[x,y])
  ret = eltype(x)[]
  done = false
  while !done
    for o in ordering
      try
          push!(ret, shift!(o))
      end
      # try
      #     push!(ret, shift!(y))
      # end
    end
    done = isempty(x) && isempty(y)
  end
  ret
end


"create a star by weaving together points from an outer and inner circle.  `n` is the number of arms"
function makestar(n; offset = -0.5, radius = 1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n+1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n+1, 0.4radius)
    Shape(weave(outercircle, innercircle)[1:end-2])
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
function makeshape(n; offset = -0.5, radius = 1.0)
    z = offset * π
    Shape(partialcircle(z, z + 2π, n+1, radius)[1:end-1])
end


function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π/8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    Shape(weave(outercircle, innercircle, 
                ordering=Vector[outercircle,innercircle,outercircle])[1:end-2])
end


const _shapes = Dict(
    :ellipse => makeshape(20),
    :rect => makeshape(4, offset=-0.25),
    :diamond => makeshape(4),
    :utriangle => makeshape(3),
    :dtriangle => makeshape(3, offset=0.5),
    :pentagon => makeshape(5),
    :hexagon => makeshape(6),
    :heptagon => makeshape(7),
    :octagon => makeshape(8),
    :cross => makecross(offset=-0.25),
    :xcross => makecross(),
  )

for n in [4,5,6,7,8]
  _shapes[symbol("star$n")] = makestar(n)
end


# :ellipse, :rect, :diamond, :utriangle, :dtriangle,
#                      :cross, :xcross, :star1, :star2, :hexagon, :octagon




# const _xcross = Shape(@compat(Tuple{Float64,Float64})[
#   ]

# # function hexagon(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
# #   n = max(length(xs), length(ys), length(rs))

# #   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
# #   for i in 1:n
# #     x = Compose.x_measure(xs[mod1(i, length(xs))])
# #     y = Compose.y_measure(ys[mod1(i, length(ys))])
# #     r = rs[mod1(i, length(rs))]
# #     u = 0.6r

# #     polys[i] = [
# #       (x-r, y-u), (x-r, y+u), # L edge
# #       (x, y+r),               # B
# #       (x+r, y+u), (x+r, y-u), # R edge
# #       (x, y-r)                # T
# #     ]
# #   end

# #   return Gadfly.polygon(polys)
# # end



# const _xcross = Shape(@compat(Tuple{Float64,Float64})[
#   ]

# function octagon(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))

#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = 0.4r

#     polys[i] = [
#       (x-r, y-u), (x-r, y+u), # L edge
#       (x-u, y+r), (x+u, y+r), # B edge
#       (x+r, y+u), (x+r, y-u), # R edge
#       (x+u, y-r), (x-u, y-r), # T edge
#     ]
#   end

#   return Gadfly.polygon(polys)
# end

# -----------------------------------------------------------------------

type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end
