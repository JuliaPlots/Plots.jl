# PlotThemes

[![Build Status](https://travis-ci.org/pkofod/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/pkofod/PlotThemes.jl)

PlotThemes is a package to spice up the plots made with [Plots.jl](https://github.com/tbreloff/Plots.jl).
The package is currently not tagget at METADATA, so you need to clone it to install.
```julia
Pkg.clone("https://github.com/pkofod/PlotThemes.jl.git")
```
Colors and theme names may change.

```julia
using StatPlots, RDatasets, Distributions

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
plot(mp, cp, cp2, vp, np, gp, lp, oh, layout=(4,2), size=(1000,2000))
```

![dark](https://cloud.githubusercontent.com/assets/8431156/19231320/b586c026-8ed9-11e6-989a-c7f181ce8e1d.png)

Or using the `:sand` theme.
![sand](https://cloud.githubusercontent.com/assets/8431156/19231322/b587c048-8ed9-11e6-824c-a6f8098b576c.png)

# Contrast
![contrast](https://cloud.githubusercontent.com/assets/8431156/19234379/87084ff0-8eeb-11e6-81bd-5e6abada0082.png)

# Solarized
Using `:solarized`.
![solarized dark theme](https://cloud.githubusercontent.com/assets/8431156/19231323/b58bf5a0-8ed9-11e6-81c0-3547a0201615.png)

Using `:solarized_light`.
![solarized light theme](https://cloud.githubusercontent.com/assets/8431156/19231321/b5872ebc-8ed9-11e6-8a5b-a9b615e348a9.png)
