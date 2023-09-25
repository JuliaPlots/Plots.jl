module Shapes

using Plots: Plots, RecipesPipeline
using Plots.Commons

# keep in mind: these will be reexported and are public API
export shape,
    partialcircle,
    weave,
    makestar,
    makeshape,
    makecross,
    from_polar,
    makearrowhead,
    center,
    scale!,
    scale,
    translate,
    translate!,
    rotate,
    roatate!,
    shape_data

const P2 = NTuple{2,Float64}
const P3 = NTuple{3,Float64}

nanpush!(a::AVec{P2}, b) = (push!(a, (NaN, NaN)); push!(a, b); nothing)
nanappend!(a::AVec{P2}, b) = (push!(a, (NaN, NaN)); append!(a, b); nothing)
nanpush!(a::AVec{P3}, b) = (push!(a, (NaN, NaN, NaN)); push!(a, b); nothing)
nanappend!(a::AVec{P3}, b) = (push!(a, (NaN, NaN, NaN)); append!(a, b); nothing)

compute_angle(v::P2) = (angle = atan(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

struct Shape{X<:Number,Y<:Number}
    x::Vector{X}
    y::Vector{Y}
end

"""
    shape(x, y)
    shape(vertices)

Construct a polygon to be plotted
"""
shape(verts::AVec) = Shape(RecipesPipeline.unzip(verts)...)
Shape(s::Shape) = deepcopy(s)
function shape(x::AVec{X}, y::AVec{Y}) where {X,Y}
    return Shape(convert(Vector{X}, x), convert(Vector{Y}, y))
end

get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))

"return the vertex points from a Shape or Segments object"
Plots.coords(shape::Shape) = shape.x, shape.y

Plots.coords(shapes::AVec{<:Shape}) = RecipesPipeline.unzip(map(coords, shapes))

"get an array of tuples of points on a circle with radius `r`"
partialcircle(start_θ, end_θ, n = 20, r = 1) =
    [(r * cos(u), r * sin(u)) for u in range(start_θ, stop = end_θ, length = n)]

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x, y; ordering = Vector[x, y])
    ret = eltype(x)[]
    done = false
    while !done
        for o in ordering
            try
                push!(ret, popfirst!(o))
            catch
            end
        end
        done = isempty(x) && isempty(y)
    end
    ret
end

"create a star by weaving together points from an outer and inner circle.  `n` is the number of arms"
function makestar(n; offset = -0.5, radius = 1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n + 1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n + 1, 0.4radius)
    shape(weave(outercircle, innercircle))
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
makeshape(n; offset = -0.5, radius = 1.0) =
    shape(partialcircle(offset * π, offset * π + 2π, n + 1, radius))

function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π / 8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    shape(
        weave(
            outercircle,
            innercircle,
            ordering = Vector[outercircle, innercircle, outercircle],
        ),
    )
end

from_polar(angle, dist) = (dist * cos(angle), dist * sin(angle))

makearrowhead(angle; h = 2.0, w = 0.4, tip = from_polar(angle, h)) = Shape(
    NTuple{2,Float64}[
        (0, 0),
        from_polar(angle - 0.5π, w) .- tip,
        from_polar(angle + 0.5π, w) .- tip,
        (0, 0),
    ],
)

const _shapes = KW(
    :circle    => makeshape(20),
    :rect      => makeshape(4, offset = -0.25),
    :diamond   => makeshape(4),
    :utriangle => makeshape(3, offset = 0.5),
    :dtriangle => makeshape(3, offset = -0.5),
    :rtriangle => makeshape(3, offset = 0.0),
    :ltriangle => makeshape(3, offset = 1.0),
    :pentagon  => makeshape(5),
    :hexagon   => makeshape(6),
    :heptagon  => makeshape(7),
    :octagon   => makeshape(8),
    :cross     => makecross(offset = -0.25),
    :xcross    => makecross(),
    :vline     => shape([(0, 1), (0, -1)]),
    :hline     => shape([(1, 0), (-1, 0)]),
    :star4     => makestar(4),
    :star5     => makestar(5),
    :star6     => makestar(6),
    :star7     => makestar(7),
    :star8     => makestar(8),
)

shape(k::Symbol) = deepcopy(_shapes[k])

# -----------------------------------------------------------------------

# uses the centroid calculation from https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
"return the centroid of a Shape"
function center(shape::Shape)
    x, y = coords(shape)
    n = length(x)
    A, Cx, Cy = 0, 0, 0
    for i in 1:n
        ip1 = i == n ? 1 : i + 1
        A += x[i] * y[ip1] - x[ip1] * y[i]
    end
    A *= 0.5
    for i in 1:n
        ip1 = i == n ? 1 : i + 1
        m = (x[i] * y[ip1] - x[ip1] * y[i])
        Cx += (x[i] + x[ip1]) * m
        Cy += (y[i] + y[ip1]) * m
    end
    Cx / 6A, Cy / 6A
end

function scale!(shape::Shape, x::Real, y::Real = x, c = center(shape))
    sx, sy = coords(shape)
    cx, cy = c
    for i in eachindex(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    shape
end

"""
    scale(shape, x, y = x, c = center(shape))
    scale!(shape, x, y = x, c = center(shape))

Scale shape by a factor.
"""
scale(shape::Shape, x::Real, y::Real = x, c = center(shape)) =
    scale!(deepcopy(shape), x, y, c)

function translate!(shape::Shape, x::Real, y::Real = x)
    sx, sy = coords(shape)
    for i in eachindex(sx)
        sx[i] += x
        sy[i] += y
    end
    shape
end

"""
    translate(shape, x, y = x)
    translate!(shape, x, y = x)

Translate a Shape in space.
"""
translate(shape::Shape, x::Real, y::Real = x) = translate!(deepcopy(shape), x, y)

rotate_x(x::Real, y::Real, θ::Real, centerx::Real, centery::Real) =
    ((x - centerx) * cos(θ) - (y - centery) * sin(θ) + centerx)

rotate_y(x::Real, y::Real, θ::Real, centerx::Real, centery::Real) =
    ((y - centery) * cos(θ) + (x - centerx) * sin(θ) + centery)

rotate(x::Real, y::Real, θ::Real, c) = (rotate_x(x, y, θ, c...), rotate_y(x, y, θ, c...))

function rotate!(shape::Shape, θ::Real, c = center(shape))
    x, y = coords(shape)
    for i in eachindex(x)
        xi = rotate_x(x[i], y[i], θ, c...)
        yi = rotate_y(x[i], y[i], θ, c...)
        x[i], y[i] = xi, yi
    end
    shape
end

"rotate an object in space"
function rotate(shape::Shape, θ::Real, c = center(shape))
    x, y = coords(shape)
    x_new = rotate_x.(x, y, θ, c...)
    y_new = rotate_y.(x, y, θ, c...)
    Shape(x_new, y_new)
end

end # Shapes
