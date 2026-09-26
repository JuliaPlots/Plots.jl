const _attribute_defaults = Dict(
    :Series => _series_defaults,
    :Subplot => _subplot_defaults,
    :Plot => _plot_defaults,
    :Axis => _axis_defaults,
)

attrtypes() = join(keys(_attribute_defaults), ", ")
attributes(attrtype::Symbol) = sort(collect(keys(_attribute_defaults[attrtype])))

function lookup_aliases(attrtype::Symbol, attribute::Symbol)
    attribute = get(Commons._keyAliases, attribute, attribute)
    attribute ∈ keys(_attribute_defaults[attrtype]) && return attribute
    error("There is no attribute named $attribute in $attrtype")
end

# NOTE: the following cannot be tested in CI (interactive)
# COV_EXCL_START
"""
    plotattr([attr])

Look up the properties of a Plots attribute, or specify an attribute type.
Options are $(attrtypes()).
Call `plotattr()` to search for an attribute via fuzzy finding.
The information is the same as that given on https://docs.juliaplots.org/stable/attributes/.
"""
function plotattr()
    if isijulia()
        @maxlog_warn "Fuzzy finding of attributes is disabled in notebooks."
        return
    end
    attr = Symbol(JLFzf.inter_fzf(collect(Commons._all_attrs), "--read0", "--height=80%"))
    letter = ""
    attrtype = if attr ∈ Commons._all_series_attrs
        "Series"
    elseif attr ∈ Commons._all_subplot_attrs
        "Subplot"
    elseif attr ∈ Commons._lettered_all_axis_attrs
        if attr ∉ Commons._all_axis_attrs
            letters = collect(String(attr))
            letter = first(letters)
            attr = Symbol(join(letters[2:end]))
        end
        "Axis"
    elseif attr ∈ Commons._all_plot_attrs
        "Plot"
    elseif attr ∈ Commons._all_magic_attr
        "Magic"
    else
        "Unknown"
    end

    d = default(attr)
    return """
    # $letter$attr

    - $attrtype attribute
    - Default: `$(d isa Symbol ? string(':', d) : d)`.
    - $(_argument_description(attr))
    """ |> print
end
# COV_EXCL_STOP

function plotattr(attrtype::Symbol)
    attrtype ∈ keys(_attribute_defaults) || error("Viable options are $(attrtypes())")
    return println("Defined $attrtype attributes are:\n$(join(attributes(attrtype), ", "))")
end

function plotattr(attribute::AbstractString)
    attribute = Symbol(attribute)
    attribute = get(Commons._keyAliases, attribute, attribute)
    # `xlims` is documented as `lims`, the letter only picks the axis
    attribute ∈ Commons._lettered_all_axis_attrs &&
        (attribute = Symbol(chop(string(attribute), head = 1, tail = 0)))
    for (k, v) in _attribute_defaults
        attribute ∈ keys(v) && return plotattr(k, attribute)
    end
    error("There is no attribute named $attribute")
end

function plotattr(attrtype::Symbol, attribute::Symbol)
    attrtype ∈ keys(_attribute_defaults) ||
        ArgumentError("`attrtype` must match one of $(attrtypes())")

    attribute = lookup_aliases(attrtype, attribute)
    type, desc = _arg_desc[attribute]
    def = string(_attribute_defaults[attrtype][attribute])
    aliases = if (al = PlotsBase.Commons.aliases(attribute)) |> length > 0
        "Aliases: " * string(Tuple(al)) * ".\n\n"
    else
        ""
    end

    # Looks up the different elements and plots them
    return println(
        ":$attribute\n\n",
        "$desc\n\n",
        aliases,
        "Type: $type.\n\n",
        "`$attrtype` attribute",
        isempty(def) ? "" : ", defaults to `$def`.",
    )
end

"""
    getattr(obj, attr::Symbol)

Return the value of attribute `attr` of a `Plot`, `Subplot`, `Axis` or `Series`, resolving aliases, so
`getattr(pl, :c)` and `getattr(pl, :seriescolor)` ask the same question.

`obj` sets the scope: a `Plot` answers for all of its subplots and series, a `Subplot` for
itself and its own series, an `Axis` for its subplot with its letter implied, and a `Series`
for itself. One value comes back as itself, several as a row matrix, the shape `plot` takes
them in. A magic attribute such as `line` comes back as a named tuple of the attributes it
sets. Whatever comes back is valid input for the same attribute.

```julia
julia> pl = plot(rand(5, 2); layout = 2, title = ["A" "B"], linestyle = :dash);

julia> getattr(pl, :title)
1×2 Matrix{String}:
 "A"  "B"

julia> getattr(pl[1], :title)
"A"

julia> getattr(pl[1][:yaxis], :lims)
:auto
```
"""
getattr(plt::Plot, attr::Symbol) = _getattr(plt, plt.subplots, plt.series_list, attr)
getattr(sp::Subplot, attr::Symbol) = _getattr(sp.plt, [sp], sp.series_list, attr)
getattr(series::Series, attr::Symbol) =
    _getattr(series[:subplot].plt, [series[:subplot]], [series], attr)
function getattr(axis::Axis, attr::Symbol)
    sps = axis.sps
    series = mapreduce(sp -> sp.series_list, vcat, sps; init = Series[])
    return _getattr(first(sps).plt, sps, series, attr; letter = axis[:letter])
end

_one_or_row(f, xs) = length(xs) == 1 ? f(only(xs)) : permutedims(map(f, xs))

function _getattr(plt::Plot, subplots, series_list, attr::Symbol; letter = nothing)
    attr = get(Commons._keyAliases, attr, attr)
    # a magic attribute is read back as the attributes it sets
    haskey(Commons._magic_components, attr) && return NamedTuple(
        c => _getattr(plt, subplots, series_list, c; letter) for
            c in Commons._magic_components[attr]
    )

    # with a letter to go on this is the axis, which matters for `link`, also a plot attribute
    letter ≡ nothing ||
        !haskey(_axis_defaults, attr) ||
        return _one_or_row(sp -> sp[get_attr_symbol(letter, :axis)][attr], subplots)

    # the defaults rather than the `_*_attrs` sets, which miss what `@add_attributes` adds later
    haskey(_plot_defaults, attr) && return plt[attr]
    haskey(_subplot_defaults, attr) && return _one_or_row(sp -> sp[attr], subplots)

    if attr ∈ Commons._lettered_all_axis_attrs
        l, base = Symbol(first(string(attr))), Symbol(chop(string(attr), head = 1, tail = 0))
        letter ≡ nothing ||
            letter ≡ l ||
            throw(
            ArgumentError(
                "`$attr` asks the $l axis, this is the $letter axis. Use `$base` or `$(Symbol(letter, base))`.",
            ),
        )
        return _getattr(plt, subplots, series_list, base; letter = l)
    elseif haskey(_axis_defaults, attr)
        # no letter to go on, so answer for every axis at once
        return _one_or_row(subplots) do sp
            NamedTuple(l => sp[get_attr_symbol(l, :axis)][attr] for l in (:x, :y, :z))
        end
    end

    haskey(_series_defaults, attr) && return _one_or_row(series -> series[attr], series_list)

    # a name Plots does not know is kept in `extra_kwargs`, at whichever level took it
    for (objects, key) in (
            ([plt], :extra_plot_kwargs),
            (subplots, :extra_kwargs),
            (series_list, :extra_kwargs),
        )
        hits = filter(obj -> haskey(obj[key], attr), objects)
        isempty(hits) || return _one_or_row(obj -> obj[key][attr], hits)
    end
    throw(ArgumentError("There is no attribute named `$attr`"))
end
