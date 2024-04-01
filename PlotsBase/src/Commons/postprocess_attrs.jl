
# add all pluralized forms to the _keyAliases dict
foreach(arg -> add_aliases(arg, makeplural(arg)), _all_attrs)

# fill symbol cache
for letter in (:x, :y, :z)
    new_attr_dict!(letter)
    for keyword in _axis_attrs
        # populate attribute cache
        letter_keyword = set_attr_symbol!(letter, string(keyword))
        # allow the underscore version too: `xguide` or `x_guide`
        add_aliases(letter_keyword, Symbol(letter, "_", keyword))
    end
    for keyword in (_magic_axis_attrs..., :(_discrete_indices))
        _attrsymbolcache[letter][keyword] = Symbol(letter, keyword)
    end
end

# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)
