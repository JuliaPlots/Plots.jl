

# Geometry which displays arbitrary shapes at given (x, y) positions.
immutable ShapeGeometry <: Gadfly.GeometryElement
    vertices::AbstractVector{@compat(Tuple{Float64,Float64})}
    tag::Symbol

    function ShapeGeometry(shape; tag::Symbol=Gadfly.Geom.empty_tag)
        new(shape, tag)
    end
end

# TODO: add for PR
# const shape = ShapeGeometry


function Gadfly.element_aesthetics(::ShapeGeometry)
    [:x, :y, :size, :color]
end


# Generate a form for a shape geometry.
#
# Args:
#   geom: shape geometry.
#   theme: the plot's theme.
#   aes: aesthetics.
#
# Returns:
#   A compose Form.
#
function Gadfly.render(geom::ShapeGeometry, theme::Gadfly.Theme, aes::Gadfly.Aesthetics)

    # TODO: add for PR
    # Gadfly.assert_aesthetics_defined("Geom.shape", aes, :x, :y)
    # Gadfly.assert_aesthetics_equal_length("Geom.shape", aes,
    #                                       element_aesthetics(geom)...)

    default_aes = Gadfly.Aesthetics()
    default_aes.color = Gadfly.DataFrames.PooledDataArray(RGBA{Float32}[theme.default_color])
    default_aes.size = Compose.Measure[theme.default_point_size]
    aes = Gadfly.inherit(aes, default_aes)

    lw_hover_scale = 10
    lw_ratio = theme.line_width / aes.size[1]

    aes_x, aes_y = Gadfly.concretize(aes.x, aes.y)

    ctx = Compose.compose!(
        Compose.context(),
        # circle(aes.x, aes.y, aes.size, geom.tag),
        makeGadflyShapeContext(geom, aes.x, aes.y, aes.size),
        Compose.fill(aes.color),
        Compose.linewidth(theme.highlight_width))

    if aes.color_key_continuous != nothing && aes.color_key_continuous
        Compose.compose!(ctx,
            Compose.stroke(map(theme.continuous_highlight_color, aes.color)))
    else
        Compose.compose!(ctx,
            Compose.stroke(map(theme.discrete_highlight_color, aes.color)),
            Compose.svgclass([Gadfly.svg_color_class_from_label(Gadfly.escape_id(aes.color_label([c])[1]))
                      for c in aes.color]))
    end

    return Compose.compose!(Compose.context(order=4), Compose.svgclass("geometry"), ctx)
end

function gadflyshape(sv::Shape)
  ShapeGeometry(sv.vertices)
end

# const _square = ShapeGeometry(@compat(Tuple{Float64,Float64})[
#     ( 1.0, -1.0),
#     ( 1.0,  1.0),
#     (-1.0,  1.0),
#     (-1.0, -1.0)
#   ])

# const _diamond = ShapeGeometry(@compat(Tuple{Float64,Float64})[
#     ( 0.0, -1.0),
#     ( 1.0,  0.0),
#     ( 0.0,  1.0),
#     (-1.0,  0.0)
#   ])

# const _cross = ShapeGeometry(@compat(Tuple{Float64,Float64})[
#     (-1.0, -0.4), (-1.0,  0.4), # L edge
#     (-0.4,  0.4),               # BL inside
#     (-0.4,  1.0), ( 0.4,  1.0), # B edge
#     ( 0.4,  0.4),               # BR inside
#     ( 1.0,  0.4), ( 1.0, -0.4), # R edge
#     ( 0.4, -0.4),               # TR inside
#     ( 0.4, -1.0), (-0.4, -1.0), # T edge
#     (-0.4, -0.4)                # TL inside
#   ])


