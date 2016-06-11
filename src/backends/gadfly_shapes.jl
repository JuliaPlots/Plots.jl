

# Geometry which displays arbitrary shapes at given (x, y) positions.
# note: vertices is a list of shapes
immutable ShapeGeometry <: Gadfly.GeometryElement
    vertices::AbstractVector #{Tuple{Float64,Float64}}
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
        make_polygon(geom, aes.x, aes.y, aes.size),
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
  ShapeGeometry(Any[vertices(sv)])
end

function gadflyshape(sv::AVec{Shape})
    ShapeGeometry(Any[vertices(s) for s in sv])
end


# create a Compose context given a ShapeGeometry and the xs/ys/sizes
function make_polygon(geom::ShapeGeometry, xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  T = Tuple{Compose.Measure, Compose.Measure}
  polys = Array(Vector{T}, n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    polys[i] = T[(x + r * sx, y + r * sy) for (sx,sy) in cycle(geom.vertices, i)]
  end
  Gadfly.polygon(polys, geom.tag)
end


# ---------------------------------------------------------------------------------------------
