<a href="https://opencollective.com/plotsjl/donate" target="_blank">
  <img src="https://opencollective.com/webpack/donate/button@2x.png?color=blue" width=200 />
</a>

________________________________

[![npm version](https://badge.fury.io/js/typescript.svg)](https://www.npmjs.com/package/typescript)
[![Downloads](https://img.shields.io/npm/dm/typescript.svg)](https://www.npmjs.com/package/typescript)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/microsoft/TypeScript/badge)](https://securityscorecards.dev/viewer/?uri=github.com/microsoft/TypeScript)

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaplots.org/latest/generated/statsplots/)

[![Project Chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://julialang.zulipchat.com/#narrow/stream/236493-plots)

[![Aqua.Jl QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

[![ci](https://github.com/Own65/Plots.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/Own65/Plots.jl/actions/workflows/ci.yml)

[pkgeval-img]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges

[pkgeval-url]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html

[gitter-url]: https://gitter.im/tbreloff/Plots.jl?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge

[![Codecov](https://codecov.io/gh/JuliaPlots/Plots.jl/branch/v2/graph/badge.svg)](https://codecov.io/gh/JuliaPlots/Plots.jl/tree/v2)

________________________________


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

Editor: Rei de Roma
