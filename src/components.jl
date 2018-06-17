

const P2 = FixedSizeArrays.Vec{2,Float64}
const P3 = FixedSizeArrays.Vec{3,Float64}

nanpush!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); append!(a, b))
nanpush!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); append!(a, b))
compute_angle(v::P2) = (angle = atan2(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

struct Shape
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

"""
    Shape(x, y)
    Shape(vertices)

Construct a polygon to be plotted
"""
Shape(verts::AVec) = Shape(unzip(verts)...)
Shape(s::Shape) = deepcopy(s)

get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))

#deprecated
@deprecate shape_coords coords

"return the vertex points from a Shape or Segments object"
function coords(shape::Shape)
    shape.x, shape.y
end

function coords(shapes::AVec{Shape})
    length(shapes) == 0 && return zeros(0), zeros(0)
    xs = map(get_xs, shapes)
    ys = map(get_ys, shapes)
    x, y = map(copy, coords(shapes[1]))
    for shape in shapes[2:end]
        nanappend!(x, shape.x)
        nanappend!(y, shape.y)
    end
    x, y
end

"get an array of tuples of points on a circle with radius `r`"
function partialcircle(start_θ, end_θ, n = 20, r=1)
    Tuple{Float64,Float64}[(r*cos(u),r*sin(u)) for u in range(start_θ, stop=end_θ, length=n)]
end

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x,y; ordering = Vector[x,y])
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
    outercircle = partialcircle(z1, z1 + 2π, n+1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n+1, 0.4radius)
    Shape(weave(outercircle, innercircle))
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
function makeshape(n; offset = -0.5, radius = 1.0)
    z = offset * π
    Shape(partialcircle(z, z + 2π, n+1, radius))
end


function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π/8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    Shape(weave(outercircle, innercircle,
                ordering=Vector[outercircle,innercircle,outercircle]))
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
  :rtriangle,
  :ltriangle,
  :pentagon,
  :heptagon,
  :octagon,
  :star4,
  :star6,
  :star7,
  :star8,
  :vline,
  :hline,
  :+,
  :x,
]

