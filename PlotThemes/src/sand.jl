#inspired by flatwhite syntax theme for Atom
const sand_palette = [colorant"#6494ED", # blue
                      colorant"#73C990", # green
                      colorant"#E2C08D", # brown
                      colorant"#FF6347", # red
                      colorant"#2E2C29", # dark,
                      colorant"#4B4844"] # medium

sand_bg = colorant"#F7F3EE"

sand = PlotTheme(sand_bg,
                    colorant"#E2DCD4",
                    colorant"#CBBFAF",
                    colorant"#725B61",
                    expand_palette(sand_bg, sand_palette),
                    sand_palette[[1,4]])

add_plots_theme(:sand, sand)
