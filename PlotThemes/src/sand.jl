#inspired by flatwhite syntax theme for Atom
const sand_palette = [
    colorant"#6494ED", # blue
    colorant"#73C990", # green
    colorant"#E2C08D", # brown
    colorant"#FF6347", # red
    colorant"#2E2C29", # dark,
    colorant"#4B4844" # medium
]

sand_bg = colorant"#F7F3EE"

_themes[:sand] = PlotTheme(
    bg = sand_bg,
    bginside = colorant"#E2DCD4",
    fg = colorant"#CBBFAF",
    fgtext = colorant"#725B61",
    fgguide = colorant"#725B61",
    fglegend = colorant"#725B61",
    palette = expand_palette(sand_bg, sand_palette),
    gradient = sand_palette[[1,4]]
)