const _shapes = KW(
    :circle    => makeshape(20),
    :rect       => makeshape(4, offset=-0.25),
    :diamond    => makeshape(4),
    :utriangle  => makeshape(3, offset=0.5),
    :dtriangle  => makeshape(3, offset=-0.5),
    :rtriangle  => makeshape(3, offset=0.0),
    :ltriangle  => makeshape(3, offset=1.0),
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

Shape(k::Symbol) = deepcopy(_shapes[k])

# -----------------------------------------------------------------------


# uses the centroid calculation from https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
"return the centroid of a Shape"
function center(shape::Shape)
    x, y = coords(shape)
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

function scale!(shape::Shape, x::Real, y::Real = x, c = center(shape))
    sx, sy = coords(shape)
    cx, cy = c
    for i=1:length(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    shape
end

function scale(shape::Shape, x::Real, y::Real = x, c = center(shape))
    shapecopy = deepcopy(shape)
    scale!(shapecopy, x, y, c)
end

"translate a Shape in space"
function translate!(shape::Shape, x::Real, y::Real = x)
    sx, sy = coords(shape)
    for i=1:length(sx)
        sx[i] += x
        sy[i] += y
    end
    shape
end

function translate(shape::Shape, x::Real, y::Real = x)
    shapecopy = deepcopy(shape)
    translate!(shapecopy, x, y)
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
    x, y = coords(shape)
    cx, cy = c
    for i=1:length(x)
        xi = rotate_x(x[i], y[i], Θ, cx, cy)
        yi = rotate_y(x[i], y[i], Θ, cx, cy)
        x[i], y[i] = xi, yi
    end
    shape
end

"rotate an object in space"
function rotate(shape::Shape, Θ::Real, c = center(shape))
    shapecopy = deepcopy(shape)
    rotate!(shapecopy, Θ, c)
end

# -----------------------------------------------------------------------


mutable struct Font
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
  family = "sans-serif"
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

function scalefontsize(k::Symbol, factor::Number)
    f = default(k)
    f = round(Int, factor * f)
    default(k, f)
end

"""
    scalefontsizes(factor::Number)

Scales all **current** font sizes by `factor`. For example `scalefontsizes(1.1)` increases all current font sizes by 10%. To reset to initial sizes, use `scalefontsizes()`
"""
function scalefontsizes(factor::Number)
    for k in (:titlefontsize, :guidefontsize, :tickfontsize, :legendfontsize)
        scalefontsize(k, factor)
    end
end

"""
    scalefontsizes()

Resets font sizes to initial default values.
"""
function scalefontsizes()
  for k in (:titlefontsize, :guidefontsize, :tickfontsize, :legendfontsize)
      f = default(k)
      if k in keys(_initial_fontsizes)
        factor = f / _initial_fontsizes[k]
        scalefontsize(k, 1.0/factor)
      end
  end
end

"Wrap a string with font info"
struct PlotText
  str::AbstractString
  font::Font
end
PlotText(str) = PlotText(string(str), font())

"""
    text(string, args...)

Create a PlotText object wrapping a string with font info, for plot annotations
"""
text(t::PlotText) = t
text(t::PlotText, font::Font) = PlotText(t.str, font)
text(str::AbstractString, f::Font) = PlotText(str, f)
function text(str, args...)
  PlotText(string(str), font(args...))
end

Base.length(t::PlotText) = length(t.str)

# -----------------------------------------------------------------------

# -----------------------------------------------------------------------

struct Stroke
  width
  color
  alpha
  style
end

"""
    stroke(args...; alpha = nothing)

Define the properties of the stroke used in plotting lines
"""
function stroke(args...; alpha = nothing)
  width = 1
  color = :black
  style = :solid

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
      catch
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


struct Brush
  size  # fillrange, markersize, or any other sizey attribute
  color
  alpha
end

function brush(args...; alpha = nothing)
  size = 1
  color = :black

  for arg in args
    T = typeof(arg)

    if T <: Colorant
      color = arg
    elseif T <: Symbol || T <: AbstractString
      try
        color = parse(Colorant, string(arg))
      catch
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

mutable struct SeriesAnnotations
    strs::AbstractVector  # the labels/names
    font::Font
    baseshape::Union{Any, Nothing}
    scalefactor::Tuple
end
function series_annotations(strs::AbstractVector, args...)
    fnt = font()
    shp = Union{Any, Nothing}()
    scalefactor = (1,1)
    for arg in args
        if isa(arg, Shape) || (isa(arg, AbstractVector) && eltype(arg) == Shape)
            shp = Union{Any, Nothing}()
        elseif isa(arg, Font)
            fnt = arg
        elseif isa(arg, Symbol) && haskey(_shapes, arg)
            shp = _shapes[arg]
        elseif isa(arg, Number)
            scalefactor = (arg,arg)
        elseif is_2tuple(arg)
            scalefactor = arg
        else
            warn("Unused SeriesAnnotations arg: $arg ($(typeof(arg)))")
        end
    end
    # if scalefactor != 1
    #     for s in get(shp)
    #         scale!(s, scalefactor, scalefactor, (0,0))
    #     end
    # end
    SeriesAnnotations(strs, fnt, shp, scalefactor)
end
series_annotations(anns::SeriesAnnotations) = anns
series_annotations(::Nothing) = nothing

function series_annotations_shapes!(series::Series, scaletype::Symbol = :pixels)
    anns = series[:series_annotations]
    # msw,msh = anns.scalefactor
    # ms = series[:markersize]
    # msw,msh = if isa(ms, AbstractVector)
    #     1,1
    # elseif is_2tuple(ms)
    #     ms
    # else
    #     ms,ms
    # end

    # @show msw msh
    if anns != nothing && (anns.baseshape != nothing)
        # we use baseshape to overwrite the markershape attribute
        # with a list of custom shapes for each
        msw,msh = anns.scalefactor
        msize = Float64[]
        shapes = Shape[begin
            str = _cycle(anns.strs,i)

            # get the width and height of the string (in mm)
            sw, sh = text_size(str, anns.font.pointsize)

            # how much to scale the base shape?
            # note: it's a rough assumption that the shape fills the unit box [-1,-1,1,1],
            #       so we scale the length-2 shape by 1/2 the total length
            scalar = (backend() == PyPlotBackend() ? 1.7 : 1.0)
            xscale = 0.5to_pixels(sw) * scalar
            yscale = 0.5to_pixels(sh) * scalar

            # we save the size of the larger direction to the markersize list,
            # and then re-scale a copy of baseshape to match the w/h ratio
            maxscale = max(xscale, yscale)
            push!(msize, maxscale)
            baseshape = _cycle(get(anns.baseshape),i)
            shape = scale(baseshape, msw*xscale/maxscale, msh*yscale/maxscale, (0,0))
        end for i=1:length(anns.strs)]
        series[:markershape] = shapes
        series[:markersize] = msize
    end
    return
end

mutable struct EachAnn
    anns
    x
    y
end
Base.start(ea::EachAnn) = 1
Base.done(ea::EachAnn, i) = ea.anns == nothing || isempty(ea.anns.strs) || i > length(ea.y)
function Base.next(ea::EachAnn, i)
    tmp = _cycle(ea.anns.strs,i)
    str,fnt = if isa(tmp, PlotText)
        tmp.str, tmp.font
    else
        tmp, ea.anns.font
    end
    ((_cycle(ea.x,i), _cycle(ea.y,i), str, fnt), i+1)
end

annotations(::Nothing) = []
annotations(anns::AVec) = anns
annotations(anns) = Any[anns]
annotations(sa::SeriesAnnotations) = sa

# Expand arrays of coordinates, positions and labels into induvidual annotations
# and make sure labels are of type PlotText
function process_annotation(sp::Subplot, xs, ys, labs, font = font())
    anns = []
    labs = makevec(labs)
    for i in 1:max(length(xs), length(ys), length(labs))
        x, y, lab = _cycle(xs, i), _cycle(ys, i), _cycle(labs, i)
        if lab == :auto
            alphabet = "abcdefghijklmnopqrstuvwxyz"
            push!(anns, (x, y, text(string("(", alphabet[sp[:subplot_index]], ")"), font)))
        else
            push!(anns, (x, y, isa(lab, PlotText) ? lab : text(lab, font)))
        end
    end
    anns
end
function process_annotation(sp::Subplot, positions::Union{AVec{Symbol},Symbol}, labs, font = font())
    anns = []
    positions, labs = makevec(positions), makevec(labs)
    for i in 1:max(length(positions), length(labs))
        pos, lab = _cycle(positions, i), _cycle(labs, i)
        pos = get(_positionAliases, pos, pos)
        if lab == :auto
            alphabet = "abcdefghijklmnopqrstuvwxyz"
            push!(anns, (pos, text(string("(", alphabet[sp[:subplot_index]], ")"), font)))
        else
            push!(anns, (pos, isa(lab, PlotText) ? lab : text(lab, font)))
        end
    end
    anns
end

# Give each annotation coordinates based on specified position
function locate_annotation(sp::Subplot, pos::Symbol, lab::PlotText)
    position_multiplier = Dict{Symbol, Tuple{Float64,Float64}}(
        :topleft       => (0.1, 0.9),
        :topcenter     => (0.5, 0.9),
        :topright      => (0.9, 0.9),
        :bottomleft    => (0.1, 0.1),
        :bottomcenter  => (0.5, 0.1),
        :bottomright   => (0.9, 0.1),
    )
    xmin, xmax = ignorenan_extrema(sp[:xaxis])
    ymin, ymax = ignorenan_extrema(sp[:yaxis])
    x, y = (xmin, ymin).+ position_multiplier[pos].* (xmax - xmin, ymax - ymin)
    (x, y, lab)
end
locate_annotation(sp::Subplot, x, y, label::PlotText) = (x, y, label)
# -----------------------------------------------------------------------

"type which represents z-values for colors and sizes (and anything else that might come up)"
struct ZValues
  values::Vector{Float64}
  zrange::Tuple{Float64,Float64}
end

function zvalues(values::AVec{T}, zrange::Tuple{T,T} = (ignorenan_minimum(values), ignorenan_maximum(values))) where T<:Real
  ZValues(collect(float(values)), map(Float64, zrange))
end

# -----------------------------------------------------------------------

abstract type AbstractSurface end

"represents a contour or surface mesh"
struct Surface{M<:AMat} <: AbstractSurface
  surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi,yi) for yi in y, xi in x])

