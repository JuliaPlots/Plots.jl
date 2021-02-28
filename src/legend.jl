"""
```julia
legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax, inout)
```

Return `(x,y)` at an angle `theta` degrees from
`(xcenter,ycenter)` on a rectangle defined by (`xmin`,
`xmax`, `ymin`, `ymax`).
"""
function legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax)
    (s,c) = sincosd(theta)
    x = c < 0 ? (xmin-xcenter)/c : (xmax-xcenter)/c
    y = s < 0 ? (ymin-ycenter)/s : (ymax-ycenter)/s
    A = min(x,y)
    return (xcenter + A*c, ycenter + A*s)
end


"""
Split continuous range `[-1,1]` into an integer `[1,2,3]`
"""
function legend_anchor_index(x)
    return ceil(Integer,2//3*(x+1))
end
