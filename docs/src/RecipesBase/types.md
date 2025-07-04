```@setup types
using Plots, Random
Random.seed!(100)
default(legend = :topleft, markerstrokecolor = :auto, markersize = 6)
```

# Recipe Types

## Overview

There are four main types of recipes which are determined by the signature of the [`@recipe`](@ref) macro.

### User Recipes

```julia
@recipe function f(custom_arg_1::T, custom_arg_2::S, ...; ...)
```

!!! tip
    [`@userplot`](@ref) provides a convenient way to create a custom type to dispatch on and defines custom plotting functions.
    ```julia
    @userplot MyPlot
    @recipe function f(mp::MyPlot; ...)
        ...
    end
    ```
    Now we can plot with:
    ```julia
    myplot(args...; kw...)
    myplot!(args...; kw...)
    ```

### Type Recipes

```julia
@recipe function f(::Type{T}, val::T) where T
```

!!! compat
    With RecipesBase 1.0 type recipes are aware of the current axis (`:x`, `:y`, `:z`).
    ```julia
    @recipe function f(::Type{MyType}, val::MyType)
        guide --> "My Guide"
        ...
    end
    ```
    This only sets the guide for the axes with `MyType`.
    For more complex type recipes the current axis letter can be accessed in [`@recipe`](@ref) with `plotattributes[:letter]`.

!!! compat
    With RecipesBase 1.0 type recipes of the form
    ```julia
    @recipe function f(::Type{T}, val::T) where T <: AbstractArray{MyType}
    ```
    for `AbstractArray`s of custom types are supported too.

!!! info
    User recipes and type recipes must return either
    - an `AbstractArray{<:V}` where `V` is a *valid type*,
    - two functions, or
    - nothing

    A *valid type* is either a Plots *datapoint* or a type that can be handled by another user recipe or type recipe.
    Plots *datapoints* are all subtypes of `Union{AbstractString, Missing}` and `Union{Number, Missing}`.

    If two functions are returned the former should tell Plots how to convert from `T` to a *datapoint* and the latter how to convert from *datapoint* to string for tick label formatting.

### Plot Recipes

```julia
@recipe function f(::Type{Val{:myplotrecipename}}, plt::AbstractPlot; ...)
```

### Series Recipes

```julia
@recipe function f(::Type{Val{:myseriesrecipename}}, x, y, z; ...)
```

!!! tip
    The [`@shorthands`](@ref) macro provides a convenient way to define plotting functions for custom plot recipes or series recipes.
    ```julia
    @shorthands myseriestype
    @recipe function f(::Type{Val{:myseriestype}}, x, y, z; ...)
        ...
    end
    ```
    This allows to plot with:
    ```julia
    myseriestype(args...; kw...)
    myseriestype!(args...; kw...)
    ```

!!! warning
    Plot recipes and series recipes have to set the `seriestype` attribute.

## User Recipes
User recipes are called early in the processing pipeline and allow designing custom visualizations.
```julia
@recipe function f(custom_arg_1::T, custom_arg_2::S, ...; ...)
```

We have already seen an example for a user recipe in the syntax section above.
User recipes can also be used to define a custom visualization without necessarily wishing to plot a custom type.
For this purpose we can create a type to dispatch on.
The [`@userplot`](@ref) macro is a convenient way to do this.
```julia
@userplot MyPlot
```
expands to
```julia
mutable struct MyPlot
    args
end
export myplot, myplot!
myplot(args...; kw...) = plot(MyPlot(args); kw...)
myplot!(args...; kw...) = plot!(MyPlot(args); kw...)
myplot!(p::AbstractPlot, args...; kw...) = plot!(p, MyPlot(args); kw...)
```

To check `args` type, define a struct with type parameters.

```julia
@userplot struct MyPlot{T<:Tuple{AbstractVector}}
    args::T
end
```

We can use this to define a user recipe for a pie plot.
```@example types
# defines mutable struct `UserPie` and sets shorthands `userpie` and `userpie!`
@userplot UserPie
@recipe function f(up::UserPie)
    y = up.args[end] # extract y from the args
    # if we are passed two args, we use the first as labels
    labels = length(up.args) == 2 ? up.args[1] : eachindex(y)
    framestyle --> :none
    aspect_ratio --> true
    s = sum(y)
    θ = 0
    # add a shape for each piece of pie
    for i in 1:length(y)
        # determine the angle until we stop
        θ_new = θ + 2π * y[i] / s
        # calculate the coordinates
        coords = [(0.0, 0.0); Plots.partialcircle(θ, θ_new, 50)]
        @series begin
            seriestype := :shape
            label --> string(labels[i])
            coords
        end
        θ = θ_new
    end
    # we already added all shapes in @series so we don't want to return a series
    # here. (Technically we are returning an empty series which is not added to
    # the legend.)
    primary := false
    ()
end
```

