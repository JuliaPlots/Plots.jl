#inspired by nucleus theme for Atom
dark_palette = [
    colorant"#FE4365", # red
    colorant"#eca25c", # orange
    colorant"#3f9778", # green
    colorant"#005D7F" # blue
]
dark_bg = colorant"#363D46"

_themes[:dark] = PlotTheme(
    dark_bg,
    colorant"#30343B",
    colorant"#ADB2B7",
    colorant"#FFFFFF",
    expand_palette(dark_bg, dark_palette; lchoices=linspace(57,57,1),
                                          cchoices=linspace(100,100,1)),
    dark_palette[[2,1]]
)
