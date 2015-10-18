## Examples for backend: winston

### Initialize

```julia
using Plots
winston()
```

### Lines

A simple line plot of the columns.

```julia
plot(fakedata(50,5),w=3)
```

![](../img/winston/winston_example_1.png)

### Parametric plots

Plot function pair (x(u), y(u)).

```julia
plot(sin,(x->begin  # /Users/tom/.julia/v0.4/Plots/docs/example_generation.jl, line 50:
            sin(2x)
        end),0,2π,line=4,leg=false,fill=(0,:orange))
```

![](../img/winston/winston_example_3.png)

### Colors

Access predefined palettes (or build your own with the `colorscheme` method).  Line/marker colors are auto-generated from the plot's palette, unless overridden.  Set the `z` argument to turn on series gradients.

```julia
y = rand(100)
plot(0:10:100,rand(11,4),lab="lines",w=3,palette=:grays,fill=(0.5,:auto))
scatter!(y,z=abs(y - 0.5),m=(10,:heat),lab="grad")
```

![](../img/winston/winston_example_4.png)

### Global

Change the guides/background/limits/ticks.  Convenience args `xaxis` and `yaxis` allow you to pass a tuple or value which will be mapped to the relevant args automatically.  The `xaxis` below will be replaced with `xlabel` and `xlims` args automatically during the preprocessing step. You can also use shorthand functions: `title!`, `xaxis!`, `yaxis!`, `xlabel!`, `ylabel!`, `xlims!`, `ylims!`, `xticks!`, `yticks!`

```julia
plot(rand(20,3),xaxis=("XLABEL",(-5,30),0:2:20,:flip),background_color=RGB(0.2,0.2,0.2),leg=false)
title!("TITLE")
yaxis!("YLABEL",:log10)
```

![](../img/winston/winston_example_5.png)

### Two-axis

Use the `axis` arguments.

Note: Currently only supported with Qwt and PyPlot

```julia
plot(Vector[randn(100),randn(100) * 100],axis=[:l :r],ylabel="LEFT",yrightlabel="RIGHT")
```

![](../img/winston/winston_example_6.png)

### Arguments

Plot multiple series with different numbers of points.  Mix arguments that apply to all series (marker/markersize) with arguments unique to each series (colors).  Special arguments `line`, `marker`, and `fill` will automatically figure out what arguments to set (for example, we are setting the `linestyle`, `linewidth`, and `color` arguments with `line`.)  Note that we pass a matrix of colors, and this applies the colors to each series.

```julia
plot(Vector[rand(10),rand(20)],marker=(:ellipse,8),line=(:dot,3,[:black :orange]))
```

![](../img/winston/winston_example_7.png)

### Build plot in pieces

Start with a base plot...

```julia
plot(rand(100) / 3,reg=true,fill=(0,:green))
```

![](../img/winston/winston_example_8.png)

### 

and add to it later.

```julia
scatter!(rand(100),markersize=6,c=:orange)
```

![](../img/winston/winston_example_9.png)

### Line types



```julia
types = intersect(supportedTypes(),[:line,:path,:steppre,:steppost,:sticks,:scatter])'
n = length(types)
x = Vector[sort(rand(20)) for i = 1:n]
y = rand(20,n)
plot(x,y,line=(types,3),lab=map(string,types),ms=15)
```

![](../img/winston/winston_example_11.png)

### Line styles



```julia
styles = setdiff(supportedStyles(),[:auto])'
plot(cumsum(randn(20,length(styles)),1),style=:auto,label=map(string,styles),w=5)
```

![](../img/winston/winston_example_12.png)

### Marker types



```julia
markers = setdiff(supportedMarkers(),[:none,:auto,Shape])'
n = length(markers)
x = (linspace(0,10,n + 2))[2:end - 1]
y = repmat(reverse(x)',n,1)
scatter(x,y,m=(8,:auto),lab=map(string,markers),bg=:linen)
```

![](../img/winston/winston_example_13.png)

### Bar

x is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)

```julia
bar(randn(999))
```

![](../img/winston/winston_example_14.png)

### Histogram



```julia
histogram(randn(1000),nbins=50)
```

![](../img/winston/winston_example_15.png)

- Supported arguments: `annotation`, `color`, `color_palette`, `fillcolor`, `fillrange`, `group`, `label`, `legend`, `linestyle`, `linetype`, `linewidth`, `markercolor`, `markershape`, `markersize`, `nbins`, `show`, `size`, `smooth`, `title`, `windowtitle`, `x`, `xlabel`, `xlims`, `xscale`, `y`, `ylabel`, `ylims`, `yscale`
- Supported values for axis: `:auto`, `:left`
- Supported values for linetype: `:bar`, `:hist`, `:line`, `:none`, `:path`, `:scatter`, `:sticks`
- Supported values for linestyle: `:auto`, `:dash`, `:dashdot`, `:dot`, `:solid`
- Supported values for marker: `:auto`, `:cross`, `:diamond`, `:dtriangle`, `:ellipse`, `:none`, `:rect`, `:star5`, `:utriangle`, `:xcross`
- Is `subplot`/`subplot!` supported? No

(Automatically generated: 2015-10-18T00:50:13)