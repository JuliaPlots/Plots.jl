"""
```julia
legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax)
```

Return `(x,y)` at an angle `theta` degrees from
`(xcenter,ycenter)` on a rectangle defined by (`xmin`, `xmax`, `ymin`, `ymax`).
"""
function legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax)
    (s, c) = sincosd(theta)
    x = c < 0 ? (xmin - xcenter) / c : (xmax - xcenter) / c
    y = s < 0 ? (ymin - ycenter) / s : (ymax - ycenter) / s
    A = min(x, y)
    return (xcenter + A * c, ycenter + A * s)
end

"""
Split continuous range `[-1,1]` evenly into an integer `[1,2,3]`
"""
function legend_anchor_index(x)
    x < -1 // 3 && return 1
    x < 1 // 3 && return 2
    return 3
end

"""
Turn legend argument into a (theta, :inner) or (theta, :outer) tuple.
For backends where legend position is given in normal coordinates (0,0) -- (1,1),
so :topleft exactly corresponds to (45, :inner) etc.

If `leg` is a (::Real,::Real) tuple, keep it as is.
"""
legend_angle(leg::Real) = (leg, :inner)
legend_angle(leg::Tuple{S, T}) where {S <: Real, T <: Real} = leg
legend_angle(leg::Tuple{S, Symbol}) where {S <: Real} = leg
legend_angle(leg::Symbol) = get(
    (
        topleft = (135, :inner),
        top = (90, :inner),
        topright = (45, :inner),
        left = (180, :inner),
        right = (0, :inner),
        bottomleft = (225, :inner),
        bottom = (270, :inner),
        bottomright = (315, :inner),
        outertopleft = (135, :outer),
        outertop = (90, :outer),
        outertopright = (45, :outer),
        outerleft = (180, :outer),
        outerright = (0, :outer),
        outerbottomleft = (225, :outer),
        outerbottom = (270, :outer),
        outerbottomright = (315, :outer),
    ),
    leg,
    (45, :inner),
)
