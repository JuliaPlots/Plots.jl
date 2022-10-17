
const _attribute_defaults = Dict(
    :Series => _series_defaults,
    :Subplot => _subplot_defaults,
    :Plot => _plot_defaults,
    :Axis => _axis_defaults,
)

attrtypes() = join(keys(_attribute_defaults), ", ")
attributes(attrtype::Symbol) = sort(collect(keys(_attribute_defaults[attrtype])))

function lookup_aliases(attrtype, attribute)
    attribute = Symbol(attribute)
    attribute = in(attribute, keys(_keyAliases)) ? _keyAliases[attribute] : attribute
    in(attribute, keys(_attribute_defaults[attrtype])) && return attribute
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
    attr = Symbol(JLFzf.inter_fzf(collect(Plots._all_args), "--read0", "--height=80%"))
    letter = ""
    attrtype = if attr in _all_series_args
        "Series"
    elseif attr in _all_subplot_args
        "Subplot"
    elseif attr in _lettered_all_axis_args
        if attr ∉ _all_axis_args
            letters = collect(String(attr))
            letter = first(letters)
            attr = Symbol(join(letters[2:end]))
        end
        "Axis"
    elseif attr in _all_plot_args
        "Plot"
    elseif attr in _all_magic_args
        "Magic"
    else
        "Unkown"
    end

    d = default(attr)
    print("""
    # $letter$attr

    - $attrtype attribute
    - Default: $(d isa Symbol ? string(':', d) : d)
    - $(get(Plots._arg_desc, attr, ""))
    """)
end
# COV_EXCL_STOP

function plotattr(attrtype::Symbol)
    in(attrtype, keys(_attribute_defaults)) || error("Viable options are $(attrtypes())")
    println("Defined $attrtype attributes are:\n$(join(attributes(attrtype), ", "))")
end

function plotattr(attribute::AbstractString)
    attribute = Symbol(attribute)
    attribute = in(attribute, keys(_keyAliases)) ? _keyAliases[attribute] : attribute
    for (k, v) in _attribute_defaults
        if in(attribute, keys(v))
            return plotattr(k, "$attribute")
        end
    end
    error("There is no attribute named $attribute")
end

printnothing(x) = x
printnothing(x::Nothing) = "nothing"

function plotattr(attrtype::Symbol, attribute::AbstractString)
    in(attrtype, keys(_attribute_defaults)) ||
        ArgumentError("`attrtype` must match one of $(attrtypes())")

    attribute = Symbol(lookup_aliases(attrtype, attribute))

    desc = get(_arg_desc, attribute, "")
    first_period_idx = findfirst(isequal('.'), desc)
    if isnothing(first_period_idx)
        typedesc = ""
        desc = strip(desc)
    else
        typedesc = desc[1:(first_period_idx - 1)]
        desc = strip(desc[(first_period_idx + 1):end])
    end
    als = keys(filter(x -> x[2] == attribute, _keyAliases)) |> collect |> sort
    als = join(map(string, als), ", ")
    def = _attribute_defaults[attrtype][attribute]

    # Looks up the different elements and plots them
    println(
        "$(printnothing(attribute)) ",
        typedesc == "" ? "" : "{$(printnothing(typedesc))}",
        "\n",
        als == "" ? "" : "$(printnothing(als))\n",
        "\n$(printnothing(desc))\n",
        "$(printnothing(attrtype)) attribute, ",
        def == "" ? "" : " default: $(printnothing(def))",
    )
end
