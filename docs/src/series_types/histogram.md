```@setup histogram
using Plots; gr()
Plots.reset_defaults()
```

# [Histograms](@id histogram)

One-dimensional histograms are accessed through the function `histogram` and its mutating variant `histogram!`. We
will use the default GR backend on this page.

The most basic plot of a histogram is that of a vector of random numbers sampled from the unit normal distribution.

```@example histogram
using Plots

x = randn(10^3)
histogram(x)
```

The default number of bins is determined by the
[Freedman-Diaconis rule](https://en.wikipedia.org/wiki/Histogram#Freedman%E2%80%93Diaconis'_choice). You can select
other bin algorithms using the attribute `bins`, which can take on values like `:sqrt`, or `:scott` for
[Scott's rule](https://en.wikipedia.org/wiki/Histogram#Scott's_normal_reference_rule). Alternatively, you can pass
in a range to more precisely control the number of bins and their minimum and maximum. For example, to plot 20 bins
from -5 to +5, type

```julia
range(-5, 5, length=21)
```

where we have to add 1 to the length because the length counts the number of bin boundaries. Finally, you can also pass
in an integer, like `bins=15`, but this will only be an approximation and the actual number of bins may vary.

## Normalization

It is often desirable to normalize the histogram in some way. To do this, the `normalize` attribute is used, and
we want `normalize=:pdf` (or `:true`) to normalize the total area of the bins to 1. Since we sampled from the normal
distribution, we may as well plot it too. Of course, other common attributes like the title, axis labels, and colors
can be changed as well.

```@example histogram
p(x) = 1/sqrt(2pi) * exp(-x^2/2)
b_range = range(-5, 5, length=21)

histogram(x, label="Experimental", bins=b_range, normalize=:pdf, color=:gray)
plot!(p, label="Analytical", lw=3, color=:red)
xlims!(-5, 5)
ylims!(0, 0.4)
title!("Normal distribution, 1000 samples")
xlabel!("x")
ylabel!("P(x)")
```

`normalize` can take on other values, including:

* `:probability`, which sums all the bin heights to 1
* `:density`, which makes the area of each bin equal to the counts

## Weighted Histograms

Another common feature is to weight the values in `x`. Say that `x` consists of data sampled from a uniform
distribution and we wanted to weight the values according to an exponential function. We would pass in a vector of
weights of the same length as `x`. To check that the weighting is done correctly, we plot the exponential function
multiplied by a normalization factor.

```@example histogram
f_exp(x) = exp(x)/(exp(1)-1)

x = rand(10^4)
w = exp.(x)

histogram(x, label="Experimental", bins=:scott, weights=w, normalize=:pdf, color=:gray)
plot!(f_exp, label="Analytical", lw=3, color=:red)
plot!(legend=:topleft)
xlims!(0, 1.0)
ylims!(0, 1.6)
title!("Uniform distribution, weighted by exp(x)")
xlabel!("x")
ylabel!("P(x)")
```

## Other Variations

* Histogram scatter plots can be made via `scatterhist` and `scatterhist!`, where points substitute in for bars.
* Histogram step plots can be made via `stephist` and `stephist!`, where an outline substitutes in for bars.

```@example histogram
p1 = histogram(x, title="Bar")
p2 = scatterhist(x, title="Scatter")
p3 = stephist(x, title="Step")
plot(p1, p2, p3, layout=(1, 3), legend=false)
```

Note that the Y axis of the histogram scatter plot will not start from 0 by default.

## 2D Histograms

Two-dimensional histograms are accessed through the function `histogram2d` and its mutating variant `histogram2d!`.
To plot them, two vectors `x` and `y` of the same length are needed.

The histogram is plotted in 2D as a heatmap instead of as 3D bars. The default colormap is `:inferno`, as with contour
plots and heatmaps. Bins without any count are not plotted at all by default.

```@example histogram
x = randn(10^4)
y = randn(10^4)
histogram2d(x, y)
```

Things like custom bin numbers, weights, and normalization work in 2D, along with changing things like the
colormap. However, the bin numbers need to be passed in via tuples; if only one number is passed in for
the bins, for example, it is assumed that both axes will set the same number of bins. Additionally, the weights
only accept a single vector for the `x` values.

Not plotting the bins at all may not be visually appealing, especially if a colormap is used with dark colors on the
low end. To rectify this, use the attribute `show_empty_bins=true`.

```@example histogram
w = exp.(x)
histogram2d(x, y, bins=(40, 20), show_empty_bins=true,
    normalize=:pdf, weights=w, color=:plasma)
title!("Normalized 2D Histogram")
xlabel!("x")
ylabel!("y")
```
