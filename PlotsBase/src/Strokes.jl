module Strokes

export Stroke, Brush, stroke, brush

using ..Colors: Colorant
using ..Commons: all_alphas, all_reals, all_styles

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

    for arg ∈ args
        T = typeof(arg)

        # if arg in _all_styles
        if all_styles(arg)
            style = arg
        elseif T <: Colorant
            color = arg
        elseif T <: Symbol || T <: AbstractString
            try
                color = parse(Colorant, string(arg))
            catch
            end
        elseif all_alphas(arg)
            alpha = arg
        elseif all_reals(arg)
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

function brush(args...; alpha = nothing)
    size = 1
    color = :black

    for arg ∈ args
        T = typeof(arg)

        if T <: Colorant
            color = arg
        elseif T <: Symbol || T <: AbstractString
            try
                color = parse(Colorant, string(arg))
            catch
            end
        elseif all_alphas(arg)
            alpha = arg
        elseif all_reals(arg)
            size = arg
        else
            @warn "Unused brush arg: $arg ($(typeof(arg)))"
        end
    end

    Brush(size, color, alpha)
end

end  # module

# -----------------------------------------------------------------------------

using .Strokes
