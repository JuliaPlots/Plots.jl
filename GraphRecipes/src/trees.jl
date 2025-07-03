import AbstractTrees
using AbstractTrees: children

export TreePlot

"""
    TreePlot(root)

Wrap a tree-like object for plotting. Uses `AbstractTrees.children()` to recursively add children to the plot and `AbstractTrees.printnode()` to generate the labels.

# Example

```julia
using AbstractTrees, GraphRecipes
@eval AbstractTrees children(d::AnstractDict) = [p for p in d]
@eval AbstractTrees children(p::Pair) = AbstractTrees.children(p[2])
@eval AbstractTrees  function printnode(io::IO, p::Pair)
    str = isempty(children(p[2])) ? string(p[1], ": ", p[2]) : string(p[1], ": ")
    print(io, str)
end

d = Dict(:a => 2,:d => Dict(:b => 4,:c => "Hello"),:e => 5.0)

plot(TreePlot(d)) 
````
"""
struct TreePlot{T}
    root::T
end

function add_children!(nodes, source, destiny, node, parent_idx)
    for child in children(node)
        push!(nodes, child)
        child_idx = length(nodes)
        push!(source, parent_idx)
        push!(destiny, child_idx)
        add_children!(nodes, source, destiny, child, child_idx)
    end
    return
end

function string_from_node(node)
    io = IOBuffer()
    AbstractTrees.printnode(io, node)
    return String(take!(io))
end

# recursively build a graph of children of `tree_wrapper.root`
@recipe function f(tree_wrapper::TreePlot; namefunc = string_from_node)
    root = tree_wrapper.root
    # recursively add children
    nodes = Any[root]
    source, destiny = Int[], Int[]
    add_children!(nodes, source, destiny, root, 1)

    # set up the graphplot
    names --> map(namefunc, nodes)
    method --> :buchheim
    root --> :top
    GraphPlot((source, destiny))
end
