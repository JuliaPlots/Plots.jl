#inspired by nucleus theme for Atom
const dark_palette = [
    colorant"#FE4365", # red
    colorant"#eca25c", # orange
    colorant"#3f9778", # green
    colorant"#005D7F", # blue
]
const dark_bg = colorant"#363D46"

const _dark = [
    :bg => dark_bg,
    :bginside => colorant"#30343B",
    :fg => colorant"#ADB2B7",
    :fgtext => colorant"#FFFFFF",
    :fgguide => colorant"#FFFFFF",
    :fglegend => colorant"#FFFFFF",
    :legend_font_color => colorant"#FFFFFF",
    :legend_title_font_color => colorant"#FFFFFF",
    :title_font_color => colorant"#FFFFFF",
    :palette =>
        expand_palette(dark_bg, dark_palette; lchoices = [57], cchoices = [100]),
    :colorgradient => :fire,
] |> Dict |> PlotTheme
