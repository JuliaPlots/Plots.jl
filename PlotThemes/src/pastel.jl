const pastel_palette = [
    colorant"#EDDCD2",
    colorant"#FAD2E1",
    colorant"#C5DEDD",
    colorant"#99C1DE",
    colorant"#FDE2E4",
    colorant"#DBE7E4",
    colorant"#BCD4E6",

]

const pastel_bg         = colorant"#fdfaf9"
const pastel_bginside   = colorant"#f8f4f3"
const pastel_fg         = colorant"#554e52"
const pastel_fgguide    = colorant"#7a7079"

const pastel_gradient = cgrad([
    colorant"#EDDCD2",
    colorant"#99C1DE"
])

const _pastel = [
    :bg => pastel_bg,
    :bginside => pastel_bginside,
    :fg => pastel_fg,
    :fgtext => pastel_fg,
    :fgguide => pastel_fgguide,
    :fglegend => pastel_fgguide,
    :palette => expand_palette(pastel_bg, pastel_palette),
    :colorgradient => pastel_gradient,
] |> Dict |> PlotTheme
