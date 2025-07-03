function random_labelled_graph()
    n = 15
    rng = StableRNG(1)
    A = Float64[rand(rng) < 0.5 ? 0 : rand(rng) for i in 1:n, j in 1:n]
    for i in 1:n
        A[i, 1:(i - 1)] = A[1:(i - 1), i]
        A[i, i] = 0
    end
    x = rand(rng, n)
    y = rand(rng, n)
    z = rand(rng, n)
    p = graphplot(
        A;
        nodesize = 0.2,
        node_weights = 1:n,
        nodecolor = range(colorant"yellow", stop = colorant"red", length = n),
        names = 1:n,
        fontsize = 10,
        linecolor = :darkgrey,
        layout_kw = Dict(:x => x, :y => y),
        rng,
    )
    return p, n, A, x, y, z
end

function random_3d_graph()
    n, A, x, y, z = random_labelled_graph()[2:end]
    return graphplot(
        A,
        node_weights = 1:n,
        markercolor = :darkgray,
        dim = 3,
        markersize = 5,
        markershape = :circle,
        linecolor = :darkgrey,
        linealpha = 0.5,
        layout_kw = Dict(:x => x, :y => y, :z => z),
        rng = StableRNG(1),
    )
end

function light_graphs()
    g = wheel_graph(10)
    return graphplot(g, curves = false, rng = StableRNG(1))
end

function directed()
    g = [
        0 1 1
        0 0 1
        0 1 0
    ]
    return graphplot(g, names = 1:3, curvature_scalar = 0.1, rng = StableRNG(1))
end

function edgelabel()
    n = 8
    g = wheel_digraph(n)
    edgelabel_dict = Dict()
    for i in 1:n
        for j in 1:n
            edgelabel_dict[(i, j)] = string("edge ", i, " to ", j)
        end
    end

    return graphplot(
        g,
        names = 1:n,
        edgelabel = edgelabel_dict,
        curves = false,
        nodeshape = :rect,
        rng = StableRNG(1),
    )
end

function selfedges()
    g = [
        1 1 1
        0 0 1
        0 0 1
    ]
    return graphplot(DiGraph(g), self_edge_size = 0.2, rng = StableRNG(1))
end

multigraphs() = graphplot(
    [[1, 1, 2, 2], [1, 1, 1], [1]],
    names = "node_" .* string.(1:3),
    nodeshape = :circle,
    self_edge_size = 0.25,
    rng = StableRNG(1),
)

function arc_chord_diagrams()
    rng = StableRNG(1)
    adjmat = Symmetric(sparse(rand(rng, 0:1, 8, 8)))
    return plot(
        graphplot(
            adjmat;
            method = :chorddiagram,
            names = [text(string(i), 8) for i in 1:8],
            linecolor = :black,
            fillcolor = :lightgray,
            rng
        ),
        graphplot(
            adjmat;
            method = :arcdiagram,
            markersize = 0.5,
            markershape = :circle,
            linecolor = :black,
            markercolor = :black,
            rng,
        ),
    )
end

function marker_properties()
    N = 8
    seed = 42
    rng = StableRNG(seed)
    g = barabasi_albert(N, 1; rng = rng)
    weights = [length(neighbors(g, i)) for i in 1:nv(g)]
    return graphplot(
        g,
        curvature_scalar = 0,
        node_weights = weights,
        nodesize = 0.25,
        linecolor = :gray,
        linewidth = 2.5,
        nodeshape = :circle,
        node_z = rand(rng, N),
        markercolor = :viridis,
        nodestrokewidth = 1.5,
        markerstrokestyle = :solid,
        markerstrokealpha = 1.0,
        markerstrokecolor = :lightgray,
        colorbar = true,
        rng = rng,
    )
end

function ast_example()
    code = :(
        function mysum(list)
            out = 0
            for value in list
                out += value
            end
            return out
        end
    )
    return plot(
        code,
        fontsize = 10,
        shorten = 0.01,
        axis_buffer = 0.15,
        nodeshape = :rect,
        size = (1000, 1000),
        rng = StableRNG(1),
    )
