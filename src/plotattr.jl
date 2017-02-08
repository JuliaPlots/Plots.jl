
const _attribute_defaults =  Dict(:Series => Plots._series_defaults,
                        :Subplot => Plots._subplot_defaults,
                        :Plot => Plots._plot_defaults,
                        :Axis => Plots._axis_defaults)

attrtypes() = join(keys(_attribute_defaults), ", ")
attributes(attrtype::Symbol) = sort(collect(keys(_attribute_defaults[attrtype])))

function lookup_aliases(attrtype, attribute)
    attribute = Symbol(attribute)
    attribute = in(attribute, keys(_keyAliases)) ? _keyAliases[attribute] : attribute
    in(attribute, keys(_attribute_defaults[attrtype])) && return attribute
    error("There is no attribute named $attribute in $attrtype")
end

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

function plotattr(attrtype::Symbol, attribute::AbstractString)
    in(attrtype, keys(_attribute_defaults)) || ArgumentError("`attrtype` must match one of $(attrtypes())")

    attribute = Symbol(lookup_aliases(attrtype, attribute))

    desc = get(_arg_desc, attribute, "")
    first_period_idx = findfirst(desc, '.')
    typedesc = desc[1:first_period_idx-1]
    desc = strip(desc[first_period_idx+1:end])
    als = keys(filter((_,v)->v==attribute, _keyAliases)) |> collect |> sort
    als = join(map(string,als), ", ")


    # Looks up the different elements and plots them
    println("$attribute ($attrtype attribute)")
    println("Aliases: $als \n")
    println("Default: $(_attribute_defaults[attrtype][attribute])\t(Type: $typedesc)\n")
    println("Description: ")
    println(desc)
end
