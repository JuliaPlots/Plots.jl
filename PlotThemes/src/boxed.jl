const _boxed = [
    :minorticks => true,
    :grid => false,
    :frame => :box,
    :guide_font_valign => :top,
    :guide_font_halign => :right,
    :foreground_color_legend => nothing,
    :legend_font_size => 9,
    :legend => :topright,
    :xlim => (:auto, :auto),
    :ylim => (:auto, :auto),
    :label => "",
    :palette => expand_palette(
        colorant"white",
        [RGB(0, 0, 0); wong_palette];
        lchoices = [57],
        cchoices = [100],
    ),
] |> Dict |> PlotTheme
