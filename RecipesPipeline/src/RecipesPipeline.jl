# # RecipesPipeline
module RecipesPipeline

import RecipesBase
import RecipesBase: @recipe, @series, RecipeData, is_explicit
import PlotUtils # tryrange and adapted_grid
using Dates

export recipe_pipeline!
# Plots relies on these:
export SliceIt,
    DefaultsDict,
    Formatted,
    AbstractSurface,
    Surface,
    Volume,
    is3d,
    is_surface,
    needs_3d_axes,
    group_as_matrix,
    reset_kw!,
    pop_kw!,
    scale_func,
    inverse_scale_func,
    unzip,
    dateformatter,
    datetimeformatter,
    timeformatter
# API
export warn_on_recipe_aliases,
    splittable_attribute,
    split_attribute,
    process_userrecipe!,
    get_axis_limits,
    is_axis_attribute,
    type_alias,
    plot_setup!,
    slice_series_attributes!

include("api.jl")
include("utils.jl")
include("series.jl")
include("group.jl")
include("user_recipe.jl")
include("type_recipe.jl")
include("plot_recipe.jl")
include("series_recipe.jl")
include("recipes.jl")


"""
    recipe_pipeline!(plt, plotattributes, args)

Recursively apply user recipes, type recipes, plot recipes and series recipes to build a
list of `Dict`s, each corresponding to a series. At the beginning `plotattributes`
contains only the keyword arguments passed in by the user. Add all series to the plot
bject `plt` and return it.
"""
function recipe_pipeline!(plt, plotattributes, args)
    plotattributes[:plot_object] = plt

    # --------------------------------
    # "USER RECIPES"
    # --------------------------------

    # process user and type recipes
    kw_list = _process_userrecipes!(plt, plotattributes, args)

    # --------------------------------
    # "PLOT RECIPES"
    # --------------------------------

    # The "Plot recipe" acts like a series type, and is processed before the plot layout
    # is created, which allows for setting layouts and other plot-wide attributes.
    # We get inputs which have been fully processed by "user recipes" and "type recipes",
    # so we can expect standard vectors, surfaces, etc.  No defaults have been set yet.

    kw_list = _process_plotrecipes!(plt, kw_list)

    # --------------------------------
    # Plot/Subplot/Layout setup
    # --------------------------------

    plot_setup!(plt, plotattributes, kw_list)

    # At this point, `kw_list` is fully decomposed into individual series... one KW per
    # series. The next step is to recursively apply series recipes until the backend
    # supports that series type.

    # --------------------------------
    # "SERIES RECIPES"
    # --------------------------------

    _process_seriesrecipes!(plt, kw_list)

    # --------------------------------
    # Return processed plot object
    # --------------------------------

    return plt
end

end
