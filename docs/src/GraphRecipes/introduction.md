```@setup graphintro
using Plots, GraphRecipes; gr()
Plots.reset_defaults()
```
# GraphRecipes
[GraphRecipes](https://github.com/JuliaPlots/GraphRecipes.jl) is a collection of recipes for visualizing graphs. Users specify a graph through an adjacency matrix, an adjacency list, or an `AbstractGraph` via [Graphs](https://github.com/JuliaGraphs/Graphs.jl). GraphRecipes will then use a layout algorithm to produce a visualization of the graph that the user passed.

## Installation
GraphRecipes can be installed with the package manager:
```julia
] add GraphRecipes
```

## Usage
The main user interface is through the fuction `graphplot`:
```@example graphintro
using GraphRecipes, Plots

g = [0  1  1;
     1  0  1;
     1  1  0]
graphplot(g)
```

See [Examples](@ref graph_examples) for example usages and [Attributes](@ref graph_attributes) for an explanation of keyword arguments to the `graphplot` function.
