module PlotThemes

    using Plots
    import Plots: _invisible, _themes

    _255_to_1(c::Symbol, colors) = RGBA(map(x-> x/255,colors[c])...)

    include("ggplot2.jl")
    include("solarized.jl")
    include("stata.jl")
end # module
