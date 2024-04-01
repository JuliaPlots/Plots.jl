
# add all pluralized forms to the _keyAliases dict
foreach(arg -> add_aliases(arg, makeplural(arg)), _all_attrs)

add_attr_dict!(letter::Symbol) = get!(_attrsymbolcache, letter, Dict{Symbol,Symbol}())
add_attr!(letter::Symbol, keyword::Symbol) =
    let letter_keyword = Symbol(letter, keyword)
        _attrsymbolcache[letter][keyword] = letter_keyword
    end

# fill symbol cache
for letter in (:x, :y, :z)
    add_attr_dict!(letter)
    for keyword in _axis_attrs
        # populate attribute cache
        letter_keyword = add_attr!(letter, keyword)
        # allow the underscore version too: xguide or x_guide
        add_aliases(letter_keyword, Symbol(letter, "_", keyword))
    end
    for keyword in (_magic_axis_attrs..., :(_discrete_indices))
        _attrsymbolcache[letter][keyword] = Symbol(letter, keyword)
    end
end

# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)
