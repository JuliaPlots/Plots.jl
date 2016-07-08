

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

const _series_recipe_deps = Dict()

function series_recipe_dependencies(st::Symbol, deps::Symbol...)
    _series_recipe_deps[st] = deps
end

function seriestype_supported(st::Symbol)
    seriestype_supported(backend(), st)
end

# returns :no, :native, or :recipe depending on how it's supported
function seriestype_supported(pkg::AbstractBackend, st::Symbol)
    # is it natively supported
    if st in supported_types(pkg)
        return :native
    end
    
    haskey(_series_recipe_deps, st) || return :no

    supported = true
    for dep in _series_recipe_deps[st]
        if seriestype_supported(pkg, dep) == :no
            supported = false
        end
    end
    supported ? :recipe : :no
end

macro deps(st, args...)
    :(series_recipe_dependencies($(quot(st)), $(map(quot, args)...)))
end

# get a list of all seriestypes
function all_seriestypes()
    sts = Set{Symbol}(keys(_series_recipe_deps))
    for bsym in backends()
        btype = _backendType[bsym]
        sts = union(sts, Set{Symbol}(supported_types(btype())))
    end
    sort(collect(sts))
end


# ----------------------------------------------------------------------------------


num_series(x::AMat) = size(x,2)
num_series(x) = 1


RecipesBase.apply_recipe{T}(d::KW, ::Type{T}, plt::Plot) = throw(MethodError("Unmatched plot recipe: $T"))



if is_installed("DataFrames")
    @eval begin
        import DataFrames

        # if it's one symbol, set the guide and return the column
        function handle_dfs(df::DataFrames.AbstractDataFrame, d::KW, letter, sym::Symbol)
            get!(d, Symbol(letter * "guide"), string(sym))
            collect(df[sym])
        end

        # if it's an array of symbols, set the labels and return a Vector{Any} of columns
        function handle_dfs(df::DataFrames.AbstractDataFrame, d::KW, letter, syms::AbstractArray{Symbol})
            get!(d, :label, reshape(syms, 1, length(syms)))
            Any[collect(df[s]) for s in syms]
        end

        # for anything else, no-op
        function handle_dfs(df::DataFrames.AbstractDataFrame, d::KW, letter, anything)
            anything
        end

        # handle grouping by DataFrame column
        function extractGroupArgs(group::Symbol, df::DataFrames.AbstractDataFrame, args...)
            extractGroupArgs(collect(df[group]))
        end

        # if a DataFrame is the first arg, lets swap symbols out for columns
        @recipe function f(df::DataFrames.AbstractDataFrame, args...)
            # if any of these attributes are symbols, swap out for the df column
            for k in (:fillrange, :line_z, :marker_z, :markersize, :ribbon, :weights, :xerror, :yerror)
                if haskey(d, k) && isa(d[k], Symbol)
                    d[k] = collect(df[d[k]])
                end
            end

            # return a list of new arguments
            tuple(Any[handle_dfs(df, d, (i==1 ? "x" : i==2 ? "y" : "z"), arg) for (i,arg) in enumerate(args)]...)
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
@deps line path

# @recipe function f(::Type{Val{:sticks}}, x, y, z)
#     nx = length(x)
#     n = 3nx
#     newx, newy = zeros(n), zeros(n)
#     for i=1:nx
#         rng = 3i-2:3i
#         newx[rng] = x[i]
#         newy[rng] = [0., y[i], 0.]
#     end
#     x := newx
#     y := newy
#     seriestype := :path
#     ()
# end
# @deps sticks path

function hvline_limits(axis::Axis)
    vmin, vmax = axis_limits(axis)
    if vmin >= vmax
        if isfinite(vmin)
            vmax = vmin + 1
        else
            vmin, vmax = 0.0, 1.1
        end
    end
    vmin, vmax
end

@recipe function f(::Type{Val{:hline}}, x, y, z)
    xmin, xmax = hvline_limits(d[:subplot][:xaxis])
    n = length(y)
    newx = repmat(Float64[xmin, xmax, NaN], n)
    newy = vec(Float64[yi for i=1:3,yi=y])
    x := newx
    y := newy
    seriestype := :path
    ()
end
@deps hline path

@recipe function f(::Type{Val{:vline}}, x, y, z)
    ymin, ymax = hvline_limits(d[:subplot][:yaxis])
    n = length(y)
    newx = vec(Float64[yi for i=1:3,yi=y])
    newy = repmat(Float64[ymin, ymax, NaN], n)
    x := newx
    y := newy
    seriestype := :path
    ()
end
@deps vline path

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
@deps steppre path scatter

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
@deps steppost path scatter


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
@deps sticks path scatter


