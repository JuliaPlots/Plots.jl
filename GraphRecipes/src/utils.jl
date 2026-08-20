"""
This function builds a BezierCurve which leaves point p vertically upwards and
arrives point q vertically upwards. It may create a loop if necessary.
It assumes the view is [0,1]. That can be modified using the `xview` and
`yview` keyword arguments (default: `0:1`).
"""
function directed_curve(
        x1,
        x2,
        y1,
        y2;
        xview = 0:1,
        yview = 0:1,
        root::Symbol = :bottom,
        rng = nothing,
    )
    if root in (:left, :right)
        # flip x/y to simplify
        x1, x2, y1, y2, xview, yview = y1, y2, x1, x2, yview, xview
    end
    x = Float64[x1, x1]
    y = Float64[y1]

    minx, maxx = extrema(xview)
    miny, maxy = extrema(yview)
    dist = sqrt((x2 - x1)^2 + (y2 - y1)^2)
    flip = root in (:top, :right)
    need_loop = (flip && y1 ≤ y2) || (!flip && y1 ≥ y2)

    # these points give the initial/final "rise"
    # note: this is a function of distance between points and axis scale
    y_offset = if need_loop
        0.3dist
    else
        min(0.3dist, 0.5 * abs(y2 - y1))
    end
    y_offset = max(0.02 * (maxy - miny), y_offset)

    if flip
        # got the other direction
        y_offset *= -1
    end
    push!(y, y1 + y_offset)

    # try to figure out when to loop around vs just connecting straight
    if need_loop
        if abs(x2 - x1) > 0.1 * (maxx - minx)
            # go between
            sgn = x2 > x1 ? 1 : -1
            x_offset = 0.5 * abs(x2 - x1)
            append!(x, [x1 + sgn * x_offset, x2 - sgn * x_offset])
        else
            # add curve points which will create a loop
            x_offset =
                0.3 *
                (maxx - minx) *
                (rand(rng_from_rng_or_seed(rng, nothing), Bool) ? 1 : -1)
            append!(x, [x1 + x_offset, x2 + x_offset])
        end
        append!(y, [y1 + y_offset, y2 - y_offset])
    end

    append!(x, [x2, x2])
    append!(y, [y2 - y_offset, y2])
    if root in (:left, :right)
        # flip x/y to simplify
        x, y = y, x
    end
    return x, y
end

function shorten_segment(x1, y1, x2, y2, shorten)
    xshort = shorten * (x2 - x1)
    yshort = shorten * (y2 - y1)
    return x1 + xshort, y1 + yshort, x2 - xshort, y2 - yshort
end

# """
#     shorten_segment_absolute(x1, y1, x2, y2, shorten)
#
# Remove an amount `shorten` from the end of the line [x1,y1] -> [x2,y2].
# """
# function shorten_segment_absolute(x1, y1, x2, y2, shorten)
#     if x1 == x2 && y1 == y2
#         return x1, y1, x2, y2
#     end
#     t = shorten/sqrt(x1*(x1-2x2) + x2^2 + y1*(y1-2y2) + y2^2)
#     x1, y1, (1.0-t)*x2 + t*x1, (1.0-t)*y2 + t*y1
# end

"""
    nearest_intersection(xs, ys, xd, yd, vec_xy_d)

Find where the line defined by [xs,ys] -> [xd,yd] intersects with the closed shape who's
vertices are stored in `vec_xy_d`. Return the intersection that is closest to the point
[xs,ys] (the source node).
"""
function nearest_intersection(xs, ys, xd, yd, vec_xy_d)
    if xs == xd && ys == yd
        return xs, ys, xd, yd
    end
    t = Vector{Float64}(undef, 2)
    xvec = Vector{Float64}(undef, 2)
    yvec = Vector{Float64}(undef, 2)
    xy_d_edge = Vector{Float64}(undef, 2)
    ret = Vector{Float64}(undef, 2)
    A = Array{Float64}(undef, 2, 2)
    nearest = Inf
    for i in 1:(length(vec_xy_d) - 1)
        xvec .= [vec_xy_d[i][1], vec_xy_d[i + 1][1]]
        yvec .= [vec_xy_d[i][2], vec_xy_d[i + 1][2]]
        A .= [-xs + xd -xvec[1] + xvec[2]; -ys + yd -yvec[1] + yvec[2]]
        t .= (A + eps() * I) \ [xs - xvec[1]; ys - yvec[1]]
        xy_d_edge .=
            [(1 - t[2]) * xvec[1] + t[2] * xvec[2], (1 - t[2]) * yvec[1] + t[2] * yvec[2]]
        if 0 ≤ t[2] ≤ 1
            tmp = abs2(xy_d_edge[1] - xs) + abs2(xy_d_edge[2] - ys)
            if tmp < nearest
                ret .= xy_d_edge
                nearest = tmp
            end
        end
    end
    return xs, ys, ret[1], ret[2]