Now we can just use the recipe like this:

```@example types
userpie('A':'D', rand(4))
```

## Type Recipes
Type recipes define one-to-one mappings from custom types to something Plots supports
```julia
@recipe function f(::Type{T}, val::T) where T
```

Suppose we have a custom wrapper for vectors.

```@example types
struct MyWrapper
    v::Vector
end
```
We can tell Plots to just use the wrapped vector for plotting in a type recipe.
```@example types
@recipe f(::Type{MyWrapper}, mw::MyWrapper) = mw.v
```
Now Plots knows what to do when it sees a `MyWrapper`.
```@example types
mw = MyWrapper(cumsum(rand(10)))
plot(mw)
```
Due to the recursive application of type recipes they even compose automatically.
```@example types
struct MyOtherWrapper
    w
end

@recipe f(::Type{MyOtherWrapper}, mow::MyOtherWrapper) = mow.w

mow = MyOtherWrapper(mw)
plot(mow)
```
If we want an element-wise conversion of custom types we can define a conversion function to a type that Plots supports (`Real`, `AbstractString`) and a formatter for the tick labels.
Consider the following simple time type.
```@example types
struct MyTime
    h::Int
    m::Int
end

# show e.g. `MyTime(1, 30)` as "01:30"
time_string(mt) = join((lpad(string(c), 2, "0") for c in (mt.h, mt.m)), ":")
# map a `MyTime` object to the number of minutes that have passed since midnight.
# this is the actual data Plots will use.
minutes_since_midnight(mt) = 60 * mt.h + mt.m
# convert the minutes passed since midnight to a nice string showing `MyTime`
formatter(n) = time_string(MyTime(divrem(n, 60)...))

# define the recipe (it must return two functions)
@recipe f(::Type{MyTime}, mt::MyTime) = (minutes_since_midnight, formatter)
```
Now we can plot vectors of `MyTime` automatically with the correct tick labelling.
`DateTime`s and `Char`s are implemented with such a type recipe in Plots for example.

```@example types
times = MyTime.(0:23, rand(0:59, 24))
vals = log.(1:24)

plot(times, vals)
```
Again everything composes nicely.
```@example types
plot(MyWrapper(vals), MyOtherWrapper(times))
```

## Plot Recipes
Plot recipes are called after all input data is processed by type recipes but before the plot and subplots are set-up. They allow to build series with custom layouts and set plot-wide attributes.
```julia
@recipe function f(::Type{Val{:myplotrecipename}}, plt::AbstractPlot; ...)
```

Plot recipes define a new series type.
They are applied after type recipes.
Hence, standard Plots types can be assumed for input data `:x`, `:y` and `:z` in `plotattributes`.
Plot recipes can access plot and subplot attributes before they are processed, for example to build layouts.
Both, plot recipes and series recipes must change the series type.
Otherwise we get a warning that we would run into a StackOverflow error.

We can define a seriestype `:yscaleplot`, that automatically shows data with a linear y scale in one subplot and with a logarithmic yscale in another one.
```@example types
@recipe function f(::Type{Val{:yscaleplot}}, plt::AbstractPlot)
    x, y = plotattributes[:x], plotattributes[:y]
    layout := (1, 2)
    for (i, scale) in enumerate((:linear, :log))
        @series begin
            title --> string(scale, " scale")
            seriestype := :path
            subplot := i
            yscale := scale
        end
    end
end
```
We can call it with `plot(...; ..., seriestype = :yscaleplot)` or we can define a shorthand with the [`@shorthands`](@ref) macro.
```julia
@shorthands myseries
```
expands to
```julia
export myseries, myseries!
myseries(args...; kw...) = plot(args...; kw..., seriestype = :myseries)
myseries!(args...; kw...) = plot!(args...; kw..., seriestype = :myseries)
```
So let's try the `yscaleplot` plot recipe.
```@example types
@shorthands yscaleplot

yscaleplot((1:10).^2)
```
Magically the composition with type recipes works again.
```@example types
yscaleplot(MyWrapper(times), MyOtherWrapper((1:24).^2))
```
## Series Recipes
Series recipes are applied recursively until the current backend supports a series type. They are used for example to convert the input data of a bar plot to the coordinates of the shapes that define the bars.
```julia
@recipe function f(::Type{Val{:myseriesrecipename}}, x, y, z; ...)
```

