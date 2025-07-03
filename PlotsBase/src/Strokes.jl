module Strokes

export Stroke, Brush, stroke, brush

import ..Colors: Colorant
using ..Commons

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

        # if arg in _all_styles
        if Commons.all_styles(arg)
            style = arg
        elseif T <: Colorant
            color = arg
        elseif T <: Symbol || T <: AbstractString
            try
                color = parse(Colorant, string(arg))
            catch
            end
        elseif Commons.all_alphas(arg)
            alpha = arg
        elseif Commons.all_reals(arg)
            width = arg
        else
            @maxlog_warn "Unused stroke arg: $arg ($(typeof(arg)))"
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
        elseif Commons.all_alphas(arg)
            alpha = arg
        elseif Commons.all_reals(arg)
            size = arg
        else
            @maxlog_warn "Unused brush arg: $arg ($(typeof(arg)))"
        end
    end

    return Brush(size, color, alpha)
end

end