end

function nearest_intersection(xs, ys, xd, yd, vec_xy_d::GeometryTypes.Circle)
    if xs == xd && ys == yd
        return xs, ys, xd, yd
    end

    α = atan(ys - yd, xs - xd)
    xd = xd + vec_xy_d.r * cos(α)
    yd = yd + vec_xy_d.r * sin(α)

    return xs, ys, xd, yd
end

function nearest_intersection(xs, ys, zs, xd, yd, zd, vec_xyz_d)
    # TODO make 3d work.
end

"""
Randomly pick a point to be the center control point of a bezier curve,
which is both equidistant between the endpoints and normally distributed
around the midpoint.
"""
function random_control_point(
        xi,
        xj,
        yi,
        yj,
        curvature_scalar;
        rng = rng_from_rng_or_seed(rng, nothing),
    )
    xmid = 0.5 * (xi + xj)
    ymid = 0.5 * (yi + yj)

    # get the angle of y relative to x
    theta = atan((yj - yi) / (xj - xi)) + 0.5pi

    # calc random shift relative to dist between x and y
    dist = sqrt((xj - xi)^2 + (yj - yi)^2)
    dist_from_mid = curvature_scalar * (rand(rng) - 0.5) * dist

    # now we have polar coords, we can compute the position, adding to the midpoint
    return (xmid + dist_from_mid * cos(theta), ymid + dist_from_mid * sin(theta))
end

function control_point(xi, xj, yi, yj, dist_from_mid)
    xmid = 0.5 * (xi + xj)
    ymid = 0.5 * (yi + yj)

    # get the angle of y relative to x
    theta = atan((yj - yi) / (xj - xi)) + 0.5pi

    # dist = sqrt((xj-xi)^2 + (yj-yi)^2)
    # dist_from_mid = curvature_scalar * 0.5dist

    # now we have polar coords, we can compute the position, adding to the midpoint
    return (xmid + dist_from_mid * cos(theta), ymid + dist_from_mid * sin(theta))
end

function annotation_extent(p, annotation; width_scalar = 0.06, height_scalar = 0.096)
    str = string(annotation[3])
    position = annotation[1:2]
    plot_size = get(p, :size, (600, 400))
    fontsize = annotation[4]
    xextent_length = width_scalar * (600 / plot_size[1]) * fontsize * length(str)^0.8
    xextent = [position[1] - xextent_length, position[1] + xextent_length]
    yextent_length = height_scalar * (400 / plot_size[2]) * fontsize
    yextent = [position[2] - yextent_length, position[2] + yextent_length]

    return [xextent, yextent]
end

clockwise_difference(angle1, angle2) = pi - abs(abs(angle1 - angle2) - pi)

function clockwise_mean(angles)
    if clockwise_difference(angles[2], angles[1]) > angles[2] - angles[1]
        return mean(angles) + pi
    else
        return mean(angles)
    end
end

"""
    unoccupied_angle(x1, y1, x, y)

Starting from the point [x1,y1], find the angle theta such that a line leaving at an angle
theta will have maximum distance from the points [x[i],y[i]]
"""
function unoccupied_angle(x1, y1, x, y)
    @assert length(x) == length(y)

    if length(x) == 1
        return atan(y[1] - y1, x[1] - x1) + pi
    end

    max_range = zeros(2)
    # Calculate all angles between the point [x1,y1] and all points [x[i],y[i]], make sure
    # that all of the angles are between 0 and 2pi
    angles = [atan(y[i] - y1, x[i] - x1) for i in 1:length(x)]
    for i in 1:length(angles)
        if angles[i] < 0
            angles[i] += 2pi
        end
    end
    # Sort all of the angles and calculate which two angles subtend the largest gap.
    sort!(angles)
    max_range .= [angles[end], angles[1]]
    for i in 2:length(x)
        if (
                clockwise_difference(angles[i], angles[i - 1]) >
                    clockwise_difference(max_range[2], max_range[1])
            )
            max_range .= [angles[i - 1], angles[i]]
        end
    end
    # Return the angle that is in the middle of the two angles subtending the largest
    # empty angle.
    return clockwise_mean(max_range)