Base.Array(surf::Surface) = surf.surf

for f in (:length, :size)
  @eval Base.$f(surf::Surface, args...) = $f(surf.surf, args...)
end
Base.copy(surf::Surface) = Surface(copy(surf.surf))
Base.eltype(surf::Surface{T}) where {T} = eltype(T)

function expand_extrema!(a::Axis, surf::Surface)
    ex = a[:extrema]
    for vi in surf.surf
        expand_extrema!(ex, vi)
    end
    ex
end

"For the case of representing a surface as a function of x/y... can possibly avoid allocations."
struct SurfaceFunction <: AbstractSurface
    f::Function
end


# -----------------------------------------------------------------------

# # I don't want to clash with ValidatedNumerics, but this would be nice:
# ..(a::T, b::T) = (a,b)

struct Volume{T}
    v::Array{T,3}
    x_extents::Tuple{T,T}
    y_extents::Tuple{T,T}
    z_extents::Tuple{T,T}
end

default_extents(::Type{T}) where {T} = (zero(T), one(T))

function Volume(v::Array{T,3},
                x_extents = default_extents(T),
                y_extents = default_extents(T),
                z_extents = default_extents(T)) where T
    Volume(v, x_extents, y_extents, z_extents)
end

Base.Array(vol::Volume) = vol.v
for f in (:length, :size)
  @eval Base.$f(vol::Volume, args...) = $f(vol.v, args...)
