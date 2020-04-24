__precompile__(true)

module PlotThemes

using PlotUtils, Requires

export add_theme, theme_palette

_255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)
RGB255(r,g,b) = RGB(r/255, g/255, b/255)

function expand_palette(bg, cs; kwargs...)
    colors = palette(cs).colors.colors
    c = convert.(RGBA, distinguishable_colors(20, vcat(bg, colors); kwargs...))[2:end]
    return palette(c)
end

const KW = Dict{Symbol, Any}

struct PlotTheme
    defaults::KW
end

PlotTheme(; kw...) = PlotTheme(KW(kw))

# adjust an existing theme
PlotTheme(base::PlotTheme; kw...) = PlotTheme(KW(base.defaults..., KW(kw)...))

"Get the palette of a PlotTheme"
function theme_palette(s::Symbol)
    if haskey(_themes, s) && haskey(_themes[s].defaults, :palette)
        return _themes[s].defaults[:palette]
    else
        return palette(:default)
    end
end

const _themes = Dict{Symbol, PlotTheme}(:default => PlotTheme())

function add_theme(s::Symbol, thm::PlotTheme)
    _themes[s] = thm
end

# add themes
include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
include("lime.jl")
include("orange.jl")
include("wong.jl")
include("juno.jl")
include("gruvbox.jl")
include("sheet.jl")

function __init__()
    # need to do this here so PlotUtils picks up the change
    for (s,thm) in _themes
        add_theme(s, thm)
    end

    @require Juno = "e5e0dc1b-0480-54bc-9374-aad01c23163d" include("juno_smart.jl")
end

end # module
