

typealias P2 FixedSizeArrays.Vec{2,Float64}
typealias P3 FixedSizeArrays.Vec{3,Float64}

nanpush!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); append!(a, b))
nanpush!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); append!(a, b))
compute_angle(v::P2) = (angle = atan2(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

immutable Shape
    x::Vector{Float64}
    y::Vector{Float64}
    # function Shape(x::AVec, y::AVec)
    #     # if x[1] != x[end] || y[1] != y[end]
    #     #     new(vcat(x, x[1]), vcat(y, y[1]))
    #     # else
    #         new(x, y)
    #     end
    # end
end
Shape(verts::AVec) = Shape(unzip(verts)...)

get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))


function shape_coords(shape::Shape)
    shape.x, shape.y
end

function shape_coords(shapes::AVec{Shape})
    length(shapes) == 0 && return zeros(0), zeros(0)
    xs = map(get_xs, shapes)
    ys = map(get_ys, shapes)
    x, y = map(copy, shape_coords(shapes[1]))
    for shape in shapes[2:end]
        nanappend!(x, shape.x)
        nanappend!(y, shape.y)
    end
    x, y
end

"get an array of tuples of points on a circle with radius `r`"
function partialcircle(start_θ, end_θ, n = 20, r=1)
    Tuple{Float64,Float64}[(r*cos(u),r*sin(u)) for u in linspace(start_θ, end_θ, n)]
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


from_polar(angle, dist) = P2(dist*cos(angle), dist*sin(angle))

function makearrowhead(angle; h = 2.0, w = 0.4)
    tip = from_polar(angle, h)
    Shape(P2[(0,0), from_polar(angle - 0.5π, w) - tip,
        from_polar(angle + 0.5π, w) - tip, (0,0)])
end

const _shape_keys = Symbol[
  :circle,
  :rect,
  :star5,
  :diamond,
  :hexagon,
  :cross,
  :xcross,
  :utriangle,
  :dtriangle,
  :pentagon,
  :heptagon,
  :octagon,
  :star4,
  :star6,
  :star7,
  :star8,
  :vline,
  :hline,
]

const _shapes = KW(
    :circle    => makeshape(20),
    :rect       => makeshape(4, offset=-0.25),
    :diamond    => makeshape(4),
    :utriangle  => makeshape(3),
    :dtriangle  => makeshape(3, offset=0.5),
    :pentagon   => makeshape(5),
    :hexagon    => makeshape(6),
    :heptagon   => makeshape(7),
    :octagon    => makeshape(8),
    :cross      => makecross(offset=-0.25),
    :xcross     => makecross(),
    :vline      => Shape([(0,1),(0,-1)]),
    :hline      => Shape([(1,0),(-1,0)]),
  )

for n in [4,5,6,7,8]
  _shapes[Symbol("star$n")] = makestar(n)
end

# -----------------------------------------------------------------------


# uses the centroid calculation from https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
function center(shape::Shape)
    x, y = shape_coords(shape)
    n = length(x)
    A, Cx, Cy = 0.0, 0.0, 0.0
    for i=1:n
        ip1 = i==n ? 1 : i+1
        A += x[i] * y[ip1] - x[ip1] * y[i]
    end
    A *= 0.5
    for i=1:n
        ip1 = i==n ? 1 : i+1
        m = (x[i] * y[ip1] - x[ip1] * y[i])
        Cx += (x[i] + x[ip1]) * m
        Cy += (y[i] + y[ip1]) * m
    end
    Cx / 6A, Cy / 6A
end

