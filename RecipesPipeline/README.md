# RecipesPipeline

[![Build Status](https://travis-ci.com/mkborregaard/RecipeUtils.jl.svg?branch=master)](https://travis-ci.com/mkborregaard/RecipeUtils.jl)
[![Codecov](https://codecov.io/gh/mkborregaard/RecipeUtils.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mkborregaard/RecipeUtils.jl)

#### [WIP] An implementation of the recipe pipeline from Plots
This package was factored out of Plots.jl to allow any other plotting package to use the recipe pipeline. In short, the extremely lightweight RecipesBase.jl package can be depended on by any package to define "recipes": plot specifications of user-defined types, as well as custom plot types. RecipePipeline.jl contains the machinery to translate these recipes to full specifications for a plot.

The package is intended to be used by consumer plotting packages, and is currently used by [Plots.jl](https://github.com/JuliaPlots/Plots.jl) (v.1.1.0 and above) and [MakieRecipes.jl](https://github.com/JuliaPlots/MakieRecipes.jl), a package that bridges RecipesBase recipes to [Makie.jl](https://github.com/JuliaPlots/Makie.jl).

Current functionality:
```julia
using RecipesBase

# Our user-defined data type
struct T end

@recipe function plot(::T, n = 1; customcolor = :green)
    markershape --> :auto        # if markershape is unset, make it :auto
    markercolor :=  customcolor  # force markercolor to be customcolor
    xrotation   --> 45           # if xrotation is unset, make it 45
    zrotation   --> 90           # if zrotation is unset, make it 90
    rand(10,n)                   # return the arguments (input data) for the next recipe
end

using Makie, MakieRecipes
recipeplot(T(), 3; markersize = 5)

```
