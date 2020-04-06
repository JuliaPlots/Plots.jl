using Statistics

if Juno.isactive()
    colors = Juno.syntaxcolors()
    colors = Dict(k => parse(Colorant, "#"*Base.hex(v, 6, false)) for (k, v) in colors)

    juno_palette = unique([colors[k] for k in keys(colors) if k ∉ ["background", "variable"]])

    colvec = sort(HSV.(juno_palette), lt=(a,b) -> a.h < b.h)
    filter!(c -> c.s > 0.5*mean(c -> c.s, colvec), colvec)
    grad = Vector{eltype(colvec)}()
    for i = 1:length(colvec)-1
        append!(grad, range(colvec[i], stop = colvec[i+1]))
    end

    global _themes
    _themes[:juno] = PlotTheme(
        bg = colors["background"],
        bginside = colors["background"],
        fg = colors["variable"],
        fgtext = colors["variable"],
        fgguide = colors["variable"],
        fglegend = colors["variable"],
        palette = expand_palette(colors["background"], juno_palette; lchoices = [57], cchoices = [100]),
        colorgradient = grad
    )
end
