# a blue/green/yellow theme of no specific origin
const lime_palette = reverse([colorant"#271924", # dark blue
                      colorant"#394256", # semi dark blue
                      colorant"#30727F", # green blue
                      colorant"#36A58F", # turqoise
                      colorant"#80D584", # green,
                      colorant"#EBFB73"]) # yellow

const black = lime_palette[6]

const _lime = PlotTheme(Dict([
    :bg => black,
    :bginside => black,
    :fg => lime_palette[1],
    :fgtext => lime_palette[2],
    :fgguide => lime_palette[2],
    :fglegend => lime_palette[2],
    :palette => expand_palette(black, lime_palette[1:4]),
    :colorgradient => :viridis])
)
