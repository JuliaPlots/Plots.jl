

# TODO: there should be a distinction between an object that will manage a full plot, vs a component of a plot.
# the PlotRecipe as currently implemented is more of a "custom component"
# a recipe should fully describe the plotting command(s) and call them, likewise for updating.
#   actually... maybe those should explicitly derive from AbstractPlot???

abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)

num_series(x::AMat) = size(x,2)
num_series(x) = 1

_apply_recipe(d::KW; kw...) = ()

# if it's not a recipe, just do nothing and return the args
function _apply_recipe(d::KW, args...; issubplot=false, kw...)
    if issubplot && !haskey(d, :n) && !haskey(d, :layout)
        # put in a sensible default
        d[:n] = maximum(map(num_series, args))
    end
    args
end

macro kw(k, v)
    esc(:(get!(d, $k, $v)))
end

macro plotrecipe(args, expr)
    if !isa(args, Expr)
        error("The first argument to `@plotrecipe` should be a valid argument list for dispatch.")
    end

    # wrap the args in a tuple
    if args.head != :tuple
        args = Expr(:tuple, args)
    end

    # replace all the key => value lines with argument setting logic
    # TODO: when this is moved out of Plots, also move the replacement of key aliases to just after the _apply_recipe calls
    for (i,e) in enumerate(expr.args)
        if isa(e,Expr) && e.head == :(=>)
            k, v = e.args[1:2]
            expr.args[i] = :(get!(d, get(Plots._keyAliases, $k, $k), $v))
        end
    end

    # now build a function definition for _apply_recipe, wrapping the return value in a tuple if needed
    esc(quote
        function Plots._apply_recipe(d::KW, $(args.args...); kw...)
            ret = $expr
            if typeof(ret) <: Tuple
                ret
            else
                (ret,)
            end
        end
    end)
end


# ---------------------------------------------------------------------------

"""
`apply_series_recipe` should take a processed series KW dict and break it up
into component parts.  For example, a box plot is made up of `shape` for the
boxes, `path` for the lines, and `scatter` for the outliers.

Returns a Vector{KW}.
"""
apply_series_recipe(d::KW, lt) = KW[d]

# ---------------------------------------------------------------------------
# Box Plot

const _box_halfwidth = 0.4

function apply_series_recipe(d::KW, ::Type{Val{:box}})
    # dumpdict(d, "box before", true)
    # TODO: add scatter series with outliers

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    d[:linetype] = :shape
    groupby = extractGroupArgs(d[:x])

    for (i, glabel) in enumerate(groupby.groupLabels)

        # filter y values, then compute quantiles
        q1,q2,q3,q4,q5 = quantile(d[:y][groupby.groupIds[i]], linspace(0,1,5))

        # make the shape
        l, m, r = i - _box_halfwidth, i, i + _box_halfwidth
        xcoords = [
            m, l, r, m, m, NaN,         # lower T
            l, l, r, r, l, NaN,         # lower box
            l, l, r, r, l, NaN,         # upper box
            m, l, r, m, m               # upper T
        ]
        ycoords = [
            q1, q1, q1, q1, q2, NaN,    # lower T
            q2, q3, q3, q2, q2, NaN,    # lower box
            q4, q3, q3, q4, q4, NaN,    # upper box
            q5, q5, q5, q5, q4, NaN,    # upper T
        ]
        push!(shapes, Shape(xcoords, ycoords))
    end

    d[:x], d[:y] = shape_coords(shapes)
    d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))

    KW[d]
end

# ---------------------------------------------------------------------------
# Violin Plot

# if the user has KernelDensity installed, use this for violin plots.
# otherwise, just use a histogram
try
    Pkg.installed("KernelDensity")
    import KernelDensity

    # warn("using KD for violin")
    @eval function violin_coords(y)
        kd = KernelDensity.kde(y, npoints = 30)
        kd.density, kd.x
    end
catch
    # warn("using hist for violin")
    @eval function violin_coords(y)
        edges, widths = hist(y, 20)
        centers = 0.5 * (edges[1:end-1] + edges[2:end])
        ymin, ymax = extrema(y)
        vcat(0.0, widths, 0.0), vcat(ymin, centers, ymax)
    end
end


function apply_series_recipe(d::KW, ::Type{Val{:violin}})
    # dumpdict(d, "box before", true)
    # TODO: add scatter series with outliers

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    d[:linetype] = :shape
    groupby = extractGroupArgs(d[:x])

    for (i, glabel) in enumerate(groupby.groupLabels)

        # get the edges and widths
        y = d[:y][groupby.groupIds[i]]
        widths, centers = violin_coords(y)

        # normalize
        widths = _box_halfwidth * widths / maximum(widths)

        # make the violin
        xcoords = vcat(widths, -reverse(widths)) + i
        ycoords = vcat(centers, reverse(centers))
        push!(shapes, Shape(xcoords, ycoords))
    end

    d[:x], d[:y] = shape_coords(shapes)
    d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))

    KW[d]
