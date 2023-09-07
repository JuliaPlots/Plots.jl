module Strokes

export stroke, brush

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

    Brush(size, color, alpha)
end

# -----------------------------------------------------------------------

end # Strokes
