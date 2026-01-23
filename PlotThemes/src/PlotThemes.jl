module PlotThemes

using PlotUtils

export add_theme, theme_palette, PlotTheme

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


# add themes
include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
include("lime.jl")
include("orange.jl")
include("wong.jl")
include("boxed.jl")
include("juno.jl")
include("gruvbox.jl")
include("sheet.jl")
include("dao.jl")
include("dracula.jl")
include("rose_pine.jl")


const _themes = Dict{Symbol, PlotTheme}([
    :default => PlotTheme(),
    :dao => _dao,
    :dark => _dark,
    :ggplot2 => _ggplot2,
    :gruvbox_light => _gruvbox_light,
    :gruvbox_dark => _gruvbox_dark,
    :solarized => _solarized,
    :solarized_light => _solarized_light,
    :sand => _sand,
    :bright => _bright,
    :vibrant => _vibrant,
    :mute => _mute,
    :wong => _wong,
    :wong2 => _wong2,
    :boxed => _boxed,
    :juno => _juno,
    :lime => _lime,
    :orange => _orange,
    :dracula => _dracula,
    :rose_pine => _rose_pine,
    :rose_pine_dawn => _rose_pine_dawn

])


function add_theme(s::Symbol, thm::PlotTheme)
    _themes[s] = thm
end


end # module
