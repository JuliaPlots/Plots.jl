# PlotThemes

[![Build Status](https://travis-ci.org/pkofod/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/pkofod/PlotThemes.jl)


```julia
using StatPlots, PlotThemes

set_theme(:dark) # or another theme

using RDatasets
iris = dataset("datasets","iris")
marginalhist(iris, :PetalLength, :PetalWidth)

M = randn(1000,4)
M[:,2] += 0.8sqrt(abs(M[:,1])) - 0.5M[:,3] + 5
M[:,3] -= 0.7M[:,1].^2 + 2
corrplot(M, label = ["x$i" for i=1:4])

cornerplot(M)

import RDatasets
singers = RDatasets.dataset("lattice","singer")
violin(singers,:VoicePart,:Height,marker=(0.2,:blue,stroke(0)))
boxplot!(singers,:VoicePart,:Height,marker=(0.3,:orange,stroke(2)))

using Distributions
plot(Normal(3,5), fill=(0, .5,:orange))

dist = Gamma(2)
scatter(dist, leg=false)
bar!(dist, func=cdf, alpha=0.3)
```
