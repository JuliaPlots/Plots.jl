# unfished
const _solarized_palette = (:yellow, :orange, :red, :magenta, :violet, :blue,
                               :cyan, :green)

const _solarized_colors = Dict{Symbol, Tuple}(
                          :base03 => (0, 43, 54),
                          :base02 => (7, 54, 66),
                          :base01 => (88, 110, 117),
                          :base00 => (101, 123, 131),
                          :base0  => (131, 148, 150),
                          :base1  => (147, 161, 161),
                          :base2  => (238, 232, 213),
                          :base3  => (253, 246, 227),
                          :yellow => (181, 137, 0),
                          :orange => (203, 75, 22),
                          :red    => (220, 50, 47),
                          :magenta=> (211, 54, 130),
                          :violet => (108, 113, 196),
                          :blue   => (38, 139, 210),
                          :cyan   => (42, 161, 152),
                          :green  => (133, 153, 0))

_get_solarized_color(c) = _255_to_1(c, _solarized_colors)

add_theme(:solarized_base,
    palette  = [map(c->_get_solarized_color(c),_solarized_palette)...],
    bglegend = _invisible,
    fglegend = _invisible)

add_theme(:solarized,
    base = :solarized_base,
    bginside = _get_solarized_color(:base03),
    bgoutside= _get_solarized_color(:base02),
    fg       = _get_solarized_color(:base0),
    fgtext   = _get_solarized_color(:base0),
    fglegend = _get_solarized_color(:base0),
    fgguide  = _get_solarized_color(:base1))

add_theme(:solarized_dark, base = :solarized)
add_theme(:solarized_alldark,
          base = :solarized_dark,
          bgoutside = _get_solarized_color(:base03))

add_theme(:solarized_bright,
          base = :solarized_base,
          bginside = _get_solarized_color(:base3),
          bgoutside= _get_solarized_color(:base2),
          fg       = _get_solarized_color(:base00),
          fgtext   = _get_solarized_color(:base00),
          fgguide  = _get_solarized_color(:base01))

add_theme(:solarized_allbright,
          base = :solarized_bright,
          bgoutside = _get_solarized_color(:base2))
