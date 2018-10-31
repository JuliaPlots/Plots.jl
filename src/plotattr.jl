
const _attribute_defaults =  Dict(:Series => _series_defaults,
                        :Subplot => _subplot_defaults,
                        :Plot => _plot_defaults,
                        :Axis => _axis_defaults)

attrtypes() = join(keys(_attribute_defaults), ", ")
attributes(attrtype::Symbol) = sort(collect(keys(_attribute_defaults[attrtype])))

function lookup_aliases(attrtype, attribute)
    attribute = Symbol(attribute)
    attribute = in(attribute, keys(_keyAliases)) ? _keyAliases[attribute] : attribute
    in(attribute, keys(_attribute_defaults[attrtype])) && return attribute
    error("There is no attribute named $attribute in $attrtype")
end

"""
    plotattr([attr])

Look up the properties of a Plots attribute, or specify an attribute type. Call `plotattr()` for options.
The information is the same as that given on https://docs.juliaplots.org/latest/attributes/.
"""
function plotattr()
    println("Specify an attribute type to get a list of supported attributes. Options are $(attrtypes())")
end

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
    in(attrtype, keys(_attribute_defaults)) || ArgumentError("`attrtype` must match one of $(attrtypes())")

    attribute = Symbol(lookup_aliases(attrtype, attribute))

    desc = get(_arg_desc, attribute, "")
    first_period_idx = findfirst(isequal('.'), desc)
    typedesc = desc[1:first_period_idx-1]
    desc = strip(desc[first_period_idx+1:end])
    als = keys(filter(x->x[2]==attribute, _keyAliases)) |> collect |> sort
    als = join(map(string,als), ", ")
    def = _attribute_defaults[attrtype][attribute]


    # Looks up the different elements and plots them
    println("$(printnothing(attribute)) ", typedesc == "" ? "" : "{$(printnothing(typedesc))}", "\n",
        als == "" ? "" : "$(printnothing(als))\n",
        "\n$(printnothing(desc))\n",
        "$(printnothing(attrtype)) attribute, ", def == "" ? "" : " default: $(printnothing(def))")
end
