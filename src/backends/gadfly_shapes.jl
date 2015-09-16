
# Compose pseudo-forms for simple symbols, all parameterized by center and size

using Compose: x_measure, y_measure

function create

function square(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
    n = max(length(xs), length(ys), length(rs))

    rect_xs = Vector{Measure}(n)
    rect_ys = Vector{Measure}(n)
    rect_ws = Vector{Measure}(n)
    s = 1/sqrt(2)
    for i in 1:n
        x = x_measure(xs[1 + i % length(xs)])
        y = y_measure(ys[1 + i % length(ys)])
        r = rs[1 + i % length(rs)]

        rect_xs[i] = x - s*r
        rect_ys[i] = y - s*r
        rect_ws[i] = 2*s*r
    end

    return rectangle(rect_xs, rect_ys, rect_ws, rect_ws)
end


function diamond(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
    n = max(length(xs), length(ys), length(rs))

    polys = Vector{Vector{Tuple{Measure, Measure}}}(n)
    for i in 1:n
        x = x_measure(xs[1 + i % length(xs)])
        y = y_measure(ys[1 + i % length(ys)])
        r = rs[1 + i % length(rs)]
        polys[i] = Tuple{Measure, Measure}[(x, y - r), (x + r, y), (x, y + r), (x - r, y)]
    end

    return polygon(polys)
end


function cross(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
    n = max(length(xs), length(ys), length(rs))

    polys = Vector{Vector{Tuple{Measure, Measure}}}(n)
    s = 1/sqrt(5)
    for i in 1:n
        x = x_measure(xs[1 + i % length(xs)])
        y = y_measure(ys[1 + i % length(ys)])
        r = rs[1 + i % length(rs)]
        u = s*r
        polys[i] = Tuple{Measure, Measure}[
            (x, y - u), (x + u, y - 2u), (x + 2u, y - u),
            (x + u, y), (x + 2u, y + u), (x + u, y + 2u),
            (x, y + u), (x - u, y + 2u), (x - 2u, y + u),
            (x - u, y), (x - 2u, y - u), (x - u, y - 2u) ]
    end

    return polygon(polys)
end
