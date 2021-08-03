const P2 = GeometryBasics.Point2{Float64}
const P3 = GeometryBasics.Point3{Float64}

const _haligns = :hcenter, :left, :right
const _valigns = :vcenter, :top, :bottom

nanpush!(a::AVec{P2}, b) = (push!(a, P2(NaN, NaN)); push!(a, b))
nanappend!(a::AVec{P2}, b) = (push!(a, P2(NaN, NaN)); append!(a, b))
nanpush!(a::AVec{P3}, b) = (push!(a, P3(NaN, NaN, NaN)); push!(a, b))
nanappend!(a::AVec{P3}, b) = (push!(a, P3(NaN, NaN, NaN)); append!(a, b))
compute_angle(v::P2) = (angle = atan(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

struct Shape{X<:Number, Y<:Number}
    x::Vector{X}
    y::Vector{Y}
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
Shape(verts::AVec) = Shape(RecipesPipeline.unzip(verts)...)
Shape(s::Shape) = deepcopy(s)

get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))

#deprecated
@deprecate shape_coords coords

"return the vertex points from a Shape or Segments object"
coords(shape::Shape) = shape.x, shape.y

#coords(shapes::AVec{Shape}) = unzip(map(coords, shapes))
function coords(shapes::AVec{<:Shape})
    c = map(coords, shapes)
    x = [q[1] for q in c]
    y = [q[2] for q in c]
    x, y
end

"get an array of tuples of points on a circle with radius `r`"
partialcircle(start_θ, end_θ, n=20, r=1) = [
  (r*cos(u), r*sin(u)) for u in range(start_θ, stop=end_θ, length=n)
]

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x, y; ordering=Vector[x, y])
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
function makestar(n; offset=-0.5, radius=1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n+1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n+1, 0.4radius)
    Shape(weave(outercircle, innercircle))
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
makeshape(n; offset=-0.5, radius=1.0) = Shape(
  partialcircle(offset * π, offset * π + 2π, n+1, radius)
)

function makecross(; offset=-0.5, radius=1.0)
    z2 = offset * π
    z1 = z2 - π/8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    Shape(weave(outercircle, innercircle,
                ordering=Vector[outercircle, innercircle, outercircle]))
end

from_polar(angle, dist) = P2(dist*cos(angle), dist*sin(angle))

makearrowhead(angle; h=2.0, w=0.4, tip=from_polar(angle, h)) = Shape(
  P2[(0, 0), from_polar(angle - 0.5π, w) - tip, from_polar(angle + 0.5π, w) - tip, (0, 0)]
)

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
    :vline      => Shape([(0, 1), (0, -1)]),
    :hline      => Shape([(1, 0), (-1, 0)]),
  )

for n in 4:8
  _shapes[Symbol("star$n")] = makestar(n)
end

Shape(k::Symbol) = deepcopy(_shapes[k])

# -----------------------------------------------------------------------

# uses the centroid calculation from https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
"return the centroid of a Shape"
function center(shape::Shape)
    x, y = coords(shape)
    n = length(x)
    A, Cx, Cy = 0, 0, 0
    for i ∈ 1:n
        ip1 = i == n ? 1 : i+1
        A += x[i] * y[ip1] - x[ip1] * y[i]
    end
    A *= 0.5
    for i ∈ 1:n
        ip1 = i == n ? 1 : i+1
        m = (x[i] * y[ip1] - x[ip1] * y[i])
        Cx += (x[i] + x[ip1]) * m
        Cy += (y[i] + y[ip1]) * m
    end
    Cx / 6A, Cy / 6A
end

