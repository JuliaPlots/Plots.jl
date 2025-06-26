<a href="https://opencollective.com/plotsjl/donate" target="_blank">
  <img src="https://opencollective.com/webpack/donate/button@2x.png?color=blue" width=200 />
</a>

[gh-ci-url]: 
https://github.com/JuliaPlots/GraphRecipes.jl/workflows/ci/badge.svg?branch=master

[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

[pkgeval-img]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges

[pkgeval-url]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html

[gitter-url]: https://gitter.im/tbreloff/Plots.jl?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://docs.juliaplots.org/stable

[![Plots Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Fmonthly_downloads%2FPlots&query=total_requests&suffix=%2Fmonth&label=Downloads)](https://juliapkgstats.com/pkg/Plots)

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://docs.juliaplots.org/dev

[![][gh-ci-img]][gh-ci-url]
[![][pkgeval-img]][pkgeval-url]
[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://julialang.zulipchat.com/#narrow/stream/236493-plots)
[![][docs-stable-img]][docs-stable-url]
[![][docs-dev-img]][docs-dev-url]
[![Codecov](https://codecov.io/gh/JuliaPlots/Plots.jl/branch/v2/graph/badge.svg)](https://codecov.io/gh/JuliaPlots/Plots.jl/tree/v2)

[gh-ci-img]: https://github.com/JuliaPlots/GraphRecipes.jl/workflows/ci/badge.svg?branch=master
[gh-ci-url]: https://github.com/JuliaPlots/GraphRecipes.jl/actions?query=workflow%3Aci
<a href='https://codespaces.new/JuliaPlots/Plots.jl?quickstart=1'><img src='https://github.com/codespaces/badge.svg' alt='Open in GitHub Codespaces' style='max-width: 100%;'></a>


## Summary
In this repository, a graph is a network of connected nodes (although sometimes people use the same word to refer to a plot). If you want to do plotting, then use [Plots.jl](https://github.com/JuliaPlots/Plots.jl).

For a given graph, there are many legitimate ways to display and visualize the graph. However, some graph layouts will convey the structure of the underlying graph much more clearly than other layouts. GraphRecipes provides many options for producing graph layouts including  (un)directed graphs, tree graphs and arc/chord diagrams. For each layout type the `graphplot` function will try to create a default layout that optimizes visual clarity. However, the user can tweak the default layout through a large number of powerful keyword arguments, see the [documentation](https://docs.juliaplots.org/stable/GraphRecipes/introduction) for more details and some examples.

# Plots

## Installation
```julia
] add GraphRecipes
```

## An example
```julia
using GraphRecipes
using PlotsBase

import GR; gr()

g = [0 1 1;
     1 0 1;
     1 1 0]

graphplot(g,
          x=[0,-1/tan(π/3),1/tan(π/3)], y=[1,0,0],
          nodeshape=:circle, nodesize=1.1,
          axis_buffer=0.6,
          curves=false,
          color=:black,
          nodecolor=[colorant"#389826",colorant"#CB3C33",colorant"#9558B2"],
          linewidth=10)
```
![](assets/readme_julia_logo_pun.png)


This repo maintains a collection of recipes for graph analysis, and is a reduced and refactored version of the previous PlotRecipes. It uses the powerful machinery of [Plots](https://github.com/JuliPlots/Plots.jl) and [RecipesBase](https://github.com/JuliaPlots/Plots.jl/tree/master/RecipesBase) to turn simple transformations into flexible visualizations.

Original author: Thomas Breloff (@tbreloff)
