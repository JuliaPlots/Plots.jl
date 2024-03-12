module BezierCurves

import ..Plots

"create a BezierCurve for plotting"
mutable struct BezierCurve{T<:Tuple}
    control_points::Vector{T}
end

function (bc::BezierCurve)(t::Real)
    p = (0.0, 0.0)
    n = length(bc.control_points) - 1
    for i in 0:n
        p = p .+ bc.control_points[i + 1] .* binomial(n, i) .* (1 - t)^(n - i) .* t^i
    end
    p
end

Plots.coords(curve::BezierCurve, n::Integer = 30; range = [0, 1]) =
    map(curve, Base.range(first(range), stop = last(range), length = n))

end
