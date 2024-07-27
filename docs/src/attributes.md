
# [Attributes](@id attributes)

```@setup attr
using Plots
```

### Introduction to Attributes

In Plots, input data is passed positionally (for example, the `y` in `plot(y)`), and attributes are passed as keywords (for example, `plot(y, color = :blue)`).
Most of the information on this page is available from your Julia REPL.
After one executes, `using Plots` in the REPL, one can use the function `plotattr()` to print a list of all attributes for either series, plots, subplots, or axes.

```julia
# Valid Operations
plotattr(:Plot)
plotattr(:Series)
plotattr(:Subplot)
plotattr(:Axis)
```

Once you acquire the list of attributes, you can either use the aliases of a specific attribute or investigate a specific attribut to print that attribute's aliases and its description.

```@repl attr
# Specific Attribute Example
plotattr("size")
```

!!! note
    Do not forget to enclose the attribute you are attempting to use with double quotes!

---

### [Aliases](@id aliases)

Keywords can take a range of values through the **alias mechanic**.  For example, `plot(y, color = :blue)` is really interpreted as `plot(y, seriescolor = :blue)`.  Each attribute has a number of aliases (see the charts below), which are available to avoid the pain of constantly looking up plotting API documentation because you forgot the argument name.  `c`, `color`, and `seriescolor` all mean the same thing, and in fact those are eventually converted into the more precise attributes `linecolor`, `markercolor`, `markerstrokecolor`, and `fillcolor` (which you can then override if desired).


!!! tip
    Use aliases for one-off analysis and visualization, but use the true keyword name for long-lived library code to avoid confusion.

---

### [Magic Arguments](@id magic-arguments)


Some arguments encompass smart shorthands for setting many related arguments at the same time.  Plots uses type checking and multiple dispatch to smartly "figure out" which values apply to which argument.  Pass in a tuple of values.  Single values will be first wrapped in a tuple before processing.

##### axis (and xaxis/yaxis/zaxis)

Passing a tuple of settings to the `xaxis` argument will allow the quick definition
of `xlabel`, `xlims`, `xticks`, `xscale`, `xflip`, and `xtickfont`.  The following are equivalent:

```julia
plot(y, xaxis = ("my label", (0,10), 0:0.5:10, :log, :flip, font(20, "Courier")))

plot(y,
    xlabel = "my label",
    xlims = (0,10),
    xticks = 0:0.5:10,
    xscale = :log,
    xflip = true,
    xtickfont = font(20, "Courier")
)
```

Note that `yaxis` and `zaxis` work similarly, and `axis` will apply to all.

Passing a tuple to `xticks` (and similarly to `yticks` and `zticks`) changes
the position of the ticks and the labels:

```julia
plot!(xticks = ([0:π:3*π;], ["0", "\\pi", "2\\pi"]))
yticks!([-1:1:1;], ["min", "zero", "max"])
```

##### line

Set attributes corresponding to a series line.  Aliases: `l`.  The following are equivalent:

```julia
plot(y, line = (:steppre, :dot, :arrow, 0.5, 4, :red))

plot(y,
    seriestype = :steppre,
    linestyle = :dot,
    arrow = :arrow,
    linealpha = 0.5,
    linewidth = 4,
    linecolor = :red
)
```

##### fill

Set attributes corresponding to a series fill area.  Aliases: `f`, `area`.  The following are equivalent:

```julia
plot(y, fill = (0, 0.5, :red))

plot(y,
    fillrange = 0,
    fillalpha = 0.5,
    fillcolor = :red
)
```

##### marker

Set attributes corresponding to a series marker.  Aliases: `m`, `mark`.  The following are equivalent:

```julia
scatter(y, marker = (:hexagon, 20, 0.6, :green, stroke(3, 0.2, :black, :dot)))

scatter(y,
    markershape = :hexagon,
    markersize = 20,
    markeralpha = 0.6,
    markercolor = :green,
    markerstrokewidth = 3,
    markerstrokealpha = 0.2,
    markerstrokecolor = :black,
    markerstrokestyle = :dot
)
```

### [Notable Arguments](@id notable-arguments)
This is a collection of some notable arguments that are not well-known:

```julia
scatter(y, thickness_scaling = 2)  # increases fontsizes and linewidth by factor 2
# good for presentations and posters
# If backend does not support this, use the function `scalefontsizes(2)` that scales
# the default fontsizes.


scatter(y, ticks=:native)  # Tells backends to calculate ticks by itself.
# Good idea if you use interactive backends where you perform mouse zooming

scatter(rand(100), smooth=true)  # Adds a regression line to your plots
```