end

# ---------------------------------------------------------------------------
# Error Bars

function error_style!(d::KW)
    d[:linetype] = :path
    d[:linecolor] = d[:markerstrokecolor]
    d[:linewidth] = d[:markerstrokewidth]
    d[:label] = ""
end

# if we're passed a tuple of vectors, convert to a vector of tuples
function error_zipit(ebar)
    if istuple(ebar)
        collect(zip(ebar...))
    else
        ebar
    end
end

function error_coords(xorig, yorig, ebar)
    # init empty x/y, and zip errors if passed Tuple{Vector,Vector}
    x, y = zeros(0), zeros(0)

    # for each point, create a line segment from the bottom to the top of the errorbar
    for i = 1:max(length(xorig), length(yorig))
        xi = get_mod(xorig, i)
        yi = get_mod(yorig, i)
        ebi = get_mod(ebar, i)
        nanappend!(x, [xi, xi])
        e1, e2 = if istuple(ebi)
            first(ebi), last(ebi)
        elseif isscalar(ebi)
            ebi, ebi
        else
            error("unexpected ebi type $(typeof(ebi)) for errorbar: $ebi")
        end
        nanappend!(y, [yi - e1, yi + e2])
    end
    x, y
end

# we will create a series of path segments, where each point represents one
# side of an errorbar
function apply_series_recipe(d::KW, ::Type{Val{:yerror}})
    error_style!(d)
    d[:markershape] = :hline
    d[:x], d[:y] = error_coords(d[:x], d[:y], error_zipit(d[:yerror]))
    KW[d]
end

function apply_series_recipe(d::KW, ::Type{Val{:xerror}})
    error_style!(d)
    d[:markershape] = :vline
    d[:y], d[:x] = error_coords(d[:y], d[:x], error_zipit(d[:xerror]))
    KW[d]
end


# ---------------------------------------------------------------------------
# quiver

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
#     d[:label] = ""
#     d[:linetype] = :scatter
#
#     # create a second series to draw the arrow shaft
#     dpath = copy(d)
#     error_style!(dpath)
#     dpath[:markershape] = :none
#
#     velocity = error_zipit(d[:quiver])
#     xorig, yorig = d[:x], d[:y]
#
#     # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
#     # x, y = zeros(0), zeros(0)
#     paths = P2[]
#     arrows = P2[]
#     arrowshapes = Shape[]
#     for i = 1:max(length(xorig), length(yorig))
#
#         # get the starting position
#         xi = get_mod(xorig, i)
#         yi = get_mod(yorig, i)
#         p = P2(xi, yi)
#
#         # get the velocity
#         vi = get_mod(velocity, i)
#         vx, vy = if istuple(vi)
#             first(vi), last(vi)
#         elseif isscalar(vi)
#             vi, vi
#         else
#             error("unexpected vi type $(typeof(vi)) for quiver: $vi")
#         end
#         v = P2(vx, vy)
#
#         nanappend!(paths, [p, p+v])
#         push!(arrows, p+v)
#         push!(arrowshapes, makearrowhead(compute_angle(v)))
#
#         # # dist = sqrt(vx^2 + vy^2)
#         # dist = norm(v)
#         # arrow_h = 0.1dist          # height of arrowhead
#         # arrow_w = 0.5arrow_h       # halfwidth of arrowhead
#         # U1 = v ./ dist             # vector of arrowhead height
#         # U2 = P2(-U1[2], U1[1])     # vector of arrowhead halfwidth
#         # U1 *= arrow_h
#         # U2 *= arrow_w
#         #
#         # append!(pts, P2(xi, yi) .+ P2[(0,0), v-U1, v-U1+U2, v, v-U1-U2, v-U1, (NaN,NaN)])
#         # # a1 = v - arrow_h * U1 + arrow_w * U2
#         # # a2 = v - arrow_h * U1 - arrow_w * U2
#         # # nanappend!(x, xi + [0.0, vx, a1[1], a2[1], vx])
#         # # nanappend!(y, yi + [0.0, vy, a1[2], a2[2], vy])
#     end
#
#     # d[:x], d[:y] = Plots.unzip(pts)
#     dpath[:x], dpath[:y] = Plots.unzip(paths)
#     d[:x], d[:y] = Plots.unzip(arrows)
#     d[:markershape] = arrowshapes
#
#     KW[dpath, d]
# end