end

julia_type_tree() = plot(
    AbstractFloat,
    method = :tree,
    fontsize = 10,
    nodeshape = :ellipse,
    size = (1000, 1000),
    rng = StableRNG(1),
)

@eval AbstractTrees children(d::AbstractDict) = [p for p in d]
@eval AbstractTrees children(p::Pair) = AbstractTrees.children(p[2])
@eval AbstractTrees function printnode(io::IO, p::Pair)
    str = isempty(children(p[2])) ? string(p[1], ": ", p[2]) : string(p[1], ": ")
    return print(io, str)
end

function julia_dict_tree()
    d = Dict(:a => 2, :d => Dict(:b => 4, :c => "Hello"), :e => 5.0)
    return plot(
        TreePlot(d),
        method = :tree,
        fontsize = 10,
        nodeshape = :ellipse,
        size = (1000, 1000),
        rng = StableRNG(1),
    )
end

diamond_nodeshape(x_i, y_i, s) =
    [(x_i + 0.5s * dx, y_i + 0.5s * dy) for (dx, dy) in [(1, 1), (-1, 1), (-1, -1), (1, -1)]]

function diamond_nodeshape_wh(x_i, y_i, h, w)
    out = Tuple{Float64, Float64}[(-0.5, 0), (0, -0.5), (0.5, 0), (0, 0.5)]
    return map(out) do t
        x = t[1] * h
        y = t[2] * w
        (x + x_i, y + y_i)
    end
end

function custom_nodeshapes_single()
    rng = StableRNG(1)
    g = rand(rng, 5, 5)
    g[g .> 0.5] .= 0
    for i in 1:5
        g[i, i] = 0
    end
    return graphplot(g, nodeshape = diamond_nodeshape, rng = rng)
end

function custom_nodeshapes_various()
    rng = StableRNG(1)
    g = rand(rng, 5, 5)
    g[g .> 0.5] .= 0
    for i in 1:5
        g[i, i] = 0
    end
    return graphplot(
        g,
        nodeshape = [
            :circle,
            diamond_nodeshape,
            diamond_nodeshape_wh,
            :hexagon,
            diamond_nodeshape_wh,
        ],
        rng = rng,
    )
end

function funky_edge_and_marker_args()
    n = 5
    g = SimpleDiGraph(n)

    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 4)
    add_edge!(g, 4, 4)
    add_edge!(g, 4, 5)

    curviness_matrix = zeros(n, n)
    edgewidth_matrix = zeros(n, n)
    edgestyle_dict = Dict()
    for e in edges(g)
        curviness_matrix[e.src, e.dst] = 0.5sin(e.src)
        edgewidth_matrix[e.src, e.dst] = 0.8e.dst
        edgestyle_dict[(e.src, e.dst)] = e.src < 2.0 ? :solid : e.src > 3.0 ? :dash : :dot
    end
    edge_z_function = (s, d, w) -> curviness_matrix[s, d]

    return graphplot(
        g,
        names = [" I ", " am ", " a ", "funky", "graph"],
        x = [1, 2, 3, 4, 5],
        y = [5, 4, 3, 2, 1],
        nodesize = 0.3,
        size = (1000, 1000),
        axis_buffer = 0.6,
        fontsize = 16,
        self_edge_size = 1.3,
        curvature_scalar = curviness_matrix,
        edgestyle = edgestyle_dict,
        edgewidth = edgewidth_matrix,
        edge_z = edge_z_function,
        nodeshape = :circle,
        node_z = [1, 2, 3, 4, 5],
        nodestroke_z = [5, 4, 3, 2, 1],
        edgecolor = :viridis,
        markercolor = :viridis,
        nodestrokestyle = [:dash, :solid, :dot],
        nodestrokewidth = 6,
        linewidth = 2,
        colorbar = true,
        rng = StableRNG(1),
    )
end
