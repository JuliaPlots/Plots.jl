# PlotThemes

[![Build Status](https://travis-ci.org/JuliaPlots/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/JuliaPlots/PlotThemes.jl)

#### Primary author: Patrick Kofod Mogensen (@pkofod)

PlotThemes is a package to spice up the plots made with [Plots.jl](https://github.com/tbreloff/Plots.jl). To install:

```julia
Pkg.add("PlotThemes")
```

Note: This is a relatively new package, and so colors and theme names may change.

```julia
using StatPlots, RDatasets, Distributions

# choose the dark theme (or sand/solarized/etc)
theme(:dark)

# some data
iris = dataset("datasets","iris")
singers = dataset("lattice","singer")
M = randn(1000,4)
M[:,2] += 0.8sqrt(abs(M[:,1])) - 0.5M[:,3] + 5
M[:,3] -= 0.7M[:,1].^2 + 2

# marginalhist, corrplot, and cornerplot
mp = @df iris marginalhist(:PetalLength, :PetalWidth)
cp = corrplot(M, label = ["x$i" for i=1:4])
cp2 = cornerplot(M)

# violin/boxplot
vp = @df singers begin
    violin(:VoicePart, :Height)
    boxplot!(:VoicePart, :Height)
end

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

# Dark
`theme(:dark)`

![dark](https://user-images.githubusercontent.com/16589944/33489504-511a882e-d6b4-11e7-8b4d-64c54f926b7c.png)

# Sand
`theme(:sand)`

![sand](https://user-images.githubusercontent.com/16589944/33489509-568adb42-d6b4-11e7-8529-e32602edce20.png)

# Lime
`theme(:lime)`

![lime](https://user-images.githubusercontent.com/16589944/33489523-5dbe46c4-d6b4-11e7-9976-4c217f299408.png)

# Orange
`theme(:orange)`

![orange](https://user-images.githubusercontent.com/16589944/33489526-60efe2bc-d6b4-11e7-958d-07e766adf849.png)

# Solarized
`theme(:solarized)`

![solarized](https://user-images.githubusercontent.com/16589944/33489533-6500a21a-d6b4-11e7-9f02-a44e1066a20a.png)

# Solarized Light
`theme(:solarized_light)`

![solarized_light](https://cloud.githubusercontent.com/assets/8431156/19231321/b5872ebc-8ed9-11e6-8a5b-a9b615e348a9.png)

# Juno
`theme(:juno)`

![juno](https://user-images.githubusercontent.com/16589944/33489542-713aa45e-d6b4-11e7-8385-558819e9d47c.png)

# Default
`theme(:default)`

![default](https://user-images.githubusercontent.com/16589944/33489485-4b3c190e-d6b4-11e7-90c7-b58b35b735ac.png)
