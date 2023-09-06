const _deprecated_attributes = Dict{Symbol,Symbol}(:orientation => :permute)
const _all_defaults = KW[_series_defaults, _plot_defaults, _subplot_defaults]

const _initial_defaults = deepcopy(_all_defaults)
const _initial_axis_defaults = deepcopy(_axis_defaults)

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
    :tickfontsize  => _axis_defaults[:tickfontsize],
    :guidefontsize => _axis_defaults[:guidefontsize],
)

const _initial_fontsizes =
    merge(_initial_plt_fontsizes, _initial_sp_fontsizes, _initial_ax_fontsizes)

# add all pluralized forms to the _keyAliases dict
for arg in _all_args
    add_aliases(arg, makeplural(arg))
end

# fill symbol cache
for letter in (:x, :y, :z)
    Commons._attrsymbolcache[letter] = Dict{Symbol,Symbol}()
    for k in _axis_args
        # populate attribute cache
        lk = Symbol(letter, k)
        Commons._attrsymbolcache[letter][k] = lk
        # allow the underscore version too: xguide or x_guide
        add_aliases(lk, Symbol(letter, "_", k))
    end
    for k in (_magic_axis_args..., :(_discrete_indices))
        Commons._attrsymbolcache[letter][k] = Symbol(letter, k)
    end
end

# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)

_generate_doclist(attributes) =
    replace(join(sort(collect(attributes)), "\n- "), "_" => "\\_")
