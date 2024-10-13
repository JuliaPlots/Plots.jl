# StatsPlots

[![Build Status](https://travis-ci.org/JuliaPlots/StatsPlots.jl.svg?branch=master)](https://travis-ci.org/JuliaPlots/StatsPlots.jl)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaplots.org/latest/generated/statsplots/)
[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://julialang.zulipchat.com/#narrow/stream/236493-plots)


### Original author: Thomas Breloff (@tbreloff), maintained by the JuliaPlots members

This package is a drop-in replacement for Plots.jl that contains many statistical recipes for concepts and types introduced in the JuliaStats organization.

- Types:
    - DataFrames
    - Distributions
- Recipes:
    - histogram/histogram2d
    - groupedhist
    - [boxplot](https://en.wikipedia.org/wiki/Box_plot)
    - [dotplot](https://en.wikipedia.org/wiki/Dot_plot_(statistics))
    - [violin](https://en.wikipedia.org/wiki/Violin_plot)
    - marginalhist
    - corrplot/cornerplot
    - [andrewsplot](https://en.wikipedia.org/wiki/Andrews_plot)
    - errorline ([ribbon](https://ggplot2.tidyverse.org/reference/geom_ribbon.html), [stick](https://www.mathworks.com/help/matlab/ref/errorbar.html), [plume](https://www.e-education.psu.edu/files/meteo410/file/Plume.pdf))
    - MDS plot
    - [qq-plot](https://en.wikipedia.org/wiki/Q%E2%80%93Q_plot)

It is thus slightly less lightweight, but has more functionality.


Initialize:

```julia
#]add StatsPlots # install the package if it isn't installed
using StatsPlots # no need for `using Plots` as that is reexported here
gr(size=(400,300))
```

Table-like data structures, including `DataFrames`, `IndexedTables`, `DataStreams`, etc... (see [here](https://github.com/davidanthoff/IterableTables.jl) for an exhaustive list), are supported thanks to the macro `@df` which allows passing columns as symbols. Those columns can then be manipulated inside the `plot` call, like normal `Arrays`:
```julia
using DataFrames, IndexedTables
df = DataFrame(a = 1:10, b = 10 .* rand(10), c = 10 .* rand(10))
@df df plot(:a, [:b :c], colour = [:red :blue])
@df df scatter(:a, :b, markersize = 4 .* log.(:c .+ 0.1))
t = table(1:10, rand(10), names = [:a, :b]) # IndexedTable
@df t scatter(2 .* :b)
```

Inside a `@df` macro call, the `cols` utility function can be used to refer to a range of columns:

```julia
@df df plot(:a, cols(2:3), colour = [:red :blue])
```

or to refer to a column whose symbol is represented by a variable:

```julia
s = :b
@df df plot(:a, cols(s))
```

`cols()` will refer to all columns of the data table.

In case of ambiguity, symbols not referring to `DataFrame` columns must be escaped by `^()`:
```julia
df[:red] = rand(10)
@df df plot(:a, [:b :c], colour = ^([:red :blue]))
```

The `@df` macro plays nicely with the new syntax of the [Query.jl](https://github.com/davidanthoff/Query.jl) data manipulation package (v0.8 and above), in that a plot command can be added at the end of a query pipeline, without having to explicitly collect the outcome of the query first:

```julia
using Query, StatsPlots
df |>
    @filter(_.a > 5) |>
    @map({_.b, d = _.c-10}) |>
    @df scatter(:b, :d)
```

The `@df` syntax is also compatible with the Plots.jl grouping machinery:

```julia
using RDatasets
school = RDatasets.dataset("mlmRev","Hsb82")
@df school density(:MAch, group = :Sx)
```

To group by more than one column, use a tuple of symbols:

```julia
@df school density(:MAch, group = (:Sx, :Sector), legend = :topleft)
```

![grouped](https://user-images.githubusercontent.com/6333339/35101563-eacf9be4-fc57-11e7-88d3-db5bb47b08ac.png)

To name the legend entries with custom or automatic names (i.e. `Sex = Male, Sector = Public`) use the curly bracket syntax `group = {Sex = :Sx, :Sector}`. Entries with `=` get the custom name you give, whereas entries without `=` take the name of the column.

---

The old syntax, passing the `DataFrame` as the first argument to the `plot` call is no longer supported.

---

## Visualizing a table interactively

A GUI based on the Interact package is available to create plots from a table interactively, using any of the recipes defined below. This small app can be deployed in a Jupyter lab / notebook, Juno plot pane, a Blink window or in the browser, see [here](http://juliagizmos.github.io/Interact.jl/latest/deploying/) for instructions.

```julia
import RDatasets
iris = RDatasets.dataset("datasets", "iris")
using StatsPlots, Interact
using Blink
w = Window()
body!(w, dataviewer(iris))
```

![dataviewer](https://user-images.githubusercontent.com/6333339/43359702-abd82d74-929e-11e8-8fc9-b589287f1c23.png)


## marginalhist with DataFrames

```julia
using RDatasets
iris = dataset("datasets","iris")
@df iris marginalhist(:PetalLength, :PetalWidth)
```

![marginalhist](https://user-images.githubusercontent.com/6333339/29869938-fbe08d02-8d7c-11e7-9409-ca47ee3aaf35.png)

---

## marginalscatter with DataFrames

```julia
using RDatasets
iris = dataset("datasets","iris")
@df iris marginalscatter(:PetalLength, :PetalWidth)
```

![marginalscatter](https://user-images.githubusercontent.com/12200202/92408723-3aa78e00-f0f3-11ea-8ddc-9517f0f58207.png)

---

## marginalkde

```julia
x = randn(1024)
y = randn(1024)
marginalkde(x, x+y)
```

![correlated-marg](https://user-images.githubusercontent.com/90048/96789354-04804e00-13c3-11eb-82d3-6130e8c9d48a.png)


* `levels=N` can be used to set the number of contour levels (default 10); levels are evenly-spaced in the cumulative probability mass.
* `clip=((-xl, xh), (-yl, yh))` (default `((-3, 3), (-3, 3))`) can be used to adjust the bounds of the plot.  Clip values are expressed as multiples of the `[0.16-0.5]` and `[0.5,0.84]` percentiles of the underlying 1D distributions (these would be 1-sigma ranges for a Gaussian).


## corrplot and cornerplot
This plot type shows the correlation among input variables. The marker color in scatter plots reveal the degree of correlation. Pass the desired colorgradient to `markercolor`. With the default gradient positive correlations are blue, neutral are yellow and negative are red. In the 2d-histograms the color gradient show the frequency of points in that bin (as usual controlled by `seriescolor`).

```julia
gr(size = (600, 500))
```
then
```julia
@df iris corrplot([:SepalLength :SepalWidth :PetalLength :PetalWidth], grid = false)
```
or also:
```julia
@df iris corrplot(cols(1:4), grid = false)
```

![corrplot](https://user-images.githubusercontent.com/8429802/51600111-8a771880-1f01-11e9-818f-6cbfc5efad74.png)


A correlation plot may also be produced from a matrix:

```julia
M = randn(1000,4)
M[:,2] .+= 0.8sqrt.(abs.(M[:,1])) .- 0.5M[:,3] .+ 5
M[:,3] .-= 0.7M[:,1].^2 .+ 2
corrplot(M, label = ["x$i" for i=1:4])
```

![](https://user-images.githubusercontent.com/8429802/51600126-91059000-1f01-11e9-9d37-f49bee5ff534.png)

```julia
cornerplot(M)
```

![](https://user-images.githubusercontent.com/8429802/51600133-96fb7100-1f01-11e9-9943-4a10f1ad2907.png)


```julia
cornerplot(M, compact=true)
```

![](https://user-images.githubusercontent.com/8429802/51600140-9bc02500-1f01-11e9-87e3-746ae4daccbb.png)

---

## boxplot, dotplot, and violin

```julia
import RDatasets
singers = RDatasets.dataset("lattice", "singer")
@df singers violin(string.(:VoicePart), :Height, linewidth=0)
@df singers boxplot!(string.(:VoicePart), :Height, fillalpha=0.75, linewidth=2)
@df singers dotplot!(string.(:VoicePart), :Height, marker=(:black, stroke(0)))
```

![violin](https://user-images.githubusercontent.com/16589944/98538614-506c3780-228b-11eb-881c-158c2f781798.png)

Asymmetric violin or dot plots can be created using the `side` keyword (`:both` - default,`:right` or `:left`), e.g.:

```julia
singers_moscow = deepcopy(singers)
singers_moscow[:Height] = singers_moscow[:Height] .+ 5
@df singers violin(string.(:VoicePart), :Height, side=:right, linewidth=0, label="Scala")
@df singers_moscow violin!(string.(:VoicePart), :Height, side=:left, linewidth=0, label="Moscow")
@df singers dotplot!(string.(:VoicePart), :Height, side=:right, marker=(:black,stroke(0)), label="")
@df singers_moscow dotplot!(string.(:VoicePart), :Height, side=:left, marker=(:black,stroke(0)), label="")
```

Dot plots can spread their dots over the full width of their column `mode = :uniform`, or restricted to the kernel density
(i.e. width of violin plot) with `mode = :density` (default). Horizontal position is random, so dots are repositioned
each time the plot is recreated. `mode = :none` keeps the dots along the center.


![violin2](https://user-images.githubusercontent.com/16589944/98538618-52ce9180-228b-11eb-83d2-6d7b7c89fd52.png)

---

## Equal-area histograms

The ea-histogram is an alternative histogram implementation, where every 'box' in
the histogram contains the same number of sample points and all boxes have the same
area. Areas with a higher density of points thus get higher boxes. This type of
histogram shows spikes well, but may oversmooth in the tails. The y axis is not
intuitively interpretable.

```julia
a = [randn(100); randn(100) .+ 3; randn(100) ./ 2 .+ 3]
ea_histogram(a, bins = :scott, fillalpha = 0.4)
```

![equal area histogram](https://user-images.githubusercontent.com/8429802/29754490-8d1b01f6-8b86-11e7-9f86-e1063a88dfd8.png)

---

## AndrewsPlot

AndrewsPlots are a way to visualize structure in high-dimensional data by depicting each
row of an array or table as a line that varies with the values in columns.
https://en.wikipedia.org/wiki/Andrews_plot

```julia
using RDatasets
iris = dataset("datasets", "iris")
@df iris andrewsplot(:Species, cols(1:4), legend = :topleft)
```

![iris_andrews_curve](https://user-images.githubusercontent.com/1159782/46241166-c392e800-c368-11e8-93de-125c6eb38b52.png)

---

## ErrorLine
The ErrorLine function shows error distributions for lines plots in a variety of styles.

```julia
x = 1:10
y = fill(NaN, 10, 100, 3)
for i = axes(y,3)
    y[:,:,i] = collect(1:2:20) .+ rand(10,100).*5 .* collect(1:2:20) .+ rand()*100
end

errorline(1:10, y[:,:,1], errorstyle=:ribbon, label="Ribbon")
errorline!(1:10, y[:,:,2], errorstyle=:stick, label="Stick", secondarycolor=:matched)
errorline!(1:10, y[:,:,3], errorstyle=:plume, label="Plume")
```

![ErrorLine Styles](https://user-images.githubusercontent.com/24966610/186655231-2b7b9e37-0beb-4796-ad08-cbb84020ffd8.svg)

---

## Distributions

```julia
using Distributions
plot(Normal(3,5), fill=(0, .5,:orange))
```

![](https://cloud.githubusercontent.com/assets/933338/16718702/561510f6-46f0-11e6-834a-3cf17a5b77d6.png)

```julia
dist = Gamma(2)
scatter(dist, leg=false)
bar!(dist, func=cdf, alpha=0.3)
```

![](https://cloud.githubusercontent.com/assets/933338/16718720/729b6fea-46f0-11e6-9bff-fdf2541ce305.png)

### Quantile-Quantile plots

The `qqplot` function compares the quantiles of two distributions, and accepts either a vector of sample values or a `Distribution`. The `qqnorm` is a shorthand for comparing a distribution to the normal distribution. If the distributions are similar the points will be on a straight line.

```julia
x = rand(Normal(), 100)
y = rand(Cauchy(), 100)

plot(
 qqplot(x, y, qqline = :fit), # qqplot of two samples, show a fitted regression line
 qqplot(Cauchy, y),           # compare with a Cauchy distribution fitted to y; pass an instance (e.g. Normal(0,1)) to compare with a specific distribution
 qqnorm(x, qqline = :R)       # the :R default line passes through the 1st and 3rd quartiles of the distribution
)
```
![skaermbillede 2017-09-28 kl 22 46 28](https://user-images.githubusercontent.com/8429802/30989741-0c4f9dac-a49f-11e7-98ff-028192a8d5b1.png)

## Grouped Bar plots

```julia
groupedbar(rand(10,3), bar_position = :stack, bar_width=0.7)
```

![tmp](https://cloud.githubusercontent.com/assets/933338/18962081/58a2a5e0-863d-11e6-8638-94f88ecc544d.png)

This is the default:

```julia
groupedbar(rand(10,3), bar_position = :dodge, bar_width=0.7)
```

![tmp](https://cloud.githubusercontent.com/assets/933338/18962092/673f6c78-863d-11e6-9ee9-8ca104e5d2a3.png)

The `group` syntax is also possible in combination with `groupedbar`:

```julia
ctg = repeat(["Category 1", "Category 2"], inner = 5)
nam = repeat("G" .* string.(1:5), outer = 2)

groupedbar(nam, rand(5, 2), group = ctg, xlabel = "Groups", ylabel = "Scores",
        title = "Scores by group and category", bar_width = 0.67,
        lw = 0, framestyle = :box)
```

![](https://user-images.githubusercontent.com/6645258/32116755-b7018f02-bb2a-11e7-82c7-ca471ecaeecf.png)

## Grouped Histograms

```
using RDatasets
iris = dataset("datasets", "iris")
@df iris groupedhist(:SepalLength, group = :Species, bar_position = :dodge)
```
![dodge](https://user-images.githubusercontent.com/6033297/77240750-a11d0c00-6ba6-11ea-9715-81a8a7e20cd6.png)

```
@df iris groupedhist(:SepalLength, group = :Species, bar_position = :stack)
```
![stack](https://user-images.githubusercontent.com/6033297/77240749-9c585800-6ba6-11ea-85ea-e023341cb246.png)

## Dendrograms

```julia
using Clustering
D = rand(10, 10)
D += D'
hc = hclust(D, linkage=:single)
plot(hc)
```

![dendrogram](https://user-images.githubusercontent.com/381464/43355211-855d5aa2-920d-11e8-82d7-2bf1a7aeccb5.png)

The `branchorder=:optimal` option in `hclust()` can be used to minimize
the distance between neighboring leaves:

```julia
using Clustering
using Distances
using StatsPlots
using Random

n = 40

mat = zeros(Int, n, n)
# create banded matrix
for i in 1:n
    last = minimum([i+Int(floor(n/5)), n])
    for j in i:last
        mat[i,j] = 1
    end
end

# randomize order
mat = mat[:, randperm(n)]
dm = pairwise(Euclidean(), mat, dims=2)

# normal ordering
hcl1 = hclust(dm, linkage=:average)
plot(
    plot(hcl1, xticks=false),
    heatmap(mat[:, hcl1.order], colorbar=false, xticks=(1:n, ["$i" for i in hcl1.order])),
    layout=grid(2,1, heights=[0.2,0.8])
    )
```

![heatmap dendrogram non-optimal](https://user-images.githubusercontent.com/3502975/59949267-a1824e00-9440-11e9-96dd-4628a8372ae2.png)

Compare to:

```julia
# optimal ordering
hcl2 = hclust(dm, linkage=:average, branchorder=:optimal)
plot(
    plot(hcl2, xticks=false),
    heatmap(mat[:, hcl2.order], colorbar=false, xticks=(1:n, ["$i" for i in hcl2.order])),
    layout=grid(2,1, heights=[0.2,0.8])
    )
```

![heatmap dendrogram optimal](https://user-images.githubusercontent.com/3502975/59949464-20778680-9441-11e9-8ed7-9a639b50dfb2.png)

### Dendrogram on the right side

```julia
using Distances
using Clustering
using StatsBase
using StatsPlots

pd=rand(Float64,16,7)

dist_col=pairwise(CorrDist(),pd,dims=2)
hc_col=hclust(dist_col, branchorder=:optimal)
dist_row=pairwise(CorrDist(),pd,dims=1)
hc_row=hclust(dist_row, branchorder=:optimal)

pdz=similar(pd)
for row in hc_row.order
	pdz[row,hc_col.order]=zscore(pd[row,hc_col.order])
end
nrows=length(hc_row.order)
rowlabels=(1:16)[hc_row.order]
ncols=length(hc_col.order)
collabels=(1:7)[hc_col.order]
l = grid(2,2,heights=[0.2,0.8,0.2,0.8],widths=[0.8,0.2,0.8,0.2])
plot(
	layout = l,
	plot(hc_col,xticks=false),
	plot(ticks=nothing,border=:none),
	plot(
		pdz[hc_row.order,hc_col.order],
		st=:heatmap,
		#yticks=(1:nrows,rowlabels),
		yticks=(1:nrows,rowlabels),
		xticks=(1:ncols,collabels),
		xrotation=90,
		colorbar=false
	),
	plot(hc_row,yticks=false,xrotation=90,orientation=:horizontal,xlim=(0,1))
)

```

![heatmap with dendrograms on top and on the right](https://user-images.githubusercontent.com/13688320/224165246-bb3aba7d-5df2-47b5-9678-3384d13610fd.png)


## GroupedErrors.jl for population analysis

Population analysis on a table-like data structures can be done using the highly recommended [GroupedErrors](https://github.com/piever/GroupedErrors.jl) package.

This external package, in combination with StatsPlots, greatly simplifies the creation of two types of plots:

### 1. Subject by subject plot (generally a scatter plot)

Some simple summary statistics are computed for each experimental subject (mean is default but any scalar valued function would do) and then plotted against some other summary statistics, potentially splitting by some categorical experimental variable.

### 2. Population plot (generally a ribbon plot in continuous case, or bar plot in discrete case)

Some statistical analysis is computed at the single subject level (for example the density/hazard/cumulative of some variable, or the expected value of a variable given another) and the analysis is summarized across subjects (taking for example mean and s.e.m), potentially splitting by some categorical experimental variable.


For more information please refer to the [README](https://github.com/piever/GroupedErrors.jl/blob/master/README.md).

A GUI based on QML and the GR Plots.jl backend to simplify the use of StatsPlots.jl and GroupedErrors.jl even further can be found [here](https://github.com/piever/PlugAndPlot.jl) (usable but still in alpha stage).

## Ordinations

MDS from [`MultivariateStats.jl`](https://github.com/JuliaStats/MultivariateStats.jl)
can be plotted as scatter plots.

```julia
using MultivariateStats, RDatasets, StatsPlots

iris = dataset("datasets", "iris")
X = convert(Matrix, iris[:, 1:4])
M = fit(MDS, X'; maxoutdim=2)

plot(M, group=iris.Species)
```

![MDS plot](https://user-images.githubusercontent.com/3502975/64883550-a6186600-d62d-11e9-8f6b-c5094abf5573.png)

PCA will be added once the API in MultivariateStats is changed.
See https://github.com/JuliaStats/MultivariateStats.jl/issues/109 and https://github.com/JuliaStats/MultivariateStats.jl/issues/95.


## Covariance ellipses

A 2×2 covariance matrix `Σ` can be plotted as an ellipse, which is a contour line of a Gaussian density function with variance `Σ`.
```
covellipse([0,2], [2 1; 1 4], n_std=2, aspect_ratio=1, label="cov1")
covellipse!([1,0], [1 -0.5; -0.5 3], showaxes=true, label="cov2")
```
![covariance ellipses](https://user-images.githubusercontent.com/4170948/84170978-f0c2f380-aa82-11ea-95de-ce2fe14e16ec.png)
