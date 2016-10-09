# PlotThemes

[![Build Status](https://travis-ci.org/pkofod/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/pkofod/PlotThemes.jl)


```julia
using StatPlots, RDatasets, Distributions
pyplot(size=(1500,1000))

# load PlotThemes and choose dark (or sand/solarized/etc)
using PlotThemes
plot_theme(:dark) # or another theme

# some data
iris = dataset("datasets","iris")
singers = dataset("lattice","singer")
M = randn(1000,4)
M[:,2] += 0.8sqrt(abs(M[:,1])) - 0.5M[:,3] + 5
M[:,3] -= 0.7M[:,1].^2 + 2

# marginalhist, corrplot, and cornerplot
mp = marginalhist(iris, :PetalLength, :PetalWidth)
cp = corrplot(M, label = ["x$i" for i=1:4])
cp2 = cornerplot(M)

# violin/boxplot
vp = violin(singers,:VoicePart,:Height)
boxplot!(singers,:VoicePart,:Height)

# Distributions
np = plot(Normal(3,5), fill=(0, .5,:orange))
dist = Gamma(2)
gp = scatter(dist, leg=false)
bar!(dist, func=cdf, alpha=0.3)

# Regular line plot
lp = plot(cumsum(randn(30,5)).^2,lw=1.5, xlabel = "the x's", ylabel = "the y's")

# Open-High-Low-Close plot
n = 20
hgt = rand(n) + 1
bot = randn(n)
openpct = rand(n)
closepct = rand(n)
y = OHLC[(openpct[i] * hgt[i] + bot[i],bot[i] + hgt[i],bot[i],closepct[i] * hgt[i] + bot[i]) for i = 1:n]
oh = ohlc(y)

# put them all together in a 4x2 grid
plot(mp, cp, cp2, vp, np, gp, lp, oh, layout=(4,2))
```

![](https://cloud.githubusercontent.com/assets/8431156/19215305/8931f030-8d9a-11e6-9b15-011c19ff7456.png)

Or using the `:sand` theme.

![](https://cloud.githubusercontent.com/assets/8431156/19215525/02fbf8f6-8da1-11e6-9ef8-09d74fc802a0.png)

# Solarized

![](https://cloud.githubusercontent.com/assets/8431156/19223536/80e12616-8e72-11e6-9085-daca2e88baf3.png)

![](https://cloud.githubusercontent.com/assets/8431156/19223543/a37b0c78-8e72-11e6-8c99-27d8cc0db403.png)
