# https://github.com/morhetz/gruvbox
const _gruvbox_dark_palette =  (:bright_green, :bright_yellow, :bright_blue, :bright_aqua, :bright_purple, :bright_red, :bright_orange)

const _gruvbox_light_palette = (:faded_green, :faded_yellow, :faded_blue, :faded_aqua, :faded_purple, :faded_red, :faded_orange)

const _gruvbox_colors = Dict(
	:dark0_hard     => RGB255(29,32,33),
	:dark0          => RGB255(40,40,40),
	:dark0_soft     => RGB255(50,48,47),
	:dark1          => RGB255(60,56,54),
	:dark2          => RGB255(80,73,69),
	:dark3          => RGB255(102,92,84),
	:dark4          => RGB255(124,111,100),
	:dark4_256      => RGB255(124,111,100),
	:gray_245       => RGB255(146,131,116),
	:gray_244       => RGB255(146,131,116),
	:light0_hard    => RGB255(249,245,215),
	:light0         => RGB255(253,244,193),
	:light0_soft    => RGB255(242,229,188),
	:light1         => RGB255(235,219,178),
	:light2         => RGB255(213,196,161),
	:light3         => RGB255(189,174,147),
	:light4         => RGB255(168,153,132),
	:light4_256     => RGB255(168,153,132),
	:bright_red     => RGB255(251,73,52),
	:bright_green   => RGB255(184,187,38),
	:bright_yellow  => RGB255(250,189,47),
	:bright_blue    => RGB255(131,165,152),
	:bright_purple  => RGB255(211,134,155),
	:bright_aqua    => RGB255(142,192,124),
	:bright_orange  => RGB255(254,128,25),
	:neutral_red    => RGB255(204,36,29),
	:neutral_green  => RGB255(152,151,26),
	:neutral_yellow => RGB255(215,153,33),
	:neutral_blue   => RGB255(69,133,136),
	:neutral_purple => RGB255(177,98,134),
	:neutral_aqua   => RGB255(104,157,106),
	:neutral_orange => RGB255(214,93,14),
	:faded_red      => RGB255(157,0,6),
	:faded_green    => RGB255(121,116,14),
	:faded_yellow   => RGB255(181,118,20),
	:faded_blue     => RGB255(7,102,120),
	:faded_purple   => RGB255(143,63,113),
	:faded_aqua     => RGB255(66,123,88),
	:faded_orange   => RGB255(175,58,3),
)

const _gruvbox_dark = PlotTheme(Dict([
	:bg => _gruvbox_colors[:dark2],
	:bginside => _gruvbox_colors[:dark0],
	:fg => _gruvbox_colors[:light3],
	:fgtext => _gruvbox_colors[:light3],
	:fgguide => _gruvbox_colors[:dark1],
	:fglegend => _gruvbox_colors[:light3],
	:palette => expand_palette(_gruvbox_colors[:dark3], [_gruvbox_colors[c] for c in _gruvbox_dark_palette]),
    :colorgradient => cgrad(:YlOrRd, rev = true) ])
)

const _gruvbox_light = PlotTheme(Dict([
	:bg => _gruvbox_colors[:light1],
	:bginside => _gruvbox_colors[:light0],
	:fg => _gruvbox_colors[:dark1],
	:fgtext => _gruvbox_colors[:dark1],
	:fgguide => _gruvbox_colors[:dark1],
	:fglegend => _gruvbox_colors[:dark1],
	:palette => expand_palette(_gruvbox_colors[:light3], [_gruvbox_colors[c] for c in _gruvbox_light_palette]),
    :colorgradient => cgrad(:YlOrRd, rev = true) ])
)
