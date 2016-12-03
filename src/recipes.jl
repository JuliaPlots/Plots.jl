


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
    if is_seriestype_supported(pkg, st)
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
    :(Plots.series_recipe_dependencies($(quot(st)), $(map(quot, args)...)))
end

# get a list of all seriestypes
function all_seriestypes()
    sts = Set{Symbol}(keys(_series_recipe_deps))
    for bsym in backends()
        btype = _backendType[bsym]
        sts = union(sts, Set{Symbol}(supported_seriestypes(btype())))
    end
    sort(collect(sts))
end


# ----------------------------------------------------------------------------------

num_series(x::AMat) = size(x,2)
num_series(x) = 1

RecipesBase.apply_recipe{T}(d::KW, ::Type{T}, plt::Plot) = throw(MethodError("Unmatched plot recipe: $T"))

# ---------------------------------------------------------------------------


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
    n == 0 && return zeros(0),zeros(0)
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

# create vertical line segments from fill
@recipe function f(::Type{Val{:sticks}}, x, y, z)
    n = length(x)
    fr = d[:fillrange]
    if fr == nothing
        yaxis = d[:subplot][:yaxis]
        fr = if yaxis[:scale] == :identity
            0.0
        else
            min(axis_limits(yaxis)[1], minimum(y))
        end
    end
    newx, newy = zeros(3n), zeros(3n)
    for i=1:n
        rng = 3i-2:3i
        newx[rng] = [x[i], x[i], NaN]
        newy[rng] = [cycle(fr,i), y[i], NaN]
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

    # widen limits out a bit
    expand_extrema!(axis, widen(extrema(xseg.pts)...))

    # switch back
    if !isvertical(d)
        xseg, yseg = yseg, xseg
    end


    # reset orientation
    orientation := default(:orientation)

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

centers(v::AVec) = 0.5 * (v[1:end-1] + v[2:end])

@recipe function f(::Type{Val{:histogram2d}}, x, y, z)
    xedges, yedges, counts = my_hist_2d(x, y, d[:bins],
                                              normed = d[:normalize],
                                              weights = d[:weights])
    for (i,c) in enumerate(counts)
        if c == 0
            counts[i] = NaN
        end
    end
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
    x, y = Array(float_extended_type(xorig), 0), Array(Float64, 0)
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


# TODO: move quiver to PlotRecipes

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
    if :arrow in supported_attrs()
        quiver_using_arrows(d)
    else
        quiver_using_hack(d)
    end
    ()
end
@deps quiver shape path


# -------------------------------------------------

# TODO: move OHLC to PlotRecipes finance.jl

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


# "Sparsity plot... heatmap of non-zero values of a matrix"
# function spy{T<:Real}(z::AMat{T}; kw...)
#     mat = map(zi->float(zi!=0), z)'
#     xn, yn = size(mat)
#     heatmap(mat; leg=false, yflip=true, aspect_ratio=:equal,
#         xlim=(0.5, xn+0.5), ylim=(0.5, yn+0.5),
#         kw...)
# end

# Only allow matrices through, and make it seriestype :spy so the backend can
# optionally handle it natively.

@userplot Spy

@recipe function f(g::Spy)
    @assert length(g.args) == 1 && typeof(g.args[1]) <: AbstractMatrix
    seriestype := :spy
    mat = g.args[1]
    n,m = size(mat)
    Plots.SliceIt, 1:m, 1:n, Surface(mat)
end

@recipe function f(::Type{Val{:spy}}, x,y,z)
    yflip := true
    aspect_ratio := 1
    rs, cs, zs = findnz(z.surf)
    xlim := extrema(cs)
    ylim := extrema(rs)
    if d[:markershape] == :none
        markershape := :circle
    end
    if d[:markersize] == default(:markersize)
        markersize := 1
    end
    markerstrokewidth := 0
    marker_z := zs
    label := ""
    x := cs
    y := rs
    z := nothing
    seriestype := :scatter
    ()
end

# -------------------------------------------------

"Adds a+bx... straight line over the current plot"
function abline!(plt::Plot, a, b; kw...)
    plot!(plt, [extrema(plt)...], x -> b + a*x; kw...)
end

abline!(args...; kw...) = abline!(current(), args...; kw...)


# -------------------------------------------------
# Dates

@recipe f(::Type{Date}, dt::Date) = (dt -> convert(Int,dt), dt -> string(convert(Date,dt)))
@recipe f(::Type{DateTime}, dt::DateTime) = (dt -> convert(Int,dt), dt -> string(convert(DateTime,dt)))

# -------------------------------------------------
# Complex Numbers

@userplot ComplexPlot
@recipe function f(cp::ComplexPlot)
    xguide --> "Real Part"
    yguide --> "Imaginary Part"
    seriestype --> :scatter
    real(cp.args[1]), imag(cp.args[1])
end
