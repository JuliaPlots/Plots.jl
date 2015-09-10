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

