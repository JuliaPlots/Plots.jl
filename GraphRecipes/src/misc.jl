
# -------------------------------------------------------------------
# AST trees

function add_ast(adjlist, names, depthdict, depthlists, nodetypes, ex::Expr, parent_idx)
    idx = length(names) + 1
    iscall = ex.head == :call
    push!(names, iscall ? string(ex.args[1]) : string(ex.head))
    push!(nodetypes, iscall ? :call : :expr)
    l = Int[]
    push!(adjlist, l)

    depth = parent_idx == 0 ? 1 : depthdict[parent_idx] + 1
    depthdict[idx] = depth
    while length(depthlists) < depth
        push!(depthlists, Int[])
    end
    push!(depthlists[depth], idx)

    for arg in (iscall ? ex.args[2:end] : ex.args)
        if isa(arg, LineNumberNode)
            continue
        end
        push!(l, add_ast(adjlist, names, depthdict, depthlists, nodetypes, arg, idx))
    end
    idx
end

function add_ast(adjlist, names, depthdict, depthlists, nodetypes, x, parent_idx)
    push!(names, string(x))
    push!(nodetypes, :leaf)
    push!(adjlist, Int[])
    idx = length(names)

    depth = parent_idx == 0 ? 1 : depthdict[parent_idx] + 1
    depthdict[idx] = depth
    while length(depthlists) < depth
        push!(depthlists, Int[])
    end
    push!(depthlists[depth], idx)

    idx
end

@recipe function f(ex::Expr)
    names = String[]
    adjlist = Vector{Int}[]
    depthdict = Dict{Int,Int}()
    depthlists = Vector{Int}[]
    nodetypes = Symbol[]
    add_ast(adjlist, names, depthdict, depthlists, nodetypes, ex, 0)
    names := names
    # method := :tree
    method := :buchheim
    root --> :top

    # markercolor --> Symbol[(nt == :call ? :pink : nt == :leaf ? :white : :lightgreen) for nt in nodetypes]

    # # compute the y-values from the depthdict dict
    # n = length(depthlists)-1
    # layers = Float64[(depthdict[i]-1)/n for i=1:length(names)]
    # # add_noise --> false
    #
    # positions = zeros(length(names))
    # for (depth, lst) in enumerate(depthlists)
    #     n = length(lst)
    #     pos = n > 1 ? linspace(0, 1, n) : [0.5]
    #     for (i, idx) in enumerate(lst)
    #         positions[idx] = pos[i]
    #     end
    # end
    #
    # layout_kw := Dict{Symbol,Any}(:layers => layers, :add_noise => false, :positions => positions)

    GraphPlot(get_source_destiny_weight(adjlist))
end

# -------------------------------------------------------------------
# Type trees

function add_subs!(nodes, source, destiny, ::Type{T}, supidx) where {T}
    for sub in subtypes(T)
        push!(nodes, sub)
        subidx = length(nodes)
        push!(source, supidx)
        push!(destiny, subidx)
        add_subs!(nodes, source, destiny, sub, subidx)
    end
end

# recursively build a graph of subtypes of T
@recipe function f(
    ::Type{T};
    namefunc = node -> isa(node, UnionAll) ? split(string(node), '.')[end] : node.name.name,
) where {T}
    # get the supertypes
    sups = Any[T]
    sup = T
    while sup != Any
        sup = supertype(sup)
        pushfirst!(sups, sup)
    end

    # add the subtypes
    n = length(sups)
    nodes = copy(sups)
    source, destiny = collect(1:(n - 1)), collect(2:n)
    add_subs!(nodes, source, destiny, T, n)

    # set up the graphplot
    names := map(namefunc, nodes)
    method --> :buchheim
    root --> :top
    GraphPlot((source, destiny))
end
