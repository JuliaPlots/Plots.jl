const _graph_funcs = Dict{Symbol,Any}(
    :spectral => spectral_graph,
    :sfdp => sfdp_graph,
    :circular => circular_graph,
    :shell => shell_graph,
    :spring => spring_graph,
    :stress => by_axis_local_stress_graph,
    :tree => tree_graph,
    :buchheim => buchheim_graph,
    :arcdiagram => arc_diagram,
    :chorddiagram => chord_diagram,
)

const _graph_inputs = Dict{Symbol,Any}(
    :spectral => :adjmat,
    :sfdp => :adjmat,
    :circular => :adjmat,
    :shell => :adjmat,
    :stress => :adjmat,
    :spring => :adjmat,
    :tree => :sourcedestiny,
    :buchheim => :adjlist,
    :arcdiagram => :sourcedestiny,
    :chorddiagram => :sourcedestiny,
)

function prepare_graph_inputs(method::Symbol, inputs...; display_n = nothing)
    input_type = get(_graph_inputs, method, :sourcedestiny)
    if input_type ≡ :adjmat
        mat = if display_n === nothing
            get_adjacency_matrix(inputs...)
        else
            get_adjacency_matrix(inputs..., display_n)
        end
        (mat,)
    elseif input_type ≡ :sourcedestiny
        get_source_destiny_weight(inputs...)
    elseif input_type ≡ :adjlist
        (get_adjacency_list(inputs...),)
    end
end

# -----------------------------------------------------

function get_source_destiny_weight(mat::AbstractArray{T,2}) where {T}
    nrow, ncol = size(mat)    # rows are sources and columns are destinies
    @assert nrow == ncol

    nosymmetric = !issymmetric(mat) # plots only triu for symmetric matrices
    nosparse = !issparse(mat) # doesn't plot zeros from a sparse matrix

    L = length(mat)

    source  = Array{Int}(undef, L)
    destiny = Array{Int}(undef, L)
    weights = Array{T}(undef, L)

    idx = 0
    for i ∈ 1:nrow, j ∈ 1:ncol
        value = mat[i, j]
        if !isnan(value) && (nosparse || value != zero(T)) # TODO: deal with Nullable
            if i < j
                idx          += 1
                source[idx]  = i
                destiny[idx] = j
                weights[idx] = value
            elseif nosymmetric && (i > j)
                idx          += 1
                source[idx]  = i
                destiny[idx] = j
                weights[idx] = value
            end
        end
    end
    resize!(source, idx), resize!(destiny, idx), resize!(weights, idx)
end

function get_source_destiny_weight(source::AbstractVector, destiny::AbstractVector)
    if length(source) != length(destiny)
        throw(ArgumentError("Source and destiny must have the same length."))
    end
    source, destiny, ones(length(source))
end

function get_source_destiny_weight(
    source::AbstractVector,
    destiny::AbstractVector,
    weights::AbstractVector,
)
    if !(length(source) == length(destiny) == length(weights))
        throw(ArgumentError("Source, destiny and weights must have the same length."))
    end
    source, destiny, weights
end

function get_source_destiny_weight(
    adjlist::AbstractVector{V},
) where {V<:AbstractVector{T}} where {T<:Any}
    source = Int[]
    destiny = Int[]
    for (i, l) ∈ enumerate(adjlist)
        for j ∈ l
            push!(source, i)
            push!(destiny, j)
        end
    end
    get_source_destiny_weight(source, destiny)
end

# -----------------------------------------------------

get_adjacency_matrix(mat::AbstractMatrix) = mat

get_adjacency_matrix(
    source::AbstractVector{Int},
    destiny::AbstractVector{Int},
    weights::AbstractVector,
    n = infer_size_from(source, destiny),
) = Matrix(sparse(source, destiny, weights, n, n))

get_adjacency_matrix(
    adjlist::AbstractVector{V},
) where {V<:AbstractVector{T}} where {T<:Any} =
    get_adjacency_matrix(get_source_destiny_weight(adjlist)...)

# -----------------------------------------------------

get_adjacency_list(mat::AbstractMatrix) = get_adjacency_list(get_source_destiny_weight(mat))

function get_adjacency_list(
    source::AbstractVector{Int},
    destiny::AbstractVector{Int},
    weights::AbstractVector,
)
    n = infer_size_from(source, destiny)
    adjlist = [Int[] for i ∈ 1:n]
    for (s, d) ∈ zip(source, destiny)
        push!(adjlist[s], d)
    end
    adjlist
end

get_adjacency_list(adjlist::AbstractVector{<:AbstractVector{Int}}) = adjlist

# -----------------------------------------------------

function make_symmetric(A::AbstractMatrix)
    A = copy(A)
    for i ∈ 1:size(A, 1), j ∈ (i + 1):size(A, 2)
        A[i, j] = A[j, i] = A[i, j] + A[j, i]
    end
    A
end

