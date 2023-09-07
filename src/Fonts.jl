module Fonts

using Plots.Colors
using Plots.Commons
# keep in mind: these will be reexported and are public API
export font, scalefontsizes, resetfontsizes, text, is_horizontal

mutable struct Font
    family::AbstractString
    pointsize::Int
    halign::Symbol
    valign::Symbol
    rotation::Float64
    color::Colorant
end

"""
    font(args...)
Create a Font from a list of features. Values may be specified either as
arguments (which are distinguished by type/value) or as keyword arguments.
# Arguments
- `family`: AbstractString. "serif" or "sans-serif" or "monospace"
- `pointsize`: Integer. Size of font in points
- `halign`: Symbol. Horizontal alignment (:hcenter, :left, or :right)
- `valign`: Symbol. Vertical alignment (:vcenter, :top, or :bottom)
- `rotation`: Real. Angle of rotation for text in degrees (use a non-integer type)
- `color`: Colorant or Symbol
# Examples
```julia-repl
julia> font(8)
julia> font(family="serif", halign=:center, rotation=45.0)
```
"""
function font(args...; kw...)
    # defaults
    family = "sans-serif"
    pointsize = 14
    halign = :hcenter
    valign = :vcenter
    rotation = 0
    color = colorant"black"

    for arg in args
        T = typeof(arg)
        @assert arg !== :match

        if T == Font
            family = arg.family
            pointsize = arg.pointsize
            halign = arg.halign
            valign = arg.valign
            rotation = arg.rotation
            color = arg.color
        elseif arg === :center
            halign = :hcenter
            valign = :vcenter
        elseif arg ∈ _haligns
            halign = arg
        elseif arg ∈ _valigns
            valign = arg
        elseif T <: Colorant
            color = arg
        elseif T <: Symbol || T <: AbstractString
            try
                color = parse(Colorant, string(arg))
            catch
                family = string(arg)
            end
        elseif T <: Integer
            pointsize = arg
        elseif T <: Real
            rotation = convert(Float64, arg)
        else
            @warn "Unused font arg: $arg ($T)"
        end
    end

    for sym in keys(kw)
        if sym === :family
            family = string(kw[sym])
        elseif sym === :pointsize
            pointsize = kw[sym]
        elseif sym === :halign
            halign = kw[sym]
            halign === :center && (halign = :hcenter)
            @assert halign ∈ _haligns
        elseif sym === :valign
            valign = kw[sym]
            valign === :center && (valign = :vcenter)
            @assert valign ∈ _valigns
        elseif sym === :rotation
            rotation = kw[sym]
        elseif sym === :color
            col = kw[sym]
            color = col isa Colorant ? col : parse(Colorant, col)
        else
            @warn "Unused font kwarg: $sym"
        end
    end

    Font(family, pointsize, halign, valign, rotation, color)
end

function scalefontsize(k::Symbol, factor::Number)
    f = default(k)
    f = round(Int, factor * f)
    default(k, f)
end

"""
    scalefontsizes(factor::Number)

Scales all **current** font sizes by `factor`. For example `scalefontsizes(1.1)` increases all current font sizes by 10%. To reset to initial sizes, use `scalefontsizes()`
"""
function scalefontsizes(factor::Number)
    for k in keys(merge(_initial_plt_fontsizes, _initial_sp_fontsizes))
        scalefontsize(k, factor)
    end

    for letter in (:x, :y, :z)
        for k in keys(_initial_ax_fontsizes)
            scalefontsize(get_attr_symbol(letter, k), factor)
        end
    end
end

"""
    scalefontsizes()

Resets font sizes to initial default values.
"""
function scalefontsizes()
    for k in keys(merge(_initial_plt_fontsizes, _initial_sp_fontsizes))
        f = default(k)
        if k in keys(_initial_fontsizes)
            factor = f / _initial_fontsizes[k]
            scalefontsize(k, 1.0 / factor)
        end
    end

    for letter in (:x, :y, :z)
        for k in keys(_initial_ax_fontsizes)
            if k in keys(_initial_fontsizes)
                f = default(get_attr_symbol(letter, k))
                factor = f / _initial_fontsizes[k]
                scalefontsize(get_attr_symbol(letter, k), 1.0 / factor)
            end
        end
    end
end

resetfontsizes() = scalefontsizes()

"Wrap a string with font info"
struct PlotText
    str::AbstractString
    font::Font
end
PlotText(str) = PlotText(string(str), font())

"""
    text(string, args...; kw...)

Create a PlotText object wrapping a string with font info, for plot annotations.
`args` and `kw` are passed to `font`.
"""
text(t::PlotText) = t
text(t::PlotText, font::Font) = PlotText(t.str, font)
text(str::AbstractString, f::Font) = PlotText(str, f)
text(str, args...; kw...) = PlotText(string(str), font(args...; kw...))

Base.length(t::PlotText) = length(t.str)

is_horizontal(t::PlotText) = abs(sind(t.font.rotation)) ≤ sind(45)
end # Fonts
