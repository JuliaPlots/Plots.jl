## Colors

There are many color attributes, for lines, fills, markers, backgrounds, and foregrounds.  Many colors follow a hierarchy... `linecolor` gets its value from `seriescolor`, for example, unless you override the value.  This allows for you to simply set precisely what you want, without lots of boilerplate.

Color attributes will accept many different types:

- `Symbol`s or `String`s will be passed to `Colors.parse(Colorant, c)`, so `:red` is equivalent to `colorant"red"`
- `false` or `nothing` will be converted to an invisible `RGBA(0,0,0,0)`
- Any `Colors.Colorant`, with or without alpha/opacity
- Any `Plots.ColorScheme`, which includes `ColorVector`, `ColorGradient`, etc
- An integer, which picks the corresponding color from the `seriescolor`

In addition, there is an extensive facility for selecting and generating color maps/gradients.

- A valid Symbol: `:inferno` (the default), `:heat`, `:blues`, etc
- A list of colors (or anything that can be converted to a color)
- A pre-built `ColorGradient`, which can be constructed with the `cgrad` helper function.  See [this short tutorial](https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/cgrad.ipynb) for example usage.

### Color names
The supported color names is the union of [X11's](https://en.wikipedia.org/wiki/X11_color_names) and SVG's.
They are defined in the [Colors.jl](https://github.com/JuliaGraphics/Colors.jl/blob/master/src/names_data.jl)
,like `blue`, `blue2`, `blue3`, ...etc.

---

#### Series Colors

For series, there are a few attributes to know:

- **seriescolor**: Not used directly, but defines the base color for the series
- **linecolor**: Color of paths
- **fillcolor**: Color of area fill
- **markercolor**: Color of the interior of markers and shapes
- **markerstrokecolor**: Color of the border/stroke of markers and shapes

`seriescolor` defaults to `:auto`, and gets assigned a color from the `color_palette` based on its index in the subplot.  By default, the other colors `:match`.  (See the table below)

!!! tip
    In general, color gradients can be set by `*color`, and the corresponding color values to look up in the gradients by `*_z`.

This color... | matches this color...
--- | ---
linecolor | seriescolor
fillcolor | seriescolor
markercolor | seriescolor
markerstrokecolor | foreground_color_subplot

!!! note
    each of these attributes have a corresponding alpha override: `seriesalpha`, `linealpha`, `fillalpha`, `markeralpha`, and `markerstrokealpha`.  They are optional, and you can still give alpha information as part of an `Colors.RGBA`.

!!! note
    In some contexts, and when the user hasn't set a value, the `linecolor` or `markerstrokecolor` may be overridden.

---

#### Foreground/Background

Foreground and background colors work similarly:


This color... | matches this color...
--- | ---
background\_color\_outside | background\_color
background\_color\_subplot | background\_color
background\_color\_legend  | background\_color\_subplot
background\_color\_inside  | background\_color\_subplot
foreground\_color\_subplot | foreground\_color
foreground\_color\_legend  | foreground\_color\_subplot
foreground\_color\_grid    | foreground\_color\_subplot
foreground\_color\_title   | foreground\_color\_subplot
foreground\_color\_axis    | foreground\_color\_subplot
foreground\_color\_border  | foreground\_color\_subplot
foreground\_color\_guide   | foreground\_color\_subplot
foreground\_color\_text    | foreground\_color\_subplot


---

#### Misc

- the `linecolor` under the default theme is not CSS-defined, but close to `:steelblue`.
- `line_z` and `marker_z` parameters will map data values into a `ColorGradient` value
- `color_palette` determines the colors assigned when `seriescolor == :auto`:
    - If passed a vector of colors, it will force cycling of those colors
    - If passed a gradient, it will infinitely draw unique colors from that gradient, attempting to spread them out
