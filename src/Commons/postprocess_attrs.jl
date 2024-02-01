
# add all pluralized forms to the _keyAliases dict
for arg in _all_attrs
    add_aliases(arg, makeplural(arg))
end

# fill symbol cache
for letter in (:x, :y, :z)
    _attrsymbolcache[letter] = Dict{Symbol,Symbol}()
    for k in _axis_attrs
        # populate attribute cache
        lk = Symbol(letter, k)
        _attrsymbolcache[letter][k] = lk
        # allow the underscore version too: xguide or x_guide
        add_aliases(lk, Symbol(letter, "_", k))
    end
    for k in (_magic_axis_attrs..., :(_discrete_indices))
        _attrsymbolcache[letter][k] = Symbol(letter, k)
    end
end

# add all non_underscored forms to the _keyAliases
add_non_underscore_aliases!(_keyAliases)
