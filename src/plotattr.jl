const _attribute_defaults = Dict(
    :Series => _series_defaults,
    :Subplot => _subplot_defaults,
    :Plot => _plot_defaults,
    :Axis => _axis_defaults,
)

attrtypes() = join(keys(_attribute_defaults), ", ")
attributes(attrtype::Symbol) = sort(collect(keys(_attribute_defaults[attrtype])))

function lookup_aliases(attrtype::Symbol, attribute::Symbol)
    attribute = get(_keyAliases, attribute, attribute)
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
The information is the same as that given on https://docs.juliaplots.org/latest/attributes/.
"""
function plotattr()
    if isijulia()
        @warn "Fuzzy finding of attributes is disabled in notebooks."
        return
    end
    attr = Symbol(JLFzf.inter_fzf(collect(Plots._all_args), "--read0", "--height=80%"))
    letter = ""
    attrtype = if attr ∈ _all_series_args
        "Series"
    elseif attr ∈ _all_subplot_args
        "Subplot"
    elseif attr ∈ _lettered_all_axis_args
        if attr ∉ _all_axis_args
            letters = collect(String(attr))
            letter = first(letters)
            attr = Symbol(join(letters[2:end]))
        end
        "Axis"
    elseif attr ∈ _all_plot_args
        "Plot"
    elseif attr ∈ _all_magic_args
        "Magic"
    else
        "Unknown"
    end

    d = default(attr)
    return print(
        """
        # $letter$attr

        - $attrtype attribute
        - Default: `$(d isa Symbol ? string(':', d) : d)`.
        - $(_argument_description(attr))
        """
    )
end
# COV_EXCL_STOP

function plotattr(attrtype::Symbol)
    attrtype ∈ keys(_attribute_defaults) || error("Viable options are $(attrtypes())")
    return println("Defined $attrtype attributes are:\n$(join(attributes(attrtype), ", "))")
end

function plotattr(attribute::AbstractString)
    attribute = Symbol(attribute)
    attribute = get(_keyAliases, attribute, attribute)
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
    def = _attribute_defaults[attrtype][attribute]
    aliases = if (al = Plots.aliases(attribute)) |> length > 0
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
        def == "" ? "" : ", defaults to `$def`.",
    )
end
