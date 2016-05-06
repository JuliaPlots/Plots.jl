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

The `@recipe` macro will process a function definition, replace `-->` commands, and
then add a new version of `apply_recipe` for dispatching on the arguments.

Set attributes using the `-->` command, and return a comma separated list of arguments that
should replace the current arguments.

The `is_key_supported` method should likely be overridden... by default everything is considered supported.

## An example:

```julia
# Plots will be the ultimate consumer of our recipe in this example
using Plots
gr()

type T end

@recipe function plot{N<:Integer}(t::T, n::N = 1; customcolor = :green)
    :markershape --> :auto, :require
    :markercolor --> customcolor, :force
    :xrotation   --> 45
    :zrotation   --> 90, :quiet
    rand(10,n)
end

# This call will implicitly call `RecipesBase.apply_recipe` as part of the Plots
# processing pipeline (see the Pipeline section of the Plots documentation).
# It will plot 5 line plots, all with black circles for markers.
# The markershape argument must be supported, and the zrotation argument's warning
# will be suppressed.  The user can override all arguments except markercolor.
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
