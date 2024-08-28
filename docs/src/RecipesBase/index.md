# RecipesBase

**Author: Thomas Breloff (@tbreloff)**

RecipesBase is a lightweight Package without dependencies that allows to define custom visualizations with the [`@recipe`](@ref) macro.

Package developers and users can define recipes to tell [Plots.jl](https://github.com/JuliaPlots/Plots.jl) how to plot custom types without depending on it.
Furthermore, recipes can be used for complex visualizations and new series types.
Plots, for example, uses recipes internally to define histograms or bar plots.
[StatsPlots.jl](https://github.com/JuliaPlots/StatsPlots.jl) and [GraphRecipes.jl](https://github.com/JuliaPlots/GraphRecipes.jl) extend Plots functionality for statistical plotting and visualization of graphs.

RecipesBase exports the [`@recipe`](@ref) macro which provides a nice syntax for defining plot recipes.
Under the hood [`@recipe`](@ref) defines a new method for `RecipesBase.apply_recipe` which is called recursively in Plots at different stages of the argument processing pipeline.
This way other packages can communicate with Plots, i.e. define custom plotting recipes, only depending on RecipesBase.
Furthermore, the convenience macros [`@series`](@ref), [`@userplot`](@ref) and [`@shorthands`](@ref) are exported by RecipesBase.
