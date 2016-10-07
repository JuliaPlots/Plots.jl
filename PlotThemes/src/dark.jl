#inspired by nucleus theme for Atom
const dark_palette = [ colorant"#FE4365", # red
orange= colorant"#eca25c", # orange
green = colorant"#3f9778", # green
blue = colorant"#005D7F"] # blue

dark_bg = colorant"#363D46"
dark = PlotTheme(dark_bg,
                    colorant"#30343B",
                    colorant"#ADB2B7",
                    colorant"#FFFFFF",
                    expand_palette(dark_bg, dark_palette; lchoices=linspace(57,57,1),
                                                          cchoices=linspace(100,100,1)),
                    nothing)

add_plots_theme(:dark, dark)
