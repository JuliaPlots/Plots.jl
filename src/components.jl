
immutable Shape
  vertices::AVec
end

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


const _shapes = @compat Dict(
    :ellipse    => makeshape(20),
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
  _shapes[symbol("star$n")] = makestar(n)
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

    if arg == :center
      halign = :hcenter
      valign = :vcenter
    elseif arg in (:hcenter, :left, :right)
      halign = arg
    elseif arg in (:vcenter, :top, :bottom)
      valign = arg
    elseif T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
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
  str::@compat(AbstractString)
  font::Font
end

function text(str, args...)
  PlotText(string(str), font(args...))
end

# -----------------------------------------------------------------------

immutable Stroke
  width
  color
  alpha
  style
end

function stroke(args...; alpha = nothing)
  # defaults
  # width = 1
  # color = colorant"black"
  # style = :solid
  width = nothing
  color = nothing
  style = nothing

  for arg in args
    T = typeof(arg)

    if arg in _allStyles
      style = arg
    elseif T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
      try
        color = parse(Colorant, string(arg))
      end
    elseif typeof(arg) <: Real
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
  # defaults
  # sz = 1
  # color = colorant"black"
  size = nothing
  color = nothing

  for arg in args
    T = typeof(arg)

    if T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
      try
        color = parse(Colorant, string(arg))
      end
    elseif typeof(arg) <: Real
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

"represents a contour or surface mesh"
immutable Surface{M<:AMat}
  # x::AVec
  # y::AVec
  surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi,yi) for xi in x, yi in y])

Base.Array(surf::Surface) = surf.surf

# -----------------------------------------------------------------------

type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end


@require FixedSizeArrays begin

  export
    P2,
    P3,
    points,
    BezierCurve
  
  typealias P2 FixedSizeArrays.Vec{2,Float64}
  typealias P3 FixedSizeArrays.Vec{3,Float64}

  type BezierCurve{T <: FixedSizeArrays.Vec}
      points::Vector{T}
  end

  function Base.call(bc::BezierCurve, t::Real)
      p = zero(P2)
      n = length(bc.points)-1
      for i in 0:n
          p += bc.points[i+1] * binomial(n, i) * (1-t)^(n-i) * t^i
      end
      p
  end

  Base.mean(x::Real, y::Real) = 0.5*(x+y)
  Base.mean{N,T<:Real}(p::FixedSizeArrays.Vec{N,T}, q::FixedSizeArrays.Vec{N,T}) = 0.5 * (p + q)

  points(curve::BezierCurve, n::Integer = 50) = map(curve, linspace(0,1,n))

  function BezierCurve(p::P2, q::P2)
    mn = mean(p,q)
    yoffset = max(0.2, min(1.0, abs(mn[2]-p[2])))
    firstoffset = P2(0, yoffset)

    uppery = p + firstoffset
    lowery = q - firstoffset
    insideoffset = P2(0.2,0)
    inside = []
    if abs(p[1]-q[1]) <= 0.1 && p[2] >= q[2]
      inside = [uppery+insideoffset, lowery+insideoffset]
    end
    # inside = if abs(p[1]-q[1]) <= 0
    #     [uppery+insideoffset, lowery+insideoffset]
    # else
    #     []
    # end

    # if p[2] < q[2] + 0.5
        
    BezierCurve([p, uppery, inside..., lowery, q])
  end

end