If we want to call the `userpie` recipe with a custom type we run into errors.
```julia
userpie(MyWrapper(rand(4)))
```
```julia
ERROR: MethodError: no method matching keys(::MyWrapper)
Stacktrace:
 [1] eachindex(::MyWrapper) at ./abstractarray.jl:209
```
Furthermore, if we want to show multiple pie charts in different subplots, we don't get what we expect either
```@example types
userpie(rand(4, 2), layout = 2)
```
We could overcome these issues by implementing the required `AbstractArray` methods for `MyWrapper` (instead of the type recipe) and by more carefully dealing with different series in the `userpie` recipe.
However, the simpler approach is writing the pie recipe as a series recipe and relying on Plots' processing pipeline.
```@example types
@recipe function f(::Type{Val{:seriespie}}, x, y, z)
    framestyle --> :none
    aspect_ratio --> true
    s = sum(y)
    θ = 0
    for i in eachindex(y)
        θ_new = θ + 2π * y[i] / s
        coords = [(0.0, 0.0); Plots.partialcircle(θ, θ_new, 50)]
        @series begin
            seriestype := :shape
            label --> string(x[i])
            x := first.(coords)
            y := last.(coords)
        end
        θ = θ_new
    end
end
@shorthands seriespie
```
Here we use the already processed values `x` and `y` to calculate the shape coordinates for each pie piece, update `x` and `y` with these coordinates and set the series type to `:shape`.
```@example types
seriespie(rand(4))
```
This automatically works together with type recipes ...
```@example types
seriespie(MyWrapper(rand(4)))
```
... or with layouts
```@example types
seriespie(rand(4, 2), layout = 2)
```

## Remarks

Plot recipes and series recipes are actually very similar.
In fact, a pie recipe could be also implemented as a plot recipe by acessing the data through `plotattributes`.

```@example types
@recipe function f(::Type{Val{:plotpie}}, plt::AbstractPlot)
    y = plotattributes[:y]
    labels = plotattributes[:x]
    framestyle --> :none
    aspect_ratio --> true
    s = sum(y)
    θ = 0
    for i in 1:length(y)
        θ_new = θ + 2π * y[i] / s
        coords = [(0.0, 0.0); Plots.partialcircle(θ, θ_new, 50)]
        @series begin
            seriestype := :shape
            label --> string(labels[i])
            x := first.(coords)
            y := last.(coords)
        end
        θ = θ_new
    end
end
@shorthands plotpie

plotpie(rand(4, 2), layout = (1, 2))
```
The series recipe syntax is just a little nicer in this case.

!!! info
    Here's subtle difference between these recipe types:
    Plot recipes are applied in any case while series are only applied if the backend does not support the series type natively.

Let's try it the other way around and implement our `yscaleplot` recipe as a series recipe.

```@example types
@recipe function f(::Type{Val{:yscaleseries}}, x, y, z)
    layout := (1, 2)
    for (i, scale) in enumerate((:linear, :log))
        @series begin
            title --> string(scale, " scale")
            seriestype := :path
            subplot := i
            yscale := scale
        end
    end
end
@shorthands yscaleseries
```
That looks a little nicer than the plot recipe version as well.
Let's try to plot.
```julia
yscaleseries((1:10).^2)
```
```julia
MethodError: Cannot `convert` an object of type Int64 to an object of type Plots.Subplot{Plots.GRBackend}
Closest candidates are:
  convert(::Type{T}, !Matched::T) where T at essentials.jl:168
  Plots.Subplot{Plots.GRBackend}(::Any, !Matched::Any, !Matched::Any, !Matched::Any, !Matched::Any, !Matched::Any, !Matched::Any, !Matched::Any) where T<:RecipesBase.AbstractBackend at /home/daniel/.julia/packages/Plots/rNwM4/src/types.jl:88
```

That is because the plot and subplots have already been built before the series recipe is applied.

!!! tip
    For everything that modifies plot-wide attributes plot recipes have to be used, otherwise series recipes are recommended.
