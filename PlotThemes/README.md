# PlotThemes

[![Build Status](https://travis-ci.org/pkofod/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/pkofod/PlotThemes.jl)


```julia
using StatPlots, PlotThemes
pyplot(size=(1500,1000))
plot_theme(:dark) # or another theme
ps = []
using RDatasets
iris = dataset("datasets","iris")
push!(ps, marginalhist(iris, :PetalLength, :PetalWidth))

M = randn(1000,4)
M[:,2] += 0.8sqrt(abs(M[:,1])) - 0.5M[:,3] + 5
M[:,3] -= 0.7M[:,1].^2 + 2
push!(ps, corrplot(M, label = ["x$i" for i=1:4]))

push!(ps, cornerplot(M))

import RDatasets
singers = RDatasets.dataset("lattice","singer")
push!(ps, violin(singers,:VoicePart,:Height,marker=(0.2,:blue,stroke(0))))
boxplot!(singers,:VoicePart,:Height,marker=(0.3,:orange,stroke(2)))

using Distributions
push!(ps, plot(Normal(3,5), fill=(0, .5,:orange)))

dist = Gamma(2)
push!(ps,  scatter(dist, leg=false))
bar!(dist, func=cdf, alpha=0.3)
plot(ps..., layout=(3,2))
```

![](https://cloud.githubusercontent.com/assets/8431156/19212997/4597a80e-8d60-11e6-9c16-6c4171964a7e.png)