function scale!(shape::Shape, x::Real, y::Real=x, c=center(shape))
    sx, sy = coords(shape)
    cx, cy = c
    for i ∈ eachindex(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    shape
end

scale(shape::Shape, x::Real, y::Real=x, c=center(shape)) = scale!(deepcopy(shape), x, y, c)


"translate a Shape in space"
function translate!(shape::Shape, x::Real, y::Real=x)
    sx, sy = coords(shape)
    for i ∈ eachindex(sx)
        sx[i] += x
        sy[i] += y
    end
    shape
end

translate(shape::Shape, x::Real, y::Real=x) = translate!(deepcopy(shape), x, y)

rotate_x(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real) = (
    (x - centerx) * cos(Θ) - (y - centery) * sin(Θ) + centerx
)

rotate_y(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real) = (
    (y - centery) * cos(Θ) + (x - centerx) * sin(Θ) + centery
)

rotate(x::Real, y::Real, θ::Real, c=center(shape)) = (
  rotate_x(x, y, Θ, c...),
  rotate_y(x, y, Θ, c...),
)

function rotate!(shape::Shape, Θ::Real, c=center(shape))
    x, y = coords(shape)
    for i ∈ eachindex(x)
        xi = rotate_x(x[i], y[i], Θ, c...)
        yi = rotate_y(x[i], y[i], Θ, c...)
        x[i], y[i] = xi, yi
    end
    shape
end

"rotate an object in space"
function rotate(shape::Shape, θ::Real, c=center(shape))
    x, y = coords(shape)
    x_new = rotate_x.(x, y, θ, c...)
    y_new = rotate_y.(x, y, θ, c...)
    Shape(x_new, y_new)
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

"""
    font(args...)
Create a Font from a list of features. Values may be specified either as
arguments (which are distinguished by type/value) or as keyword arguments.
# Arguments
- `family`: AbstractString. "serif" or "sans-serif" or "monospace"
- `pointsize`: Integer. Size of font in points
- `halign`: Symbol. Horizontal alignment (:hcenter, :left, or :right)
- `valign`: Symbol. Vertical aligment (:vcenter, :top, or :bottom)
- `rotation`: Real. Angle of rotation for text in degrees (use a non-integer type)
- `color`: Colorant or Symbol
# Examples
```julia-repl
julia> font(8)
julia> font(family="serif", halign=:center, rotation=45.0)
```
"""
function font(args...; kw...)
  # defaults
  family = "sans-serif"
  pointsize = 14
  halign = :hcenter
  valign = :vcenter
  rotation = 0
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
    elseif arg ∈ _haligns
      halign = arg
    elseif arg ∈ _valigns
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
      @warn "Unused font arg: $arg ($(typeof(arg)))"
    end
  end

  for sym in keys(kw)
    if sym == :family
      family = string(kw[sym])
    elseif sym == :pointsize
      pointsize = kw[sym]
    elseif sym == :halign
      halign = kw[sym]
      halign == :center && (halign = :hcenter)
      @assert halign ∈ _haligns
    elseif sym == :valign
      valign = kw[sym]
      valign == :center && (valign = :vcenter)
      @assert valign ∈ _valigns
    elseif sym == :rotation
      rotation = kw[sym]
    elseif sym == :color
      color = parse(Colorant, kw[sym])
    else
      @warn "Unused font kwarg: $sym"
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
    for k in keys(merge(_initial_plt_fontsizes, _initial_sp_fontsizes))
        scalefontsize(k, factor)
    end

    for letter in (:x, :y, :z)
        for k in keys(_initial_ax_fontsizes)
            scalefontsize(Symbol(letter, k), factor)
        end
    end
end

"""
    scalefontsizes()

Resets font sizes to initial default values.
"""
function scalefontsizes()
    for k in keys(merge(_initial_plt_fontsizes, _initial_sp_fontsizes))
        f = default(k)
        if k in keys(_initial_fontsizes)
            factor = f / _initial_fontsizes[k]
            scalefontsize(k, 1.0/factor)
        end
    end

    for letter in (:x, :y, :z)
        for k in keys(_initial_ax_fontsizes)
            if k in keys(_initial_fontsizes)
                f = default(Symbol(letter, k))
                factor = f / _initial_fontsizes[k]
                scalefontsize(Symbol(letter, k), 1.0/factor)
            end
        end
    end
end

resetfontsizes() = scalefontsizes()

"Wrap a string with font info"
struct PlotText
  str::AbstractString
  font::Font
end
PlotText(str) = PlotText(string(str), font())

"""
    text(string, args...; kw...)

Create a PlotText object wrapping a string with font info, for plot annotations.
`args` and `kw` are passed to `font`.
"""
text(t::PlotText) = t
text(t::PlotText, font::Font) = PlotText(t.str, font)
text(str::AbstractString, f::Font) = PlotText(str, f)
text(str, args...; kw...) = PlotText(string(str), font(args...; kw...))

Base.length(t::PlotText) = length(t.str)

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
function stroke(args...; alpha=nothing)
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
      @warn "Unused stroke arg: $arg ($(typeof(arg)))"
    end
  end

  Stroke(width, color, alpha, style)
end


struct Brush
  size  # fillrange, markersize, or any other sizey attribute
  color
  alpha
end

function brush(args...; alpha=nothing)
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
      @warn "Unused brush arg: $arg ($(typeof(arg)))"
    end
  end

  Brush(size, color, alpha)
end

# -----------------------------------------------------------------------

mutable struct SeriesAnnotations
    strs::AVec  # the labels/names
    font::Font
    baseshape::Union{Shape, AVec{Shape}, Nothing}
    scalefactor::Tuple
end

_text_label(lab::Tuple, font) = text(lab[1], font, lab[2:end]...)
_text_label(lab::PlotText, font) = lab
_text_label(lab, font) = text(lab, font)

series_annotations(anns::AMat) = map(series_annotations, anns)
series_annotations(scalar) = series_annotations([scalar])
series_annotations(anns::SeriesAnnotations) = anns
series_annotations(::Nothing) = nothing

function series_annotations(strs::AVec, args...)
    fnt = font()
    shp = nothing
    scalefactor = 1, 1
    for arg in args
        if isa(arg, Shape) || (isa(arg, AVec) && eltype(arg) == Shape)
            shp = arg
        elseif isa(arg, Font)
            fnt = arg
        elseif isa(arg, Symbol) && haskey(_shapes, arg)
            shp = _shapes[arg]
        elseif isa(arg, Number)
            scalefactor = arg, arg
        elseif is_2tuple(arg)
            scalefactor = arg
        elseif isa(arg, AVec)
            strs = collect(zip(strs, arg))
        else
            @warn "Unused SeriesAnnotations arg: $arg ($(typeof(arg)))"
        end
    end
    # if scalefactor != 1
    #     for s in get(shp)
    #         scale!(s, scalefactor, scalefactor, (0, 0))
    #     end
    # end
    SeriesAnnotations([_text_label(s, fnt) for s ∈ strs], fnt, shp, scalefactor)
end

function series_annotations_shapes!(series::Series, scaletype::Symbol=:pixels)
    anns = series[:series_annotations]
    # msw, msh = anns.scalefactor
    # ms = series[:markersize]
    # msw, msh = if isa(ms, AVec)
    #     1, 1
    # elseif is_2tuple(ms)
    #     ms
    # else
    #     ms, ms
    # end

    # @show msw msh
    if anns !== nothing && anns.baseshape !== nothing
        # we use baseshape to overwrite the markershape attribute
        # with a list of custom shapes for each
        msw, msh = anns.scalefactor
        msize = Float64[]
        shapes = Vector{Shape}(undef, length(anns.strs))
        for i ∈ eachindex(anns.strs)
            str = _cycle(anns.strs, i)

            # get the width and height of the string (in mm)
            sw, sh = text_size(str, anns.font.pointsize)

            # how much to scale the base shape?
            # note: it's a rough assumption that the shape fills the unit box [-1, -1, 1, 1],
            #       so we scale the length-2 shape by 1/2 the total length
            scalar = (backend() == PyPlotBackend() ? 1.7 : 1.0)
            xscale = 0.5to_pixels(sw) * scalar
            yscale = 0.5to_pixels(sh) * scalar

            # we save the size of the larger direction to the markersize list,
            # and then re-scale a copy of baseshape to match the w/h ratio
            maxscale = max(xscale, yscale)
            push!(msize, maxscale)
            baseshape = _cycle(anns.baseshape, i)
            shapes[i] = scale(baseshape, msw*xscale/maxscale, msh*yscale/maxscale, (0, 0))
        end
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

function Base.iterate(ea::EachAnn, i=1)
    if ea.anns === nothing || isempty(ea.anns.strs) || i > length(ea.y)
        return
    end

    tmp = _cycle(ea.anns.strs, i)
    str, fnt = if isa(tmp, PlotText)
        tmp.str, tmp.font
    else
        tmp, ea.anns.font
    end
    ((_cycle(ea.x, i), _cycle(ea.y, i), str, fnt), i+1)
end

# -----------------------------------------------------------------------
annotations(anns::AMat) = map(annotations, anns)
annotations(sa::SeriesAnnotations) = sa
annotations(anns::AVec) = anns
annotations(anns) = Any[anns]
annotations(::Nothing) = []

_annotationfont(sp::Subplot) = Plots.font(;
  family=sp[:annotationfontfamily],
  pointsize=sp[:annotationfontsize],
  halign=sp[:annotationhalign],
  valign=sp[:annotationvalign],
  rotation=sp[:annotationrotation],
  color=sp[:annotationcolor],
)

_annotation(sp::Subplot, font, lab, pos...; alphabet="abcdefghijklmnopqrstuvwxyz") = (
  pos...,
  lab == :auto ? text("($(alphabet[sp[:subplot_index]]))", font) : _text_label(lab, font)
)

# Expand arrays of coordinates, positions and labels into individual annotations
# and make sure labels are of type PlotText
function process_annotation(sp::Subplot, xs, ys, labs, font=_annotationfont(sp))
    anns = []
    labs = makevec(labs)
    xlength = length(methods(length, (typeof(xs),))) == 0 ? 1 : length(xs)
    ylength = length(methods(length, (typeof(ys),))) == 0 ? 1 : length(ys)
    for i in 1:max(xlength, ylength, length(labs))
      x, y, lab = _cycle(xs, i), _cycle(ys, i), _cycle(labs, i)
      x = typeof(x) <: TimeType ? Dates.value(x) : x
      y = typeof(y) <: TimeType ? Dates.value(y) : y
      push!(anns, _annotation(sp, font, lab, x, y))
    end
    anns
end

function process_annotation(sp::Subplot, positions::Union{AVec{Symbol}, Symbol, Tuple}, labs, font=_annotationfont(sp))
    anns = []
    positions, labs = makevec(positions), makevec(labs)
    for i in 1:max(length(positions), length(labs))
        pos, lab = _cycle(positions, i), _cycle(labs, i)
        push!(anns, _annotation(sp, font, lab, get(_positionAliases, pos, pos)))
    end
    anns
end

_relative_position(xmin, xmax, pos::Length{:pct}) = xmin + pos.value * (xmax - xmin)

# Give each annotation coordinates based on specified position
function locate_annotation(
  sp::Subplot, pos::Symbol, label::PlotText;
  position_multiplier=Dict{Symbol, Tuple{Float64, Float64}}(
    :topleft       => (0.1pct, 0.9pct),
    :topcenter     => (0.5pct, 0.9pct),
    :topright      => (0.9pct, 0.9pct),
    :bottomleft    => (0.1pct, 0.1pct),
    :bottomcenter  => (0.5pct, 0.1pct),
    :bottomright   => (0.9pct, 0.1pct),
  )
)
    x, y = position_multiplier[pos]
    (
      _relative_position(axis_limits(sp, :x)..., x),
      _relative_position(axis_limits(sp, :y)..., y),
      label
    )
end
locate_annotation(sp::Subplot, x, y, label::PlotText) = (x, y, label)
locate_annotation(sp::Subplot, x, y, z, label::PlotText) = (x, y, z, label)

locate_annotation(sp::Subplot, rel::NTuple{2, <:Number}, label::PlotText) = (
  _relative_position(axis_limits(sp, :x)..., rel[1] * Plots.pct),
  _relative_position(axis_limits(sp, :y)..., rel[2] * Plots.pct),
  label
)
locate_annotation(sp::Subplot, rel::NTuple{3, <:Number}, label::PlotText) = (
  _relative_position(axis_limits(sp, :x)..., rel[1] * Plots.pct),
  _relative_position(axis_limits(sp, :y)..., rel[2] * Plots.pct),
  _relative_position(axis_limits(sp, :z)..., rel[3] * Plots.pct),
  label
)
# -----------------------------------------------------------------------

"type which represents z-values for colors and sizes (and anything else that might come up)"
struct ZValues
  values::Vector{Float64}
  zrange::Tuple{Float64, Float64}
end

function zvalues(values::AVec{T}, zrange::Tuple{T, T}=(ignorenan_minimum(values), ignorenan_maximum(values))) where T<:Real
  ZValues(collect(float(values)), map(Float64, zrange))
end

# -----------------------------------------------------------------------

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
# ..(a::T, b::T) = (a, b)

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
    headlength = headwidth = 0.3
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
            @warn "Skipped arrow arg $arg"
        end
    end
    Arrow(style, side, headlength, headwidth)
end


# allow for do-block notation which gets called on every valid start/end pair which
# we need to draw an arrow
function add_arrows(func::Function, x::AVec, y::AVec)
    for i ∈ 2:length(x)
        xyprev = (x[i-1], y[i-1])
        xy = (x[i], y[i])
        if ok(xyprev) && ok(xy)
            if i == length(x) || !ok(x[i+1], y[i+1])
                # add the arrow from xyprev to xy
                func(xyprev, xy)
            end
        end
    end
end

# -----------------------------------------------------------------------
"create a BezierCurve for plotting"
mutable struct BezierCurve{T <: GeometryBasics.Point}
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

@deprecate curve_points coords

coords(curve::BezierCurve, n::Integer=30; range=[0, 1]) = map(
  curve, Base.range(first(range), stop=last(range), length=n)
)

function extrema_plus_buffer(v, buffmult=0.2)
    vmin, vmax = ignorenan_extrema(v)
    vdiff = vmax-vmin
    buffer = vdiff * buffmult
    vmin - buffer, vmax + buffer
end
