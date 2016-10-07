#inspired by flatwhite syntax theme for Atom
const sand_palette = [colorant"#6494ED", # blue
                      colorant"#73C990", # green
                      colorant"#E2C08D", # brown
                      colorant"#FF6347", # red
                      colorant"#2E2C29", # dark,
                      colorant"#4B4844"] # medium

sand = PlotTheme(colorant"#F7F3EE",
                    colorant"#E2DCD4",
                    colorant"#CBBFAF",
                    colorant"#725B61",
                    [convert(RGBA,c) for c in  distinguishable_colors(20, vcat(colorant"#F7F3EE",sand_palette))][2:end],
                    nothing)

add_theme(:sand,
    bg = sand.bg_secondary,
    bginside = sand.bg_primary,
    fg       = sand.lines,
    fgtext  = sand.text,
    fgguide = sand.text,
    fglegend = sand.text,
    palette = sand.palette)
