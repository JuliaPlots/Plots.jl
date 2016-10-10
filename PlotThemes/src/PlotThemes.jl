module PlotThemes

using Plots, Colors
import Plots: _invisible, _themes
export PlotTheme, plot_theme

_255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)
RGB255(r,g,b) = RGB(r/255, g/255, b/255)
expand_palette(bg, palette; kwargs...) = [convert(RGBA,c) for c in  distinguishable_colors(20, vcat(bg, palette); kwargs...)][2:end]
immutable PlotTheme
    bg_primary
    bg_secondary
    lines
    text
    palette
    gradient
end

PlotTheme(bg_primary, bg_secondary, lines, text, palette) = PlotTheme(bg_primary, bg_secondary, lines, text, palette, nothing)

function add_plots_theme(s, theme)
    add_theme(s,
    bg = theme.bg_secondary,
    bginside = theme.bg_primary,
    fg       = theme.lines,
    fgtext  = theme.text,
    fgguide = theme.text,
    fglegend = theme.text,
    palette = theme.palette)
    if !(theme.gradient == nothing)
        PlotUtils.register_gradient_colors(s, theme.gradient)
    end
end

function plot_theme(s)
    PlotUtils._default_gradient[] = s
    Plots.set_theme(s)
end

include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
include("lime.jl")
include("orange.jl")
end # module
