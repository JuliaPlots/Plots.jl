```@setup colors
using Plots; gr()
Plots.reset_defaults()
```

# Colorschemes

Plots supports all colorschemes from [ColorSchemes.jl](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes-1).
They can be used as a gradient or as a palette and are passed as a symbol holding their name to `cgrad` or `palette`.

```@example colors
plot(
    [x -> sin(x - a) for a in range(0, π / 2, length = 5)], 0, 2π;
    palette = :Dark2_5,
)
```

```@example colors
function f(x, y)
    r = sqrt(x^2 + y^2)
    return cos(r) / (1 + r)
end
x = range(0, 2π, length = 30)
heatmap(x, x, f, c = :thermal)
```

### ColorPalette

Plots chooses colors for series automatically from the palette passed to the `color_palette` attribute.
The attribute accepts symbols of colorscheme names or `ColorPalette` objects.
Color palettes can be constructed with `palette(cs, [n])` where `cs` can be a `Symbol`, a vector of colors, a `ColorScheme`, `ColorPalette` or `ColorGradient`.
The optional argument `n` decides how many colors to choose from `cs`.

```@example colors
palette(:tab10)
```

```@example colors
palette([:purple, :green], 7)
```

### ColorGradient

For `heatmap`, `surface`, `contour` or `line_z`, `marker_z` and `line_z` Plots.jl chooses colors from a `ColorGradient`.
If not specified, the default `ColorGradient` `:inferno` is used.
A different gradient can be selected by passing a symbol for a colorscheme name to the `seriescolor` attribute.
For more detailed configuration, the color attributes also accept a `ColorGradient` object.
Color gradients can be constructed with
```julia
cgrad(cs, [z], alpha = nothing, rev = false, scale = nothing, categorical = nothing)
```
where `cs` can be a `Symbol`, a vector of colors, a `ColorScheme`, `ColorPalette` or `ColorGradient`.

```@example colors
cgrad(:acton)
```
You can pass a vector of values between 0 and 1 as second argument to specify positions of color transitions.
```@example colors
cgrad([:orange, :blue], [0.1, 0.3, 0.8])
```
With `rev = true` the colorscheme colors are reversed.
```@example colors
cgrad(:thermal, rev = true)
```
Setting `categorical = true` returns a `CategoricalColorGradient` that only chooses from a discrete set of colors without interpolating continuously.
The optional second argument determines how many colors to choose from the colorscheme.
They are distributed uniformly along the colorscheme colors.
```@example colors
cgrad(:matter, 5, categorical = true)
```
Categorical gradients also accept a vector for positions of color transitions and can be reversed.
```@example colors
cgrad(:matter, [0.1, 0.3, 0.8], rev = true, categorical = true)
```
The distribution of color selection can be scaled with the `scale` keyword argument which accepts `:log`, `:log10`, `:ln`, `:log2`, `:exp` or a function to be applied on the color position values between 0 and 1.
```@example colors
cgrad(:roma, scale = :log)
```
Categorical gradients can also be scaled.
```@example colors
cgrad(:roma, 10, categorical = true, scale = :exp)
```

# Pre-defined ColorSchemes
