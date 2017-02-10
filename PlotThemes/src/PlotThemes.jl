__precompile__(true)

module PlotThemes

using PlotUtils

export
    add_theme

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

# by default we don't change the gradient
function PlotTheme(bg_primary, bg_secondary, lines, text, palette)
    PlotTheme(bg_primary, bg_secondary, lines, text, palette, nothing)
end

# adjust an existing theme
function PlotTheme(base::PlotTheme;
                    bg_primary = base.bg_primary,
                    bg_secondary = base.bg_secondary,
                    lines = base.lines,
                    text = base.text,
                    palette = base.palette,
                    gradient = base.gradient
                   )
    PlotTheme(bg_primary, bg_secondary, lines, text, palette, gradient)
end

const _themes = Dict{Symbol, PlotTheme}()

gradient_name(s::Symbol) = Symbol(s, "_grad")

function add_theme(s::Symbol, thm::PlotTheme)
    if thm.gradient != nothing
        PlotUtils.register_gradient_colors(gradient_name(s), thm.gradient)
    end
    _themes[s] = thm
end

include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
include("lime.jl")
include("orange.jl")
include("juno.jl")

function __init__()
    # need to do this here so PlotUtils picks up the change
    for (s,thm) in _themes
        add_theme(s, thm)
    end
end

end # module
