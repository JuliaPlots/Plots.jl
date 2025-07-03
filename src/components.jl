const P2 = NTuple{2, Float64}
const P3 = NTuple{3, Float64}

const _haligns = :hcenter, :left, :right
const _valigns = :vcenter, :top, :bottom

nanpush!(a::AVec{P2}, b) = (push!(a, (NaN, NaN)); push!(a, b); nothing)
nanappend!(a::AVec{P2}, b) = (push!(a, (NaN, NaN)); append!(a, b); nothing)
nanpush!(a::AVec{P3}, b) = (push!(a, (NaN, NaN, NaN)); push!(a, b); nothing)
nanappend!(a::AVec{P3}, b) = (push!(a, (NaN, NaN, NaN)); append!(a, b); nothing)

compute_angle(v::P2) = (angle = atan(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

struct Shape{X <: Number, Y <: Number}
    x::Vector{X}
    y::Vector{Y}
end

"""
    Shape(x, y)
    Shape(vertices)

Construct a polygon to be plotted
"""
Shape(verts::AVec) = Shape(RecipesPipeline.unzip(verts)...)
Shape(s::Shape) = deepcopy(s)
function Shape(x::AVec{X}, y::AVec{Y}) where {X, Y}
    return Shape(convert(Vector{X}, x), convert(Vector{Y}, y))
end

get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))

#deprecated
@deprecate shape_coords coords

"return the vertex points from a Shape or Segments object"
coords(shape::Shape) = shape.x, shape.y

coords(shapes::AVec{<:Shape}) = RecipesPipeline.unzip(map(coords, shapes))

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
    return ret
end

"create a star by weaving together points from an outer and inner circle.  `n` is the number of arms"
function makestar(n; offset = -0.5, radius = 1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n + 1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n + 1, 0.4radius)
    return Shape(weave(outercircle, innercircle))
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
makeshape(n; offset = -0.5, radius = 1.0) =
    Shape(partialcircle(offset * π, offset * π + 2π, n + 1, radius))

function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π / 8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    return Shape(
        weave(
            outercircle,
            innercircle,
            ordering = Vector[outercircle, innercircle, outercircle],
        ),
    )
end

from_polar(angle, dist) = (dist * cos(angle), dist * sin(angle))

makearrowhead(angle; h = 2.0, w = 0.4, tip = from_polar(angle, h)) = Shape(
    NTuple{2, Float64}[
        (0, 0),
        from_polar(angle - 0.5π, w) .- tip,
        from_polar(angle + 0.5π, w) .- tip,
        (0, 0),
    ],
)

const _shapes = KW(
    :circle => makeshape(20),
    :rect => makeshape(4, offset = -0.25),
    :diamond => makeshape(4),
    :utriangle => makeshape(3, offset = 0.5),
    :dtriangle => makeshape(3, offset = -0.5),
    :rtriangle => makeshape(3, offset = 0.0),
    :ltriangle => makeshape(3, offset = 1.0),
    :pentagon => makeshape(5),
    :hexagon => makeshape(6),
    :heptagon => makeshape(7),
    :octagon => makeshape(8),
    :cross => makecross(offset = -0.25),
    :xcross => makecross(),
    :vline => Shape([(0, 1), (0, -1)]),
    :hline => Shape([(1, 0), (-1, 0)]),
    :star4 => makestar(4),
    :star5 => makestar(5),
    :star6 => makestar(6),
    :star7 => makestar(7),
    :star8 => makestar(8),
)

Shape(k::Symbol) = deepcopy(_shapes[k])

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
    return Cx / 6A, Cy / 6A
end

