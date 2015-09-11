### Lines

A simple line plot of the 3 columns.

```julia
plot(rand(100,3))
```

![](../img/qwt_example_1.png)

### Functions

Plot multiple functions

```julia
plot(0:0.01:4π,[sin,cos])
```

![](../img/qwt_example_2.png)

### Global

Change the guides/background without a separate call.

```julia
plot(rand(10); title="TITLE",xlabel="XLABEL",ylabel="YLABEL",background_color=RGB(0.5,0.5,0.5))
```

![](../img/qwt_example_3.png)

### Vectors

Plot multiple series with different numbers of points.

```julia
plot(Vector[rand(10),rand(20)]; marker=:ellipse,markersize=8)
```

![](../img/qwt_example_4.png)

### Vectors w/ pluralized args

Mix arguments that apply to all series with arguments unique to each series.

```julia
plot(Vector[rand(10),rand(20)]; marker=:ellipse,markersize=8,colors=[:red,:blue])
```

![](../img/qwt_example_5.png)

### Build plot in pieces

You can add to a plot at any time.

```julia
plot(rand(100) / 3; reg=true,fillto=0)
scatter!(rand(100); markersize=6,color=:blue)
```

![](../img/qwt_example_6.png)

### Heatmaps



```julia
heatmap(randn(10000),randn(10000); nbins=200)
```

![](../img/qwt_example_7.png)

### Lots of line types

Options: (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar)  
Note: some may not work with all backends

```julia
plot(rand(20,4); linetypes=[:line,:step,:sticks,:dots])
```

![](../img/qwt_example_8.png)

### Bar

x is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)

```julia
bar(randn(1000))
```

![](../img/qwt_example_9.png)

### Histogram

note: fillto isn't supported on all backends

```julia
histogram(randn(1000); nbins=50,fillto=20)
```

![](../img/qwt_example_10.png)