function Base.scale!(shape::Shape, x::Real, y::Real = x, c = center(shape))
    sx, sy = shape_coords(shape)
    cx, cy = c
    for i=1:length(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    shape
end

function Base.scale(shape::Shape, x::Real, y::Real = x, c = center(shape))
    shapecopy = deepcopy(shape)
    scale!(shape, x, y, c)
end

function translate!(shape::Shape, x::Real, y::Real = x)
    sx, sy = shape_coords(shape)
    for i=1:length(sx)
        sx[i] += x
        sy[i] += y
    end
    shape
end

function translate(shape::Shape, x::Real, y::Real = x)
    shapecopy = deepcopy(shape)
    translate!(shape, x, y)
end

function rotate_x(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real)
    (x - centerx) * cos(Θ) - (y - centery) * sin(Θ) + centerx
end

function rotate_y(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real)
    (y - centery) * cos(Θ) + (x - centerx) * sin(Θ) + centery
end

function rotate(x::Real, y::Real, θ::Real, c = center(shape))
    cx, cy = c
    rotate_x(x, y, Θ, cx, cy), rotate_y(x, y, Θ, cx, cy)
end

function rotate!(shape::Shape, Θ::Real, c = center(shape))
    x, y = shape_coords(shape)
    cx, cy = c
    for i=1:length(x)
        x[i] = rotate_x(x[i], y[i], Θ, cx, cy)
        y[i] = rotate_y(x[i], y[i], Θ, cx, cy)
    end
    shape
end

function rotate(shape::Shape, Θ::Real, c = center(shape))
    shapecopy = deepcopy(shape)
    rotate!(shapecopy, Θ, c)
end

# -----------------------------------------------------------------------


immutable Font
  family::AbstractString
  pointsize::Int
  halign::Symbol
  valign::Symbol
  rotation::Float64
  color::Colorant
end

"Create a Font from a list of unordered features"
function font(args...)

  # defaults
  family = "Helvetica"
  pointsize = 14
  halign = :hcenter
  valign = :vcenter
  rotation = 0.0
  color = colorant"black"

  for arg in args
    T = typeof(arg)

    if T == Font
      family = arg.family
      pointsize = arg.pointsize
      halign = arg.halign
      valign = arg.valign
      rotation = arg.rotation
      color = arg.color
    elseif arg == :center
      halign = :hcenter
      valign = :vcenter
    elseif arg in (:hcenter, :left, :right)
      halign = arg
    elseif arg in (:vcenter, :top, :bottom)
      valign = arg
    elseif T <: Colorant
      color = arg
    elseif T <: Symbol || T <: AbstractString
      try
        color = parse(Colorant, string(arg))
      catch
        family = string(arg)
      end
    elseif typeof(arg) <: Integer
      pointsize = arg
    elseif typeof(arg) <: Real
      rotation = convert(Float64, arg)
    else
      warn("Unused font arg: $arg ($(typeof(arg)))")
    end
  end

  Font(family, pointsize, halign, valign, rotation, color)
end

"Wrap a string with font info"
immutable PlotText
  str::AbstractString
  font::Font
end
PlotText(str) = PlotText(string(str), font())

text(t::PlotText) = t
text(str::AbstractString, f::Font) = PlotText(str, f)
function text(str, args...)
  PlotText(string(str), font(args...))
end


annotations(::Void) = []
annotations(anns::AVec) = anns
annotations(anns) = Any[anns]


# -----------------------------------------------------------------------

# -----------------------------------------------------------------------

immutable Stroke
  width
  color
  alpha
  style
end

function stroke(args...; alpha = nothing)
  width = nothing
  color = nothing
  style = nothing

  for arg in args
    T = typeof(arg)

    # if arg in _allStyles
    if allStyles(arg)
      style = arg
    elseif T <: Colorant
      color = arg
    elseif T <: Symbol || T <: AbstractString
      try
        color = parse(Colorant, string(arg))
      end
    elseif allAlphas(arg)
      alpha = arg
    elseif allReals(arg)
      width = arg
    else
      warn("Unused stroke arg: $arg ($(typeof(arg)))")
    end
  end

  Stroke(width, color, alpha, style)
end


immutable Brush
  size  # fillrange, markersize, or any other sizey attribute
  color
  alpha
end

function brush(args...; alpha = nothing)
  size = nothing
  color = nothing

  for arg in args
    T = typeof(arg)

    if T <: Colorant
      color = arg
    elseif T <: Symbol || T <: AbstractString
      try
        color = parse(Colorant, string(arg))
      end
    elseif allAlphas(arg)
      alpha = arg
    elseif allReals(arg)
      size = arg
    else
      warn("Unused brush arg: $arg ($(typeof(arg)))")
    end
  end

  Brush(size, color, alpha)
end

# -----------------------------------------------------------------------

"type which represents z-values for colors and sizes (and anything else that might come up)"
immutable ZValues
  values::Vector{Float64}
  zrange::Tuple{Float64,Float64}
end

function zvalues{T<:Real}(values::AVec{T}, zrange::Tuple{T,T} = (minimum(values), maximum(values)))
  ZValues(collect(float(values)), map(Float64, zrange))
end

# -----------------------------------------------------------------------

abstract AbstractSurface

"represents a contour or surface mesh"
immutable Surface{M<:AMat} <: AbstractSurface
  surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi,yi) for yi in y, xi in x])