function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
    d[:label] = ""
    d[:linetype] = :shape

    velocity = error_zipit(d[:quiver])
    xorig, yorig = d[:x], d[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    pts = P2[]
    for i = 1:max(length(xorig), length(yorig))

        # get the starting position
        xi = get_mod(xorig, i)
        yi = get_mod(yorig, i)
        p = P2(xi, yi)

        # get the velocity
        vi = get_mod(velocity, i)
        vx, vy = if istuple(vi)
            first(vi), last(vi)
        elseif isscalar(vi)
            vi, vi
        elseif isa(vi,Function)
            vi(xi, yi)
        else
            error("unexpected vi type $(typeof(vi)) for quiver: $vi")
        end
        v = P2(vx, vy)

        dist = norm(v)
        arrow_h = 0.1dist          # height of arrowhead
        arrow_w = 0.5arrow_h       # halfwidth of arrowhead
        U1 = v ./ dist             # vector of arrowhead height
        U2 = P2(-U1[2], U1[1])     # vector of arrowhead halfwidth
        U1 *= arrow_h
        U2 *= arrow_w

        ppv = p+v
        nanappend!(pts, P2[p, ppv-U1, ppv-U1+U2, ppv, ppv-U1-U2, ppv-U1])
    end

    d[:x], d[:y] = Plots.unzip(pts[2:end])
    KW[d]
end



# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

function rotate(x::Real, y::Real, θ::Real; center = (0,0))
  cx = x - center[1]
  cy = y - center[2]
  xrot = cx * cos(θ) - cy * sin(θ)
  yrot = cy * cos(θ) + cx * sin(θ)
  xrot + center[1], yrot + center[2]
end

# ---------------------------------------------------------------------------

type EllipseRecipe <: PlotRecipe
  w::Float64
  h::Float64
  x::Float64
  y::Float64
  θ::Float64
end
EllipseRecipe(w,h,x,y) = EllipseRecipe(w,h,x,y,0)

# return x,y coords of a rotated ellipse, centered at the origin
function rotatedEllipse(w, h, x, y, θ, rotθ)
  # # coord before rotation
  xpre = w * cos(θ)
  ypre = h * sin(θ)

  # rotate and translate
  r = rotate(xpre, ypre, rotθ)
  x + r[1], y + r[2]
end

function getRecipeXY(ep::EllipseRecipe)
  x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
  top = rotate(0, ep.h, ep.θ)
  right = rotate(ep.w, 0, ep.θ)
  linex = Float64[top[1], 0, right[1]] + ep.x
  liney = Float64[top[2], 0, right[2]] + ep.y
  Any[x, linex], Any[y, liney]
end

function getRecipeArgs(ep::EllipseRecipe)
  [(:line, (3, [:dot :solid], [:red :blue], :path))]
end

# # -------------------------------------------------


"Sparsity plot... heatmap of non-zero values of a matrix"
function spy{T<:Real}(z::AMat{T}; kw...)
    mat = map(zi->float(zi!=0), z)'
    xn, yn = size(mat)
    heatmap(mat; leg=false, yflip=true, aspect_ratio=:equal,
        xlim=(0.5, xn+0.5), ylim=(0.5, yn+0.5),
        kw...)
end

"Adds a+bx... straight line over the current plot"
function abline!(plt::Plot, a, b; kw...)
    plot!(plt, [extrema(plt)...], x -> b + a*x; kw...)
end

abline!(args...; kw...) = abline!(current(), args...; kw...)

# =================================================
# Arc and chord diagrams

"Takes an adjacency matrix and returns source, destiny and weight lists"
function mat2list{T}(mat::AbstractArray{T,2})
    nrow, ncol = size(mat) # rows are sources and columns are destinies

    nosymmetric = !issym(mat) # plots only triu for symmetric matrices
    nosparse = !issparse(mat) # doesn't plot zeros from a sparse matrix

    L = length(mat)

    source  = Array(Int, L)
    destiny = Array(Int, L)
    weight  = Array(T, L)

    idx = 1
    for i in 1:nrow, j in 1:ncol
        value = mat[i, j]
        if !isnan(value) && ( nosparse || value != zero(T) ) # TODO: deal with Nullable

            if i < j
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            elseif nosymmetric && (i > j)
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            end

        end
    end

    resize!(source, idx-1), resize!(destiny, idx-1), resize!(weight, idx-1)
end

# ---------------------------------------------------------------------------
# Arc Diagram

curvecolor(value, min, max, grad) = getColorZ(grad, (value-min)/(max-min))

"Plots a clockwise arc, from source to destiny, colored by weight"
function arc!(source, destiny, weight, min, max, grad)
    radius = (destiny - source) / 2
    arc = Plots.partialcircle(0, π, 30, radius)
    x, y = Plots.unzip(arc)
    plot!(x .+ radius .+ source,  y, line = (curvecolor(weight, min, max, grad), 0.5, 2), legend=false)
end

"""
`arcdiagram(source, destiny, weight[, grad])`

Plots an arc diagram, form `source` to `destiny` (clockwise), using `weight` to determine the colors.
"""
function arcdiagram(source, destiny, weight; kargs...)

    args = KW(kargs)
    grad = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))

    if length(source) == length(destiny) == length(weight)

        vertices = unique(vcat(source, destiny))
        sort!(vertices)

        xmin, xmax = extrema(vertices)
        plot(xlim=(xmin - 0.5, xmax + 0.5), legend=false)

        wmin,wmax = extrema(weight)

        for (i, j, value) in zip(source,destiny,weight)
            arc!(i, j, value, wmin, wmax, grad)
        end

        scatter!(vertices, zeros(length(vertices)); legend=false, args...)

    else

        throw(ArgumentError("source, destiny and weight should have the same length"))

    end
