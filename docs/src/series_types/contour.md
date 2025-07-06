```@setup contour
using Plots
Plots.reset_defaults()
```

# [Contour Plots](@id contour)

The easiest way to get started with contour plots is to use the PythonPlot backend. PythonPlot requires the `PythonPlot.jl`
package which can be installed by typing `]` and then `add PythonPlot` into the REPL. The first time you call `pythonplot()`,
Julia may install matplotlib for you. All of the plots generated on this page use PythonPlot, although the code will work
for the default GR backend as well.

Let's define some ranges and a function `f(x, y)` to plot. Notice the `'` in the line defining `z`.
This is the adjoint operator and makes `x` a row vector. You can check the shape of `x'` by typing `size(x')`. In the
tutorial, we mentioned that the `@.` macro evaluates whatever is to the right of it in an element-wise manner. More
precisely, the dot `.` is shorthand for broadcasting; since `x'` is of size `(1, 100)` and y is of size `(50, )`,
`z = @. f(x', y)` will broadcast the function `f` over `x'` and `y` and yield a matrix of size `(50, 100)`.

```@example contour
using Plots; pythonplot()

f(x, y) = (3x + y^2) * abs(sin(x) + cos(y))

x = range(0, 5, length=100)
y = range(0, 3, length=50)
z = @. f(x', y)
contour(x, y, z)
```

Much like with `plot!` and `scatter!`, the `contour` function also has a mutating version `contour!` which can be
used to modify the plot after it has been generated.

With the `pythonplot` backend, `contour` can also take in a row vector for `x`, so alternatively, you can define `x` as
a row vector as shown below and PythonPlot will know how to plot it correctly. Beware that this will NOT work for other
backends such as the default GR backend, which require `x` and `y` to both be column vectors.

```julia
x = range(0, 5, length=100)'
y = range(0, 3, length=50)
z = @. f(x, y)
contour(x, y, z)
```

## Common Attributes

Let's make this plot more presentable with the following attributes:

1. The number of levels can be changed with `levels`.
2. Besides the title and axes labels, we can also add contour labels via the attribute `contour_labels`, which has the alias `clabels`. We'll use the LaTeXStrings.jl package to write the function expression in the title. (To install this package, type `]` and then `add LaTeXStrings` into the REPL.)
3. The colormap can be changed using `seriescolor`, which has the alias `color`, or even `c`. The default colormap is `:inferno`, from matplotlib. A full list of colormaps can be found in the ColorSchemes section of the manual.
4. The colorbar location can be changed with the attribute `colorbar`, alias `cbar`. We can remove it by setting `cbar=false`.
5. The widths of the isocontours can be changed using `linewidth`, or `lw`.

Note that `levels`, `color`, and `contour_labels` need to be specified in `contour`.

```@example contour
using LaTeXStrings

f(x, y) = (3x + y^2) * abs(sin(x) + cos(y))

x = range(0, 5, length=100)
y = range(0, 3, length=50)
z = @. f(x', y)

contour(x, y, z, levels=10, color=:turbo, clabels=true, cbar=false, lw=1)
title!(L"Plot of $(3x + y^2)|\sin(x) + \cos(y)|$")
xlabel!(L"x")
ylabel!(L"y")
```

If only black lines are desired, you can set the `color` attribute like so:

```julia
contour(x, y, z, color=[:black])
```

and for alternating black and red lines of a specific hex value, you could type `color=[:black, "#E52B50"]`, and so on.

To get a full list of the available values that an attribute can take, type `plotattr("attribute")` into the REPL. For
example, `plotattr("cbar")` shows that it can take either symbols from a predefined list (e.g. `:left` and `:top`),
which move the colorbar from its default location; or a boolean `true` or `false`, the latter of which hides the
colorbar.

## Filled Contours

We can also specify that the contours should be filled in. One way to do this is by using the attribute `fill`:

```julia
contour(x, y, z, fill=true)
```

Another way is to use the function `contourf`, along with its mutating version `contourf!`:

```@example contour
contourf(x, y, z, levels=20, color=:turbo)
title!(L"(3x + y^2)|\sin(x) + \cos(y)|")
xlabel!(L"x")
ylabel!(L"y")
```

If you are using the GR backend to plot filled contours, there will be black lines separating the filled regions. If
these lines are undesirable, you can set the line width to 0: `lw=0`.

## Logarithmic Contour Plots

Much like with line and scatter plots, the X and Y axes can be made logarithmic through the `xscale` and `yscale`
attributes. If both axes need to be logarithmic, then you can set `scale=:log10`.

It will be easier for the backend to generate the plot if the attributes are specified in the `contourf` command
directly instead of using their mutating versions.

```@example contour
g(x, y) = log(x*y)

x = 10 .^ range(0, 6, length=100)
y = 10 .^ range(0, 6, length=100)
z = @. g(x', y)
contourf(x, y, z, color=:plasma, scale=:log10,
    title=L"\log(xy)", xlabel=L"x", ylabel=L"y")
```

It is often desired that the colorbar be logarithmic. The process to get this working correctly is a bit more involved
and will require some manual tweaking. First, we define a function `h(x, y) = exp(x^2 + y^2)`, which we will plot the
logarithm of. Then we adjust the `levels` and `colorbar_ticks` attributes.

The `colorbar_ticks` attribute can take in a tuple of two vectors `(tickvalues, ticklabels)`. Since `h(x, y)` varies
from `10^0` to `10^8` over the prescribed domain, tickvalues will be a vector `tv = 0:8`. We can format
the labels with superscripts by using LaTeXStrings again. Note that the string interpolation operator changes from `$`
to `%$` when working within `L"..."` to avoid clashing with `$` as normally used in LaTeX.

```@example contour
h(x, y) = exp(x^2 + y^2)

x = range(-3, 3, length=100)
y = range(-3, 3, length=100)
z = @. h(x', y)

tv = 0:8
tl = [L"10^{%$i}" for i in tv]
contourf(x, y, log10.(z), color=:turbo, levels=8,
    colorbar_ticks=(tv, tl), aspect_ratio=:equal,
    title=L"\exp(x^{2} + y^{2})", xlabel=L"x", ylabel=L"y")
```

If you want the fill boundaries to correspond to the orders of magnitude, `levels=8`. Depending on the data, this
number may require some tweaking. If you want a smoother plot, then you can set `levels` to a much larger number.
