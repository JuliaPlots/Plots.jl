# Names follow:
# https://draculatheme.com/contribute#color-palette
const dracula_palette = [
    colorant"#8be9fd" # Cyan
    colorant"#ff79c6" # Pink
    colorant"#50fa7b" # Green
    colorant"#bd93f9" # Purple
    colorant"#ffb86c" # Orange
    colorant"#ff5555" # Red
    colorant"#f1fa8c" # Yellow
    colorant"#6272a4" # Comment
]
const dracula_bg = colorant"#282a36"
const dracula_fg = colorant"#f8f8f2"

const _dracula = PlotTheme(Dict([
    :bg => dracula_bg,
    :bginside => colorant"#30343B",
    :fg => dracula_fg,
    :fgtext => dracula_fg,
    :fgguide => dracula_fg,
    :fglegend => dracula_fg,
    :legendfontcolor => dracula_fg,
    :legendtitlefontcolor => dracula_fg,
    :titlefontcolor => dracula_fg,
    :palette => expand_palette(dracula_bg, dracula_palette),
    :colorgradient => :viridis])
)
