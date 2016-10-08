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

# put them all together in a 3x2 grid
plot(mp, cp, cp2, vp, np, gp, layout=(3,2))
```

![](https://cloud.githubusercontent.com/assets/8431156/19213193/ff73747a-8d64-11e6-9a96-4cc3c5b802f5.png)
