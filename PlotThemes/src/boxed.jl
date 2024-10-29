const _boxed = PlotTheme(Dict([
    :minorticks => true,
    :grid => false,
    :frame => :box,
    :guidefontvalign => :top,
    :guidefonthalign => :right,
    :foreground_color_legend  =>  nothing,
    :legendfontsize => 9,
    :legend  => :topright,
    :xlim => (:auto,:auto),
    :ylim => (:auto,:auto),
    :label => "",
    :palette => expand_palette(colorant"white", [RGB(0,0,0); wong_palette];
        lchoices = [57],
        cchoices = [100])
    ]))
