# PlotThemes

[![Build Status](https://travis-ci.org/pkofod/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/pkofod/PlotThemes.jl)


```julia
using StatPlots, RDatasets, Distributions

# load PlotThemes and choose dark (or sand/solarized/etc)
using PlotThemes
plot_theme(:solarized) # or another theme

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
plot(mp, cp, cp2, vp, np, gp, lp, oh, layout=(4,2), size=(1000,2000))
```

![solarized dark](https://cloud.githubusercontent.com/assets/8431156/19230231/c321be26-8ed3-11e6-9f17-c398d8840245.png)

Or using the `:solarized_light` theme.
![solarized light](https://cloud.githubusercontent.com/assets/8431156/19230234/c4a77d6c-8ed3-11e6-8226-df8874a2e9d3.png)

# Atom inspired
Using `:dark`.
![dark theme](https://cloud.githubusercontent.com/assets/8431156/19230182/6c0a2d08-8ed3-11e6-8ad8-aa46a3f67f90.png)

Using `:sand`.
![sand theme](https://cloud.githubusercontent.com/assets/8431156/19230183/6d5edb90-8ed3-11e6-927f-5729f888b2d7.png)
