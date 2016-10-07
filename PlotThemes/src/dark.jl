dark1 = colorant"#30353A"
dark2 = colorant"#3D444D"
light =colorant"#ADB2B7"
red=colorant"#FE4365"
orange=colorant"#eca25c"
green=colorant"#3f9778"
blue=colorant"#005D7F"
black =colorant"#ffffff"

dark_bg = colorant"#363D46"
dark = PlotTheme(dark_bg,
                    colorant"#30343B",
                    colorant"#ADB2B7",
                    colorant"#FFFFFF",
                    [convert(RGBA,c) for c in  distinguishable_colors(20, dark_bg;lchoices=linspace(57,57,1),
                                                                        cchoices=linspace(100,100,1))][2:end],
                    nothing)

add_theme(:dark,
    bg = dark.bg_secondary,
    bginside = dark.bg_primary,
    fg       = dark.lines,
    fgtext  = dark.text,
    fgguide = dark.text,
    fglegend = dark.text,
    palette = dark.palette)
