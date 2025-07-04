# RecipesPipeline

## An implementation of the recipe pipeline from Plots

This package was factored out of `Plots.jl` to allow any other plotting package to use the recipe pipeline. In short, the extremely lightweight `RecipesBase` package can be depended on by any package to define "recipes": plot specifications of user-defined types, as well as custom plot types. `RecipesPipeline` contains the machinery to translate these recipes to full specifications for a plot.