# create a Compose context given a ShapeGeometry and the xs/ys/sizes
function makeGadflyShapeContext(geom::ShapeGeometry, xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  T = @compat(Tuple{Compose.Measure, Compose.Measure})
  polys = Array(Vector{T}, n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    # polys[i] = [(x, y - r), (x + r, y), (x, y + r), (x - r, y)]
    polys[i] = T[(x + r * sx, y + r * sy) for (sx,sy) in geom.vertices]
  end
  Gadfly.polygon(polys, geom.tag)
end


# ---------------------------------------------------------------------------------------------



# Compose pseudo-forms for simple symbols, all parameterized by center and size

# using Compose: x_measure, y_measure


# function createGadflyAnnotation(d::Dict, initargs::Dict)
#   sz = [d[:markersize] * Gadfly.px]

#   x, y = d[:x], d[:y]
#   marker = d[:markershape]

#   if d[:linetype] == :ohlc
#     shape = ohlcshape(x, y, d[:markersize])
#     d[:y] = Float64[z.open for z in y]
#     d[:linetype] = :none
#     return Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), shape, Gadfly.fill(nothing), Gadfly.stroke(getColor(d[:color]))))  

#   elseif marker == :rect
#     shape = square(x, y, sz)

#   elseif marker == :diamond
#     shape = diamond(x, y, sz)

#   elseif marker == :utriangle
#     shape = utriangle(x, y, sz)

#   elseif marker == :dtriangle
#     shape = utriangle(x, y, sz, -1)

#   elseif marker == :cross
#     shape = cross(x, y, sz)

#   elseif marker == :xcross
#     shape = xcross(x, y, sz)

#   elseif marker == :star1
#     shape = star1(x, y, sz)

#   elseif marker == :star2
#     shape = star2(x, y, sz)

#   elseif marker == :hexagon
#     shape = hexagon(x, y, sz)

#   elseif marker == :octagon
#     shape = octagon(x, y, sz)

#   else
#     # make circles
#     sz = 0.8 * d[:markersize] * Gadfly.px
#     xs = collect(float(d[:x]))
#     ys = collect(float(d[:y]))
#     shape = Gadfly.circle(xs,ys,[sz])
#   end

#   Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), shape, Gadfly.fill(getColorVector(d[:markercolor])), Gadfly.stroke(getColor(initargs[:foreground_color]))))  
# end


# function square(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))
#   rect_xs = Array(Compose.Measure, n)
#   rect_ys = Array(Compose.Measure, n)
#   rect_ws = Array(Compose.Measure, n)
#   s = 1/sqrt(2)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]

#     rect_xs[i] = x - s*r
#     rect_ys[i] = y + s*r
#     rect_ws[i] = 2*s*r
#   end

#   return Gadfly.rectangle(rect_xs, rect_ys, rect_ws, rect_ws)
# end


# function diamond(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     polys[i] = [(x, y - r), (x + r, y), (x, y + r), (x - r, y)]
#   end

#   return Gadfly.polygon(polys)
# end



# function cross(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = 0.4r

#     # make a "plus sign"
#     polys[i] = [
#       (x-r, y-u), (x-r, y+u), # L edge
#       (x-u, y+u),             # BL inside
#       (x-u, y+r), (x+u, y+r), # B edge
#       (x+u, y+u),             # BR inside
#       (x+r, y+u), (x+r, y-u), # R edge
#       (x+u, y-u),             # TR inside
#       (x+u, y-r), (x-u, y-r), # T edge
#       (x-u, y-u)              # TL inside
#     ]
#   end

#   return Gadfly.polygon(polys)
# end

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



# function star1(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
  
#   # some magic scalars
#   sx1, sx2, sx3 = 0.7, 0.4, 0.2
#   sy1, sy2, sy3 = 1.2, 0.45, 0.1

#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     polys[i] = [
#       (x-sx1*r, y+    r),  # BL
#       (x,       y+sy2*r),
#       (x+sx1*r, y+    r),  # BR
#       (x+sx2*r, y+sy3*r),
#       (x+    r, y-sy2*r),  # R
#       (x+sx3*r, y-sy2*r),
#       (x,       y-sy1*r),  # T
#       (x-sx3*r, y-sy2*r),
#       (x-    r, y-sy2*r),  # L
#       (x-sx2*r, y+sy3*r)
#     ]
#   end

#   return Gadfly.polygon(polys)
# end



# function star2(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
#   n = max(length(xs), length(ys), length(rs))
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = 0.4r
#     polys[i] = [
#       (x-u, y),   (x-r, y-r), # TL
#       (x,   y-u), (x+r, y-r), # TR
#       (x+u, y),   (x+r, y+r), # BR
#       (x,   y+u), (x-r, y+r)  # BL
#     ]
#   end

#   return Gadfly.polygon(polys)
# end



# function hexagon(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
#   n = max(length(xs), length(ys), length(rs))

#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[mod1(i, length(xs))])
#     y = Compose.y_measure(ys[mod1(i, length(ys))])
#     r = rs[mod1(i, length(rs))]
#     u = 0.6r

#     polys[i] = [
#       (x-r, y-u), (x-r, y+u), # L edge
#       (x, y+r),               # B
#       (x+r, y+u), (x+r, y-u), # R edge
#       (x, y-r)                # T
#     ]
#   end

#   return Gadfly.polygon(polys)
# end


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


# # ---------------------------

# function ohlcshape(xs::AVec, ys::AVec{OHLC}, tickwidth::Real)
#   @assert length(xs) == length(ys)
#   n = length(xs)
#   u = tickwidth * Compose.px
#   polys = Array(Vector{@compat(Tuple{Compose.Measure, Compose.Measure})}, n)
#   for i in 1:n
#     x = Compose.x_measure(xs[i])
#     o = Compose.y_measure(ys[i].open)
#     h = Compose.y_measure(ys[i].high)
#     l = Compose.y_measure(ys[i].low)
#     c = Compose.y_measure(ys[i].close)
#     # o,h,l,c = map(Compose.y_measure, ys[i])
#     polys[i] = [
#       (x, o), (x - u, o), (x, o),   # open tick
#       (x, l), (x, h), (x, c),       # high/low bar
#       (x + u, c), (x, c)            # close tick
#     ]
#   end
#   return Gadfly.polygon(polys)
# end



