
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
    print("""
    # $letter$attr

    - $attrtype attribute
    - Default: `$(d isa Symbol ? string(':', d) : d)`.
    - $(_argument_description(attr))
    """)
end
# COV_EXCL_STOP

function plotattr(attrtype::Symbol)
    attrtype ∈ keys(_attribute_defaults) || error("Viable options are $(attrtypes())")
    println("Defined $attrtype attributes are:\n$(join(attributes(attrtype), ", "))")
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
    println(
        ":$attribute\n\n",
        "$desc\n\n",
        aliases,
        "Type: $type.\n\n",
        "`$attrtype` attribute",
        def == "" ? "" : ", defaults to `$def`.",
    )
end

function getattr(plt::Plot, s::Symbol)
    attribute = get(_keyAliases, s, s)
    _getattr(plt, plt.subplots, plt.series_list, attribute)
end
function getattr(sp::Subplot, s::Symbol)
    attribute = get(_keyAliases, s, s)
    _getattr(sp.plt, [sp], sp.series_list, attribute)
end
function getattr(axis::Axis, s::Symbol)
    attribute = get(_keyAliases, s, s)
    if attribute in _axis_args
        attribute = get_attr_symbol(axis[:letter], attribute)
    end
    _getattr(only(axis.sps).plt, axis.sps, only(axis.sps).series_list, attribute)
end
# TODO: to implement this we need a series to know its subplot
# function getattr(series::Series, s::Symbol)
#     attribute = get(_keyAliases, s, s)
#     _getattr(plt, plt.subplots, [series], attribute)
# end

function _getattr(plt::Plot, subplots::Vector{<:Subplot}, serieses::Vector{Series}, attribute::Symbol)
    if attribute ∈ _all_plot_args
        return plt[attribute]
    elseif attribute ∈ _all_subplot_args && attribute ∉ _magic_subplot_args
        return reduce(hcat, getindex.(subplots, attribute))
    elseif (attribute ∈ _all_axis_args || attribute ∈ _lettered_all_axis_args) && attribute ∉ _magic_axis_args
        if attribute ∈ _lettered_all_axis_args
            letters = collect(String(attribute))
            letter = Symbol(first(letters))
            attribute = Symbol(letters[2:end]...)
            axis = get_attr_symbol(letter, :axis)
            reduce(hcat, getindex.(getindex.(subplots, axis), attribute))
        else
            axes = (:xaxis, :yaxis, :zaxis)
            return map(subplots) do sp
                return NamedTuple(axis => sp[axis][attribute] for axis in axes)
            end
        end
    elseif attribute ∈ _all_series_args && attribute ∉ _magic_series_args
        return reduce(hcat, map(serieses) do series
            series[attribute]
        end)
    else
        if attribute in _all_magic_args
            @info "$attribute is a magic argument. These are not present in the Plot object. Please use the more specific attribute, such as `linestyle` instead of `line`."
            return missing
        end
        extra_kwargs = Dict(
            :plot =>
                haskey(plt[:extra_plot_kwargs], attribute) ?
                plt[:extra_plot_kwargs][attribute] : [],
            :subplots => [
                i => sp[:extra_kwargs][attribute] for
                (i, sp) in enumerate(subplots) if haskey(sp[:extra_kwargs], attribute)
            ],
            :series => [
                i => series[:extra_kwargs][attribute] for (i, series) in enumerate(serieses) if
                haskey(series[:extra_kwargs], attribute)
            ],
        )
        !all(isempty, values(extra_kwargs)) && return extra_kwargs
        throw(ArgumentError("Attribute not found."))
    end
end
