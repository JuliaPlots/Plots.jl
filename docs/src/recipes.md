```@setup recipes
using Plots; gr()
Plots.reset_defaults()
```


# [Recipes](@id recipes)

Recipes are a way of defining visualizations in your own packages and code, without having to depend on Plots. The functionality relies on [RecipesBase](https://github.com/JuliaPlots/Plots.jl/tree/master/RecipesBase), a super lightweight but powerful package which allows users to create advanced plotting logic without Plots.  The `@recipe` macro in RecipesBase will add a method definition for `RecipesBase.apply_recipe`.  Plots adds to and calls this same function, and so your package and Plots can communicate without ever knowing about the other.  Magic!

Visualizing custom user types has always been a confusing problem.  Should a package developer add a dependency on a plotting package (forcing the significant baggage that comes with that dependency)? Should they attempt conditional dependencies?  Should they submit a PR to graphics packages to define their custom visualizations?  It seems that every option had many cons for each pro, and the decision was tough.  With recipes, these issues go away.  One tiny package (RecipesBase) gives simple hooks into the visualization pipeline, allowing users and package developers to focus solely on the specifics of their visualization.  Pick the shapes/lines/colors that will represent your data well, decide on custom defaults, and convert the inputs (if you need to).  Everything else is handled by Plots.  There are many examples of recipes both within Plots and in many external packages, including [GraphRecipes](https://github.com/JuliaPlots/GraphRecipes.jl).


### Visualizing User Types

Examples are always best.  Lets explore the implementation of [creating visualization recipes for Distributions](https://github.com/tbreloff/ExamplePlots.jl/tree/master/notebooks/usertype_recipes.ipynb).

### Custom treatment of input combinations

Want to do something special whenever the first input is a time series?  Maybe you want to preprocess your data depending on keyword flags?  This is all possible by making recipes with unique dispatch signatures.  You can offload and use the pre and post processing of Plots, and just add the bits that are specific to you.

### Type Recipes: Easy drop-in replacement of data types

Many times a data type is a simple wrapper of a Function or Array.  For example:

```julia
mutable struct MyVec
    v::Vector{Int}
end
```

If `MyVec` was a subtype of AbstractVector, there would not be anything to do... it should "just work".  However this isn't always desireable, and it would be nice if you could call `plot(10:20, myvec)` without having to personally define every possible combination of inputs.  It this case, you'll want to use a special type of recipe signature:

```julia
@recipe f(::Type{MyVec}, myvec::MyVec) = myvec.v
```

Afterwards, all plot commands which work for vectors will also work for your datatype.


### Series Recipes

Lets quickly discuss a mainstay of data visualization: the histogram.  Hadley Wickham has explored the nature of histograms as part of his [Layered Grammar of Graphics](https://vita.had.co.nz/papers/layered-grammar.pdf).  In it, he discusses how a histogram is really nothing more than a bar graph which has its data pre-binned.  This is true, and it can be taken further.  A bar-graph is really an extension of a step-graph, in which zeros are interwoven among the x-values.  A step-graph is really nothing more than a path (line) which can travel only horizontally or vertically.  Of course, a similar decomposition could be had by treating the bars as filled polygons.

The point to be had is that a graphics package need only be able to draw lines and polygons, and they can support drawing a histogram.  The path from data to histogram is normally very complicated, but we can avoid the complexity and define a recipe to convert it to its subcomponents.  In a few lines of readable code, we can implement a key statistical visualization.  See the [tutorial on series recipes](https://github.com/tbreloff/ExamplePlots.jl/tree/master/notebooks/series_recipes.ipynb) for a better understanding of how you might use them.



## Recipe Types

Above we described `Type recipes` and `Series Recipes`. In total there are four main types of recipes in Plots (listed in the order they are processed):

- User Recipes
- Type Recipes
- Plot Recipes
- Series Recipes

**The recipe type is determined completely by the dispatch signature.**  Each recipe type is called from a different part of the [plotting pipeline](https://docs.juliaplots.org/latest/pipeline/), so you will choose a type of recipe to match how much processing you want completed before your recipe is applied.

These are the dispatch signatures for each type (note that most of these can accept positional or keyword args, denoted by `...`):

### User Recipes
```julia
@recipe function f(custom_arg_1::T, custom_arg_2::S, ...; ...) end
```
- Process a unique set of types early in the pipeline.  Good for user-defined types or special combinations of Base types.
- The `@userplot` macro is a nice convenience which both defines a new type (to ensure correct dispatch) and exports shorthands.
- See `graphplot` for an example.

### [Type Recipes](@id type-recipes)
```julia
@recipe function f(::Type{T}, val::T) where{T} end
```
- For user-defined types which wrap or have a one-to-one mapping to something supported by Plots, simply define a conversion method.
- Note: this is effectively saying "when you see type T, replace it with ..."
- See `SymPy` for an example.

### Plot Recipes
```julia
@recipe function f(::Type{Val{:myplotrecipename}}, plt::AbstractPlot; ...) end
```
- These are called after input data has been processed, but **before the plot is created**.
- Build layouts, add subplots, and other plot-wide attributes.
- See `marginalhist` in [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) for an example.

### [Series Recipes](@id series-recipes)
```julia
@recipe function f(::Type{Val{:myseriesrecipename}}, x, y, z; ...) end
```
- These are the last calls to happen.  Each backend will support a short list of series types (`path`, `shape`, `histogram`, etc).  If a series type is natively supported, processing is passed (delegated) to the backend.  If a series type is **not** natively supported by the backend, we attempt to call a "series recipe".
- Note: If there's no series recipe defined, and the backend doesn't support it, you'll see an error like: `ERROR: The backend must not support the series type Val{:hi}, and there isn't a series recipe defined.`
- Note: You must have the `x, y, z` included in the signature, or it won't be processed as a series type!!

## Recipe Syntax/Rules

Lets decompose what's happening inside the recipe macro, starting with a simple recipe:

```@example recipes
mutable struct MyType end

@recipe function f(::MyType, n::Integer = 10; add_marker = false)
    linecolor   --> :blue
    seriestype  :=  :path
    markershape --> (add_marker ? :circle : :none)
    delete!(plotattributes, :add_marker)
    rand(n)
end
```

We create a new type `MyType`, which is empty, and used purely for dispatch.  Our goal here is to create a random path of `n` points.

There are a few important things to know, after which recipes boil down to updating an attribute dictionary and returning input data:

- A recipe signature `f(args...; kw...)` is converted into a definition of `apply_recipe(plotattributes::KW, args...)` where:
    - `plotattributes` is an attribute dictionary of type `typealias KW Dict{Symbol,Any}`
    - Your `args` must be distinct enough that dispatch will call your definition (and without masking an existing definition).  Using a custom data type will ensure proper dispatch.
    - The function `f` is unused/meaningless... call it whatever you want.
- The special operator `-->` turns `linecolor --> :blue` into `get!(plotattributes, :linecolor, :blue)`, setting the attribute only when it doesn't already exist.  (Tip: Wrap the right hand side in parentheses for complex expressions.)
- The special operator `:=` turns `seriestype := :path` into `plotattributes[:seriestype] = :path`, forcing that attribute value.  (Tip: Wrap the right hand side in parentheses for complex expressions.)
- One cannot use aliases (such as `colour` or `alpha`) in a recipe, only the full attribute name.
- The return value of the recipe is the `args` of a `RecipeData` object, which also has a reference to the attribute dictionary.
- A recipe returns a Vector{RecipeData}.  We'll see how to add to this list later with the `@series` macro.

!!! compat "RecipesBase 0.9"
    Use of the `return` keyword in a recipe requires at least  RecipesBase 0.9.

Breaking down the example:

In the example above, we use `MyType` for dispatch, with optional positional argument `n::Integer`:

```julia
@recipe function f(::MyType, n::Integer = 10; add_marker = false)
```

With a call to `plot(MyType())` or similar, this recipe will be invoked.  If `linecolor` has not been set, it is set to `:blue`:

```julia
    linecolor   --> :blue
```

The `seriestype` is forced to be `:path`:

```julia
    seriestype  :=  :path
```

The `markershape` is a little more complex; it checks the `add_marker` custom keyword, but only if `markershape` was not already set.  (Note: the `add_marker` key is redundant, as the user can just set the marker shape directly... I use it only for demonstration):

```julia
    markershape --> (add_marker ? :circle : :none)
```

then return the data to be plotted.
```julia
    rand(n)
end
```

Some example usages of our (mostly useless) recipe:

```@example recipes
mt = MyType()
plot(
    plot(mt),
    plot(mt, 100, linecolor = :red),
    plot(mt, marker = (:star,20), add_marker = false),
    plot(mt, add_marker = true)
)
```

---

### User Recipes

The example above is an example of a "user recipe", in which you define the full signature for dispatch.  User recipes (like others) can be stacked and modular.  The following is valid:

```julia
@recipe f(mt::MyType, n::Integer = 10) = (mt, rand(n))
@recipe f(mt::MyType, v::AbstractVector) = (seriestype := histogram; v)
```

Here a call to `plot(MyType())` will apply these recipes in order; first mapping `mt` to `(mt, rand(10))` and then subsequently setting the seriestype to `:histogram`.

```@example recipes
plot(MyType())
```

---

### Type Recipes

For some custom data types, they are essentially light wrappers around built-in containers.  For example you may have a type:

```julia
mutable struct MyWrapper
    v::Vector
end
```

In this case, you'd like your `MyWrapper` objects to be treated just like Vectors, but do not wish to subtype AbstractArray.  No worries!  Just define a type recipe to do the conversion:

```julia
@recipe f(::Type{MyWrapper}, mw::MyWrapper) = mw.v
```

This signature is called on each input when dispatch did not find a suitable recipe for the full `args...`.  So `plot(rand(10), MyWrapper(rand(10)))` will "just work".

---

### Series Recipes

This is where the magic happens.  You can create your own custom visualizations for arbitrary data.  Quickly define violin plots, error bars, and even standard types like histograms and step plots.  A histogram is a bar plot:

```julia
@recipe function f(::Type{Val{:histogram}}, x, y, z)
    edges, counts = my_hist(y, plotattributes[:bins],
                               normed = plotattributes[:normalize],
                               weights = plotattributes[:weights])
    x := edges
    y := counts
    seriestype := :bar
    ()
end
```

while a 2D histogram is really a heatmap:

```julia
@recipe function f(::Type{Val{:histogram2d}}, x, y, z)
    xedges, yedges, counts = my_hist_2d(x, y, plotattributes[:bins],
                                              normed = plotattributes[:normalize],
                                              weights = plotattributes[:weights])
    x := centers(xedges)
    y := centers(yedges)
    z := Surface(counts)
    seriestype := :heatmap
    ()
end
```

The argument `y` is always populated, the argument `x` is populated with a call like `plot(x,y, seriestype =: histogram2d)` and correspondingly for `z`, `plot(x,y,z, seriestype =: histogram2d)`

See below where I go through a series recipe for creating boxplots.  Many of these "standard" recipes are defined in Plots, though they can be defined anywhere **without requiring the package to be dependent on Plots**.


---


# Case studies

### Marginal Histograms

Here we show a user recipe version of the `marginalhist` plot recipe for [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl). This is a nice example because, although easy to understand, it utilizes some great Plots features.

Marginal histograms are a visualization comparing two variables.  The main plot is a 2D histogram, where each rectangle is a (possibly normalized and weighted) count of data points in that bucket.  Above the main plot is a smaller histogram of the first variable, and to the right of the main plot is a histogram of the second variable.  The full recipe:

```@example recipes
@userplot MarginalHist

@recipe function f(h::MarginalHist)
    if length(h.args) != 2 || !(typeof(h.args[1]) <: AbstractVector) ||
        !(typeof(h.args[2]) <: AbstractVector)
        error("Marginal Histograms should be given two vectors.  Got: $(typeof(h.args))")
    end
    x, y = h.args

    # set up the subplots
    legend := false
    link := :both
    framestyle := [:none :axes :none]
    grid := false
    layout := @layout [tophist           _
                       hist2d{0.9w,0.9h} righthist]

    # main histogram2d
    @series begin
        seriestype := :histogram2d
        subplot := 2
        x, y
    end

    # these are common to both marginal histograms
    fillcolor := :black
    fillalpha := 0.3
    linealpha := 0.3
    seriestype := :histogram

    # upper histogram
    @series begin
        subplot := 1
        x
    end

    # right histogram
    @series begin
        orientation := :h
        subplot := 3
        y
    end
end
```

Usage:


```@example recipes
using Distributions
n = 1000
x = rand(Gamma(2), n)
y = -0.5x + randn(n)
marginalhist(x, y, fc = :plasma, bins = 40)
```


---

Now I'll go through each section in detail:

The `@userplot` macro is a nice convenience for creating a new wrapper for input arguments that can be distinct during dispatch.  It also creates lowercase convenience methods (`marginalhist` and `marginalhist!`) and exports them.

```julia
@userplot MarginalHist
```

thus create a type `MarginalHist` for dispatch. An object of type `MarginalHist` has the field `args` which is the tuple of arguments the plot function is invoked with, which can be either `marginalhist(x,y,...)` or `plot(x,y, seriestype = :marginalhist)`. The first syntax is a shorthand created by the `@userplot` macro.

We dispatch only on the generated type, as the real inputs are wrapped inside it:

```julia
@recipe function f(h::MarginalHist)
```

Some error checking.  Note that we're extracting the real inputs (like in a call to `marginalhist(randn(100), randn(100))`) into `x` and `y`:

```julia
    if length(h.args) != 2 || !(typeof(h.args[1]) <: AbstractVector) ||
        !(typeof(h.args[2]) <: AbstractVector)
        error("Marginal Histograms should be given two vectors.  Got: $(typeof(h.args))")
    end
    x, y = h.args
```

Next we build the subplot layout and define some attributes.  A few things to note:

- The layout creates three subplots (`_` is left blank)
- Attributes are mapped to each subplot when passed in as a matrix (row-vector)
- The attribute `link := :both` means that the y-axes of each row (and x-axes of
  each column) will share data extrema.  Other values include `:x`, `:y`,
  `:all`, and `:none`.

```julia
    # set up the subplots
    legend := false
    link := :both
    framestyle := [:none :axes :none]
    grid := false
    layout := @layout [tophist           _
                       hist2d{0.9w,0.9h} righthist]
```

Define the series of the main plot.  The `@series` macro makes a local copy of the attribute dictionary `plotattributes` using a "let block".  The copied dictionary and the returned args are added to the `Vector{RecipeData}` which is returned from the recipe.  This block is similar to calling `histogram2d!(x, y; subplot = 2, plotattributes...)` (but you wouldn't actually want to do that).

Note: this `@series` block gets a "snapshot" of the attributes, so it contains anything that was set before this block, but nothing from after it.  `@series` blocks can be standalone, as these are, or they can be in a loop.

```julia
    # main histogram2d
    @series begin
        seriestype := :histogram2d
        subplot := 2
        x, y
    end
```

Next we move on to the marginal plots.  We first set attributes which are shared by both:

```julia
    # these are common to both marginal histograms
    fillcolor := :black
    fillalpha := 0.3
    linealpha := 0.3
    seriestype := :histogram
```

Now we create two more series, one for each histogram.

```julia
    # upper histogram
    @series begin
        subplot := 1
        x
    end

    # right histogram
    @series begin
        orientation := :h
        subplot := 3
        y
    end
end
```

It's important to note: normally we would return arguments from a recipe, and those arguments would be added to a `RecipeData` object and pushed onto our `Vector{RecipeData}`.  However, when creating series using the `@series` macro, you have the option of returning `nothing`, which will bypass that last step.

One can also have multiple series in a single subplot and repeat the same for multiple subplots if needed. This would require one to supply the correct subplot id/number.

```julia
mutable struct SeriesRange
    range::UnitRange{Int64}
end
@recipe function f(m::SeriesRange)
    range = m.range
    layout := length(range)
    for i in range
        @series begin
            subplot := i
            seriestype := scatter
            rand(10)
        end
        @series begin
            subplot := i
            rand(10)
        end
    end
end
```
---

### Documenting plot functions

A documentation string added above the recipe definition will have no effect, just like the function name is meaningless. Since everything in Julia can be associated with a doc-string, the documentation can be added to the name of the plot function like this
```julia
"""
My docstring
"""
my_plotfunc
```
This can be put anywhere in the code and will appear on the call `?my_plotfunc`.

---

### Troubleshooting

It can sometimes be helpful when debugging recipes to see the order of dispatch inside the `apply_recipe` calls.  Turn on debugging info with:

```julia
RecipesBase.debug()
```

You can also pass a `Bool` to the `debug` method to turn it on/off.

Here are some common errors, and what to look out for:

#### convertToAnyVector

```
ERROR: In convertToAnyVector, could not handle the argument types: <<some type>>
    [inlined code] from ~/.julia/v0.4/Plots/src/series_new.jl:87
    in apply_recipe at ~/.julia/v0.4/RecipesBase/src/RecipesBase.jl:237
    in _plot! at ~/.julia/v0.4/Plots/src/plot.jl:312
    in plot at ~/.julia/v0.4/Plots/src/plot.jl:52
```

This error occurs when the input types could not be handled by a recipe. The type `<<some type>>` cannot be processed.  Remember, there may be recursive calls to multiple recipes for a complicated plot.


#### MethodError: `start` has no method matching start(::Void)

```
ERROR: MethodError: `start` has no method matching start(::Void)
    in collect at ./array.jl:260
    in collect at ./array.jl:272
    in plotly_series at ~/.julia/v0.4/Plots/src/backends/plotly.jl:345
    in _series_added at ~/.julia/v0.4/Plots/src/backends/plotlyjs.jl:36
    in _apply_series_recipe at ~/.julia/v0.4/Plots/src/plot.jl:224
    in _plot! at ~/.julia/v0.4/Plots/src/plot.jl:537
```

This error is commonly encountered when a series type expects data for `x`, `y`, or `z`, but instead was passed `nothing` (which is of type `Void`).  Check that you have a `z` value defined for 3D plots, and likewise that you have valid values for `x` and `y`.  This could also apply to attributes like `fillrange`, `marker_z`, or `line_z` if they are expected to have non-void values.

#### MethodError: Cannot `convert` an object of type Float64 to an object of type RecipeData

```
ERROR: MethodError: Cannot `convert` an object of type Float64 to an object of type RecipeData
Closest candidates are:
  convert(::Type{T}, ::T) where T at essentials.jl:171
  RecipeData(::Any, ::Any) at ~/.julia/packages/RecipesBase/G4s6f/src/RecipesBase.jl:57
```
!!! compat "RecipesBase 0.9"
    Use of the `return` keyword in recipes requires RecipesBase 0.9

This error is encountered if you use the `return` keyword in a recipe, which is not supported in RecipesBase up to v0.8.
