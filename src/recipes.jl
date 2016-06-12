

# TODO: there should be a distinction between an object that will manage a full plot, vs a component of a plot.
# the PlotRecipe as currently implemented is more of a "custom component"
# a recipe should fully describe the plotting command(s) and call them, likewise for updating.
#   actually... maybe those should explicitly derive from AbstractPlot???


"""
You can easily define your own plotting recipes with convenience methods:

```
@userplot type GroupHist
    args
end

@recipe function f(gh::GroupHist)
    # set some attributes, add some series, using gh.args as input
end

# now you can plot like:
grouphist(rand(1000,4))
```
"""
macro userplot(expr)
    _userplot(expr)
end

function _userplot(expr::Expr)
    if expr.head != :type
        errror("Must call userplot on a type/immutable expression.  Got: $expr")
    end

    typename = expr.args[2]
    funcname = Symbol(lowercase(string(typename)))
    funcname2 = Symbol(funcname, "!")

    # return a code block with the type definition and convenience plotting methods
    esc(quote
        $expr
        export $funcname, $funcname2
        $funcname(args...; kw...) = plot($typename(args); kw...)
        $funcname2(args...; kw...) = plot!($typename(args); kw...)
    end)
end

function _userplot(sym::Symbol)
    _userplot(:(type $sym
            args
    end))
end


# ----------------------------------------------------------------------------------




# ----------------------------------------------------------------------------------

abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)

num_series(x::AMat) = size(x,2)
num_series(x) = 1


# # if it's not a recipe, just do nothing and return the args
# function RecipesBase.apply_recipe(d::KW, args...; issubplot=false)
#     if issubplot && !isempty(args) && !haskey(d, :n) && !haskey(d, :layout)
#         # put in a sensible default
#         d[:n] = maximum(map(num_series, args))
#     end
#     args
# end


if is_installed("DataFrames")
    @eval begin
        import DataFrames
        DFS = Union{Symbol, AbstractArray{Symbol}}

        function handle_dfs(df::DataFrames.AbstractDataFrame, d::KW, letter, dfs::DFS)
            if isa(dfs, Symbol)
                get!(d, Symbol(letter * "guide"), string(dfs))
                collect(df[dfs])
            else
                get!(d, :label, reshape(dfs, 1, length(dfs)))
                Any[collect(df[s]) for s in dfs]
            end
        end

        function extractGroupArgs(group::Symbol, df::DataFrames.AbstractDataFrame, args...)
            extractGroupArgs(collect(df[group]))
        end


        function handle_group(df::DataFrames.AbstractDataFrame, d::KW)
            if haskey(d, :group)
                g = d[:group]
                if isa(g, Symbol)
                    d[:group] = collect(df[g])
                end
            end
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sy::DFS)
            handle_group(df, d)
            handle_dfs(df, d, "y", sy)
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sx::DFS, sy::DFS)
            handle_group(df, d)
            x = handle_dfs(df, d, "x", sx)
            y = handle_dfs(df, d, "y", sy)
            x, y
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sx::DFS, sy::DFS, sz::DFS)
            handle_group(df, d)
            x = handle_dfs(df, d, "x", sx)
            y = handle_dfs(df, d, "y", sy)
            z = handle_dfs(df, d, "z", sz)
            x, y, z
        end
    end
end


# ---------------------------------------------------------------------------

# """
# `apply_series_recipe` should take a processed series KW dict and break it up
# into component parts.  For example, a box plot is made up of `shape` for the
# boxes, `path` for the lines, and `scatter` for the outliers.
#
# Returns a Vector{KW}.
# """
# apply_series_recipe(d::KW, st) = KW[d]


# for seriestype `line`, need to sort by x values
@recipe function f(::Type{Val{:line}}, x, y, z)
    indices = sortperm(x)
    x := x[indices]
    y := y[indices]
    if typeof(z) <: AVec
        z := z[indices]
    end
    seriestype := :path
    ()
end

