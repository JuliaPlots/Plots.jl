module PlotThemes

using Plots, Colors
import Plots: _invisible, _themes
export PlotTheme

_255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)
expand_palette(bg, palette; kwargs...) = [convert(RGBA,c) for c in  distinguishable_colors(20, vcat(bg, palette); kwargs...)][2:end]
immutable PlotTheme
    bg_primary
    bg_secondary
    lines
    text
    palette
    gradient
end

function add_plots_theme(s, theme)
    add_theme(s,
    bg = theme.bg_secondary,
    bginside = theme.bg_primary,
    fg       = theme.lines,
    fgtext  = theme.text,
    fgguide = theme.text,
    fglegend = theme.text,
    palette = theme.palette)
end

include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
end # module