end
Base.copy(vol::Volume{T}) where {T} = Volume{T}(copy(vol.v), vol.x_extents, vol.y_extents, vol.z_extents)
Base.eltype(vol::Volume{T}) where {T} = T

# -----------------------------------------------------------------------

# style is :open or :closed (for now)
struct Arrow
    style::Symbol
    side::Symbol  # :head (default), :tail, or :both
    headlength::Float64
    headwidth::Float64
end

"""
    arrow(args...)

Define arrowheads to apply to lines - args are `style` (`:open` or `:closed`),
`side` (`:head`, `:tail` or `:both`), `headlength` and `headwidth`
"""
function arrow(args...)
    style = :simple
    side = :head
    headlength = 0.3
    headwidth = 0.3
    setlength = false
    for arg in args
        T = typeof(arg)
        if T == Symbol
            if arg in (:head, :tail, :both)
                side = arg
            else
                style = arg
            end
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
    Arrow(style, side, headlength, headwidth)
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

"Represents data values with formatting that should apply to the tick labels."
struct Formatted{T}
    data::T
    formatter::Function
end

# -----------------------------------------------------------------------
"create a BezierCurve for plotting"
mutable struct BezierCurve{T <: FixedSizeArrays.Vec}
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

# mean(x::Real, y::Real) = 0.5*(x+y) #commented out as I cannot see this used anywhere and it overwrites a Base method with different functionality
# mean{N,T<:Real}(ps::FixedSizeArrays.Vec{N,T}...) = sum(ps) / length(ps) # I also could not see this used anywhere, and it's type piracy - implementing a NaNMath version for this would just involve converting to a standard array

@deprecate curve_points coords

coords(curve::BezierCurve, n::Integer = 30; limits = [0,1]) = map(curve, range(limits[1],stop=limits[2], length=n))

# build a BezierCurve which leaves point p vertically upwards and arrives point q vertically upwards.
# may create a loop if necessary.  Assumes the view is [0,1]
function directed_curve(args...; kw...)
    error("directed_curve has been moved to PlotRecipes")
end

function extrema_plus_buffer(v, buffmult = 0.2)
    vmin,vmax = ignorenan_extrema(v)
    vdiff = vmax-vmin
    buffer = vdiff * buffmult
    vmin - buffer, vmax + buffer
end
