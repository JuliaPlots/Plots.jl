#inspired by nucleus theme for Atom
dark_palette = [
    colorant"#FE4365", # red
    colorant"#eca25c", # orange
    colorant"#3f9778", # green
    colorant"#005D7F" # blue
]
dark_bg = colorant"#363D46"

_themes[:dark] = PlotTheme(
    bg = dark_bg,
    bginside = colorant"#30343B",
    fg = colorant"#ADB2B7",
    fgtext = colorant"#FFFFFF",
    fgguide = colorant"#FFFFFF",
    fglegend = colorant"#FFFFFF",
    palette = expand_palette(dark_bg, dark_palette; lchoices=linspace(57,57,1),
                                          cchoices=linspace(100,100,1)),
    gradient = dark_palette[[2,1]]
)
