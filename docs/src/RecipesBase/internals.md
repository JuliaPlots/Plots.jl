## RecipesBase

The [`@recipe`](@ref) macro defines a new method for `RecipesBase.apply_recipe`.
```julia
@recipe function f(args...; kwargs...)
```
defines
```julia
RecipesBase.apply_recipe(plotattributes, args...; kwargs...)
```
returning a `Vector{RecipeData}` where `RecipeData` holds the `plotattributes` Dict and the arguments returned in [`@recipe`](@ref) or in [`@series`](@ref).
```julia
struct RecipeData
    plotattributes::AbstractDict{Symbol,Any}
    args::Tuple
end
```
This function sets and overwrites entries in `plotattributes` and possibly adds new series.
- `attr --> val` translates to `haskey(plotattributes, :attr) || plotattributes[:attr] = val`
- `attr := val` sets `plotattributes[:attr] = val`.
- [`@series`](@ref) allows to add new series within [`@recipe`](@ref). It copies `plotattributes` from [`@recipe`](@ref), applies the replacements defined in its code block and returns corresponding new `RecipeData` object.
    !!! info
        [`@series`](@ref) have to be defined as a code block with `begin` and `end` statements.
        ```julia
        @series begin
            ...
        end
        ```

So `RecipesBase.apply_recipe(plotattributes, args...; kwargs...)` returns a `Vector{RecipeData}`.
Plots can then recursively apply it again on the `plotattributes` and `args` of the elements of this vector, dispatching on a different signature.


## Plots

The standard plotting commands
```julia
plot(args...; plotattributes...)
plot!(args...; plotattributes...)
```
and shorthands like `scatter` or `bar` call the core internal plotting function `Plots._plot!`.
```julia
Plots._plot!(plt::Plot, plotattributes::AbstractDict{Symbol, Any}, args::Tuple)
```

In the following we will go through the major steps of the preprocessing pipeline implemented in `Plots._plot!`.

#### Preprocess `plotattributes`
Before `Plots._plot!` is called and after each recipe is applied, `preprocessArgs!`  preprocesses the `plotattributes` Dict.
It replaces aliases, expands magic arguments, and converts some attribute types.
- `lc = nothing` is replaced by `linecolor = RGBA(0, 0, 0, 0)`.
- `marker = (:red, :circle, 8)` expands to `markercolor = :red`, `markershape = :circle` and `markersize = 8`.

#### Process User Recipes

In the first step, `_process_userrecipe` is called.

```julia
kw_list = _process_userrecipes(plt, plotattributes, args)
```
It converts the user-provided `plotattributes` to a vector of `RecipeData`.
It recursively applies `RecipesBase.apply_recipe` on the fields of the first element of the `RecipeData` vector and prepends the resulting `RecipeData` vector to it.
If the `args` of an element are empty, it extracts `plotattributes` and adds it to a Vector of Dicts `kw_list`.
When all `RecipeData` elements are fully processed, `kw_list` is returned.

#### Process Type Recipes

After user recipes are processed, at some point in the recursion above args is of the form `(y, )`, `(x, y)` or `(x, y, z)`.
Plots defines recipes for these signatures.
The two argument version, for example, looks like this.

```julia
@recipe function f(x, y)
    did_replace = false
    newx = _apply_type_recipe(plotattributes, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(plotattributes, y)
    y === newy || (did_replace = true)
    if did_replace
        newx, newy
    else
        SliceIt, x, y, nothing
    end
end
```

It recursively calls `_apply_type_recipe` on each argument until none of the arguments is replaced.
`_apply_type_recipe` applies the type recipe with the corresponding signature and for vectors it tries to apply the recipe element-wise.
When no argument is changed by `_apply_type_recipe`, the fallback `SliceIt` recipe is applied, which adds the data to `plotattributes` and returns `RecipeData` with empty args.

#### Process Plot Recipes

At this stage all arguments have been processed to something Plots supports.
In `_plot!` we have a `Vector{Dict}` `kw_list` with an entry for each series and already populated `:x`, `:y` and `:z` keys.
Now `_process_plotrecipe` is called until all plot recipes are processed.

```julia
still_to_process = kw_list
kw_list = KW[]
while !isempty(still_to_process)
    next_kw = popfirst!(still_to_process)
    _process_plotrecipe(plt, next_kw, kw_list, still_to_process)
end
```

If no series type is set in the Dict, `_process_plotrecipe` pushes it to `kw_list` and returns.
Otherwise it tries to call `RecipesBase.apply_recipe` with the plot recipe signature.
If there is a method for this signature and the seriestype has changed by applying the recipe, the new `plotattributes` are appended to `still_to_process`.
If there is no method for the current plot recipe signature, we append the current Dict to `kw_list` and rely on series recipe processing.

After all plot recipes have been applied, the plot and subplots are set-up.
```julia
_plot_setup(plt, plotattributes, kw_list)
_subplot_setup(plt, plotattributes, kw_list)
```

#### Process Series Recipes

We are almost finished.
Now the series defaults are populated and `_process_seriesrecipe` is called for each series .

```julia
for kw in kw_list
    # merge defaults
    series_attr = Attr(kw, _series_defaults)
    _process_seriesrecipe(plt, series_attr)
end
```

If the series type is natively supported by the backend, we finalize processing and pass the series along to the backend.
Otherwise, the series recipe for the current series type is applied and `_process_seriesrecipe` is called again for the `plotattributes` in each returned `RecipeData` object.
Here we have to check again that the series type changed.
Due to this recursive processing, complex series types can be built up by simple blocks.
For example if we add an `@show st` in `_process_seriesrecipe` and plot a histogram, we go through the following series types:

```julia
plot(histogram(randn(1000)))
```
```julia
st = :histogram
st = :barhist
st = :barbins
st = :bar
st = :shape
```
```@example
using Plots # hide
plot(histogram(randn(1000))) #hide
```
