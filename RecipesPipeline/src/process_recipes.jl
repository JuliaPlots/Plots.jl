
_preprocess_args(p, args, s) = args #needs to modify still_to_process
preprocessArgs!(p) = p
is_seriestype_supported(st) = true

function _process_userrecipes(plt, plotattributes::AbstractDict{Symbol,Any}, args)
    still_to_process = RecipesBase.RecipeData[]
    args = _preprocess_args(plotattributes, args, still_to_process)

    # for plotting recipes, swap out the args and update the parameter dictionary
    # we are keeping a stack of series that still need to be processed.
    # each pass through the loop, we pop one off and apply the recipe.
    # the recipe will return a list a Series objects... the ones that are
    # finished (no more args) get added to the kw_list, the ones that are not
    # are placed on top of the stack and are then processed further.
    kw_list = Dict{Symbol,Any}[]
    while !isempty(still_to_process)
        # grab the first in line to be processed and either add it to the kw_list or
        # pass it through apply_recipe to generate a list of RecipeData objects (data + attributes)
        # for further processing.
        next_series = popfirst!(still_to_process)
        # recipedata should be of type RecipeData.  if it's not then the inputs must not have been fully processed by recipes
        if !(typeof(next_series) <: RecipesBase.RecipeData)
            error("Inputs couldn't be processed... expected RecipeData but got: $next_series")
        end
        if isempty(next_series.args)
            _process_userrecipe(plt, kw_list, next_series)
        else
            rd_list = RecipesBase.apply_recipe(next_series.plotattributes, next_series.args...)
            prepend!(still_to_process,rd_list)
        end
    end

    # don't allow something else to handle it
    plotattributes[:smooth] = false
    kw_list
end

# plot recipes

# Grab the first in line to be processed and pass it through apply_recipe
# to generate a list of RecipeData objects (data + attributes).
# If we applied a "plot recipe" without error, then add the returned datalist's KWs,
# otherwise we just add the original KW.
function _process_plotrecipe(plt, kw::AbstractDict{Symbol,Any}, kw_list::Vector{Dict{Symbol,Any}}, still_to_process::Vector{Dict{Symbol,Any}})
    if !isa(get(kw, :seriestype, nothing), Symbol)
        # seriestype was never set, or it's not a Symbol, so it can't be a plot recipe
        push!(kw_list, kw)
        return
    end
    try
        st = kw[:seriestype]
        st = kw[:seriestype] = get(_typeAliases, st, st) #TODO this requires access to the const_typeAliases
        datalist = RecipesBase.apply_recipe(kw, Val{st}, plt)
        for data in datalist
            preprocessArgs!(data.plotattributes)
            if data.plotattributes[:seriestype] == st
                error("Plot recipe $st returned the same seriestype: $(data.plotattributes)")
            end
            push!(still_to_process, data.plotattributes)
        end
    catch err
        if isa(err, MethodError)
            push!(kw_list, kw)
        else
            rethrow()
        end
    end
    return
end

# -------------------------------------------------------------------------------

# this method recursively applies series recipes when the seriestype is not supported
# natively by the backend
function _process_seriesrecipe(plt, plotattributes::AbstractDict{Symbol,Any})
    #println("process $(typeof(plotattributes))")
    # replace seriestype aliases
    st = Symbol(plotattributes[:seriestype])
    st = plotattributes[:seriestype] = get(_typeAliases, st, st) #TODO here again

    # shapes shouldn't have fillrange set
    if plotattributes[:seriestype] == :shape
        plotattributes[:fillrange] = nothing
    end

    # if it's natively supported, finalize processing and pass along to the backend, otherwise recurse
    if is_seriestype_supported(st)
        sp = _prepare_subplot(plt, plotattributes)
        _prepare_annotations(sp, plotattributes)
        _expand_subplot_extrema(sp, plotattributes, st)
        _update_series_attributes!(plotattributes, plt, sp)
        _add_the_series(plt, sp, plotattributes)

    else
        # get a sub list of series for this seriestype
        datalist = RecipesBase.apply_recipe(plotattributes, Val{st}, plotattributes[:x], plotattributes[:y], plotattributes[:z])

        # assuming there was no error, recursively apply the series recipes
        for data in datalist
            if isa(data, RecipesBase.RecipeData)
                preprocessArgs!(data.plotattributes)
                if data.plotattributes[:seriestype] == st
                    error("The seriestype didn't change in series recipe $st.  This will cause a StackOverflow.")
                end
                _process_seriesrecipe(plt, data.plotattributes)
            else
                @warn("Unhandled recipe: $(data)")
                break
            end
        end
    end
    nothing
end