@recipe function f(::Type{Val{:sticks}}, x, y, z)
    nx = length(x)
    n = 3nx
    newx, newy = zeros(n), zeros(n)
    for i=1:nx
        rng = 3i-2:3i
        newx[rng] = x[i]
        newy[rng] = [0., y[i], 0.]
    end
    x := newx
    y := newy
    seriestype := :path
    ()
end

@recipe function f(::Type{Val{:hline}}, x, y, z)
    xmin, xmax = axis_limits(d[:subplot][:xaxis])
    n = length(y)
    newx = repmat(Float64[xmin, xmax, NaN], n)
    newy = vec(Float64[yi for i=1:3,yi=y])
    x := newx
    y := newy
    seriestype := :path
    ()
end

@recipe function f(::Type{Val{:vline}}, x, y, z)
    ymin, ymax = axis_limits(d[:subplot][:yaxis])
    n = length(y)
    newx = vec(Float64[yi for i=1:3,yi=y])
    newy = repmat(Float64[ymin, ymax, NaN], n)
    x := newx
    y := newy
    seriestype := :path
    ()
end

# ---------------------------------------------------------------------------
# steps

function make_steps(x, y, st)
    n = length(x)
    newx, newy = zeros(2n-1), zeros(2n-1)
    for i=1:n
        idx = 2i-1
        newx[idx] = x[i]
        newy[idx] = y[i]
        if i > 1
            newx[idx-1] = x[st == :steppre ? i-1 : i]
            newy[idx-1] = y[st == :steppre ? i   : i-1]
        end
    end
    newx, newy
end

# create a path from steps
@recipe function f(::Type{Val{:steppre}}, x, y, z)
    d[:x], d[:y] = make_steps(x, y, :steppre)
    seriestype := :path

    # create a secondary series for the markers
    if d[:markershape] != :none
        @series begin
            seriestype := :scatter
            x := x
            y := y
            label := ""
            primary := false
            ()
        end
        markershape := :none
    end
    ()
end

# create a path from steps
@recipe function f(::Type{Val{:steppost}}, x, y, z)
    d[:x], d[:y] = make_steps(x, y, :steppost)
    seriestype := :path

    # create a secondary series for the markers
    if d[:markershape] != :none
        @series begin
            seriestype := :scatter
            x := x
            y := y
            label := ""
            primary := false
            ()
        end
        markershape := :none
    end
    ()
end


# ---------------------------------------------------------------------------
# sticks

sticks_fillfrom(fr::Void, i::Integer) = 0.0
sticks_fillfrom(fr::Number, i::Integer) = fr
sticks_fillfrom(fr::AVec, i::Integer) = fr[mod1(i, length(fr))]

# create vertical line segments from fill
@recipe function f(::Type{Val{:sticks}}, x, y, z)
    n = length(x)
    fr = d[:fillrange]
    newx, newy = zeros(3n), zeros(3n)
    for i=1:n
        rng = 3i-2:3i
        newx[rng] = [x[i], x[i], NaN]
        newy[rng] = [sticks_fillfrom(fr,i), y[i], NaN]
    end
    x := newx
    y := newy
    fillrange := nothing
    seriestype := :path

    # create a secondary series for the markers
    if d[:markershape] != :none
        @series begin
            seriestype := :scatter
            x := x
            y := y
            label := ""
            primary := false
            ()
        end
        markershape := :none
    end
    ()
end


# ---------------------------------------------------------------------------

