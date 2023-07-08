module Arrows

using ..Plots.Commons
export arrow, add_arrows

# style is :open or :closed (for now)
struct Arrow
    style::Symbol
    side::Symbol  # :head (default), :tail, or :both
    headlength::Float64
    headwidth::Float64
end

"""
    arrow(args...)

Define arrowheads to apply to lines - args are `style` (`:open` or `:closed`),
`side` (`:head`, `:tail` or `:both`), `headlength` and `headwidth`
"""
function arrow(args...)
    style, side = :simple, :head
    headlength = headwidth = 0.3
    setlength = false
    for arg in args
        T = typeof(arg)
        if T == Symbol
            if arg in (:head, :tail, :both)
                side = arg
            else
                style = arg
            end
        elseif T <: Number
            # first we apply to both, but if there's more, then only change width after the first number
            headwidth = Float64(arg)
            if !setlength
                headlength = headwidth
            end
            setlength = true
        elseif T <: Tuple && length(arg) == 2
            headlength, headwidth = Float64(arg[1]), Float64(arg[2])
        else
            @warn "Skipped arrow arg $arg"
        end
    end
    Arrow(style, side, headlength, headwidth)
end

# allow for do-block notation which gets called on every valid start/end pair which
# we need to draw an arrow
function add_arrows(func::Function, x::AVec, y::AVec)
    for i in 2:length(x)
        xyprev = (x[i - 1], y[i - 1])
        xy = (x[i], y[i])
        if ok(xyprev) && ok(xy)
            if i == length(x) || !ok(x[i + 1], y[i + 1])
                # add the arrow from xyprev to xy
                func(xyprev, xy)
            end
        end
    end
end
end # Arrows