function scale!(shape::Shape, x::Real, y::Real = x, c = center(shape))
    sx, sy = coords(shape)
    cx, cy = c
    for i in eachindex(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    return shape
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
    return shape
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
    return shape
end

"rotate an object in space"
function rotate(shape::Shape, θ::Real, c = center(shape))
    x, y = coords(shape)
    x_new = rotate_x.(x, y, θ, c...)
    y_new = rotate_y.(x, y, θ, c...)
    return Shape(x_new, y_new)
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
- `valign`: Symbol. Vertical alignment (:vcenter, :top, or :bottom)
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
        @assert arg !== :match

        if T == Font
            family = arg.family
            pointsize = arg.pointsize
            halign = arg.halign
            valign = arg.valign
            rotation = arg.rotation
            color = arg.color
        elseif arg === :center
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
        elseif T <: Integer
            pointsize = arg
        elseif T <: Real
            rotation = convert(Float64, arg)
        else
            @warn "Unused font arg: $arg ($T)"
        end
    end

    for sym in keys(kw)
        if sym === :family
            family = string(kw[sym])
        elseif sym === :pointsize
            pointsize = kw[sym]
        elseif sym === :halign
            halign = kw[sym]
            halign === :center && (halign = :hcenter)
            @assert halign ∈ _haligns
        elseif sym === :valign
            valign = kw[sym]
            valign === :center && (valign = :vcenter)
            @assert valign ∈ _valigns
        elseif sym === :rotation
            rotation = kw[sym]
        elseif sym === :color
            col = kw[sym]
            color = col isa Colorant ? col : parse(Colorant, col)
        else
            @warn "Unused font kwarg: $sym"
        end
    end

    return Font(family, pointsize, halign, valign, rotation, color)
end

function scalefontsize(k::Symbol, factor::Number)
    f = default(k)
    f = round(Int, factor * f)
    return default(k, f)
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
            scalefontsize(get_attr_symbol(letter, k), factor)
        end
    end
    return
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
            scalefontsize(k, 1.0 / factor)
        end
    end

    for letter in (:x, :y, :z)
        for k in keys(_initial_ax_fontsizes)
            if k in keys(_initial_fontsizes)
                f = default(get_attr_symbol(letter, k))
                factor = f / _initial_fontsizes[k]
                scalefontsize(get_attr_symbol(letter, k), 1.0 / factor)
            end
        end
    end
    return
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

is_horizontal(t::PlotText) = abs(sind(t.font.rotation)) ≤ sind(45)

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
            @warn "Unused stroke arg: $arg ($(typeof(arg)))"
        end
    end

    return Stroke(width, color, alpha, style)
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
            @warn "Unused brush arg: $arg ($(typeof(arg)))"
        end
    end

    return Brush(size, color, alpha)
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

series_annotations(scalar) = series_annotations([scalar])
series_annotations(anns::SeriesAnnotations) = anns
series_annotations(::Nothing) = nothing

function series_annotations(anns::AMat{SeriesAnnotations})
    @assert size(anns, 1) == 1 "matrix of SeriesAnnotations must be a row vector"
    return anns
end

function series_annotations(anns::AMat, outer_args...)
    # Types that represent annotations for an entire series
    whole_series = Union{AVec, Tuple{AVec, Vararg{Any}}}

    # whole_series types can only be in a row vector
    if size(anns, 1) > 1
        for ann in Iterators.filter(ann -> ann isa whole_series, anns)
            "Given series annotation must be the only element in its column:\n$ann" |>
                ArgumentError |>
                throw
        end
    end

    ann_vec = map(eachcol(anns)) do col
        ann = first(col) isa whole_series ? first(col) : col

        # Override arguments from outer tuple with args from inner tuple
        strs, inner_args = Iterators.peel(wraptuple(ann))
        series_annotations(strs, outer_args..., inner_args...)
    end

    return permutedims(ann_vec)
end

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
    return SeriesAnnotations(map(s -> _text_label(s, fnt), strs), fnt, shp, scalefactor)
end

function series_annotations_shapes!(series::Series, scaletype::Symbol = :pixels)
    anns = series[:series_annotations]

    if anns !== nothing && anns.baseshape !== nothing
        # we use baseshape to overwrite the markershape attribute
        # with a list of custom shapes for each
        msw, msh = anns.scalefactor
        msize = Float64[]
        shapes = Vector{Shape}(undef, length(anns.strs))
        for i in eachindex(anns.strs)
            str = _cycle(anns.strs, i)

            # get the width and height of the string (in mm)
            sw, sh = text_size(str, anns.font.pointsize)

            # how much to scale the base shape?
            # note: it's a rough assumption that the shape fills the unit box [-1, -1, 1, 1],
            #       so we scale the length-2 shape by 1/2 the total length
            scalar = backend() == PyPlotBackend() ? 1.7 : 1.0
            xscale = 0.5to_pixels(sw) * scalar
            yscale = 0.5to_pixels(sh) * scalar

            # we save the size of the larger direction to the markersize list,
            # and then re-scale a copy of baseshape to match the w/h ratio
            maxscale = max(xscale, yscale)
            push!(msize, maxscale)
            baseshape = _cycle(anns.baseshape, i)
            shapes[i] =
                scale(baseshape, msw * xscale / maxscale, msh * yscale / maxscale, (0, 0))
        end
        series[:markershape] = shapes
        series[:markersize] = msize
    end
    return nothing
end

mutable struct EachAnn
    anns
    x
    y
end

function Base.iterate(ea::EachAnn, i = 1)
    (ea.anns === nothing || isempty(ea.anns.strs) || i > length(ea.y)) && return

    tmp = _cycle(ea.anns.strs, i)
    str, fnt = if isa(tmp, PlotText)
        tmp.str, tmp.font
    else
        tmp, ea.anns.font
    end
    return (_cycle(ea.x, i), _cycle(ea.y, i), str, fnt), i + 1
end

# -----------------------------------------------------------------------
annotations(anns::AMat) = map(annotations, anns)
annotations(sa::SeriesAnnotations) = sa
annotations(anns::AVec) = anns
annotations(anns) = Any[anns]
annotations(::Nothing) = []

_annotationfont(sp::Subplot) = font(;
    family = sp[:annotationfontfamily],
    pointsize = sp[:annotationfontsize],
    halign = sp[:annotationhalign],
    valign = sp[:annotationvalign],
    rotation = sp[:annotationrotation],
    color = sp[:annotationcolor],
)

_annotation(sp::Subplot, font, lab, pos...; alphabet = "abcdefghijklmnopqrstuvwxyz") = (
    pos...,
    lab === :auto ? text("($(alphabet[sp[:subplot_index]]))", font) :
        _text_label(lab, font),
)

assign_annotation_coord!(axis, x) = discrete_value!(axis, x)[1]
assign_annotation_coord!(axis, x::TimeType) = assign_annotation_coord!(axis, Dates.value(x))

_annotation_coords(pos::Symbol) = get(_positionAliases, pos, pos)
_annotation_coords(pos) = pos

function _process_annotation_2d(sp::Subplot, x, y, lab, font = _annotationfont(sp))
    x = assign_annotation_coord!(sp[:xaxis], x)
    y = assign_annotation_coord!(sp[:yaxis], y)
    return _annotation(sp, font, lab, x, y)
end

_process_annotation_2d(
    sp::Subplot,
    pos::Union{Tuple, Symbol},
    lab,
    font = _annotationfont(sp),
) = _annotation(sp, font, lab, _annotation_coords(pos))

function _process_annotation_3d(sp::Subplot, x, y, z, lab, font = _annotationfont(sp))
    x = assign_annotation_coord!(sp[:xaxis], x)
    y = assign_annotation_coord!(sp[:yaxis], y)
    z = assign_annotation_coord!(sp[:zaxis], z)
    return _annotation(sp, font, lab, x, y, z)
end

_process_annotation_3d(
    sp::Subplot,
    pos::Union{Tuple, Symbol},
    lab,
    font = _annotationfont(sp),
) = _annotation(sp, font, lab, _annotation_coords(pos))

function _process_annotation(sp::Subplot, ann, annotation_processor::Function)
    ann = makevec.(ann)
    return [annotation_processor(sp, _cycle.(ann, i)...) for i in 1:maximum(length.(ann))]
end

# Expand arrays of coordinates, positions and labels into individual annotations
# and make sure labels are of type PlotText
process_annotation(sp::Subplot, ann) =
    _process_annotation(sp, ann, is3d(sp) ? _process_annotation_3d : _process_annotation_2d)

function _relative_position(xmin, xmax, pos::Length{:pct}, scale::Symbol)
    # !TODO Add more scales in the future (asinh, sqrt) ?
    return if scale === :log || scale === :ln
        exp(log(xmin) + pos.value * log(xmax / xmin))
    elseif scale === :log10
        exp10(log10(xmin) + pos.value * log10(xmax / xmin))
    elseif scale === :log2
        exp2(log2(xmin) + pos.value * log2(xmax / xmin))
    else  # :identity (linear scale)
        xmin + pos.value * (xmax - xmin)
    end
end

# annotation coordinates in pct
const position_multiplier = Dict(
    :N => (0.5, 0.9),
    :NE => (0.9, 0.9),
    :E => (0.9, 0.5),
    :SE => (0.9, 0.1),
    :S => (0.5, 0.1),
    :SW => (0.1, 0.1),
    :W => (0.1, 0.5),
    :NW => (0.1, 0.9),
    :topleft => (0.1, 0.9),
    :topcenter => (0.5, 0.9),
    :topright => (0.9, 0.9),
    :bottomleft => (0.1, 0.1),
    :bottomcenter => (0.5, 0.1),
    :bottomright => (0.9, 0.1),
)

# Give each annotation coordinates based on specified position
locate_annotation(sp::Subplot, rel::Tuple, label::PlotText) = (
    map(1:length(rel), (:x, :y, :z)) do i, letter
        _relative_position(
            axis_limits(sp, letter)...,
            rel[i] * pct,
            sp[get_attr_symbol(letter, :axis)][:scale],
        )
    end...,
    label,
)

locate_annotation(sp::Subplot, x, y, label::PlotText) = (x, y, label)
locate_annotation(sp::Subplot, x, y, z, label::PlotText) = (x, y, z, label)
locate_annotation(sp::Subplot, pos::Symbol, label::PlotText) =
    locate_annotation(sp, position_multiplier[pos], label)

# -----------------------------------------------------------------------

function expand_extrema!(a::Axis, surf::Surface)
    ex = a[:extrema]
    foreach(x -> expand_extrema!(ex, x), surf.surf)
    return ex
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
    style, side = :simple, :head
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
    return Arrow(style, side, headlength, headwidth)
end

# allow for do-block notation which gets called on every valid start/end pair which
# we need to draw an arrow
function add_arrows(func::Function, x::AVec, y::AVec)
    for i in 2:length(x)
        xyprev = (x[i - 1], y[i - 1])
        xy = (x[i], y[i])
        if ok(xyprev) && ok(xy)
            if i == length(x) || !ok(x[i + 1], y[i + 1])
                # add the arrow from xyprev to xy
                func(xyprev, xy)
            end
        end
    end
    return
end

# -----------------------------------------------------------------------
"create a BezierCurve for plotting"
mutable struct BezierCurve{T <: Tuple}
    control_points::Vector{T}
end

function (bc::BezierCurve)(t::Real)
    p = (0.0, 0.0)
    n = length(bc.control_points) - 1
    for i in 0:n
        p = p .+ bc.control_points[i + 1] .* binomial(n, i) .* (1 - t)^(n - i) .* t^i
    end
    return p
end

@deprecate curve_points coords

coords(curve::BezierCurve, n::Integer = 30; range = [0, 1]) =
    map(curve, Base.range(first(range), stop = last(range), length = n))

function extrema_plus_buffer(v, buffmult = 0.2)
    vmin, vmax = ignorenan_extrema(v)
    vdiff = vmax - vmin
    buffer = vdiff * buffmult
    return vmin - buffer, vmax + buffer
end

### Legend

@add_attributes subplot struct Legend
    background_color = :match
    foreground_color = :match
    position = :best
    title = nothing
    font::Font = font(8)
    title_font::Font = font(11)
    column = 1
end :match = (
    :legend_font_family,
    :legend_font_color,
    :legend_title_font_family,
    :legend_title_font_color,
)