function compute_laplacian(adjmat::AbstractMatrix, node_weights::AbstractVector)
    n, m = size(adjmat)
    @assert n == m == length(node_weights)

    # scale the edge values by the product of node_weights, so that "heavier" nodes also form
    # stronger connections
    adjmat = adjmat .* sqrt(node_weights * node_weights')

    # D is a diagonal matrix with the degrees (total weights for that node) on the diagonal
    deg = vec(sum(adjmat; dims = 1)) - diag(adjmat)
    D = diagm(0 => deg)

    # Laplacian (L = D - adjmat)
    L = eltype(adjmat)[i == j ? deg[i] : -adjmat[i, j] for i ∈ 1:n, j ∈ 1:n]

    L, D
end

import Graphs

# TODO: so much wasteful conversion... do better
function estimate_distance(adjmat::AbstractMatrix)
    source, destiny, weights = get_source_destiny_weight(sparse(adjmat))

    g = Graphs.Graph(adjmat)
    dists = convert(
        Matrix{Float64},
        hcat(map(i -> Graphs.dijkstra_shortest_paths(g, i).dists, Graphs.vertices(g))...),
    )
    tot = 0.0
    cnt = 0
    for (i, d) ∈ enumerate(dists)
        if d < 1e10
            tot += d
            cnt += 1
        end
    end
    avg = cnt > 0 ? tot / cnt : 1.0
    for (i, d) ∈ enumerate(dists)
        if d > 1e10
            dists[i] = 3avg
        end
    end
    dists
end

function get_source_destiny_weight(g::Graphs.AbstractGraph)
    source = Vector{Int}()
    destiny = Vector{Int}()
    sizehint!(source, Graphs.nv(g))
    sizehint!(destiny, Graphs.nv(g))
    for e ∈ Graphs.edges(g)
        push!(source, Graphs.src(e))
        push!(destiny, Graphs.dst(e))
    end
    get_source_destiny_weight(source, destiny)
end

get_adjacency_matrix(g::Graphs.AbstractGraph) = adjacency_matrix(g)

get_adjacency_matrix(
    source::AbstractVector{Int},
    destiny::AbstractVector{Int},
    n = infer_size_from(source, destiny),
) = get_adjacency_matrix(source, destiny, ones(length(source)), n)

get_adjacency_list(g::Graphs.AbstractGraph) = g.fadjlist

function format_nodeproperty(prop, n_edges, edge_boxes = 0; fill_value = nothing)
    prop isa Array ?
    permutedims(vcat(fill(fill_value, edge_boxes + n_edges), vec(prop), fill_value)) : prop
end
# -----------------------------------------------------

# a graphplot takes in either an (N x N) adjacency matrix
#   note: you may want to pass node weights to markersize or marker_z
# A graph has N nodes where adj_mat[i,j] is the strength of edge i --> j.  (adj_mat[i,j]==0 implies no edge)

# NOTE: this is for undirected graphs... adjmat should be symmetric and non-negative

const graph_aliases = Dict(
    :curvature_scalar => [:curvaturescalar, :curvature],
    :node_weights => [:nodeweights],
    :nodeshape => [:node_shape, :markershape],
    :nodesize => [:node_size, :markersize],
    :nodecolor => [:marker_color, :markercolor],
    :node_z => [:marker_z],
    :nodestrokealpha => [:markerstrokealpha],
    :nodealpha => [:markeralpha],
    :nodestrokewidth => [:markerstrokewidth],
    :nodestrokealpha => [:markerstrokealpha],
    :nodestrokecolor => [:markerstrokecolor],
    :nodestrokestyle => [:markerstrokestyle],
    :shorten => [:shorten_edge],
    :axis_buffer => [:axisbuffer],
    :edgewidth => [:edge_width, :ew],
    :edgelabel => [:edge_label, :el],
    :edgelabel_offset => [:edgelabeloffset, :elo],
    :self_edge_size => [:selfedgesize, :ses],
    :edge_label_box => [:edgelabelbox, :edgelabel_box, :elb],
)

"""
    graphplot(g; kwargs...)

Visualize the graph `g`, where `g` represents a graph via a matrix or a
`Graphs.graph`.
## Keyword arguments
```
dim = 2
free_dims = nothing
T = Float64
curves = true
curvature_scalar = 0.05
root = :top
node_weights = nothing
names = []
fontsize = 7
nodeshape = :hexagon
nodesize = 0.1
node_z = nothing
nodecolor = 1
nodestrokealpha = 1
nodealpha = 1
nodestrokewidth = 1
nodestrokecolor = :black
nodestrokestyle = :solid
nodestroke_z = nothing
rng = nothing
x = nothing
y = nothing
z = nothing
method = :stress
func = get(_graph_funcs, method, by_axis_local_stress_graph)
shorten = 0.0
axis_buffer = 0.2
layout_kw = Dict{Symbol,Any}()
edgewidth = (s,d,w)->1
edgelabel = nothing
edgelabel_offset = 0.0
self_edge_size = 0.1
edge_label_box = true
edge_z = nothing
edgecolor = :black
edgestyle = :solid
trim = false
```

See the [documentation]( http://docs.juliaplots.org/latest/graphrecipes/introduction/ ) for
more details.
"""
@userplot GraphPlot

@recipe function f(
    g::GraphPlot;
    dim = 2,
    free_dims = nothing,
    T = Float64,
    curves = true,
    curvature_scalar = 0.05,
    root = :top,
    node_weights = nothing,
    names = [],
    fontsize = 7,
    nodeshape = :hexagon,
    nodesize = 0.1,
    node_z = nothing,
    nodecolor = 1,
    nodestrokealpha = 1,
    nodealpha = 1,
    nodestrokewidth = 1,
    nodestrokecolor = :black,
    nodestrokestyle = :solid,
    nodestroke_z = nothing,
    rng = nothing,
    x = nothing,
    y = nothing,
    z = nothing,
    method = :stress,
    func = get(_graph_funcs, method, by_axis_local_stress_graph),
    shorten = 0.0,
    axis_buffer = 0.2,
    layout_kw = Dict{Symbol,Any}(),
    edgewidth = (s, d, w) -> 1,
    edgelabel = nothing,
    edgelabel_offset = 0.0,
    self_edge_size = 0.1,
    edge_label_box = true,
    edge_z = nothing,
    edgecolor = :black,
    edgestyle = :solid,
    trim = false,
)
    # Process the args so that they are a Graphs.Graph.
    if length(g.args) <= 1 &&
       !(eltype(g.args[1]) <: AbstractArray) &&
       !(g.args[1] isa Graphs.AbstractGraph) &&
       method != :chorddiagram &&
       method != :arcdiagram
        if !LinearAlgebra.issymmetric(g.args[1]) ||
           any(diag(g.args[1]) .!= zeros(length(diag(g.args[1]))))
            g.args = (Graphs.DiGraph(g.args[1]),)
        elseif LinearAlgebra.issymmetric(g.args[1])
            g.args = (Graphs.Graph(g.args[1]),)
        end
    end

    # To process aliases that are unique to graphplot, find aliases that are in
    # plotattributes and replace the attributes with their aliases. Then delete the alias
    # names from the plotattributes dictionary.
    @process_aliases plotattributes graph_aliases
    for arg ∈ keys(graph_aliases)
        remove_aliases!(arg, plotattributes, graph_aliases)
    end
    # The above process will remove all marker properties from the plotattributes
    # dictionary. To ensure consistency between markers and nodes, we replace all marker
    # properties with the corresponding node property.
    marker_node_collection = zip(
        [
            :markershape,
            :markersize,
            :markercolor,
            :marker_z,
            :markerstrokealpha,
            :markeralpha,
            :markerstrokewidth,
            :markerstrokealpha,
            :markerstrokecolor,
            :markerstrokestyle,
        ],
        [
            nodeshape,
            nodesize,
            nodecolor,
            node_z,
            nodestrokealpha,
            nodealpha,
            nodestrokewidth,
            nodestrokealpha,
            nodestrokecolor,
            nodestrokestyle,
        ],
    )
    for (markerproperty, nodeproperty) ∈ marker_node_collection
        # Make sure that the node properties are row vectors.
        nodeproperty isa Array && (nodeproperty = permutedims(vec(nodeproperty)))
        plotattributes[markerproperty] = nodeproperty
    end

    # If we pass a value of plotattributes[:markershape] that the backend does not
    # recognize, then the backend will throw an error. The error is thrown despite the
    # fact that we override the default behavior. Custom nodehapes are incompatible
    # with the backend's markershapes and thus replaced.
    if nodeshape isa Function ||
       nodeshape isa Array && any([s isa Function for s ∈ nodeshape])
        plotattributes[:markershape] = :circle
    end

    @assert dim in (2, 3)
    is3d = dim == 3
    adj_mat = get_adjacency_matrix(g.args...)
    nr, nc = size(adj_mat)  # number of nodes == number of rows
    @assert nr == nc
    isdirected =
        (g.args[1] isa DiGraph || !issymmetric(adj_mat)) &&
        !in(method, (:tree, :buchheim)) &&
        !(get(plotattributes, :arrow, true) == false)
    if isdirected && (g.args[1] isa Matrix)
        g = GraphPlot((adjacency_matrix(DiGraph(g.args[1])),))
    end

    source, destiny, weights = get_source_destiny_weight(g.args...)
    if !(eltype(source) <: Integer)
        names = unique(sort(vcat(source, destiny)))
        source = Int[findfirst(names, si) for si ∈ source]
        destiny = Int[findfirst(names, di) for di ∈ destiny]
    end
    n = infer_size_from(source, destiny)
    display_n = trim ? n : nr  # number of displayed nodes
    n_edges = length(source)

    isnothing(node_weights) && (node_weights = ones(display_n))

    xyz = is3d ? (x, y, z) : (x, y)
    numnothing = count(isnothing, xyz)

    # do we want to compute coordinates?
    if numnothing > 0
        isnothing(free_dims) && (free_dims = findall(isnothing, xyz))  # compute free_dims
        dat = prepare_graph_inputs(method, source, destiny, weights; display_n = display_n)
        x, y, z = func(
            dat...;
            node_weights = node_weights,
            dim = dim,
            free_dims = free_dims,
            root = root,
            rng = rng,
            layout_kw...,
        )
    end

    # reorient the points after root
    if root in (:left, :right)
        x, y = y, -x
    end
    if root ≡ :left
        x, y = -x, y
    end
    if root ≡ :bottom
        x, y = x, -y
    end

    # Since we do nodehapes manually, they only work with aspect_ratio=1.
    # TODO: rescale the nodeshapes based on the ranges of x,y,z.
    aspect_ratio --> 1
    if length(axis_buffer) == 1
        axis_buffer = fill(axis_buffer, dim)
    end

    # center and rescale to the widest of all dimensions
    if method ≡ :arcdiagram
        xl, yl = arcdiagram_limits(x, source, destiny)
        xlims --> xl
        ylims --> yl
        aspect_ratio --> :equal
    elseif all(axis_buffer .< 0) # equal axes
        ahw = 1.2 * 0.5 * maximum(v -> maximum(v) - minimum(v), xyz)
        xcenter = mean(extrema(x))
        #xlims --> (xcenter-ahw, xcenter+ahw)
        ycenter = mean(extrema(y))
        #ylims --> (ycenter-ahw, ycenter+ahw)
        if is3d
            zcenter = mean(extrema(z))
            #zlims --> (zcenter-ahw, zcenter+ahw)
        end
    else
        xlims = ignorenan_extrema(x)
        if method != :chorddiagram && numnothing > 0
            x .-= mean(x)
            x /= (xlims[2] - xlims[1])
            y .-= mean(y)
            ylims = ignorenan_extrema(y)
            y /= (ylims[2] - ylims[1])
        end
        xlims --> extrema_plus_buffer(x, axis_buffer[1])
        ylims --> extrema_plus_buffer(y, axis_buffer[2])
        if is3d
            if method != :chorddiagram && numnothing > 0
                zlims = ignorenan_extrema(z)
                z .-= mean(z)
                z /= (zlims[2] - zlims[1])
            end
            zlims --> extrema_plus_buffer(z, axis_buffer[3])
        end
    end
    xyz = is3d ? (x, y, z) : (x, y)
    # Get the coordinates for the edges of the nodes.
    node_vec_vec_xy = []
    nodewidth = 0.0
    nodewidth_array = Vector{Float64}(undef, length(x))
    if !(nodeshape isa Array)
        nodeshape = repeat([nodeshape], length(x))
    end
    if !is3d
        for i ∈ eachindex(x)
            node_number =
                i % length(nodeshape) == 0 ? length(nodeshape) : i % length(nodeshape)
            node_weight =
                isnothing(node_weights) ? 1 :
                (10 + 100node_weights[i] / sum(node_weights)) / 50
            xextent, yextent = if isempty(names)
                [
                    x[i] .+ [-0.5nodesize * node_weight, 0.5nodesize * node_weight],
                    y[i] .+ [-0.5nodesize * node_weight, 0.5nodesize * node_weight],
                ]
            else
                annotation_extent(
                    plotattributes,
                    (
                        x[i],
                        y[i],
                        names[ifelse(
                            i % length(names) == 0,
                            length(names),
                            i % length(names),
                        )],
                        fontsize * nodesize * node_weight,
                    ),
                )
            end
            nodewidth = xextent[2] - xextent[1]
            nodewidth_array[i] = nodewidth
            if nodeshape[node_number] ≡ :circle
                push!(
                    node_vec_vec_xy,
                    partialcircle(0, 2π, [x[i], y[i]], 80, nodewidth / 2),
                )
            elseif (nodeshape[node_number] ≡ :rect) || (nodeshape[node_number] ≡ :rectangle)
                push!(
                    node_vec_vec_xy,
                    [
                        (xextent[1], yextent[1]),
                        (xextent[2], yextent[1]),
                        (xextent[2], yextent[2]),
                        (xextent[1], yextent[2]),
                        (xextent[1], yextent[1]),
                    ],
                )
            elseif nodeshape[node_number] ≡ :hexagon
                push!(node_vec_vec_xy, partialcircle(0, 2π, [x[i], y[i]], 7, nodewidth / 2))
            elseif nodeshape[node_number] ≡ :ellipse
                nodeheight = (yextent[2] - yextent[1])
                push!(
                    node_vec_vec_xy,
                    partialellipse(0, 2π, [x[i], y[i]], 80, nodewidth / 2, nodeheight / 2),
                )
            elseif applicable(nodeshape[node_number], x[i], y[i], 0.0, 0.0)
                nodeheight = (yextent[2] - yextent[1])
                push!(
                    node_vec_vec_xy,
                    nodeshape[node_number](x[i], y[i], nodewidth, nodeheight),
                )
            elseif applicable(nodeshape[node_number], x[i], y[i], 0.0)
                push!(node_vec_vec_xy, nodeshape[node_number](x[i], y[i], nodewidth))
            else
                error(
                    "Unknown nodeshape: $(nodeshape[node_number]). Choose from :circle, ellipse, :hexagon, :rect or :rectangle or or a custom shape. Custom shapes can be passed as a function customshape such that customshape(x, y, nodeheight, nodewidth) -> nodeperimeter/ customshape(x, y, nodescale) -> nodeperimeter. nodeperimeter must be an array of 2-tuples, where each tuple is a corner of your custom shape, centered at (x, y) and with height nodeheight, width nodewidth or only a nodescale for symmetrically scaling shapes.",
                )
            end
        end
    else
        @assert is3d # TODO Make 3d work.
    end
    # The node_perimter_info list contains the information needed to construct the
    # information in node_vec_vec_xy. For example, if (nodeshape[i]==:circle && !is3d),
    # then all of the information in node_vec_vec_xy[i] can be summarised with three
    # numbers describing the center and the radius of the circle.
    node_perimeter_info = []
    for i ∈ eachindex(node_vec_vec_xy)
        if nodeshape[i] ≡ :circle
            push!(
                node_perimeter_info,
                GeometryTypes.Circle(
                    Point((convert(T, x[i]), convert(T, y[i]))),
                    nodewidth_array[i] / 2,
                ),
            )
        else
            push!(node_perimeter_info, node_vec_vec_xy[i])
        end
    end

    # generate a list of colors, one per segment
    segment_colors = get(plotattributes, :linecolor, nothing)
    edge_label_array = Vector{Tuple}()
    edge_label_box_vertices_array = Vector{Array}()
    if !isa(edgelabel, Dict) && !isnothing(edgelabel)
        tmp = Dict()
        if length(size(edgelabel)) < 2
            matrix_size = round(Int, sqrt(length(edgelabel)))
            edgelabel = reshape(edgelabel, matrix_size, matrix_size)
        end
        for i ∈ 1:size(edgelabel)[1], j ∈ 1:size(edgelabel)[2]
            if islabel(edgelabel[i, j])
                tmp[(i, j)] = edgelabel[i, j]
            end
        end
        edgelabel = tmp
    end
    # If the edgelabel dictionary is full of length two tuples, then make all of the
    # tuples length three with last element 1. (i.e. a multigraph that has no extra
    # edges).
    if edgelabel isa Dict
        edgelabel = convert(Dict{Any,Any}, edgelabel)
        for key ∈ keys(edgelabel)
            if length(key) == 2
                edgelabel[(key..., 1)] = edgelabel[key]
            end
        end
    end
    edge_has_been_seen = Dict()
    for edge ∈ zip(source, destiny)
        edge_has_been_seen[edge] = 0
    end
    if length(curvature_scalar) == 1
        curvature_scalar = fill(curvature_scalar, size(adj_mat, 1), size(adj_mat, 1))
    end

    edges_list = (T[], T[], T[], T[])
    # TODO do a proper job of calculating nsegments.
    nsegments = if curves && (method in (:tree, :buchheim))
        4
    elseif method ≡ :chorddiagram
        3
    elseif method ≡ :arcdiagram
        30
    elseif curves
        50
    else
        2
    end

    for (edge_num, (si, di, wi)) ∈ enumerate(zip(source, destiny, weights))
        edge_has_been_seen[(si, di)] += 1
        xseg = Float64[]
        yseg = Float64[]
        zseg = Float64[]
        l_wg = Float64[]

        # add a line segment
        xsi, ysi, xdi, ydi = shorten_segment(x[si], y[si], x[di], y[di], shorten)
        θ = (edge_has_been_seen[(si, di)] - 1) * pi / 8
        if isdirected && si != di && !is3d
            xpt, ypt = if method != :chorddiagram
                control_point(
                    xsi,
                    xdi,
                    ysi,
                    ydi,
                    edge_has_been_seen[(si, di)] * curvature_scalar[si, di] * sign(si - di),
                )
            else
                (0.0, 0.0)
            end
            # For directed graphs, shorten the line segment so that the edge ends at
            # the perimeter of the destiny node.
            if isdirected
                _, _, xdi, ydi =
                    nearest_intersection(xpt, ypt, x[di], y[di], node_perimeter_info[di])
            end
        end
        if curves
            if method in (:tree, :buchheim)
                # for trees, shorten should be on one axis only
                # dist = sqrt((x[di]-x[si])^2 + (y[di]-y[si])^2) * shorten
                dist = shorten * (root in (:left, :bottom) ? 1 : -1)
                ishoriz = root in (:left, :right)
                xsi, xdi = (ishoriz ? (x[si] + dist, x[di] - dist) : (x[si], x[di]))
                ysi, ydi = (ishoriz ? (y[si], y[di]) : (y[si] + dist, y[di] - dist))
                xpts, ypts = directed_curve(
                    xsi,
                    xdi,
                    ysi,
                    ydi,
                    xview = get(plotattributes, :xlims, (0, 1)),
                    yview = get(plotattributes, :ylims, (0, 1)),
                    root = root,
                    rng = rng,
                )
                append!(xseg, xpts)
                append!(yseg, ypts)
                append!(l_wg, [wi for i ∈ 1:length(xpts)])
            elseif method ≡ :arcdiagram
                r = (xdi - xsi) / 2
                x₀ = (xdi + xsi) / 2
                θ = range(0, stop = π, length = 30)
                xpts = x₀ .+ r .* cos.(θ)
                ypts = r .* sin.(θ) .+ ysi # ysi == ydi
                for x ∈ xpts
                    push!(xseg, x)
                    push!(l_wg, wi)
                end
                # push!(xseg, NaN)
                for y ∈ ypts
                    push!(yseg, y)
                end
                # push!(yseg, NaN)
            else
                xpt, ypt = if method != :chorddiagram
                    control_point(
                        xsi,
                        x[di],
                        ysi,
                        y[di],
                        edge_has_been_seen[(si, di)] *
                        curvature_scalar[si, di] *
                        sign(si - di),
                    )
                else
                    (0.0, 0.0)
                end
                xpts = [xsi, xpt, xdi]
                ypts = [ysi, ypt, ydi]
                t = range(0, stop = 1, length = 3)
                A = hcat(xpts, ypts)
                itp = scale(interpolate(A, BSpline(Cubic(Natural(OnGrid())))), t, 1:2)
                tfine = range(0, stop = 1, length = nsegments)
                xpts, ypts = [itp(t, 1) for t ∈ tfine], [itp(t, 2) for t ∈ tfine]
                if !isnothing(edgelabel) &&
                   haskey(edgelabel, (si, di, edge_has_been_seen[(si, di)]))
                    q = control_point(
                        xsi,
                        x[di],
                        ysi,
                        y[di],
                        (
                            edgelabel_offset +
                            edge_has_been_seen[(si, di)] * curvature_scalar[si, di]
                        ) * sign(si - di),
                    )

                    if !any(isnan.(q))
                        push!(
                            edge_label_array,
                            (
                                q...,
                                string(edgelabel[(si, di, edge_has_been_seen[(si, di)])]),
                                fontsize,
                            ),
                        )
                        edge_label_box_vertices = (annotation_extent(
                            plotattributes,
                            (
                                q[1],
                                q[2],
                                edgelabel[(si, di, edge_has_been_seen[(si, di)])],
                                0.05fontsize,
                            ),
                        ))
                        push!(edge_label_box_vertices_array, edge_label_box_vertices)
                    end
                end
                if method != :chorddiagram && !is3d
                    append!(xseg, xpts)
                    append!(yseg, ypts)
                    push!(l_wg, wi)
                else
                    push!(xseg, xsi, xpt, xdi)
                    push!(yseg, ysi, ypt, ydi)
                    is3d && push!(zseg, z[si], z[si], z[di])
                    push!(l_wg, wi)
                end
            end
        else
            push!(xseg, xsi, xdi)
            push!(yseg, ysi, ydi)
            is3d && push!(zseg, z[si], z[di])
            if !isnothing(edgelabel) &&
               haskey(edgelabel, (si, di, edge_has_been_seen[(si, di)]))
                q = [(xsi + xdi) / 2, (ysi + ydi) / 2]

                if !any(isnan.(q))
                    push!(
                        edge_label_array,
                        (
                            q...,
                            string(edgelabel[(si, di, edge_has_been_seen[(si, di)])]),
                            fontsize,
                        ),
                    )
                    edge_label_box_vertices = (annotation_extent(
                        plotattributes,
                        (
                            q[1],
                            q[2],
                            edgelabel[(si, di, edge_has_been_seen[(si, di)])],
                            0.05fontsize,
                        ),
                    ))
                    push!(edge_label_box_vertices_array, edge_label_box_vertices)
                end
            end
        end
        if si == di && !is3d
            inds = 1:n .!= si
            self_edge_angle = pi / 8 + (edge_has_been_seen[(si, di)] - 1) * pi / 8
            θ1 = unoccupied_angle(xsi, ysi, x[inds], y[inds]) - self_edge_angle / 2
            θ2 = θ1 + self_edge_angle
            nodewidth = nodewidth_array[si]
            if nodeshape ≡ :circle
                xpts = [
                    xsi + nodewidth * cos(θ1) / 2,
                    NaN,
                    NaN,
                    NaN,
                    xsi + nodewidth * cos(θ2) / 2,
                ]
                xpts[2] =
                    mean([xpts[1], xpts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * cos(θ1)
                xpts[3] =
                    mean([xpts[1], xpts[end]]) +
                    edge_has_been_seen[(si, di)] * self_edge_size * cos((θ1 + θ2) / 2)
                xpts[4] =
                    mean([xpts[1], xpts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * cos(θ2)
                ypts = [
                    ysi + nodewidth * sin(θ1) / 2,
                    NaN,
                    NaN,
                    NaN,
                    ysi + nodewidth * sin(θ2) / 2,
                ]
                ypts[2] =
                    mean([ypts[1], ypts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * sin(θ1)
                ypts[3] =
                    mean([ypts[1], ypts[end]]) +
                    edge_has_been_seen[(si, di)] * self_edge_size * sin((θ1 + θ2) / 2)
                ypts[4] =
                    mean([ypts[1], ypts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * sin(θ2)
                t = range(0, stop = 1, length = 5)
                A = hcat(xpts, ypts)
                itp = scale(interpolate(A, BSpline(Cubic(Natural(OnGrid())))), t, 1:2)
                tfine = range(0, stop = 1, length = nsegments)
                xpts, ypts = [itp(t, 1) for t ∈ tfine], [itp(t, 2) for t ∈ tfine]
            else
                _, _, start_point1, start_point2 = nearest_intersection(
                    xsi,
                    ysi,
                    xsi + 2nodewidth * cos(θ1),
                    ysi + 2nodewidth * sin(θ1),
                    node_vec_vec_xy[si],
                )
                _, _, end_point1, end_point2 = nearest_intersection(
                    xsi +
                    edge_has_been_seen[(si, di)] * (nodewidth + self_edge_size) * cos(θ2),
                    ysi +
                    edge_has_been_seen[(si, di)] * (nodewidth + self_edge_size) * sin(θ2),
                    xsi,
                    ysi,
                    node_vec_vec_xy[si],
                )
                xpts = [start_point1, NaN, NaN, NaN, end_point1]
                xpts[2] =
                    mean([xpts[1], xpts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * cos(θ1)
                xpts[3] =
                    mean([xpts[1], xpts[end]]) +
                    edge_has_been_seen[(si, di)] * self_edge_size * cos((θ1 + θ2) / 2)
                xpts[4] =
                    mean([xpts[1], xpts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * cos(θ2)
                ypts = [start_point2, NaN, NaN, NaN, end_point2]
                ypts[2] =
                    mean([ypts[1], ypts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * sin(θ1)
                ypts[3] =
                    mean([ypts[1], ypts[end]]) +
                    edge_has_been_seen[(si, di)] * self_edge_size * sin((θ1 + θ2) / 2)
                ypts[4] =
                    mean([ypts[1], ypts[end]]) +
                    0.5 * (0.5 + edge_has_been_seen[(si, di)]) * self_edge_size * sin(θ2)
                t = range(0, stop = 1, length = 5)
                A = hcat(xpts, ypts)
                itp = scale(interpolate(A, BSpline(Cubic(Natural(OnGrid())))), t, 1:2)
                tfine = range(0, stop = 1, length = nsegments)
                xpts, ypts = [itp(t, 1) for t ∈ tfine], [itp(t, 2) for t ∈ tfine]
            end
            append!(xseg, xpts)
            append!(yseg, ypts)
            mid_ind = div(length(xpts), 2)
            q = [
                xpts[mid_ind] + edgelabel_offset * cos((θ1 + θ2) / 2),
                ypts[mid_ind] + edgelabel_offset * sin((θ1 + θ2) / 2),
            ]
            if !isnothing(edgelabel) &&
               haskey(edgelabel, (si, di, edge_has_been_seen[(si, di)]))
                push!(
                    edge_label_array,
                    (
                        q...,
                        string(edgelabel[(si, di, edge_has_been_seen[(si, di)])]),
                        fontsize,
                    ),
                )
                edge_label_box_vertices = annotation_extent(
                    plotattributes,
                    (q..., edgelabel[(si, di, edge_has_been_seen[(si, di)])], 0.05fontsize),
                )
                if !any(isnan.(q))
                    push!(edge_label_box_vertices_array, edge_label_box_vertices)
                end
            end
        end
        append!(edges_list[1], xseg[.!isnan.(xseg)])
        append!(edges_list[2], yseg[.!isnan.(yseg)])
        is3d && append!(edges_list[3], zseg[.!isnan.(zseg)])
        append!(edges_list[4], l_wg[.!isnan.(l_wg)])
    end

    if is3d
        edges_list = (
            reshape(edges_list[1], 3, round(Int, length(edges_list[1]) / 3)),
            reshape(edges_list[2], 3, round(Int, length(edges_list[2]) / 3)),
            reshape(edges_list[3], 3, round(Int, length(edges_list[3]) / 3)),
        )
    else
        edges_list = (
            reshape(
                edges_list[1],
                nsegments,
                round(Int, length(edges_list[1]) / nsegments),
            ),
            reshape(
                edges_list[2],
                nsegments,
                round(Int, length(edges_list[2]) / nsegments),
            ),
        )
        edges_list = (
            [edges_list[1][:, j] for j ∈ 1:size(edges_list[1], 2)],
            [edges_list[2][:, j] for j ∈ 1:size(edges_list[2], 2)],
        )
    end

    @series begin
        @debug num_edges_nodes := (length(edges_list[1]), length(node_vec_vec_xy))  # for debugging / tests

        seriestype := if method in (:tree, :buchheim, :chorddiagram)
            :curves
        else
            if is3d
                # TODO make curves work
                if curves
                    :curves
                end
            else
                :path
            end
        end

        colorbar_entry := true

        edge_z = process_edge_attribute(edge_z, source, destiny, weights)
        edgewidth = process_edge_attribute(edgewidth, source, destiny, weights)
        edgecolor = process_edge_attribute(edgecolor, source, destiny, weights)
        edgestyle = process_edge_attribute(edgestyle, source, destiny, weights)

        !isnothing(edge_z) && (line_z := edge_z)
        linewidthattr = get(plotattributes, :linewidth, 1)
        linewidth := linewidthattr * edgewidth
        fillalpha := 1
        linecolor := edgecolor
        linestyle := get(plotattributes, :linestyle, edgestyle)
        markershape := :none
        markersize := 0
        markeralpha := 0
        markercolor := :black
        marker_z := nothing
        isdirected && (arrow --> :simple, :head, 0.3, 0.3)
        primary := false

        is3d ? edges_list[1:3] : edges_list[1:2]
    end
    # The boxes around edge labels are defined as another list of series that sits on top
    # of the series for the edges.
    edge_has_been_seen = Dict()
    for edge ∈ zip(source, destiny)
        edge_has_been_seen[edge] = 0
    end
    index = 0
    if edge_label_box && !isnothing(edgelabel)
        for (edge_num, (si, di, wi)) ∈ enumerate(zip(source, destiny, weights))
            edge_has_been_seen[(si, di)] += 1
            if haskey(edgelabel, (si, di, edge_has_been_seen[(si, di)]))
                index += 1
                @series begin
                    seriestype := :shape

                    colorbar_entry --> false
                    fillcolor --> get(plotattributes, :background_color, :white)
                    linewidth --> 0
                    linealpha --> 0
                    edge_label_box_vertices = edge_label_box_vertices_array[index]
                    (
                        [
                            edge_label_box_vertices[1][1],
                            edge_label_box_vertices[1][2],
                            edge_label_box_vertices[1][2],
                            edge_label_box_vertices[1][1],
                            edge_label_box_vertices[1][1],
                        ],
                        [
                            edge_label_box_vertices[2][1],
                            edge_label_box_vertices[2][1],
                            edge_label_box_vertices[2][2],
                            edge_label_box_vertices[2][2],
                            edge_label_box_vertices[2][1],
                        ],
                    )
                end
            end
        end
    end

    framestyle := :none
    axis := nothing
    legend --> false

    # Make sure that the node properties are row vectors.
    nodeshape = format_nodeproperty(nodeshape, n_edges, index)
    nodesize = format_nodeproperty(nodesize, n_edges, index)
    nodecolor = format_nodeproperty(nodecolor, n_edges, index)
    node_z = format_nodeproperty(node_z, n_edges, index)
    nodestrokealpha = format_nodeproperty(nodestrokealpha, n_edges, index)
    nodealpha = format_nodeproperty(nodealpha, n_edges, index)
    nodestrokewidth = format_nodeproperty(nodestrokewidth, n_edges, index)
    nodestrokealpha = format_nodeproperty(nodestrokealpha, n_edges, index)
    nodestrokecolor = format_nodeproperty(nodestrokecolor, n_edges, index)
    nodestrokestyle =
        format_nodeproperty(nodestrokestyle, n_edges, index, fill_value = :solid)

    if method ≡ :chorddiagram
        seriestype := :scatter
        markersize := 0
        markeralpha := 0
        aspect_ratio --> :equal
        if length(names) == length(x)
            annotations := [(x[i], y[i], names[i]) for i ∈ eachindex(x)]
        end
        @series begin
            seriestype := :shape
            N = length(x)
            angles = Vector{Float64}(undef, N)
            for i ∈ 1:N
                if y[i] > 0
                    angles[i] = acos(x[i])
                else
                    angles[i] = 2pi - acos(x[i])
                end
            end
            δ = 0.4 * (angles[2] - angles[1])
            vec_vec_xy = [arcshape(Θ - δ, Θ + δ) for Θ ∈ angles] # Shape
            [[xy[1] for xy ∈ vec_xy] for vec_xy ∈ vec_vec_xy],
            [[xy[2] for xy ∈ vec_xy] for vec_xy ∈ vec_vec_xy]
        end
    else
        if is3d
            seriestype := :scatter3d
            linewidth := 0
            linealpha := 0
            markercolor := nodecolor
            series_annotations --> map(string, names)
            markersize --> (10 .+ (100 .* node_weights) ./ sum(node_weights))
        else
            @series begin
                seriestype := :shape

                colorbar_entry := true
                fill_z --> node_z
                fillalpha := nodealpha
                fillcolor := nodecolor
                markersize := 0
                markeralpha := 0
                linewidth := nodestrokewidth
                linealpha := nodestrokealpha
                linecolor := nodestrokecolor
                linestyle := nodestrokestyle
                line_z := nodestroke_z

                nodeperimeters = (Any[], Any[])
                for vec_xy ∈ node_vec_vec_xy
                    push!(nodeperimeters[1], [xy[1] for xy ∈ vec_xy])
                    push!(nodeperimeters[2], [xy[2] for xy ∈ vec_xy])
                end

                nodeperimeters

                # if is3d
                #     seriestype := :volume
                #     ([[xyz[1] for xyz in vec_xyz] for vec_xyz in node_vec_vec_xyz],
                #      [[xyz[2] for xyz in vec_xyz] for vec_xyz in node_vec_vec_xyz],
                #      [[xyz[3] for xyz in vec_xyz] for vec_xyz in node_vec_vec_xyz])
                # end
            end

            if isempty(names)
                seriestype := :scatter

                colorbar_entry --> false
                markersize := 0
                markeralpha := 0
                markerstrokesize := 0
                !isnothing(edgelabel) && (annotations --> edge_label_array)
            else
                seriestype := :scatter

                colorbar_entry --> false
                markersize := 0
                markeralpha := 0
                markerstrokesize := 0
                annotations --> [
                    edge_label_array
                    [
                        (
                            x[i],
                            y[i],
                            names[ifelse(
                                i % length(names) == 0,
                                length(names),
                                i % length(names),
                            )],
                            fontsize,
                        ) for i ∈ eachindex(x)
                    ]
                ]
            end
        end
    end
    xyz
end

@recipe f(g::AbstractGraph) = GraphPlot(get_source_destiny_weight(get_adjacency_list(g)))
