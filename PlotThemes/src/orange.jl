#252634,#234B57,#207269,#4F9866,#9BB858,#FACF5A
# a blue/green/yellow theme of no specific origin
orange_palette =  reverse([
    colorant"#271924", # dark blue
    colorant"#20545D", # semi dark blue
    colorant"#32856A", # green blue
    colorant"#86B15B", # green,
    colorant"#FACF5A"  # yellow
])
black = orange_palette[5]

_themes[:orange] = PlotTheme(
    bg = black,
    bginside = black,
    fg = orange_palette[1],
    fgtext = orange_palette[2],
    fgguide = orange_palette[2],
    fglegend = orange_palette[2],
    palette = expand_palette(black, orange_palette[1:4]),
    colorgradient = :viridis
)
