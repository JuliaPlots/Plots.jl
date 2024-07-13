```@setup syntax
using Plots, Random
Random.seed!(100)
default(legend = :topleft, markerstrokecolor = :auto, markersize = 6)
```

# Recipes Syntax

The syntax in the [`@recipe`](@ref) macro is best explained using an example.
Suppose, we have a custom type storing the results of a simulation `x` and `y` and a measure `ε` for the maximum error in `y`.

```@example syntax
struct Result
    x::Vector{Float64}
    y::Vector{Float64}
    ε::Vector{Float64}
end
```

If we want to plot the `x` and `y` values of such a result with an error band given by `ε`, we could run something like
```@example syntax
res = Result(1:10, cumsum(rand(10)), cumsum(rand(10)) / 5)

using Plots

# plot the error band as invisible line with fillrange
plot(
    res.x,
    res.y .+ res.ε,
    xlabel = "x",
    ylabel = "y",
    fill = (res.y .- res.ε, :lightgray, 0.5),
    linecolor = nothing,
    primary = false, # no legend entry
)

# add the data to the plots
plot!(res.x, res.y, marker = :diamond)
```

Instead of typing this plot command over and over for different results we can define a **user recipe** to tell Plots what to do with input of the type `Result`.
Here is an example for such a user recipe with the additional feature to highlight datapoints with a maximal error above a certain threshold `ε_max`.

```@example syntax
@recipe function f(r::Result; ε_max = 0.5)
    # set a default value for an attribute with `-->`
    xlabel --> "x"
    yguide --> "y"
    markershape --> :diamond
    # add a series for an error band
    @series begin
        # force an argument with `:=`
        seriestype := :path
        # ignore series in legend and color cycling
        primary := false
        linecolor := nothing
        fillcolor := :lightgray
        fillalpha := 0.5
        fillrange := r.y .- r.ε
        # ensure no markers are shown for the error band
        markershape := :none
        # return series data
        r.x, r.y .+ r.ε
    end
    # get the seriescolor passed by the user
    c = get(plotattributes, :seriescolor, :auto)
    # highlight big errors, otherwise use the user-defined color
    markercolor := ifelse.(r.ε .> ε_max, :red, c)
    # return data
    r.x, r.y
end
```

Let's walk through this recipe step by step.
First, the function signature in the recipe definition determines the recipe type, in this case a user recipe.
The function name `f` in is irrelevant and can be replaced by any other function name.
[`@recipe`](@ref) does not use it.
In the recipe body we can set default values for [Plots attributes](https://docs.juliaplots.org/latest/attributes/).
```
attr --> val
```
This will set `attr` to `val` unless it is specified otherwise by the user in the plot command.
```
plot(args...; kw..., attr = otherval)
```
Similarly we can force an attribute value with `:=`.
```
attr := val
```
This overwrites whatever the user passed to `plot` for `attr` and sets it to `val`.
!!! tip
    It is strongly recommended to avoid using attribute aliases in recipes as this might lead to unexpected behavior in some cases.
    In the recipe above `xlabel` is used as aliases for `xguide`.
    When the recipe is used Plots will show a warning and hint to the default attribute name.
    They can also be found in the attribute tables under https://docs.juliaplots.org/latest/attributes/.

We use the [`@series`](@ref) macro to add a new series for the error band to the plot.
Within an [`@series`](@ref) block we can use the same syntax as above to force or set default values for attributes.

In [`@recipe`](@ref) we have access to `plotattributes`. This is an `AbstractDict` storing the attributes that have been already processed at the current stage in the Plots pipeline.
For user recipes, which are called early in the pipeline, this mostly contains the keyword arguments provided by the user in the `plot` command.
In our example we want to highlight data points with an error above a certain threshold by changing the marker color.
For all other data points we set the marker color to whatever is the default or has been provided as keyword argument.
We can do this by getting the `seriescolor` from `plotattributes` and defaulting to `auto` if it has not been specified by the user.

Finally, in both, [`@recipe`](@ref)s and [`@series`](@ref) blocks we return the data we wish to pass on to Plots (or the next recipe).

!!! compat
    With RecipesBase 1.0 the `return` statement is allowed in [`@recipe`](@ref) and [`@series`](@ref).

With the recipe above we can now plot `Result`s with just

```@example syntax
plot(res)
```

or

```@example syntax
scatter(res, ε_max = 0.7, color = :green, marker = :star)
```
