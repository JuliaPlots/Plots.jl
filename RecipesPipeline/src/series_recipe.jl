# # Series Recipes

@nospecialize

"""
    _process_seriesrecipes!(plt, kw_list)

Recursively apply series recipes until the backend supports the seriestype
"""
function _process_seriesrecipes!(plt, kw_list)
    for kw in kw_list
        # in series attributes given as vector with one element per series,
        # select the value for current series
        slice_series_attributes!(plt, kw_list, kw)
    end
    process_sliced_series_attributes!(plt, kw_list)
    for kw in kw_list
        series_attr = DefaultsDict(kw, series_defaults(plt))
        # now we have a fully specified series, with colors chosen. we must recursively
        # handle series recipes, which dispatch on seriestype. If a backend does not
        # natively support a seriestype, we check for a recipe that will convert that
        # series type into one made up of lower-level components.
        # For example, a histogram is just a bar plot with binned data, a bar plot is
        # really a filled step plot, and a step plot is really just a path. So any backend
        # that supports drawing a path will implicitly be able to support step, bar, and
        # histogram plots (and any recipes that use those components).
        _process_seriesrecipe(plt, series_attr)
    end
end

# this method recursively applies series recipes when the seriestype is not supported
# natively by the backend
function _process_seriesrecipe(plt, plotattributes)
    # replace seriestype aliases
    st = Symbol(plotattributes[:seriestype])
    st = plotattributes[:seriestype] = type_alias(plt, st)

    # shapes shouldn't have fillrange set
    if plotattributes[:seriestype] == :shape
        plotattributes[:fillrange] = nothing
    end

    # if it's natively supported, finalize processing and pass along to the backend,
    # otherwise recurse
    if is_seriestype_supported(plt, st)
        add_series!(plt, plotattributes)
    else
        # get a sub list of series for this seriestype
        x, y, z = plotattributes[:x], plotattributes[:y], plotattributes[:z]
        datalist = RecipesBase.apply_recipe(plotattributes, Val{st}, x, y, z)
        warn_on_recipe_aliases!(plt, datalist, :series, st)

        # assuming there was no error, recursively apply the series recipes
        for data in datalist
            if isa(data, RecipeData)
                preprocess_attributes!(plt, data.plotattributes)
                if data.plotattributes[:seriestype] == st
                    error(
                        "The seriestype didn't change in series recipe $st. This will cause a StackOverflow.",
                    )
                end
                _process_seriesrecipe(plt, data.plotattributes)
            else
                @warn "Unhandled recipe: $data"
                break
            end
        end
    end
    nothing
end

@specialize