end

function process_edge_attribute(attr, source, destiny, weights)
    if isnothing(attr) || (attr isa Symbol)
        return attr
    elseif attr isa Graphs.AbstractGraph
        mat = incidence_matrix(attr)
        attr = [mat[si, di] for (si, di) in zip(source, destiny)][:] |> permutedims
    elseif attr isa Function
        attr =
            [
            attr(si, di, wi) for
                (i, (si, di, wi)) in enumerate(zip(source, destiny, weights))
        ][:] |> permutedims
    elseif attr isa Dict
        attr = [attr[(si, di)] for (si, di) in zip(source, destiny)][:] |> permutedims
    elseif all(size(attr) .!= 1)
        attr = [attr[si, di] for (si, di) in zip(source, destiny)][:] |> permutedims
    end
    return attr
end

function PlotsBase.Shapes.partialcircle(start_θ, end_θ, circle_center::Array{T, 1}, n = 20, r = 1) where {T}
    return Tuple{Float64, Float64}[
        (r * cos(u) + circle_center[1], r * sin(u) + circle_center[2]) for
            u in range(start_θ, stop = end_θ, length = n)
    ]
end

function partialellipse(start_θ, end_θ, n = 20, major_axis = 2, minor_axis = 1)
    return Tuple{Float64, Float64}[
        (major_axis * cos(u), minor_axis * sin(u)) for
            u in range(start_θ, stop = end_θ, length = n)
    ]
end

function partialellipse(
        start_θ,
        end_θ,
        ellipse_center::Array{T, 1},
        n = 20,
        major_axis = 2,
        minor_axis = 1,
    ) where {T}
    return Tuple{Float64, Float64}[
        (major_axis * cos(u) + ellipse_center[1], minor_axis * sin(u) + ellipse_center[2])
            for u in range(start_θ, stop = end_θ, length = n)
    ]
end

# for chord diagrams:
function arcshape(θ1, θ2)
    return vcat(partialcircle(θ1, θ2, 15, 1.05), reverse(partialcircle(θ1, θ2, 15, 0.95)))
end

# x and y limits for arc diagram ()
function arcdiagram_limits(x, source, destiny)
    @assert length(x) ≥ 2
    margin = abs(0.1 * (x[2] - x[1]))
    xmin, xmax = extrema(x)
    r = abs(0.5 * (xmax - xmin))
    mean_upside = mean(source .< destiny)
    ylims = if mean_upside == 1.0
        (-margin, r + margin)
    elseif mean_upside == 0.0
        (-r - margin, margin)
    else
        (-r - margin, r + margin)
    end
    return (xmin - margin, xmax + margin), ylims
end

function islabel(item)
    ismissing(item) && return false
    ((item isa AbstractFloat) && isnan(item)) && return false
    return !in(item, (nothing, false, ""))
end

function replacement_kwarg(sym, name, plotattributes, graph_aliases)
    replacement = name
    for alias in graph_aliases[sym]
        if haskey(plotattributes, alias)
            replacement = plotattributes[alias]
        end
    end
    return replacement
end

macro process_aliases(plotattributes, graph_aliases)
    ex = Expr(:block)
    attributes = getfield(__module__, graph_aliases) |> keys
    ex.args = [
        Expr(
                :(=),
                esc(sym),
                :(
                    $(esc(replacement_kwarg))(
                        $(QuoteNode(sym)),
                        $(esc(sym)),
                        $(esc(plotattributes)),
                        $(esc(graph_aliases)),
                    )
                ),
            ) for sym in attributes
    ]
    return ex
end

remove_aliases!(sym, plotattributes, graph_aliases) =
    for alias in graph_aliases[sym]
    if haskey(plotattributes, alias)
        delete!(plotattributes, alias)
    end
end

# From Plots/src/utils.jl
isnothing(x::Nothing) = true
isnothing(x) = false

# From Plots/src/Plots.jl
ignorenan_extrema(x) = Base.extrema(x)
# From Plots/src/utils.jl
ignorenan_extrema(x::AbstractArray{F}) where {F <: AbstractFloat} = NaNMath.extrema(x)
# From Plots/src/components.jl
function extrema_plus_buffer(v, buffmult = 0.2)
    vmin, vmax = extrema(v)
    vdiff = vmax - vmin
    zero_buffer = vdiff == 0 ? 1.0 : 0.0
    buffer = (vdiff + zero_buffer) * buffmult
    return vmin - buffer, vmax + buffer
end
