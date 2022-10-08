# RecipesPipeline

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaplots.org/stable/RecipesPipeline)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.juliaplots.org/dev/RecipesPipeline)
[![CI](https://github.com/JuliaPlots/Plots.jl/workflows/ci/badge.svg?branch=master)](https://github.com/JuliaPlots/Plots.jl/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/JuliaPlots/RecipesPipeline.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaPlots/RecipesPipeline.jl)
[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://julialang.zulipchat.com/#narrow/stream/236493-plots)

#### An implementation of the recipe pipeline from Plots
This package was factored out of Plots.jl to allow any other plotting package to use the recipe pipeline. In short, the extremely lightweight RecipesBase.jl package can be depended on by any package to define "recipes": plot specifications of user-defined types, as well as custom plot types. RecipePipeline.jl contains the machinery to translate these recipes to full specifications for a plot.

The package is intended to be used by consumer plotting packages, and is currently used by [Plots.jl](https://github.com/JuliaPlots/Plots.jl) (v.1.1.0 and above) and [MakieRecipes.jl](https://github.com/JuliaPlots/Makie.jl/tree/master/MakieRecipes), a package that bridges RecipesBase recipes to [Makie.jl](https://github.com/JuliaPlots/Makie.jl).

Current functionality:
```julia
using RecipesBase

# Our user-defined data type
struct T end

RecipesBase.@recipe function plot(::T, n = 1; customcolor = :green)
    seriestype --> :scatter
    markershape --> :auto        # if markershape is unset, make it :auto
    markercolor :=  customcolor  # force markercolor to be customcolor
    xrotation   --> 45           # if xrotation is unset, make it 45
    zrotation   --> 90           # if zrotation is unset, make it 90
    rand(10,n)                   # return the arguments (input data) for the next recipe
end

using Makie, MakieRecipes
recipeplot(T(), 3; markersize = 3)

```
<img width="639" alt="Screenshot 2020-04-05 at 16 36 46" src="https://user-images.githubusercontent.com/8429802/78501571-3ea63d00-775c-11ea-9f6e-0c3651553bca.png">