# create a bar plot as a filled step function
@recipe function f(::Type{Val{:bar}}, x, y, z)
    nx, ny = length(x), length(y)
    edges = if nx == ny
        # x is centers, calc the edges
        # TODO: use bar_width, etc
        midpoints = x
        halfwidths = diff(midpoints) * 0.5
        Float64[if i == 1
            midpoints[1] - halfwidths[1]
        elseif i == ny+1
            midpoints[i-1] + halfwidths[i-2]
        else
            midpoints[i-1] + halfwidths[i-1]
        end for i=1:ny+1]
    elseif nx == ny + 1
        # x is edges
        x
    else
        error("bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    end

    # make fillto a vector... default fills to 0
    fillto = d[:fillrange]
    if fillto == nothing
        fillto = zeros(1)
    elseif isa(fillto, Number)
        fillto = Float64[fillto]
    end
    nf = length(fillto)

    npts = 3ny + 1
    heights = y
    x = zeros(npts)
    y = zeros(npts)
    fillrng = zeros(npts)

    # create the path in triplets.  after the first bottom-left coord of the first bar:
    # add the top-left, top-right, and bottom-right coords for each height
    x[1] = edges[1]
    y[1] = fillto[1]
    fillrng[1] = fillto[1]
    for i=1:ny
        idx = 3i
        rng = idx-1:idx+1
        fi = fillto[mod1(i,nf)]
        x[rng] = [edges[i], edges[i+1], edges[i+1]]
        y[rng] = [heights[i], heights[i], fi]
        fillrng[rng] = [fi, fi, fi]
    end

    x := x
    y := y
    fillrange := fillrng
    seriestype := :path
    ()
end

# ---------------------------------------------------------------------------
# Histograms

# edges from number of bins
function calc_edges(v, bins::Integer)
    vmin, vmax = extrema(v)
    linspace(vmin, vmax, bins+1)
end

# just pass through arrays
calc_edges(v, bins::AVec) = v

# find the bucket index of this value
function bucket_index(vi, edges)
    for (i,e) in enumerate(edges)
        if vi <= e
            return max(1,i-1)
        end
    end
    return length(edges)-1
end

function my_hist(v, bins; normed = false, weights = nothing)
    edges = calc_edges(v, bins)
    counts = zeros(length(edges)-1)

    # add a weighted count
    for (i,vi) in enumerate(v)
        idx = bucket_index(vi, edges)
        counts[idx] += (weights == nothing ? 1.0 : weights[i])
    end

    # normalize by bar area?
    norm_denom = normed ? sum(diff(edges) .* counts) : 1.0
    if norm_denom == 0
        norm_denom = 1.0
    end

    edges, counts ./ norm_denom
end


@recipe function f(::Type{Val{:histogram}}, x, y, z)
    edges, counts = my_hist(y, d[:bins],
                               normed = d[:normalize],
                               weights = d[:weights])
    x := edges
    y := counts
    seriestype := :bar
    ()
end

# ---------------------------------------------------------------------------
# Histogram 2D

# if tuple, map out bins, otherwise use the same for both
calc_edges_2d(x, y, bins) = calc_edges(x, bins), calc_edges(y, bins)
calc_edges_2d{X,Y}(x, y, bins::Tuple{X,Y}) = calc_edges(x, bins[1]), calc_edges(y, bins[2])

# the 2D version
function my_hist_2d(x, y, bins; normed = false, weights = nothing)
    xedges, yedges = calc_edges_2d(x, y, bins)
    counts = zeros(length(yedges)-1, length(xedges)-1)

    # add a weighted count
    for i=1:length(x)
        r = bucket_index(y[i], yedges)
        c = bucket_index(x[i], xedges)
        counts[r,c] += (weights == nothing ? 1.0 : weights[i])
    end

    # normalize to cubic area of the imaginary surface towers
    norm_denom = normed ? sum((diff(yedges) * diff(xedges)') .* counts) : 1.0
    if norm_denom == 0
        norm_denom = 1.0
    end

    xedges, yedges, counts ./ norm_denom
end

centers(v::AVec) = v[1] + cumsum(diff(v))

@recipe function f(::Type{Val{:histogram2d}}, x, y, z)
    xedges, yedges, counts = my_hist_2d(x, y, d[:bins],
                                              normed = d[:normalize],
                                              weights = d[:weights])
    x := centers(xedges)
    y := centers(yedges)
    z := Surface(counts)
    seriestype := :heatmap
    ()
end


# ---------------------------------------------------------------------------
# scatter 3d

@recipe function f(::Type{Val{:scatter3d}}, x, y, z)
    seriestype := :path3d
    if d[:markershape] == :none
        markershape := :ellipse
    end
    linewidth := 0
    linealpha := 0
    ()
end

# ---------------------------------------------------------------------------
# Box Plot

const _box_halfwidth = 0.4

notch_width(q2, q4, N) = 1.58 * (q4-q2)/sqrt(N)

# function apply_series_recipe(d::KW, ::Type{Val{:box}})
@recipe function f(::Type{Val{:boxplot}}, x, y, z; notch=false, range=1.5)
    # Plots.dumpdict(d, "box before", true)

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    groupby = extractGroupArgs(x)
    outliers_y = Float64[]
    outliers_x = Float64[]

    warning = false

    for (i, glabel) in enumerate(groupby.groupLabels)

        # filter y values
        values = d[:y][groupby.groupIds[i]]
        # then compute quantiles
        q1,q2,q3,q4,q5 = quantile(values, linspace(0,1,5))
        # notch
        n = notch_width(q2, q4, length(values))

        if notch && !warning && ( (q2>(q3-n)) || (q4<(q3+n)) )
            warn("Boxplot's notch went outside hinges. Set notch to false.")
            warning = true # Show the warning only one time
        end

        # make the shape
        center = discrete_value!(d[:subplot][:xaxis], glabel)[1]
        l, m, r = center - _box_halfwidth, center, center + _box_halfwidth
        # internal nodes for notches
        L, R = center - 0.5 * _box_halfwidth, center + 0.5 * _box_halfwidth
        # outliers
        if Float64(range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
            limit = range*(q4-q2)
            inside = Float64[]
            for value in values
                if (value < (q2 - limit)) || (value > (q4 + limit))
                    push!(outliers_y, value)
                    push!(outliers_x, center)
                else
                    push!(inside, value)
                end
            end
            # change q1 and q5 to show outliers
            # using maximum and minimum values inside the limits
            q1, q5 = extrema(inside)
        end
        # Box
        xcoords = notch::Bool ? [
            m, l, r, m, m, NaN,       # lower T
            l, l, L, R, r, r, l, NaN, # lower box
            l, l, L, R, r, r, l, NaN, # upper box
            m, l, r, m, m, NaN,       # upper T
        ] : [
            m, l, r, m, m, NaN,         # lower T
            l, l, r, r, l, NaN,         # lower box
            l, l, r, r, l, NaN,         # upper box
            m, l, r, m, m, NaN,         # upper T
        ]
        ycoords = notch::Bool ? [
            q1, q1, q1, q1, q2, NaN,             # lower T
            q2, q3-n, q3, q3, q3-n, q2, q2, NaN, # lower box
            q4, q3+n, q3, q3, q3+n, q4, q4, NaN, # upper box
            q5, q5, q5, q5, q4, NaN,             # upper T
        ] : [
            q1, q1, q1, q1, q2, NaN,    # lower T
            q2, q3, q3, q2, q2, NaN,    # lower box
            q4, q3, q3, q4, q4, NaN,    # upper box
            q5, q5, q5, q5, q4, NaN,    # upper T
        ]
        push!(shapes, Shape(xcoords, ycoords))
    end

    # d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))

    seriestype := :shape
    # n = length(groupby.groupLabels)
    # xticks --> (linspace(0.5,n-0.5,n), groupby.groupLabels)

    # clean d
    pop!(d, :notch)
    pop!(d, :range)

    # we want to set the fields directly inside series recipes... args are ignored
    d[:x], d[:y] = Plots.shape_coords(shapes)

    # Outliers
    @series begin
        seriestype := :scatter
        markershape := :ellipse
        x := outliers_x
        y := outliers_y
        label := ""
        primary := false
        ()
    end

    () # expects a tuple returned

    # KW[d]
end

# ---------------------------------------------------------------------------
# Violin Plot

# if the user has KernelDensity installed, use this for violin plots.
# otherwise, just use a histogram
if is_installed("KernelDensity")
    @eval import KernelDensity
    @eval function violin_coords(y; trim::Bool=false)
        kd = KernelDensity.kde(y, npoints = 200)
        if trim
            xmin, xmax = extrema(y)
            inside = Bool[ xmin <= x <= xmax for x in kd.x]
            return(kd.density[inside], kd.x[inside])
        end
        kd.density, kd.x
    end
else
    @eval function violin_coords(y; trim::Bool=false)
        edges, widths = hist(y, 30)
        centers = 0.5 * (edges[1:end-1] + edges[2:end])
        ymin, ymax = extrema(y)
        vcat(0.0, widths, 0.0), vcat(ymin, centers, ymax)
    end
end


# function apply_series_recipe(d::KW, ::Type{Val{:violin}})
@recipe function f(::Type{Val{:violin}}, x, y, z; trim=true)
    # dumpdict(d, "box before", true)
    # TODO: add scatter series with outliers

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    groupby = extractGroupArgs(d[:x])

    for (i, glabel) in enumerate(groupby.groupLabels)

        # get the edges and widths
        y = d[:y][groupby.groupIds[i]]
        widths, centers = violin_coords(y, trim=trim)

        # normalize
        widths = _box_halfwidth * widths / maximum(widths)

        # make the violin
        xcenter = discrete_value!(d[:subplot][:xaxis], glabel)[1]
        xcoords = vcat(widths, -reverse(widths)) + xcenter
        ycoords = vcat(centers, reverse(centers))
        push!(shapes, Shape(xcoords, ycoords))
    end

    # d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))
    seriestype := :shape
    # n = length(groupby.groupLabels)
    # xticks --> (linspace(0.5,n-0.5,n), groupby.groupLabels)

    # clean up d
    pop!(d, :trim)

    d[:x], d[:y] = shape_coords(shapes)
    ()

    # KW[d]
end

# ---------------------------------------------------------------------------
# density

@recipe function f(::Type{Val{:density}}, x, y, z; trim=false)
    newx, newy = violin_coords(y, trim=trim)
    if isvertical(d)
        newx, newy = newy, newx
    end
    x := newx
    y := newy
    seriestype := :path

    # clean up d
    pop!(d, :trim)

    ()
end



# ---------------------------------------------------------------------------
# Error Bars

function error_style!(d::KW)
    d[:seriestype] = :path
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
        xi = cycle(xorig, i)
        yi = cycle(yorig, i)
        ebi = cycle(ebar, i)
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
@recipe function f(::Type{Val{:yerror}}, x, y, z)
    error_style!(d)
    markershape := :hline
    d[:x], d[:y] = error_coords(d[:x], d[:y], error_zipit(d[:yerror]))
    ()
end

@recipe function f(::Type{Val{:xerror}}, x, y, z)
    error_style!(d)
    markershape := :vline
    d[:y], d[:x] = error_coords(d[:y], d[:x], error_zipit(d[:xerror]))
    ()
end


# ---------------------------------------------------------------------------
# quiver

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
function quiver_using_arrows(d::KW)
    d[:label] = ""
    d[:seriestype] = :path
    if !isa(d[:arrow], Arrow)
        d[:arrow] = arrow()
    end

    velocity = error_zipit(d[:quiver])
    xorig, yorig = d[:x], d[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    x, y = zeros(0), zeros(0)
    for i = 1:max(length(xorig), length(yorig))
        # get the starting position
        xi = cycle(xorig, i)
        yi = cycle(yorig, i)

        # get the velocity
        vi = cycle(velocity, i)
        vx, vy = if istuple(vi)
            first(vi), last(vi)
        elseif isscalar(vi)
            vi, vi
        elseif isa(vi,Function)
            vi(xi, yi)
        else
            error("unexpected vi type $(typeof(vi)) for quiver: $vi")
        end

        # add the points
        nanappend!(x, [xi, xi+vx, NaN])
        nanappend!(y, [yi, yi+vy, NaN])
    end

    d[:x], d[:y] = x, y
    # KW[d]
end

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
function quiver_using_hack(d::KW)
    d[:label] = ""
    d[:seriestype] = :shape

    velocity = error_zipit(d[:quiver])
    xorig, yorig = d[:x], d[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    pts = P2[]
    for i = 1:max(length(xorig), length(yorig))

        # get the starting position
        xi = cycle(xorig, i)
        yi = cycle(yorig, i)
        p = P2(xi, yi)

        # get the velocity
        vi = cycle(velocity, i)
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
    # KW[d]
end

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
@recipe function f(::Type{Val{:quiver}}, x, y, z)
    if :arrow in supported_args()
        quiver_using_arrows(d)
    else
        quiver_using_hack(d)
    end
    ()
end


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

# function rotate(x::Real, y::Real, θ::Real; center = (0,0))
#   cx = x - center[1]
#   cy = y - center[2]
#   xrot = cx * cos(θ) - cy * sin(θ)
#   yrot = cy * cos(θ) + cx * sin(θ)
#   xrot + center[1], yrot + center[2]
# end
#
# # ---------------------------------------------------------------------------
#
# type EllipseRecipe <: PlotRecipe
#   w::Float64
#   h::Float64
#   x::Float64
#   y::Float64
#   θ::Float64
# end
# EllipseRecipe(w,h,x,y) = EllipseRecipe(w,h,x,y,0)
#
# # return x,y coords of a rotated ellipse, centered at the origin
# function rotatedEllipse(w, h, x, y, θ, rotθ)
#   # # coord before rotation
#   xpre = w * cos(θ)
#   ypre = h * sin(θ)
#
#   # rotate and translate
#   r = rotate(xpre, ypre, rotθ)
#   x + r[1], y + r[2]
# end
#
# function getRecipeXY(ep::EllipseRecipe)
#   x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
#   top = rotate(0, ep.h, ep.θ)
#   right = rotate(ep.w, 0, ep.θ)
#   linex = Float64[top[1], 0, right[1]] + ep.x
#   liney = Float64[top[2], 0, right[2]] + ep.y
#   Any[x, linex], Any[y, liney]
# end
#
# function getRecipeArgs(ep::EllipseRecipe)
#   [(:line, (3, [:dot :solid], [:red :blue], :path))]
# end

# -------------------------------------------------

# TODO: this should really be in another package...
type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end
Base.convert(::Type{OHLC}, tup::Tuple) = OHLC(tup...)
# Base.tuple(ohlc::OHLC) = (ohlc.open, ohlc.high, ohlc.low, ohlc.close)

# get one OHLC path
function get_xy(o::OHLC, x, xdiff)
    xl, xm, xr = x-xdiff, x, x+xdiff
    ox = [xl, xm, NaN,
          xm, xm, NaN,
          xm, xr]
    oy = [o.open, o.open, NaN,
          o.low, o.high, NaN,
          o.close, o.close]
    ox, oy
end

# get the joined vector
function get_xy(v::AVec{OHLC}, x = 1:length(v))
    xdiff = 0.3mean(abs(diff(x)))
    x_out, y_out = zeros(0), zeros(0)
    for (i,ohlc) in enumerate(v)
        ox,oy = get_xy(ohlc, x[i], xdiff)
        nanappend!(x_out, ox)
        nanappend!(y_out, oy)
    end
    x_out, y_out
end

# these are for passing in a vector of OHLC objects
# TODO: when I allow `@recipe f(::Type{T}, v::T) = ...` definitions to replace convertToAnyVector,
#       then I should replace these with one definition to convert to a vector of 4-tuples

# to squash ambiguity warnings...
@recipe f(x::AVec{Function}, v::AVec{OHLC}) = error()
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(x::AVec{Function}, v::AVec{Tuple{R1,R2,R3,R4}}) = error()

# this must be OHLC?
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(x::AVec, ohlc::AVec{Tuple{R1,R2,R3,R4}}) = x, OHLC[OHLC(t...) for t in ohlc]

@recipe function f(x::AVec, v::AVec{OHLC})
    seriestype := :path
    get_xy(v, x)
end

@recipe function f(v::AVec{OHLC})
    seriestype := :path
    get_xy(v)
end

# the series recipe, when passed vectors of 4-tuples

# -------------------------------------------------


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
