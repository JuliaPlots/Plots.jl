module Fonts

using ..Commons
using ..Colors

# keep in mind: these will be reexported and are public API
export Font, PlotText, font, scalefontsizes, resetfontsizes, text, is_horizontal

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
        @assert arg ≢ :match

        if T == Font
            family = arg.family
            pointsize = arg.pointsize
            halign = arg.halign
            valign = arg.valign
            rotation = arg.rotation
            color = arg.color
        elseif arg ≡ :center
            halign = :hcenter
            valign = :vcenter
        elseif arg ∈ Commons._haligns
            halign = arg
        elseif arg ∈ Commons._valigns
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
            @maxlog_warn "Unused font arg: $arg ($T)"
        end
    end

    for sym in keys(kw)
        if sym ≡ :family
            family = string(kw[sym])
        elseif sym ≡ :pointsize
            pointsize = kw[sym]
        elseif sym ≡ :halign
            halign = kw[sym]
            halign ≡ :center && (halign = :hcenter)
            @assert halign ∈ _haligns
        elseif sym ≡ :valign
            valign = kw[sym]
            valign ≡ :center && (valign = :vcenter)
            @assert valign ∈ _valigns
        elseif sym ≡ :rotation
            rotation = kw[sym]
        elseif sym ≡ :color
            col = kw[sym]
            color = col isa Colorant ? col : parse(Colorant, col)
        else
            @maxlog_warn "Unused font kwarg: $sym"
        end
    end

    return Font(family, pointsize, halign, valign, rotation, color)
end

function scalefontsize(k::Symbol, factor::Number)
    f = default(k)
    f = round(Int, factor * f)
    return default(k, f)
end

"""
    scalefontsizes(factor::Number)

Scales all **current** font sizes by `factor`. For example `scalefontsizes(1.1)` increases all current font sizes by 10%. To reset to initial sizes, use `scalefontsizes()`
"""
function scalefontsizes(factor::Number)
    for k in merge(Commons._initial_plt_fontsizes, Commons._initial_sp_fontsizes) |> keys
        scalefontsize(k, factor)
    end

    for letter in (:x, :y, :z)
        for k in keys(Commons._initial_ax_fontsizes)
            scalefontsize(get_attr_symbol(letter, k), factor)
        end
    end
    return
end

"""
    scalefontsizes()

Resets font sizes to initial default values.
"""
function scalefontsizes()
    for k in merge(Commons._initial_plt_fontsizes, Commons._initial_sp_fontsizes) |> keys
        f = default(k)
        if k in keys(Commons._initial_fontsizes)
            factor = f / Commons._initial_fontsizes[k]
            scalefontsize(k, 1.0 / factor)
        end
    end

    for letter in (:x, :y, :z)
        keys_initial_fontsizes = keys(Commons._initial_fontsizes)
        for k in keys(Commons._initial_ax_fontsizes)
            if k in keys_initial_fontsizes
                f = default(get_attr_symbol(letter, k))
                factor = f / Commons._initial_fontsizes[k]
                scalefontsize(get_attr_symbol(letter, k), 1.0 / factor)
            end
        end
    end
    return
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

end
