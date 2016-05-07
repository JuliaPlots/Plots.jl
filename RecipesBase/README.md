# RecipesBase

[![Build Status](https://travis-ci.org/JuliaPlots/RecipesBase.jl.svg?branch=master)](https://travis-ci.org/JuliaPlots/RecipesBase.jl)

### Author: Thomas Breloff (@tbreloff)

This package implements a handy macro `@recipe` which will define a custom transformation
and attach attributes for user types.  It's design is an attempt to simplify and generalize
the summary and display of types and data from external packages.  With no extra dependencies
and minimal code, package authors can describe visualization routines that can be used
as components in more complex visualizations.

This functionality is primarily geared to turning user types and settings into the
data and attributes that describe a [Plots](https://github.com/tbreloff/Plots.jl) visualization, though it could be used for
other purposes as well.  Plots has extensive machinery to uniquely take advantage of the simplified
recipe description you define.

The `@recipe` macro will process a function definition, use `-->` commands to define attributes, and
pass the return value through for further processing (likely by Plots.jl).

## Why should I care about this package?

Many packages have custom types and custom data.  There is usually specialized structure, and useful
methods of visualizing that structure and data.  This package solves the difficult problem of how to
build generic visualizations of user-defined data types, without adding bulky dependencies on complex
graphics packages.

This package is as lightweight as possible.  It **exports one macro**, and defines only a few internal methods.
It has **zero dependencies**.

However, although it is lightweight, it enables a lot.  The entirety of the Plots framework becomes available
to any package implementing a recipe.  This means that complex plots and subplots can be built with uber-flexibility
using custom combinations of data types.  Some examples of applications:

- Distributions: overlayed density plots for non-normal fitted distributions.
- DataFrames: "Grammar of Graphics"-style inputs using symbols.
- Deep Learning: frameworks for visualization of neural network states and tracking of internal calculations.
- Graphs: flexible, interactive graphs with easily customizable colors, etc.
- Symbolic frameworks: sample from complex symbolic distributions.

Really there's very little that *couldn't* be mapped to a useful visualization.  I challenge you to
create the pictures that are worth a thousand words.

For more information about Plots, see [the docs](http://plots.readthedocs.io/), and be sure to reference
the [supported keywords](http://plots.readthedocs.io/en/latest/supported/#keyword-arguments).
For additional examples of recipes in the wild, see [MLPlots](https://github.com/JuliaML/MLPlots.jl).
Ask questions on [gitter](https://gitter.im/tbreloff/Plots.jl) or in the issues.

## Hello world

This will build a spiky surface:

```julia
using Plots; gr()
type T end
@recipe f(::T) = rand(10,10)
surface(T())
```

![](https://cloud.githubusercontent.com/assets/933338/15089193/7a453ec6-13cc-11e6-9ae8-959e98b615dc.png)

## A real example

```julia
# Plots will be the ultimate consumer of our recipe in this example
using Plots
gr()

# Our user-defined data type
type T end

# This is all we define.  It uses a familiar signature, but strips it apart
# in order to add a custom definition to the internal method `RecipesBase.apply_recipe`
@recipe function plot(::T, n = 1; customcolor = :green)
    :markershape --> :auto, :require
    :markercolor --> customcolor, :force
    :xrotation   --> 45
    :zrotation   --> 90, :quiet
    rand(10,n)
end

# This call will implicitly call `RecipesBase.apply_recipe` as part of the Plots
# processing pipeline (see the Pipeline section of the Plots documentation).
#   It will plot 5 line plots (a 5-column matrix is returned from the recipe).
#   All will have black circles:
#       - user override for markershape: :c == :circle
#       - customcolor overridden to :black, and markercolor is forced to be customcolor
#   If markershape is an unsupported keyword, the call will error.
#   By default, a warning will be shown for an unsupported keyword.  This will be suppressed for zrotation (:quiet flag).
plot(T(), 5; customcolor = :black, shape=:c)
```

![](https://cloud.githubusercontent.com/assets/933338/15083906/02a06810-139e-11e6-98a0-dd81c3fb1ad8.png)

In this example, we see lots of the machinery in action.  We create a new type `T` which
we will use for dispatch, and an optional argument `n`, which will be used to determine the
number of series to display.  User-defined keyword arguments are passed through, and the
`-->` command can be trailed by flags:

- `quiet`:   Suppress unsupported keyword warnings
- `require`: Error if keyword is unsupported
- `force`:   Don't allow user override for this keyword

### A humble request

If you build a recipe for your package, please let me know!  I'd love to compile both a gallery and
a listing of user-defined recipes, as well as the packages that are available for Plots visualizations.
