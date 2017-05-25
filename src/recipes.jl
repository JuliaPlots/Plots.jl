


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
            min(axis_limits(yaxis)[1], _minimum(y))
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
    procx, procy, xscale, yscale, baseline = _preprocess_barlike(d, x, y)
    nx, ny = length(procx), length(procy)
    axis = d[:subplot][isvertical(d) ? :xaxis : :yaxis]
    cv = [discrete_value!(axis, xi)[1] for xi=procx]
    procx = if nx == ny
        cv
    elseif nx == ny + 1
        0.5diff(cv) + cv[1:end-1]
    else
        error("bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    end

    # compute half-width of bars
    bw = d[:bar_width]
    hw = if bw == nothing
        0.5_mean(diff(procx))
    else
        Float64[0.5cycle(bw,i) for i=1:length(procx)]
    end

    # make fillto a vector... default fills to 0
    fillto = d[:fillrange]
    if fillto == nothing
        fillto = 0
    end
    if (yscale in _logScales) && !all(_is_positive, fillto)
        fillto = map(x -> _is_positive(x) ? typeof(baseline)(x) : baseline, fillto)
    end

    # create the bar shapes by adding x/y segments
    xseg, yseg = Segments(), Segments()
    for i=1:ny
        yi = procy[i]
        if !isnan(yi)
            center = procx[i]
            hwi = cycle(hw,i)
            fi = cycle(fillto,i)
            push!(xseg, center-hwi, center-hwi, center+hwi, center+hwi, center-hwi)
            push!(yseg, yi, fi, fi, yi, yi)
        end
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

_bin_centers(v::AVec) = (v[1:end-1] + v[2:end]) / 2

_is_positive(x) = (x > 0) && !(x ≈ 0)

_positive_else_nan{T}(::Type{T}, x::Real) = _is_positive(x) ? T(x) : T(NaN)

function _scale_adjusted_values{T<:AbstractFloat}(::Type{T}, V::AbstractVector, scale::Symbol)
    if scale in _logScales
        [_positive_else_nan(T, x) for x in V]
    else
        [T(x) for x in V]
    end
end


function _binbarlike_baseline{T<:Real}(min_value::T, scale::Symbol)
    if (scale in _logScales)
        !isnan(min_value) ? min_value / T(_logScaleBases[scale]^log10(2)) : T(1E-3)
    else
        zero(T)
    end
end


function _preprocess_binbarlike_weights{T<:AbstractFloat}(::Type{T}, w, wscale::Symbol)
    w_adj = _scale_adjusted_values(T, w, wscale)
    w_min = _minimum(w_adj)
    w_max = _maximum(w_adj)
    baseline = _binbarlike_baseline(w_min, wscale)
    w_adj, baseline
end

function _preprocess_barlike(d, x, y)
    xscale = get(d, :xscale, :identity)
    yscale = get(d, :yscale, :identity)
    weights, baseline = _preprocess_binbarlike_weights(float(eltype(y)), y, yscale)
    x, weights, xscale, yscale, baseline
end

function _preprocess_binlike(d, x, y)
    xscale = get(d, :xscale, :identity)
    yscale = get(d, :yscale, :identity)
    T = float(promote_type(eltype(x), eltype(y)))
    edge = T.(x)
    weights, baseline = _preprocess_binbarlike_weights(T, y, yscale)
    edge, weights, xscale, yscale, baseline
end


@recipe function f(::Type{Val{:barbins}}, x, y, z)
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(d, x, y)
    if (d[:bar_width] == nothing)
        bar_width := diff(edge)
    end
    x := _bin_centers(edge)
    y := weights
    seriestype := :bar
    ()
end
@deps barbins bar


@recipe function f(::Type{Val{:scatterbins}}, x, y, z)
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(d, x, y)
    xerror := diff(edge)/2
    x := _bin_centers(edge)
    y := weights
    seriestype := :scatter
    ()
end
@deps scatterbins scatter


function _stepbins_path(edge, weights, baseline::Real, xscale::Symbol, yscale::Symbol)
    log_scale_x = xscale in _logScales
    log_scale_y = yscale in _logScales

    nbins = length(linearindices(weights))
    if length(linearindices(edge)) != nbins + 1
        error("Edge vector must be 1 longer than weight vector")
    end

    x = eltype(edge)[]
    y = eltype(weights)[]

    it_e, it_w = start(edge), start(weights)
    a, it_e = next(edge, it_e)
    last_w = eltype(weights)(NaN)
    i = 1
    while (!done(edge, it_e) && !done(edge, it_e))
        b, it_e = next(edge, it_e)
        w, it_w = next(weights, it_w)

        if (log_scale_x && a ≈ 0)
            a = b/_logScaleBases[xscale]^3
        end

        if isnan(w)
            if !isnan(last_w)
                push!(x, a)
                push!(y, baseline)
            end
        else
            if isnan(last_w)
                push!(x, a)
                push!(y, baseline)
            end
            push!(x, a)
            push!(y, w)
            push!(x, b)
            push!(y, w)
        end

        a = b
        last_w = w
    end
    if (last_w != baseline)
        push!(x, a)
        push!(y, baseline)
    end

    (x, y)
end


@recipe function f(::Type{Val{:stepbins}}, x, y, z)
    axis = d[:subplot][Plots.isvertical(d) ? :xaxis : :yaxis]

    edge, weights, xscale, yscale, baseline = _preprocess_binlike(d, x, y)

    xpts, ypts = _stepbins_path(edge, weights, baseline, xscale, yscale)
    if !isvertical(d)
        xpts, ypts = ypts, xpts
    end

    # create a secondary series for the markers
    if d[:markershape] != :none
        @series begin
            seriestype := :scatter
            x := _bin_centers(edge)
            y := weights
            fillrange := nothing
            label := ""
            primary := false
            ()
        end
        markershape := :none
        xerror := :none
        yerror := :none
    end

    x := xpts
    y := ypts
    seriestype := :path
    ()
end
Plots.@deps stepbins path


function _auto_binning_nbins{N}(vs::NTuple{N,AbstractVector}, dim::Integer; mode::Symbol = :auto)
    _cl(x) = max(ceil(Int, x), 1)
    _iqr(v) = quantile(v, 0.75) - quantile(v, 0.25)
    _span(v) = _maximum(v) - _minimum(v)

    n_samples = length(linearindices(first(vs)))
    # Estimator for number of samples in one row/column of bins along each axis:
    n = max(1, n_samples^(1/N))

    v = vs[dim]

    if mode == :auto
        30
    elseif mode == :sqrt  # Square-root choice
        _cl(sqrt(n))
    elseif mode == :sturges  # Sturges' formula
        _cl(log2(n)) + 1
    elseif mode == :rice  # Rice Rule
        _cl(2 * n^(1/3))
    elseif mode == :scott  # Scott's normal reference rule
        _cl(_span(v) / (3.5 * std(v) / n^(1/3)))
    elseif mode == :fd  # Freedman–Diaconis rule
        _cl(_span(v) / (2 * _iqr(v) / n^(1/3)))
    else
        error("Unknown auto-binning mode $mode")
    end::Int
end

_hist_edge{N}(vs::NTuple{N,AbstractVector}, dim::Integer, binning::Integer) = StatsBase.histrange(vs[dim], binning, :left)
_hist_edge{N}(vs::NTuple{N,AbstractVector}, dim::Integer, binning::Symbol) = _hist_edge(vs, dim, _auto_binning_nbins(vs, dim, mode = binning))
_hist_edge{N}(vs::NTuple{N,AbstractVector}, dim::Integer, binning::AbstractVector) = binning

_hist_edges{N}(vs::NTuple{N,AbstractVector}, binning::NTuple{N}) =
    map(dim -> _hist_edge(vs, dim, binning[dim]), (1:N...))

_hist_edges{N}(vs::NTuple{N,AbstractVector}, binning::Union{Integer, Symbol, AbstractVector}) =
    map(dim -> _hist_edge(vs, dim, binning), (1:N...))

_hist_norm_mode(mode::Symbol) = mode
_hist_norm_mode(mode::Bool) = mode ? :pdf : :none

function _make_hist{N}(vs::NTuple{N,AbstractVector}, binning; normed = false, weights = nothing)
    info("binning = $binning")
    edges = _hist_edges(vs, binning)
    h = float( weights == nothing ?
        StatsBase.fit(StatsBase.Histogram, vs, edges, closed = :left) :
        StatsBase.fit(StatsBase.Histogram, vs, weights, edges, closed = :left)
    )
    normalize!(h, mode = _hist_norm_mode(normed))
end


@recipe function f(::Type{Val{:histogram}}, x, y, z)
    seriestype := :barhist
    ()
end
@deps histogram barhist

@recipe function f(::Type{Val{:barhist}}, x, y, z)
    h = _make_hist((y,), d[:bins], normed = d[:normalize], weights = d[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :barbins
    ()
end
@deps barhist barbins

@recipe function f(::Type{Val{:stephist}}, x, y, z)
    h = _make_hist((y,), d[:bins], normed = d[:normalize], weights = d[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :stepbins
    ()
end
@deps stephist stepbins

@recipe function f(::Type{Val{:scatterhist}}, x, y, z)
    h = _make_hist((y,), d[:bins], normed = d[:normalize], weights = d[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :scatterbins
    ()
end
@deps scatterhist scatterbins


@recipe function f{T, E}(h::StatsBase.Histogram{T, 1, E})
    seriestype --> :barbins

    st_map = Dict(
        :bar => :barbins, :scatter => :scatterbins, :step => :stepbins,
        :steppost => :stepbins # :step can be mapped to :steppost in pre-processing
    )
    seriestype := get(st_map, d[:seriestype], d[:seriestype])

    if d[:seriestype] == :scatterbins
        # Workaround, error bars currently not set correctly by scatterbins
        edge, weights, xscale, yscale, baseline = _preprocess_binlike(d, h.edges[1], h.weights)
        xerror --> diff(h.edges[1])/2
        seriestype := :scatter
        (Plots._bin_centers(edge), weights)
    else
        (h.edges[1], h.weights)
    end
end


@recipe function f{H <: StatsBase.Histogram}(hv::AbstractVector{H})
    for h in hv
        @series begin
            h
        end
    end
end


# ---------------------------------------------------------------------------
# Histogram 2D

@recipe function f(::Type{Val{:bins2d}}, x, y, z)
    edge_x, edge_y, weights = x, y, z.surf

    float_weights = float(weights)
    if is(float_weights, weights)
        float_weights = deepcopy(float_weights)
    end
    for (i, c) in enumerate(float_weights)
        if c == 0
            float_weights[i] = NaN
        end
    end

    x := Plots._bin_centers(edge_x)
    y := Plots._bin_centers(edge_y)
    z := Surface(float_weights)

    match_dimensions := true
    seriestype := :heatmap
    ()
end
Plots.@deps bins2d heatmap


@recipe function f(::Type{Val{:histogram2d}}, x, y, z)
    h = _make_hist((x, y), d[:bins], normed = d[:normalize], weights = d[:weights])
    x := h.edges[1]
    y := h.edges[2]
    z := Surface(h.weights)
    seriestype := :bins2d
    ()
end
@deps histogram2d bins2d


@recipe function f{T, E}(h::StatsBase.Histogram{T, 2, E})
    seriestype --> :bins2d
    (h.edges[1], h.edges[2], Surface(h.weights))
end


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
    xdiff = 0.3_mean(abs(diff(x)))
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
    xlim := _extrema(cs)
    ylim := _extrema(rs)
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
    plot!(plt, [_extrema(plt)...], x -> b + a*x; kw...)
end

abline!(args...; kw...) = abline!(current(), args...; kw...)


# -------------------------------------------------
# Dates

dateformatter(dt) = string(convert(Date, dt))
datetimeformatter(dt) = string(convert(DateTime, dt))

@recipe f(::Type{Date}, dt::Date) = (dt -> convert(Int, dt), dateformatter)
@recipe f(::Type{DateTime}, dt::DateTime) = (dt -> convert(Int, dt), datetimeformatter)

# -------------------------------------------------
# Complex Numbers

@recipe function f{T<:Number}(A::Array{Complex{T}})
    xguide --> "Re(x)"
    yguide --> "Im(x)"
    real.(A), imag.(A)
end

# Splits a complex matrix to its real and complex parts
# Reals defaults solid, imaginary defaults dashed
# Label defaults are changed to match the real-imaginary reference / indexing
@recipe function f{T<:Real,T2}(x::AbstractArray{T},y::Array{Complex{T2}})
  ylabel --> "Re(y)"
  zlabel --> "Im(y)"
  x,real.(y),imag.(y)
end


# --------------------------------------------------
# Color Gradients

@userplot ShowLibrary
@recipe function f(cl::ShowLibrary)
    if !(length(cl.args) == 1 && isa(cl.args[1], Symbol))
        error("showlibrary takes the name of a color library as a Symbol")
    end

    library = PlotUtils.color_libraries[cl.args[1]]
    z = sqrt.((1:15)*(1:20)')

    seriestype := :heatmap
    ticks := nothing
    legend := false

    layout --> length(library.lib)

    i = 0
    for grad in sort(collect(keys(library.lib)))
        @series begin
            seriescolor := cgrad(grad, cl.args[1])
            title := string(grad)
            subplot := i += 1
            z
        end
    end
end

@userplot ShowGradient
@recipe function f(grad::ShowGradient)
    if !(length(grad.args) == 1 && isa(grad.args[1], Symbol))
        error("showgradient takes the name of a color gradient as a Symbol")
    end
    z = sqrt.((1:15)*(1:20)')
    seriestype := :heatmap
    ticks := nothing
    legend := false
    seriescolor := grad.args[1]
    title := string(grad.args[1])
    z
end
