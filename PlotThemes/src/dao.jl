const dao_palette = [
    colorant"#d77255",
    colorant"#009afa",
    colorant"#707070",
    colorant"#21ab74",
    colorant"#ba3030",
    colorant"#9467bd"
]

const _dao = PlotTheme(Dict([
    :background => :white,
    :framestyle => :box,
    :grid => true,
    :gridalpha => 0.4,
    :linewidth => 1.4,
    :markerstrokewidth => 0,
    :fontfamily => "Computer Modern",
    :colorgradient => :magma,
    :guidefontsize => 12,
    :titlefontsize => 12,
    :tickfontsize => 8,
    :palette => dao_palette,
    :minorgrid => true,
    :minorticks => 5,
    :gridlinewidth => 0.7,
    :minorgridalpha => 0.06,
    :legend => :outertopright])
)
