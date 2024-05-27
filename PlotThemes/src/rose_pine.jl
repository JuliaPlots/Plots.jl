# https://rosepinetheme.com
const rose_pine_palette = [
    colorant"#524f67", # Highlight High
    colorant"#31748f", # pine
    colorant"#9ccfd8", # foam
    colorant"#ebbcba", # rose
    colorant"#f6c177", # gold
    colorant"#eb6f92", # love
    colorant"#c4a7e7", # Iris
]

const rose_pine_bg = colorant"#191724"

const _rose_pine = PlotTheme(Dict([
    :bg => rose_pine_bg,
    :bginside => colorant"#1f1d2e",
    :fg => colorant"#e0def4",
    :fgtext => colorant"#e0def4",
    :fgguide => colorant"#e0def4",
    :fglegend => colorant"#e0def4",
    :palette => expand_palette(rose_pine_bg, rose_pine_palette),
    :colorgradient => cgrad(rose_pine_palette)])
)

const rose_pine_dawn_palette = [
    colorant"#907aa9", # Iris
    colorant"#286983", # pine
    colorant"#56949f", # foam
    colorant"#cecacd", # Highlight High
    colorant"#ea9d34", # gold
    colorant"#d7827e", # rose
    colorant"#b4637a", # love
]

const rose_pine_dawn_bg = colorant"#faf4ed"

const _rose_pine_dawn = PlotTheme(Dict([
    :bg => rose_pine_dawn_bg,
    :bginside => colorant"#fffaf3",
    :fg => colorant"#575279",
    :fgtext => colorant"#575279",
    :fgguide => colorant"#575279",
    :fglegend => colorant"#575279",
    :palette => expand_palette(rose_pine_dawn_bg, rose_pine_dawn_palette),
    :colorgradient => cgrad(rose_pine_dawn_palette)])
)