# ---------------------------------------------------------------------------
# bezier curves

# get the value of the curve point at position t 
function bezier_value(pts::AVec, t::Real)
    val = 0.0
    n = length(pts)-1
    for (i,p) in enumerate(pts)
        val += p * binomial(n, i-1) * (1-t)^(n-i+1) * t^(i-1)
    end
    val
end

# create segmented bezier curves in place of line segments
@recipe function f(::Type{Val{:curves}}, x, y, z; npoints = 30)
    args = z != nothing ? (x,y,z) : (x,y)
    newx, newy = zeros(0), zeros(0)
    fr = d[:fillrange]
    newfr = fr != nothing ? zeros(0) : nothing
    newz = z != nothing ? zeros(0) : nothing
    # lz = d[:line_z]
    # newlz = lz != nothing ? zeros(0) : nothing

    # for each line segment (point series with no NaNs), convert it into a bezier curve
    # where the points are the control points of the curve
    for rng in iter_segments(args...)
        length(rng) < 2 && continue
        ts = linspace(0, 1, npoints)
        nanappend!(newx, map(t -> bezier_value(cycle(x,rng), t), ts))
        nanappend!(newy, map(t -> bezier_value(cycle(y,rng), t), ts))
        if z != nothing
            nanappend!(newz, map(t -> bezier_value(cycle(z,rng), t), ts))
        end
        if fr != nothing
            nanappend!(newfr, map(t -> bezier_value(cycle(fr,rng), t), ts))
        end
        # if lz != nothing
        #     lzrng = cycle(lz, rng) # the line_z's for this segment
        #     push!(newlz, 0.0)
        #     append!(newlz, map(t -> lzrng[1+floor(Int, t * (length(rng)-1))], ts))
        # end
    end

    x := newx
    y := newy
    if z == nothing
        seriestype := :path
    else
        seriestype := :path3d
        z := newz
    end
    if fr != nothing
        fillrange := newfr
    end
    # if lz != nothing
    #     # line_z := newlz
    #     linecolor := (isa(d[:linecolor], ColorGradient) ? d[:linecolor] : cgrad())
    # end
    # Plots.DD(d)
    ()
end
@deps curves path

# ---------------------------------------------------------------------------