end

"""
`arcdiagram(mat[, grad])`

Plots an arc diagram from an adjacency matrix, form rows to columns (clockwise),
using the values on the matrix as weights to determine the colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
"""
arcdiagram{T}(mat::AbstractArray{T,2}; kargs...) = arcdiagram(mat2list(mat)...; kargs...)

# ---------------------------------------------------------------------------
# Chord diagram

arcshape(θ1, θ2) = Shape(vcat(Plots.partialcircle(θ1, θ2, 15, 1.1),
                            reverse(Plots.partialcircle(θ1, θ2, 15, 0.9))))

colorlist(grad, ::Void) = :darkgray

function colorlist(grad, z)
    zmin, zmax = extrema(z)
    RGBA{Float64}[getColorZ(grad, (zi-zmin)/(zmax-zmin)) for zi in z]'
end

"""
`chorddiagram(source, destiny, weight[, grad, zcolor, group])`

Plots a chord diagram, form `source` to `destiny`,
using `weight` to determine the edge colors using `grad`.
`zcolor` or `group` can be used to determine the node colors.
"""
function chorddiagram(source, destiny, weight; kargs...)

    args  = KW(kargs)
    grad  = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))
    zcolor= pop!(args, :zcolor, nothing)
    group = pop!(args, :group,  nothing)

    if zcolor !== nothing && group !== nothing
        throw(ErrorException("group and zcolor can not be used together."))
    end

    if length(source) == length(destiny) == length(weight)

        plt = plot(xlim=(-2,2), ylim=(-2,2), legend=false, grid=false,
        xticks=nothing, yticks=nothing,
        xlim=(-1.2,1.2), ylim=(-1.2,1.2))

        nodemin, nodemax = extrema(vcat(source, destiny))

        weightmin, weightmax = extrema(weight)

        A  = 1.5π # Filled space
        B  = 0.5π # White space (empirical)

        Δα = A / nodemax
        Δβ = B / nodemax

        δ = Δα  + Δβ

        for i in 1:length(source)
            curve = BezierCurve(P2[ (cos((source[i ]-1)*δ + 0.5Δα), sin((source[i ]-1)*δ + 0.5Δα)), (0,0),
                                    (cos((destiny[i]-1)*δ + 0.5Δα), sin((destiny[i]-1)*δ + 0.5Δα)) ])
            plot!(curve_points(curve), line = (Plots.curvecolor(weight[i], weightmin, weightmax, grad), 1, 1))
        end

        if group === nothing
            c =  colorlist(grad, zcolor)
        elseif length(group) == nodemax

            idx = collect(0:(nodemax-1))

            for g in group
                plot!([arcshape(n*δ, n*δ + Δα) for n in idx[group .== g]]; args...)
            end

            return plt

        else
            throw(ErrorException("group should the ", nodemax, " elements."))
        end

        plot!([arcshape(n*δ, n*δ + Δα) for n in 0:(nodemax-1)]; mc=c, args...)

        return plt

    else
        throw(ArgumentError("source, destiny and weight should have the same length"))
    end
end

"""
`chorddiagram(mat[, grad, zcolor, group])`

Plots a chord diagram from an adjacency matrix,
using the values on the matrix as weights to determine edge colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
`zcolor` or `group` can be used to determine the node colors.
"""
chorddiagram(mat::AbstractMatrix; kargs...) = chorddiagram(mat2list(mat)...; kargs...)
