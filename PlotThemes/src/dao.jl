const dao_palette = [
    colorant"#d77255",
    colorant"#009afa",
    colorant"#707070",
    colorant"#21ab74",
    colorant"#ba3030",
    colorant"#9467bd",
]

const _dao = [
    :background => :white,
    :framestyle => :box,
    :grid => true,
    :gridalpha => 0.4,
    :linewidth => 1.4,
    :markerstrokewidth => 0,
    :font_family => "Computer Modern",
    :colorgradient => :magma,
    :guide_font_size => 12,
    :title_font_size => 12,
    :tick_font_size => 8,
    :palette => dao_palette,
    :minorgrid => true,
    :minorticks => 4,
    :gridlinewidth => 0.7,
    :minorgridalpha => 0.06,
    :legend => :outertopright,
] |> Dict |> PlotTheme
