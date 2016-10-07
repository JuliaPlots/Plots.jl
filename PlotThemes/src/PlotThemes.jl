module PlotThemes

using Plots, Colors
import Plots: _invisible, _themes
export PlotTheme

_255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)



immutable PlotTheme
    bg_primary
    bg_secondary
    lines
    text
    palette
    gradient
end


include("dark.jl")
include("ggplot2.jl")
include("solarized.jl")
include("sand.jl")
end # module
