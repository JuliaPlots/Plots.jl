# # Plot Recipes

@nospecialize

"""
    _process_plotrecipes!(plt, kw_list)

Grab the first in line to be processed and pass it through `apply_recipe` to generate a
list of `RecipeData` objects.
If we applied a "plot recipe" without error, then add the returned datalist's KWs,
otherwise we just add the original KW.
"""
function _process_plotrecipes!(plt, kw_list)
    still_to_process = kw_list
    kw_list = KW[]
    while !isempty(still_to_process)
        next_kw = popfirst!(still_to_process)
        _process_plotrecipe(plt, next_kw, kw_list, still_to_process)
    end
    kw_list
end

function _process_plotrecipe(plt, kw, kw_list, still_to_process)
    if !isa(get(kw, :seriestype, nothing), Symbol)
        # seriestype was never set, or it's not a Symbol, so it can't be a plot recipe
        push!(kw_list, kw)
        return
    end
    st = kw[:seriestype]
    st = kw[:seriestype] = type_alias(plt, st)
    datalist = RecipesBase.apply_recipe(kw, Val{st}, plt)
    if !isnothing(datalist)
        warn_on_recipe_aliases!(plt, datalist, :plot, st)
        for data in datalist
            preprocess_attributes!(plt, data.plotattributes)
            if data.plotattributes[:seriestype] == st
                error(
                    "Plot recipe $st returned the same seriestype: $(data.plotattributes)",
                )
            end
            push!(still_to_process, data.plotattributes)
        end
    else
        push!(kw_list, kw)
    end
    nothing
end

@specialize