# create a bar plot as a filled step function
@recipe function f(::Type{Val{:bar}}, x, y, z)
    nx, ny = length(x), length(y)
    axis = d[:subplot][isvertical(d) ? :xaxis : :yaxis]
    cv = [discrete_value!(axis, xi)[1] for xi=x]
    x = if nx == ny
        cv
    elseif nx == ny + 1
        0.5diff(cv) + cv[1:end-1]
    else
        error("bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    end

    # compute half-width of bars
    bw = d[:bar_width]
    hw = if bw == nothing
        0.5mean(diff(x))
    else
        Float64[0.5cycle(bw,i) for i=1:length(x)]
    end

    # make fillto a vector... default fills to 0
    fillto = d[:fillrange]
    if fillto == nothing
        fillto = 0
    end

    # create the bar shapes by adding x/y segments
    xseg, yseg = Segments(), Segments()
    for i=1:ny
        center = x[i]
        hwi = cycle(hw,i)
        yi = y[i]
        fi = cycle(fillto,i)
        push!(xseg, center-hwi, center-hwi, center+hwi, center+hwi, center-hwi)
        push!(yseg, yi, fi, fi, yi, yi)
    end

    # switch back
    if !isvertical(d)
        xseg, yseg = yseg, xseg
    end

    x := xseg.pts
    y := yseg.pts
    seriestype := :shape
    ()
end
@deps bar shape

# ---------------------------------------------------------------------------
# Histograms

# edges from number of bins
function calc_edges(v, bins::Integer)
    vmin, vmax = extrema(v)
    linspace(vmin, vmax, bins+1)
end

# just pass through arrays
calc_edges(v, bins::AVec) = bins

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
@deps histogram bar

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
    linewidth := 0
    seriestype := :heatmap
    ()
end
@deps histogram2d heatmap


# ---------------------------------------------------------------------------
# scatter 3d

@recipe function f(::Type{Val{:scatter3d}}, x, y, z)
    seriestype := :path3d
    if d[:markershape] == :none
        markershape := :circle
    end
    linewidth := 0
    linealpha := 0
    ()
end

# note: don't add dependencies because this really isn't a drop-in replacement

# ---------------------------------------------------------------------------
# Box Plot

const _box_halfwidth = 0.4

notch_width(q2, q4, N) = 1.58 * (q4-q2)/sqrt(N)


@recipe function f(::Type{Val{:boxplot}}, x, y, z; notch=false, range=1.5)
    xsegs, ysegs = Segments(), Segments()
    glabels = sort(collect(unique(x)))
    warning = false
    outliers_x, outliers_y = zeros(0), zeros(0)
    for (i,glabel) in enumerate(glabels)
        # filter y
        values = y[filter(i -> cycle(x,i) == glabel, 1:length(y))]

        # compute quantiles
        q1,q2,q3,q4,q5 = quantile(values, linspace(0,1,5))
        
        # notch
        n = notch_width(q2, q4, length(values))

        # warn on inverted notches?
        if notch && !warning && ( (q2>(q3-n)) || (q4<(q3+n)) )
            warn("Boxplot's notch went outside hinges. Set notch to false.")
            warning = true # Show the warning only one time
        end

        # make the shape
        center = discrete_value!(d[:subplot][:xaxis], glabel)[1]
        hw = d[:bar_width] == nothing ? _box_halfwidth : 0.5cycle(d[:bar_width], i)
        l, m, r = center - hw, center, center + hw
        
        # internal nodes for notches
        L, R = center - 0.5 * hw, center + 0.5 * hw
        
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
        if notch
            push!(xsegs, m, l, r, m, m)       # lower T
            push!(xsegs, l, l, L, R, r, r, l) # lower box
            push!(xsegs, l, l, L, R, r, r, l) # upper box
            push!(xsegs, m, l, r, m, m)       # upper T

            push!(ysegs, q1, q1, q1, q1, q2)             # lower T
            push!(ysegs, q2, q3-n, q3, q3, q3-n, q2, q2) # lower box
            push!(ysegs, q4, q3+n, q3, q3, q3+n, q4, q4) # upper box
            push!(ysegs, q5, q5, q5, q5, q4)             # upper T
        else
            push!(xsegs, m, l, r, m, m)         # lower T
            push!(xsegs, l, l, r, r, l)         # lower box
            push!(xsegs, l, l, r, r, l)         # upper box
            push!(xsegs, m, l, r, m, m)         # upper T

            push!(ysegs, q1, q1, q1, q1, q2)    # lower T
            push!(ysegs, q2, q3, q3, q2, q2)    # lower box
            push!(ysegs, q4, q3, q3, q4, q4)    # upper box
            push!(ysegs, q5, q5, q5, q5, q4)    # upper T
        end
    end

    # Outliers
    @series begin
        seriestype  := :scatter
        markershape := :circle
        markercolor := d[:fillcolor]
        markeralpha := d[:fillalpha]
        markerstrokecolor := d[:linecolor]
        markerstrokealpha := d[:linealpha]
        x           := outliers_x
        y           := outliers_y
        primary     := false
        ()
    end

    seriestype := :shape
    x := xsegs.pts
    y := ysegs.pts
    ()
end
@deps boxplot shape scatter

# ---------------------------------------------------------------------------
# Violin Plot

const _violin_warned = [false]

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
        if !_violin_warned[1]
            warn("Install the KernelDensity package for best results.")
            _violin_warned[1] = true
        end
        edges, widths = my_hist(y, 10)
        centers = 0.5 * (edges[1:end-1] + edges[2:end])
        ymin, ymax = extrema(y)
        vcat(0.0, widths, 0.0), vcat(ymin, centers, ymax)
    end
end


@recipe function f(::Type{Val{:violin}}, x, y, z; trim=true)
    xsegs, ysegs = Segments(), Segments()
    glabels = sort(collect(unique(x)))
    for glabel in glabels
        widths, centers = violin_coords(y[filter(i -> cycle(x,i) == glabel, 1:length(y))], trim=trim)
        isempty(widths) && continue

        # normalize
        widths = _box_halfwidth * widths / maximum(widths)

        # make the violin
        xcenter = discrete_value!(d[:subplot][:xaxis], glabel)[1]
        xcoords = vcat(widths, -reverse(widths)) + xcenter
        ycoords = vcat(centers, reverse(centers))

        push!(xsegs, xcoords)
        push!(ysegs, ycoords)
    end

    seriestype := :shape
    x := xsegs.pts
    y := ysegs.pts
    ()
end
@deps violin shape

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
    ()
end
@deps density path

# ---------------------------------------------------------------------------
# contourf - filled contours

@recipe function f(::Type{Val{:contourf}}, x, y, z)
    fillrange := true
    seriestype := :contour
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
@deps yerror path

@recipe function f(::Type{Val{:xerror}}, x, y, z)
    error_style!(d)
    markershape := :vline
    d[:y], d[:x] = error_coords(d[:y], d[:x], error_zipit(d[:xerror]))
    ()
end
@deps xerror path


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
@deps quiver shape path


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

# TODO: everything below here should be either changed to a
#       series recipe or moved to PlotRecipes


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
