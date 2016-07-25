const _stata_palette = (:gs6, :navy, :maroon, :forest_green, :dkorange, :teal,
                        :cranberry, :lavender, :khaki, :sienna, :emidblue,
                        :emerald, :brown, :erose, :gold, :bluishgray)

const _stata_colors =  Dict{Symbol, Tuple}(
                       :gs6 => (96, 96, 96),
                       :navy => (26, 71, 111),
                       :maroon => (144, 53, 59),
                       :forest_green => (86, 117, 47),
                       :dkorange => (227, 126, 0),
                       :teal => (110, 142, 132),
                       :cranberry => (193, 5, 52),
                       :lavender => (147, 141, 210),
                       :khaki => (202, 194, 126),
                       :sienna => (160, 82, 45),
                       :emidblue => (123, 146, 168),
                       :emerald => (45, 109, 102),
                       :brown => (156, 136, 71),
                       :erose => (191, 161, 156),
                       :gold => (255, 210, 0),
                       :bluishgray => (217, 230, 235))

_get_stata_color(c) = _255_to_1(c, _stata_colors)

add_theme(:stata_s2,
    palette  = [map(c->_get_stata_color(c), _stata_palette)...],
    bglegend = _invisible,
    fglegend = _invisible)

add_theme(:stata, base = :stata_s2)
