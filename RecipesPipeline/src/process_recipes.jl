# # The Recipe Consumer Interface
# To consume RecipesBase recipes, we allow plotting packages to overload the following
# hooks into the main Recipe pipeline.  The docstrings should eventually describe all
# necessary functionality.
# All these methods have the first parameter as the plot object which is being acted on.
# This allows for a dispatch overload by any consumer of these recipes.

"""
    _preprocess_args(p, args, s)

Take in a Vector of RecipeData (`s`) and fill in default attributes.
"""
_preprocess_args(p, args, s) = args # needs to modify still_to_process

"""
"""
_process_userrecipe(plt, kw_list, next_series) = nothing

"""
"""
preprocessArgs!(p) = p

"""
"""
is_st_supported(plt, st) = true

"""
"""
finalize_subplot!(plt, st, att) = nothing

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
            @error("Inputs couldn't be processed. Expected RecipeData but got: $next_series")
        end
        if isempty(next_series.args)
            _process_userrecipe(plt, kw_list, next_series)
        else
            rd_list = RecipesBase.apply_recipe(next_series.plotattributes, next_series.args...)
            prepend!(still_to_process,rd_list)
        end
    end

    kw_list
end

# plot recipes

# Grab the first in line to be processed and pass it through apply_recipe
# to generate a list of RecipeData objects (data + attributes).
# If we applied a "plot recipe" without error, then add the returned datalist's KWs,
# otherwise we just add the original KW.
function _process_plotrecipe(plt, kw::AbstractDict{Symbol,Any}, kw_list::Vector{Dict{Symbol,Any}}, still_to_process::Vector{Dict{Symbol,Any}}; type_aliases::AbstractDict{Symbol,Symbol}=Dict())
    if !isa(get(kw, :seriestype, nothing), Symbol)
        # seriestype was never set, or it's not a Symbol, so it can't be a plot recipe
        push!(kw_list, kw)
        return
    end
    try
        st = kw[:seriestype]
        st = kw[:seriestype] = get(type_aliases, st, st)
        datalist = RecipesBase.apply_recipe(kw, Val{st}, plt)
        for data in datalist
            preprocessArgs!(data.plotattributes)
            if data.plotattributes[:seriestype] == st
                @error("Plot recipe $st returned the same seriestype: $(data.plotattributes)")
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
function _process_seriesrecipe(plt, plotattributes::AbstractDict{Symbol,Any}; type_aliases::AbstractDict{Symbol,Symbol} = Dict{Symbol,Symbol}())
    #println("process $(typeof(plotattributes))")
    # replace seriestype aliases
    st = Symbol(plotattributes[:seriestype])
    st = plotattributes[:seriestype] = get(type_aliases, st, st)

    # shapes shouldn't have fillrange set
    if plotattributes[:seriestype] == :shape
        plotattributes[:fillrange] = nothing
    end

    # if it's natively supported, finalize processing and pass along to the backend, otherwise recurse
    if is_st_supported(plt, st)
        finalize_subplot!(plt, st, plotattributes)

    else
        # get a sub list of series for this seriestype
        datalist = RecipesBase.apply_recipe(plotattributes, Val{st}, plotattributes[:x], plotattributes[:y], plotattributes[:z])

        # assuming there was no error, recursively apply the series recipes
        for data in datalist
            if isa(data, RecipesBase.RecipeData)
                preprocessArgs!(data.plotattributes)
                if data.plotattributes[:seriestype] == st
                    @error("The seriestype didn't change in series recipe $st.  This will cause a StackOverflow.")
                end
                _process_seriesrecipe(plt, data.plotattributes)
            else
                @warn("Unhandled recipe: $(data)")
                break
            end
        end
    end
    return nothing
end
