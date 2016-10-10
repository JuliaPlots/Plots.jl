# a black/yellow theme of no specific origin
const _contrast_palette = reverse([colorant"#271924", # dark blue
                      colorant"#394256", # semi dark blue
                      colorant"#30727F", # green blue
                      colorant"#36A58F", # turqoise
                      colorant"#80D584", # green,
                      colorant"#EBFB73"]) # yellow

black = _contrast_palette[6]

contrast = PlotTheme(black,
                 black,
                    _contrast_palette[1],
                    _contrast_palette[2],
                    expand_palette(black, _contrast_palette[1:4]),
                    _contrast_palette[1:4])

add_plots_theme(:contrast, contrast)
