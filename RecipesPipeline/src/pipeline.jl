## Stubs
function _recipe_init!(plt, plotattributes, args) end
function _recipe_after_user!(plt, plotattributes, args) end
function _recipe_after_plot!(plt, plotattributes, kw_list) end
function _recipe_before_series!(plt, kw, kw_list) end
function _recipe_finish!(plt, plotattributes, args) end

##
# Here comes the specification of when which recipe is processed.
# It contains functions before and after every stage for interaction with the plotting package.

function recipe_pipeline!(plt,              # frontend specific representation of a plot
                         plotattributes,    # current state of recipe keywords
                         args;              # set of arguments passed by the user
                         type_aliases)

    _recipe_init!(plt, plotattributes, args)

    # --------------------------------
    # "USER RECIPES"
    # --------------------------------

    kw_list = _process_userrecipes(plt, plotattributes, args)
    _recipe_after_user!(plt, plotattributes, args)

    # --------------------------------
    # "PLOT RECIPES"
    # --------------------------------

    # "plot recipe", which acts like a series type, and is processed before
    # the plot layout is created, which allows for setting layouts and other plot-wide attributes.
    # we get inputs which have been fully processed by "user recipes" and "type recipes",
    # so we can expect standard vectors, surfaces, etc.  No defaults have been set yet.
    still_to_process = kw_list
    kw_list = Dict{Symbol,Any}[]
    while !isempty(still_to_process)
        next_kw = popfirst!(still_to_process)
        _process_plotrecipe(plt, next_kw, kw_list, still_to_process; type_aliases=type_aliases)
    end

    _recipe_after_plot!(plt, plotattributes, kw_list)

    # !!! note: At this point, kw_list is fully decomposed into individual series... one KW per series.          !!!
    # !!!       The next step is to recursively apply series recipes until the backend supports that series type !!!

    # --------------------------------
    # "SERIES RECIPES"
    # --------------------------------

    for kw in kw_list
        series_attr = _recipe_before_series!(plt, kw, kw_list)
        kw_list = _process_seriesrecipe(plt, series_attr)
    end

    _recipe_finish!(plt, plotattributes, args)
end
