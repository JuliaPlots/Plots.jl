const _deprecated_attributes = Dict{Symbol, Symbol}(:orientation => :permute)
const _all_defaults = KW[_series_defaults, _plot_defaults, _subplot_defaults]

const _initial_defaults = deepcopy(_all_defaults)
const _initial_axis_defaults = deepcopy(_axis_defaults)

# add defaults for the letter versions
const _axis_defaults_byletter = KW()

reset_axis_defaults_byletter!() =
    for letter in (:x, :y, :z)
    _axis_defaults_byletter[letter] = KW()
    for (k, v) in _axis_defaults
        _axis_defaults_byletter[letter][k] = v
    end
end
reset_axis_defaults_byletter!()

# to be able to reset font sizes to initial values
const _initial_plt_fontsizes =
    Dict(:plot_titlefontsize => _plot_defaults[:plot_titlefontsize])

const _initial_sp_fontsizes = Dict(
    :titlefontsize => _subplot_defaults[:titlefontsize],
    :legend_font_pointsize => _subplot_defaults[:legend_font_pointsize],
    :legend_title_font_pointsize => _subplot_defaults[:legend_title_font_pointsize],
    :annotationfontsize => _subplot_defaults[:annotationfontsize],
    :colorbar_tickfontsize => _subplot_defaults[:colorbar_tickfontsize],
    :colorbar_titlefontsize => _subplot_defaults[:colorbar_titlefontsize],
)

const _initial_ax_fontsizes = Dict(
    :tickfontsize => _axis_defaults[:tickfontsize],
    :guidefontsize => _axis_defaults[:guidefontsize],
)

const _initial_fontsizes =
    merge(_initial_plt_fontsizes, _initial_sp_fontsizes, _initial_ax_fontsizes)

const _internal_args = [
    :plot_object,
    :series_plotindex,
    :series_index,
    :markershape_to_add,
    :letter,
    :idxfilter,
]

const _axis_args = Set(keys(_axis_defaults))
const _series_args = Set(keys(_series_defaults))
const _subplot_args = Set(keys(_subplot_defaults))
const _plot_args = Set(keys(_plot_defaults))

const _magic_axis_args = [:axis, :tickfont, :guidefont, :grid, :minorgrid]
const _magic_subplot_args =
    [:title_font, :legend_font, :legend_title_font, :plot_title_font, :colorbar_titlefont]
const _magic_series_args = [:line, :marker, :fill]
const _all_magic_args =
    Set(union(_magic_axis_args, _magic_series_args, _magic_subplot_args))

const _all_axis_args = union(_axis_args, _magic_axis_args)
const _lettered_all_axis_args =
    Set([Symbol(letter, kw) for letter in (:x, :y, :z) for kw in _all_axis_args])
const _all_subplot_args = union(_subplot_args, _magic_subplot_args)
const _all_series_args = union(_series_args, _magic_series_args)
const _all_plot_args = _plot_args

const _all_args =
    union(_lettered_all_axis_args, _all_subplot_args, _all_series_args, _all_plot_args)

# add all pluralized forms to the _keyAliases dict
for arg in _all_args
    add_aliases(arg, makeplural(arg))
end

# fill symbol cache
for letter in (:x, :y, :z)
    _attrsymbolcache[letter] = Dict{Symbol, Symbol}()
    for k in _axis_args
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

# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)

_generate_doclist(attributes) =
    replace(join(sort(collect(attributes)), "\n- "), "_" => "\\_")
