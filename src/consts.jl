
const _all_defaults = KW[_series_defaults, _plot_defaults, _subplot_defaults]

const _initial_defaults = deepcopy(_all_defaults)
const _initial_axis_defaults = deepcopy(_axis_defaults)

# to be able to reset font sizes to initial values
const _initial_fontsizes = Dict(
    :titlefontsize => _subplot_defaults[:titlefontsize],
    :legend_font_pointsize => _subplot_defaults[:legend_font_pointsize],
    :legend_title_font_pointsize => _subplot_defaults[:legend_title_font_pointsize],
    :tickfontsize => _axis_defaults[:tickfontsize],
    :guidefontsize => _axis_defaults[:guidefontsize],
)

const _internal_args =
    [:plot_object, :series_plotindex, :markershape_to_add, :letter, :idxfilter]

const _axis_args = sort(union(collect(keys(_axis_defaults))))
const _series_args = sort(union(collect(keys(_series_defaults))))
const _subplot_args = sort(union(collect(keys(_subplot_defaults))))
const _plot_args = sort(union(collect(keys(_plot_defaults))))

const _magic_axis_args = [:axis, :tickfont, :guidefont, :grid, :minorgrid]
const _magic_subplot_args = [
    :titlefont,
    :legendfont,
    :legend_titlefont,
    :plot_titlefont,
    :colorbar_titlefont,
]
const _magic_series_args = [:line, :marker, :fill]

const _all_axis_args = sort(union([_axis_args; _magic_axis_args]))
const _all_subplot_args = sort(union([_subplot_args; _magic_subplot_args]))
const _all_series_args = sort(union([_series_args; _magic_series_args]))
const _all_plot_args = _plot_args

const _all_args = sort(union([
    _all_axis_args
    _all_subplot_args
    _all_series_args
    _all_plot_args
]))

# add all pluralized forms to the _keyAliases dict
for arg in _all_args
    add_aliases(arg, makeplural(arg))
end
# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)

# fill symbol cache
for letter in (:x, :y, :z)
    _attrsymbolcache[letter] = Dict{Symbol, Symbol}()
    for k in keys(_axis_defaults)
        # populate attribute cache
        lk = Symbol(letter, k)
        _attrsymbolcache[letter][k] = lk
        # allow the underscore version too: xguide or x_guide
        add_aliases(lk, Symbol(letter, "_", k))
    end
    for k in (_magic_axis_args..., :(_discrete_indices))
        _attrsymbolcache[letter][k] = Symbol(letter, k)
    end
end