Base.Array(surf::Surface) = surf.surf

for f in (:length, :size)
  @eval Base.$f(surf::Surface, args...) = $f(surf.surf, args...)
end
Base.copy(surf::Surface) = Surface{typeof(surf.surf)}(copy(surf.surf))
Base.eltype{T}(surf::Surface{T}) = eltype(T)

function expand_extrema!(a::Axis, surf::Surface)
    ex = a[:extrema]
    for vi in surf.surf
        expand_extrema!(ex, vi)
    end
    ex
end

"For the case of representing a surface as a function of x/y... can possibly avoid allocations."
immutable SurfaceFunction <: AbstractSurface
    f::Function
end

# -----------------------------------------------------------------------

# style is :open or :closed (for now)
immutable Arrow
    style::Symbol
    headlength::Float64
    headwidth::Float64
end

function arrow(args...)
    style = :simple
    headlength = 0.3
    headwidth = 0.3
    setlength = false
    for arg in args
        T = typeof(arg)
        if T == Symbol
            style = arg
        elseif T <: Number
            # first we apply to both, but if there's more, then only change width after the first number
            headwidth = Float64(arg)
            if !setlength
                headlength = headwidth
            end
            setlength = true
        elseif T <: Tuple && length(arg) == 2
            headlength, headwidth = Float64(arg[1]), Float64(arg[2])
        else
            warn("Skipped arrow arg $arg")
        end
    end
    Arrow(style, headlength, headwidth)
end


# allow for do-block notation which gets called on every valid start/end pair which
# we need to draw an arrow
function add_arrows(func::Function, x::AVec, y::AVec)
    for i=2:length(x)
        xyprev = (x[i-1], y[i-1])
        xy = (x[i], y[i])
        if ok(xyprev) && ok(xy)
            if i==length(x) || !ok(x[i+1], y[i+1])
                # add the arrow from xyprev to xy
                func(xyprev, xy)
            end
        end
    end
end


# -----------------------------------------------------------------------

type BezierCurve{T <: FixedSizeArrays.Vec}
  control_points::Vector{T}
end

function (bc::BezierCurve)(t::Real)
  p = zero(P2)
  n = length(bc.control_points)-1
  for i in 0:n
      p += bc.control_points[i+1] * binomial(n, i) * (1-t)^(n-i) * t^i
  end
  p
end

Base.mean(x::Real, y::Real) = 0.5*(x+y)
Base.mean{N,T<:Real}(ps::FixedSizeArrays.Vec{N,T}...) = sum(ps) / length(ps)

curve_points(curve::BezierCurve, n::Integer = 30; range = [0,1]) = map(curve, linspace(range..., n))

# build a BezierCurve which leaves point p vertically upwards and arrives point q vertically upwards.
# may create a loop if necessary.  Assumes the view is [0,1]
function directed_curve(p::P2, q::P2; xview = 0:1, yview = 0:1)
mn = mean(p, q)
diff = q - p

minx, maxx = minimum(xview), maximum(xview)
miny, maxy = minimum(yview), maximum(yview)
diffpct = P2(diff[1] / (maxx - minx),
             diff[2] / (maxy - miny))

# these points give the initial/final "rise"
# vertical_offset = P2(0, (maxy - miny) * max(0.03, min(abs(0.5diffpct[2]), 1.0)))
vertical_offset = P2(0, max(0.15, 0.5norm(diff)))
upper_control = p + vertical_offset
lower_control = q - vertical_offset

# try to figure out when to loop around vs just connecting straight
# TODO: choose loop direction based on sign of p[1]??
# x_close_together = abs(diffpct[1]) <= 0.05
p_is_higher = diff[2] <= 0
inside_control_points = if p_is_higher
  # add curve points which will create a loop
  sgn = mn[1] < 0.5 * (maxx + minx) ? -1 : 1
  inside_offset = P2(0.3 * (maxx - minx), 0)
  additional_offset = P2(sgn * diff[1], 0)  # make it even loopier
  [upper_control + sgn * (inside_offset + max(0,  additional_offset)),
   lower_control + sgn * (inside_offset + max(0, -additional_offset))]
else
  []
end

BezierCurve([p, upper_control, inside_control_points..., lower_control, q])
end
