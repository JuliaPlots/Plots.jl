# RecipesBase

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaplots.org/stable/RecipesBase)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.juliaplots.org/dev/RecipesBase)
[![CI](https://github.com/JuliaPlots/Plots.jl/workflows/ci/badge.svg?branch=master)](https://github.com/JuliaPlots/Plots.jl/actions/workflows/ci.yml)
[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://julialang.zulipchat.com/#narrow/stream/236493-plots)
[![deps](https://juliahub.com/docs/RecipesBase/deps.svg)](https://juliahub.com/ui/Packages/RecipesBase/8e2Mm?t=2)

### Author: Thomas Breloff (@tbreloff)

This package implements handy macros `@recipe` and `@series` which will define a custom transformation
and attach attributes for user types.  Its design is an attempt to simplify and generalize
the summary and display of types and data from external packages.  With no extra dependencies
and minimal code, package authors can describe visualization routines that can be used
as components in more complex visualizations.

This functionality is primarily geared to turning user types and settings into the
data and attributes that describe a [Plots](https://github.com/tbreloff/Plots.jl) visualization,
though it could be used for other purposes as well.
Plots has extensive machinery to uniquely take advantage of the simplified recipe description you define.  See the [Plots documentation on recipes](http://docs.juliaplots.org/latest/recipes/) for more information.

The `@recipe` macro will process a function definition, use `-->` commands to define attributes, and
pass the return value through for further processing (likely by Plots.jl).

## Why should I care about this package?

Many packages have custom types and custom data.  There is usually specialized structure, and useful
methods of visualizing that structure and data.  This package solves the difficult problem of how to
build generic visualizations of user-defined data types, without adding bulky dependencies on complex
graphics packages.

This package is as lightweight as possible.  It exports two macros, and defines only a few internal methods.
It has **zero dependencies**.

However, although it is lightweight, it enables a lot.  The entirety of the Plots framework becomes available
to any package implementing a recipe.  This means that complex plots and subplots can be built with uber-flexibility
using custom combinations of data types.  Some examples of applications:

- Distributions: overlaid density plots for non-normal fitted distributions.
- DataFrames: "Grammar of Graphics"-style inputs using symbols.
- Deep Learning: frameworks for visualization of neural network states and tracking of internal calculations.
- Graphs: flexible, interactive graphs with easily customizable colors, etc.
- Symbolic frameworks: sample from complex symbolic distributions.

Really there's very little that *couldn't* be mapped to a useful visualization.
I challenge you to create the pictures that are worth a thousand words.

For more information about Plots, see [the docs](http://juliaplots.github.io/), and be sure to reference
the [supported keywords](https://docs.juliaplots.org/stable/generated/supported/#Keyword-Arguments).
For additional examples of recipes in the wild, see [PlotRecipes](https://github.com/JuliaPlots/PlotRecipes.jl).
Ask questions on [gitter](https://gitter.im/tbreloff/Plots.jl) or in the issues.

## Hello world

This will build a spiky surface:

```julia
using Plots; gr()
struct T end
@recipe f(::T) = rand(100,100)
surface(T())
```

![](https://cloud.githubusercontent.com/assets/933338/15089193/7a453ec6-13cc-11e6-9ae8-959e98b615dc.png)

## A real example

```julia
using RecipesBase

# Our user-defined data type
struct T end

# This is all we define.  It uses a familiar signature, but strips it apart
# in order to add a custom definition to the internal method `RecipesBase.apply_recipe`
@recipe function plot(::T, n = 1; customcolor = :green)
    markershape --> :auto        # if markershape is unset, make it :auto
    markercolor :=  customcolor  # force markercolor to be customcolor
    xrotation   --> 45           # if xrotation is unset, make it 45
    zrotation   --> 90           # if zrotation is unset, make it 90
    rand(10,n)                   # return the arguments (input data) for the next recipe
end

# ----------------------------

# Plots will be the ultimate consumer of our recipe in this example
using Plots
gr()

# This call will implicitly call `RecipesBase.apply_recipe` as part of the Plots
# processing pipeline (see the Pipeline section of the Plots documentation).
#   It will plot 5 line plots (a 5-column matrix is returned from the recipe).
#   All will have black circles:
#       - user override for markershape: :c == :circle
#       - customcolor overridden to :black, and markercolor is forced to be customcolor
#   If markershape is an unsupported keyword, the call will error.
#   By default, a warning will be shown for an unsupported keyword.
#   This will be suppressed for zrotation (:quiet flag).
plot(T(), 5; customcolor = :black, shape=:c)
```

![](https://cloud.githubusercontent.com/assets/933338/15083906/02a06810-139e-11e6-98a0-dd81c3fb1ad8.png)

In this example, we see a lot of the machinery in action.  We create a new type `T`, which
we will use for dispatch, and an optional argument `n`, which will be used to determine the
number of series to display.  User-defined keyword arguments are passed through, and the
`-->` command can be trailed by flags:

- `quiet`:   Suppress unsupported keyword warnings
- `require`: Error if keyword is unsupported
- `force`:   Don't allow user override for this keyword

### Series

For complex visualizations, it can be beneficial to create many series inside a single recipe.  The `@series` macro will make a copy of the attribute dictionary `d`, and add a new RecipeData object to the returned list.  See the [case studies](http://docs.juliaplots.org/latest/recipes/#case-studies) for more details.

### Generated code

For the example above, the following code is generated.  In it, you can see the managing of the scope of the keyword args, creation of a definition for `RecipesBase.apply_recipe`, setting attributes, and creating the list of `RecipeData` objects:

```julia
function RecipesBase.apply_recipe(d::Dict{Symbol,Any},::T,n=1)
    begin
        customcolor = get!(d,:customcolor,:green)
    end
    series_list = RecipesBase.RecipeData[]
    func_return = begin
            get!(d,:markershape,:auto)
            d[:markercolor] = customcolor
            get!(d,:xrotation,45)
            get!(d,:zrotation,90)
            rand(10,n)
        end
    if func_return !== nothing
        push!(series_list,RecipesBase.RecipeData(d,RecipesBase.wrap_tuple(func_return)))
    end
    begin
        RecipesBase.is_key_supported(:customcolor) || delete!(d,:customcolor)
    end
    series_list
end
```

### A humble request

If you build a recipe for your package, please let me know!  I'd love to compile both a gallery and
a listing of user-defined recipes, as well as the packages that are available for Plots visualizations.
