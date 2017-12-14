__precompile__(true)

module PlotThemes

using PlotUtils

export
    add_theme, palette

_255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)
RGB255(r,g,b) = RGB(r/255, g/255, b/255)
expand_palette(bg, palette; kwargs...) = [convert(RGBA,c) for c in  distinguishable_colors(20, vcat(bg, palette); kwargs...)][2:end]

const KW = Dict{Symbol, Any}

struct PlotTheme
    defaults::KW
end

PlotTheme(; kw...) = PlotTheme(KW(kw))

# adjust an existing theme
PlotTheme(base::PlotTheme; kw...) = PlotTheme(KW(base.defaults..., KW(kw)...))

"Get the palette of a PlotTheme"
function palette(s::Symbol)
    if haskey(_themes, s) && haskey(_themes[s].defaults, :palette)
        return _themes[s].defaults[:palette]
    else
        return get_color_palette(:auto, plot_color(:white), 17)
    end
end

const _themes = Dict{Symbol, PlotTheme}(:default => PlotTheme())

gradient_name(s::Symbol) = s == :default ? :inferno : Symbol(s, "_grad")

function add_theme(s::Symbol, thm::PlotTheme)
    if haskey(thm.defaults, :gradient)
        PlotUtils.register_gradient_colors(gradient_name(s), thm.defaults[:gradient], :misc)
    end
    _themes[s] = thm
end

# add themes
include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
include("lime.jl")
include("orange.jl")
include("juno.jl")
include("wong.jl")

function __init__()
    # need to do this here so PlotUtils picks up the change
    for (s,thm) in _themes
        add_theme(s, thm)
    end
end

end # module
