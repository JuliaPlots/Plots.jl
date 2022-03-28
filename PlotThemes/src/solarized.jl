# https://github.com/altercation/solarized
const _solarized_palette = (:red, :yellow, :blue, :green, :orange, :magenta, :violet, :cyan)

const _solarized_colors = Dict([
    :base03 => RGB255(0, 43, 54),
    :base02 => RGB255(7, 54, 66),
    :base01 => RGB255(88, 110, 117),
    :base00 => RGB255(101, 123, 131),
    :base0  => RGB255(131, 148, 150),
    :base1  => RGB255(147, 161, 161),
    :base2  => RGB255(238, 232, 213),
    :base3  => RGB255(253, 246, 227),
    :blue   => RGB255(38, 139, 210),
    :orange => RGB255(203, 75, 22),
    :red    => RGB255(220, 50, 47),
    :green  => RGB255(133, 153, 0),
    :yellow => RGB255(181, 137, 0),
    :magenta=> RGB255(211, 54, 130),
    :violet => RGB255(108, 113, 196),
    :cyan   => RGB255(42, 161, 152)
])

const _solarized = PlotTheme(Dict([
    :bg => _solarized_colors[:base03],
    :bginside => _solarized_colors[:base02],
    :fg => _solarized_colors[:base00],
    :fgtext => _solarized_colors[:base01],
    :fgguide => _solarized_colors[:base01],
    :fglegend => _solarized_colors[:base01],
    :palette => expand_palette(_solarized_colors[:base03], [_solarized_colors[c] for c in _solarized_palette]),
    :colorgradient => :YlOrRd])
)

const _solarized_light = PlotTheme(Dict([
    :bg => _solarized_colors[:base3],
    :bginside => _solarized_colors[:base2],
    :fg => _solarized_colors[:base0],
    :fgtext => _solarized_colors[:base1],
    :fgguide => _solarized_colors[:base1],
    :fglegend => _solarized_colors[:base1],
    :palette => expand_palette(_solarized_colors[:base3], [_solarized_colors[c] for c in _solarized_palette]),
    :colorgradient => cgrad(:YlOrRd, rev = true)])
)
