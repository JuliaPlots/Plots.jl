#inspired by nucleus theme for Atom
juno_palette = [
    colorant"#FE4365", # red
    colorant"#eca25c", # orange
    colorant"#3f9778", # green
    colorant"#005D7F" # blue
]

juno_bg = colorant"#282C34"

_themes[:juno] = PlotTheme(
    bg = juno_bg,
    bginside = colorant"#21252B",
    fg = colorant"#ADB2B7",
    fgtext = colorant"#9EB1BE",
    fgguide = colorant"#9EB1BE",
    fglegend = colorant"#9EB1BE",
    palette = expand_palette(juno_bg, juno_palette; lchoices = [57], cchoices = [100]),
    gradient = cgrad(:fire).colors
)

@require Juno = "e5e0dc1b-0480-54bc-9374-aad01c23163d" begin
    if Juno.isactive()
        colors = Juno.syntaxcolors()
        colors = Dict(k => parse(Colorant, "#"*hex(colors[k], 6)) for (k, v) in colors)

        juno_palette = unique([colors[k] for k in keys(colors) if k ∉ ["background", "variable"]])

        colvec = sort(HSV.(juno_palette), lt=(a,b) -> a.h < b.h)
        filter!(c -> c.s > 0.5*mean(c -> c.s, colvec), colvec)
        grad = Vector{eltype(colvec)}(0)
        for i = 1:length(colvec)-1
            append!(grad, range(colvec[i], stop = colvec[i+1]))
        end

        _themes[:juno] = PlotTheme(
            bg = colors["background"],
            bginside = colors["background"],
            fg = colors["variable"],
            fgtext = colors["variable"],
            fgguide = colors["variable"],
            fglegend = colors["variable"],
            palette = expand_palette(colors["background"], juno_palette; lchoices = [57], cchoices = [100]),
            gradient = grad
        )
    end
end
