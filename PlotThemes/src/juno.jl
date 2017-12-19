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
    palette = expand_palette(juno_bg, juno_palette; lchoices=linspace(57,57,1),
                                          cchoices=linspace(100,100,1)),
    gradient = cgrad(:fire).colors
)
