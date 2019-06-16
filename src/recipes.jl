
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

RecipesBase.apply_recipe(plotattributes::KW, ::Type{T}, plt::AbstractPlot) where {T} = throw(MethodError(T, "Unmatched plot recipe: $T"))

# ---------------------------------------------------------------------------


# for seriestype `line`, need to sort by x values

const POTENTIAL_VECTOR_ARGUMENTS = [
    :seriescolor, :seriesalpha,
    :linecolor, :linealpha, :linewidth, :linestyle, :line_z,
    :fillcolor, :fillalpha, :fill_z,
    :markercolor, :markeralpha, :markershape, :marker_z,
    :markerstrokecolor, :markerstrokealpha,
    :yerror, :yerror,
    :series_annotations, :fillrange
]

@recipe function f(::Type{Val{:line}}, x, y, z)
    indices = sortperm(x)
    x := x[indices]
    y := y[indices]

    # sort vector arguments
    for arg in POTENTIAL_VECTOR_ARGUMENTS
        if typeof(plotattributes[arg]) <: AVec
            plotattributes[arg] = _cycle(plotattributes[arg], indices)
        end
    end

    # a tuple as fillrange has to be handled differently
    if typeof(plotattributes[:fillrange]) <: Tuple
        lower, upper = plotattributes[:fillrange]
        if typeof(lower) <: AVec
            lower = _cycle(lower, indices)
        end
        if typeof(upper) <: AVec
            upper = _cycle(upper, indices)
        end
        plotattributes[:fillrange] = (lower, upper)
    end

    if typeof(z) <: AVec
        z := z[indices]
    end
    seriestype := :path
    ()
end
@deps line path

@recipe function f(::Type{Val{:hline}}, x, y, z)
    n = length(y)
    newx = repeat(Float64[-1, 1, NaN], n)
    newy = vec(Float64[yi for i=1:3,yi=y])
    x := newx
    y := newy
    seriestype := :straightline
    ()
end
@deps hline straightline

@recipe function f(::Type{Val{:vline}}, x, y, z)
    n = length(y)
    newx = vec(Float64[yi for i=1:3,yi=y])
    newy = repeat(Float64[-1, 1, NaN], n)
    x := newx
    y := newy
    seriestype := :straightline
    ()
end
@deps vline straightline

@recipe function f(::Type{Val{:hspan}}, x, y, z)
    n = div(length(y), 2)
    newx = repeat([-Inf, Inf, Inf, -Inf, NaN], outer = n)
    newy = vcat([[y[2i-1], y[2i-1], y[2i], y[2i], NaN] for i in 1:n]...)
    linewidth --> 0
    x := newx
    y := newy
    seriestype := :shape
    ()
end
@deps hspan shape

@recipe function f(::Type{Val{:vspan}}, x, y, z)
    n = div(length(y), 2)
    newx = vcat([[y[2i-1], y[2i-1], y[2i], y[2i], NaN] for i in 1:n]...)
    newy = repeat([-Inf, Inf, Inf, -Inf, NaN], outer = n)
    linewidth --> 0
    x := newx
    y := newy
    seriestype := :shape
    ()
end
@deps vspan shape

# ---------------------------------------------------------------------------
# path and scatter

# create a path from steps
@recipe function f(::Type{Val{:scatterpath}}, x, y, z)
    x := x
    y := y
    seriestype := :scatter
    @series begin
        seriestype := :path
        label := ""
        primary := false
        ()
    end
()
end
@deps scatterpath path scatter


# ---------------------------------------------------------------------------
# steps

make_steps(x, st) = x
function make_steps(x::AbstractArray, st)
    n = length(x)
    n == 0 && return zeros(0)
    newx = zeros(2n - 1)
    for i in 1:n
        idx = 2i - 1
        newx[idx] = x[i]
        if i > 1
            newx[idx - 1] = x[st == :pre ? i : i - 1]
        end
    end
    return newx
end
make_steps(t::Tuple, st) = Tuple(make_steps(ti, st) for ti in t)


# create a path from steps
@recipe function f(::Type{Val{:steppre}}, x, y, z)
    plotattributes[:x] = make_steps(x, :post)
    plotattributes[:y] = make_steps(y, :pre)
    seriestype := :path

    # handle fillrange
    plotattributes[:fillrange] = make_steps(plotattributes[:fillrange], :pre)

    # create a secondary series for the markers
    if plotattributes[:markershape] != :none
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
    plotattributes[:x] = make_steps(x, :pre)
    plotattributes[:y] = make_steps(y, :post)
    seriestype := :path

    # handle fillrange
    plotattributes[:fillrange] = make_steps(plotattributes[:fillrange], :post)

    # create a secondary series for the markers
    if plotattributes[:markershape] != :none
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
    fr = plotattributes[:fillrange]
    if fr == nothing
        sp = plotattributes[:subplot]
        yaxis = sp[:yaxis]
        fr = if yaxis[:scale] == :identity
            0.0
        else
            NaNMath.min(axis_limits(sp, :y)[1], ignorenan_minimum(y))
        end
    end
    newx, newy = zeros(3n), zeros(3n)
    for i=1:n
        rng = 3i-2:3i
        newx[rng] = [x[i], x[i], NaN]
        newy[rng] = [_cycle(fr,i), y[i], NaN]
    end
    x := newx
    y := newy
    fillrange := nothing
    seriestype := :path

    # create a secondary series for the markers
    if plotattributes[:markershape] != :none
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
    fr = plotattributes[:fillrange]
    newfr = fr != nothing ? zeros(0) : nothing
    newz = z != nothing ? zeros(0) : nothing
    # lz = plotattributes[:line_z]
    # newlz = lz != nothing ? zeros(0) : nothing

    # for each line segment (point series with no NaNs), convert it into a bezier curve
    # where the points are the control points of the curve
    for rng in iter_segments(args...)
        length(rng) < 2 && continue
        ts = range(0, stop = 1, length = npoints)
        nanappend!(newx, map(t -> bezier_value(_cycle(x,rng), t), ts))
        nanappend!(newy, map(t -> bezier_value(_cycle(y,rng), t), ts))
        if z != nothing
            nanappend!(newz, map(t -> bezier_value(_cycle(z,rng), t), ts))
        end
        if fr != nothing
            nanappend!(newfr, map(t -> bezier_value(_cycle(fr,rng), t), ts))
        end
        # if lz != nothing
        #     lzrng = _cycle(lz, rng) # the line_z's for this segment
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
    #     linecolor := (isa(plotattributes[:linecolor], ColorGradient) ? plotattributes[:linecolor] : cgrad())
    # end
    # Plots.DD(plotattributes)
    ()
end
@deps curves path

# ---------------------------------------------------------------------------

# create a bar plot as a filled step function
@recipe function f(::Type{Val{:bar}}, x, y, z)
    procx, procy, xscale, yscale, baseline = _preprocess_barlike(plotattributes, x, y)
    nx, ny = length(procx), length(procy)
    axis = plotattributes[:subplot][isvertical(plotattributes) ? :xaxis : :yaxis]
    cv = [discrete_value!(axis, xi)[1] for xi=procx]
    procx = if nx == ny
        cv
    elseif nx == ny + 1
        0.5diff(cv) + cv[1:end-1]
    else
        error("bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    end

    # compute half-width of bars
    bw = plotattributes[:bar_width]
    hw = if bw == nothing
        if nx > 1
            0.5*_bar_width*ignorenan_minimum(filter(x->x>0, diff(procx)))
        else
            0.5 * _bar_width
        end
    else
        Float64[0.5_cycle(bw,i) for i=1:length(procx)]
    end

    # make fillto a vector... default fills to 0
    fillto = plotattributes[:fillrange]
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
            hwi = _cycle(hw,i)
            fi = _cycle(fillto,i)
            push!(xseg, center-hwi, center-hwi, center+hwi, center+hwi, center-hwi)
            push!(yseg, yi, fi, fi, yi, yi)
        end
    end

    # widen limits out a bit
    expand_extrema!(axis, widen(ignorenan_extrema(xseg.pts)...))

    # switch back
    if !isvertical(plotattributes)
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
# Plots Heatmap
@recipe function f(::Type{Val{:plots_heatmap}}, x, y, z)
    xe, ye = heatmap_edges(x), heatmap_edges(y)
    m, n = size(z.surf)
    x_pts, y_pts = fill(NaN, 6 * m * n), fill(NaN, 6 * m * n)
    fz = zeros(m * n)
    for i in 1:m # y
        for j in 1:n # x
            k = (j - 1) * m + i
            inds = (6 * (k - 1) + 1):(6 * k - 1)
            x_pts[inds] .= [xe[j], xe[j + 1], xe[j + 1], xe[j], xe[j]]
            y_pts[inds] .= [ye[i], ye[i], ye[i + 1], ye[i + 1], ye[i]]
            fz[k] = z.surf[i, j]
        end
    end
    ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    fill_z := fz
    line_z := fz
    x := x_pts
    y := y_pts
    z := nothing
    seriestype := :shape
    label := ""
    widen --> false
    ()
end
@deps plots_heatmap shape

# ---------------------------------------------------------------------------
# Histograms

_bin_centers(v::AVec) = (v[1:end-1] + v[2:end]) / 2

_is_positive(x) = (x > 0) && !(x ≈ 0)

_positive_else_nan(::Type{T}, x::Real) where {T} = _is_positive(x) ? T(x) : T(NaN)

function _scale_adjusted_values(::Type{T}, V::AbstractVector, scale::Symbol) where T<:AbstractFloat
    if scale in _logScales
        [_positive_else_nan(T, x) for x in V]
    else
        [T(x) for x in V]
    end
end


function _binbarlike_baseline(min_value::T, scale::Symbol) where T<:Real
    if (scale in _logScales)
        !isnan(min_value) ? min_value / T(_logScaleBases[scale]^log10(2)) : T(1E-3)
    else
        zero(T)
    end
end


function _preprocess_binbarlike_weights(::Type{T}, w, wscale::Symbol) where T<:AbstractFloat
    w_adj = _scale_adjusted_values(T, w, wscale)
    w_min = ignorenan_minimum(w_adj)
    w_max = ignorenan_maximum(w_adj)
    baseline = _binbarlike_baseline(w_min, wscale)
    w_adj, baseline
end

function _preprocess_barlike(plotattributes, x, y)
    xscale = get(plotattributes, :xscale, :identity)
    yscale = get(plotattributes, :yscale, :identity)
    weights, baseline = _preprocess_binbarlike_weights(float(eltype(y)), y, yscale)
    x, weights, xscale, yscale, baseline
end

function _preprocess_binlike(plotattributes, x, y)
    xscale = get(plotattributes, :xscale, :identity)
    yscale = get(plotattributes, :yscale, :identity)
    T = float(promote_type(eltype(x), eltype(y)))
    edge = T.(x)
    weights, baseline = _preprocess_binbarlike_weights(T, y, yscale)
    edge, weights, xscale, yscale, baseline
end


@recipe function f(::Type{Val{:barbins}}, x, y, z)
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)
    if (plotattributes[:bar_width] == nothing)
        bar_width := diff(edge)
    end
    x := _bin_centers(edge)
    y := weights
    seriestype := :bar
    ()
end
@deps barbins bar


@recipe function f(::Type{Val{:scatterbins}}, x, y, z)
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)
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

    nbins = length(eachindex(weights))
    if length(eachindex(edge)) != nbins + 1
        error("Edge vector must be 1 longer than weight vector")
    end

    x = eltype(edge)[]
    y = eltype(weights)[]

    it_tuple_e = iterate(edge)
    a, it_state_e = it_tuple_e
    it_tuple_e = iterate(edge, it_state_e)

    it_tuple_w = iterate(weights)

    last_w = eltype(weights)(NaN)

    while it_tuple_e != nothing && it_tuple_w != nothing
        b, it_state_e = it_tuple_e
        w, it_state_w = it_tuple_w

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

        it_tuple_e = iterate(edge, it_state_e)
        it_tuple_w = iterate(weights, it_state_w)
    end
    if (last_w != baseline)
        push!(x, a)
        push!(y, baseline)
    end

    (x, y)
end


@recipe function f(::Type{Val{:stepbins}}, x, y, z)
    axis = plotattributes[:subplot][Plots.isvertical(plotattributes) ? :xaxis : :yaxis]

    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)

    xpts, ypts = _stepbins_path(edge, weights, baseline, xscale, yscale)
    if !isvertical(plotattributes)
        xpts, ypts = ypts, xpts
    end

    # create a secondary series for the markers
    if plotattributes[:markershape] != :none
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

wand_edges(x...) = (@warn("Load the StatsPlots package in order to use :wand bins. Defaulting to :auto", once = true); :auto)

function _auto_binning_nbins(vs::NTuple{N,AbstractVector}, dim::Integer; mode::Symbol = :auto) where N
    max_bins = 10_000
    _cl(x) = min(ceil(Int, max(x, one(x))), max_bins)
    _iqr(v) = (q = quantile(v, 0.75) - quantile(v, 0.25); q > 0 ? q : oftype(q, 1))
    _span(v) = maximum(v) - minimum(v)

    n_samples = length(LinearIndices(first(vs)))

    # The nd estimator is the key to most automatic binning methods, and is modified for twodimensional histograms to include correlation
    nd = n_samples^(1/(2+N))
    nd = N == 2 ? min(n_samples^(1/(2+N)), nd / (1-cor(first(vs), last(vs))^2)^(3//8)) : nd # the >2-dimensional case does not have a nice solution to correlations

    v = vs[dim]

    if mode == :auto
        mode = :fd
    end

    if mode == :sqrt  # Square-root choice
        _cl(sqrt(n_samples))
    elseif mode == :sturges  # Sturges' formula
        _cl(log2(n_samples) + 1)
    elseif mode == :rice  # Rice Rule
        _cl(2 * nd)
    elseif mode == :scott  # Scott's normal reference rule
        _cl(_span(v) / (3.5 * std(v) / nd))
    elseif mode == :fd  # Freedman–Diaconis rule
        _cl(_span(v) / (2 * _iqr(v) / nd))
    elseif mode == :wand
        _cl(wand_edges(v))  # this makes this function not type stable, but the type instability does not propagate
    else
        error("Unknown auto-binning mode $mode")
    end
end

_hist_edge(vs::NTuple{N,AbstractVector}, dim::Integer, binning::Integer) where {N} = StatsBase.histrange(vs[dim], binning, :left)
_hist_edge(vs::NTuple{N,AbstractVector}, dim::Integer, binning::Symbol) where {N} = _hist_edge(vs, dim, _auto_binning_nbins(vs, dim, mode = binning))
_hist_edge(vs::NTuple{N,AbstractVector}, dim::Integer, binning::AbstractVector) where {N} = binning

_hist_edges(vs::NTuple{N,AbstractVector}, binning::NTuple{N, Any}) where {N} =
    map(dim -> _hist_edge(vs, dim, binning[dim]), (1:N...,))

_hist_edges(vs::NTuple{N,AbstractVector}, binning::Union{Integer, Symbol, AbstractVector}) where {N} =
    map(dim -> _hist_edge(vs, dim, binning), (1:N...,))

_hist_norm_mode(mode::Symbol) = mode
_hist_norm_mode(mode::Bool) = mode ? :pdf : :none

_filternans(vs::NTuple{1,AbstractVector}) = filter!.(isfinite, vs)
function _filternans(vs::NTuple{N,AbstractVector}) where N
    _invertedindex(v, not) = [j for (i,j) in enumerate(v) if !(i ∈ not)]
    nots = union(Set.(findall.(!isfinite, vs))...)
    _invertedindex.(vs, Ref(nots))
end

function _make_hist(vs::NTuple{N,AbstractVector}, binning; normed = false, weights = nothing) where N
    localvs = _filternans(vs)
    edges = _hist_edges(localvs, binning)
    h = float( weights == nothing ?
        StatsBase.fit(StatsBase.Histogram, localvs, edges, closed = :left) :
        StatsBase.fit(StatsBase.Histogram, localvs, StatsBase.Weights(weights), edges, closed = :left)
    )
    normalize!(h, mode = _hist_norm_mode(normed))
end


@recipe function f(::Type{Val{:histogram}}, x, y, z)
    seriestype := length(y) > 1e6 ? :stephist : :barhist
    ()
end
@deps histogram barhist

@recipe function f(::Type{Val{:barhist}}, x, y, z)
    h = _make_hist((y,), plotattributes[:bins], normed = plotattributes[:normalize], weights = plotattributes[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :barbins
    ()
end
@deps barhist barbins

@recipe function f(::Type{Val{:stephist}}, x, y, z)
    h = _make_hist((y,), plotattributes[:bins], normed = plotattributes[:normalize], weights = plotattributes[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :stepbins
    ()
end
@deps stephist stepbins

@recipe function f(::Type{Val{:scatterhist}}, x, y, z)
    h = _make_hist((y,), plotattributes[:bins], normed = plotattributes[:normalize], weights = plotattributes[:weights])
    x := h.edges[1]
    y := h.weights
    seriestype := :scatterbins
    ()
end
@deps scatterhist scatterbins


@recipe function f(h::StatsBase.Histogram{T, 1, E}) where {T, E}
    seriestype --> :barbins

    st_map = Dict(
        :bar => :barbins, :scatter => :scatterbins, :step => :stepbins,
        :steppost => :stepbins # :step can be mapped to :steppost in pre-processing
    )
    seriestype := get(st_map, plotattributes[:seriestype], plotattributes[:seriestype])

    if plotattributes[:seriestype] == :scatterbins
        # Workaround, error bars currently not set correctly by scatterbins
        edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, h.edges[1], h.weights)
        xerror --> diff(h.edges[1])/2
        seriestype := :scatter
        (Plots._bin_centers(edge), weights)
    else
        (h.edges[1], h.weights)
    end
end


@recipe function f(hv::AbstractVector{H}) where H <: StatsBase.Histogram
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
    if float_weights === weights
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
    h = _make_hist((x, y), plotattributes[:bins], normed = plotattributes[:normalize], weights = plotattributes[:weights])
    x := h.edges[1]
    y := h.edges[2]
    z := Surface(h.weights)
    seriestype := :bins2d
    ()
end
@deps histogram2d bins2d


@recipe function f(h::StatsBase.Histogram{T, 2, E}) where {T, E}
    seriestype --> :bins2d
    (h.edges[1], h.edges[2], Surface(h.weights))
end


# ---------------------------------------------------------------------------
# scatter 3d

@recipe function f(::Type{Val{:scatter3d}}, x, y, z)
    seriestype := :path3d
    if plotattributes[:markershape] == :none
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

function error_style!(plotattributes::KW)
    plotattributes[:seriestype] = :path
    plotattributes[:linecolor] = plotattributes[:markerstrokecolor]
    plotattributes[:linewidth] = plotattributes[:markerstrokewidth]
    plotattributes[:label] = ""
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
    x, y = Array{float_extended_type(xorig)}(undef, 0), Array{Float64}(undef, 0)
    # for each point, create a line segment from the bottom to the top of the errorbar
    for i = 1:max(length(xorig), length(yorig))
        xi = _cycle(xorig, i)
        yi = _cycle(yorig, i)
        ebi = _cycle(ebar, i)
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
    error_style!(plotattributes)
    markershape := :hline
    plotattributes[:x], plotattributes[:y] = error_coords(plotattributes[:x], plotattributes[:y], error_zipit(plotattributes[:yerror]))
    ()
end
@deps yerror path

@recipe function f(::Type{Val{:xerror}}, x, y, z)
    error_style!(plotattributes)
    markershape := :vline
    plotattributes[:y], plotattributes[:x] = error_coords(plotattributes[:y], plotattributes[:x], error_zipit(plotattributes[:xerror]))
    ()
end
@deps xerror path


# TODO: move quiver to PlotRecipes

# ---------------------------------------------------------------------------
# quiver

# function apply_series_recipe(plotattributes::KW, ::Type{Val{:quiver}})
function quiver_using_arrows(plotattributes::KW)
    plotattributes[:label] = ""
    plotattributes[:seriestype] = :path
    if !isa(plotattributes[:arrow], Arrow)
        plotattributes[:arrow] = arrow()
    end

    velocity = error_zipit(plotattributes[:quiver])
    xorig, yorig = plotattributes[:x], plotattributes[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    x, y = zeros(0), zeros(0)
    for i = 1:max(length(xorig), length(yorig))
        # get the starting position
        xi = _cycle(xorig, i)
        yi = _cycle(yorig, i)

        # get the velocity
        vi = _cycle(velocity, i)
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

    plotattributes[:x], plotattributes[:y] = x, y
    # KW[plotattributes]
end

# function apply_series_recipe(plotattributes::KW, ::Type{Val{:quiver}})
function quiver_using_hack(plotattributes::KW)
    plotattributes[:label] = ""
    plotattributes[:seriestype] = :shape

    velocity = error_zipit(plotattributes[:quiver])
    xorig, yorig = plotattributes[:x], plotattributes[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    pts = P2[]
    for i = 1:max(length(xorig), length(yorig))

        # get the starting position
        xi = _cycle(xorig, i)
        yi = _cycle(yorig, i)
        p = P2(xi, yi)

        # get the velocity
        vi = _cycle(velocity, i)
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

    plotattributes[:x], plotattributes[:y] = Plots.unzip(pts[2:end])
    # KW[plotattributes]
end

# function apply_series_recipe(plotattributes::KW, ::Type{Val{:quiver}})
@recipe function f(::Type{Val{:quiver}}, x, y, z)
    if :arrow in supported_attrs()
        quiver_using_arrows(plotattributes)
    else
        quiver_using_hack(plotattributes)
    end
    ()
end
@deps quiver shape path


# -------------------------------------------------

# TODO: move OHLC to PlotRecipes finance.jl

"Represent Open High Low Close data (used in finance)"
mutable struct OHLC{T<:Real}
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
    xdiff = 0.3ignorenan_mean(abs.(diff(x)))
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
@recipe f(x::AVec{Function}, v::AVec{Tuple{R1,R2,R3,R4}}) where {R1<:Number,R2<:Number,R3<:Number,R4<:Number} = error()

# this must be OHLC?
@recipe f(x::AVec, ohlc::AVec{Tuple{R1,R2,R3,R4}}) where {R1<:Number,R2<:Number,R3<:Number,R4<:Number} = x, OHLC[OHLC(t...) for t in ohlc]

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
#     mat = reshape(map(zi->float(zi!=0), z),1,:)
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
    xlim := ignorenan_extrema(cs)
    ylim := ignorenan_extrema(rs)
    if plotattributes[:markershape] == :none
        markershape := :circle
    end
    if plotattributes[:markersize] == default(:markersize)
        markersize := 1
    end
    markerstrokewidth := 0
    marker_z := zs
    label := ""
    x := cs
    y := rs
    z := nothing
    seriestype := :scatter
    grid --> false
    ()
end

# -------------------------------------------------

"Adds ax+b... straight line over the current plot, without changing the axis limits"
abline!(plt::Plot, a, b; kw...) = plot!(plt, [0, 1], [b, b+a]; seriestype = :straightline, kw...)

abline!(args...; kw...) = abline!(current(), args...; kw...)


# -------------------------------------------------
# Dates & Times

dateformatter(dt) = string(Date(Dates.UTD(dt)))
datetimeformatter(dt) = string(DateTime(Dates.UTM(dt)))
timeformatter(t) = string(Dates.Time(Dates.Nanosecond(t)))

@recipe f(::Type{Date}, dt::Date) = (dt -> Dates.value(dt), dateformatter)
@recipe f(::Type{DateTime}, dt::DateTime) = (dt -> Dates.value(dt), datetimeformatter)
@recipe f(::Type{Dates.Time}, t::Dates.Time) = (t -> Dates.value(t), timeformatter)

# -------------------------------------------------
# Complex Numbers

@recipe function f(A::Array{Complex{T}}) where T<:Number
    xguide --> "Re(x)"
    yguide --> "Im(x)"
    real.(A), imag.(A)
end

# Splits a complex matrix to its real and complex parts
# Reals defaults solid, imaginary defaults dashed
# Label defaults are changed to match the real-imaginary reference / indexing
@recipe function f(x::AbstractArray{T},y::Array{Complex{T2}}) where {T<:Real,T2}
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
    z = sqrt.((1:15)*reshape(1:20,1,:))

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
    z = sqrt.((1:15)*reshape(1:20,1,:))
    seriestype := :heatmap
    ticks := nothing
    legend := false
    seriescolor := grad.args[1]
    title := string(grad.args[1])
    z
end


# Moved in from PlotRecipes - see: http://stackoverflow.com/a/37732384/5075246
@userplot PortfolioComposition

# this shows the shifting composition of a basket of something over a variable
# - "returns" are the dependent variable
# - "weights" are a matrix where the ith column is the composition for returns[i]
# - since each polygon is its own series, you can assign labels easily
@recipe function f(pc::PortfolioComposition)
    weights, returns = pc.args
    n = length(returns)
    weights = cumsum(weights, dims = 2)
    seriestype := :shape

	# create a filled polygon for each item
    for c=1:size(weights,2)
        sx = vcat(weights[:,c], c==1 ? zeros(n) : reverse(weights[:,c-1]))
        sy = vcat(returns, reverse(returns))
        @series Plots.isvertical(plotattributes) ? (sx, sy) : (sy, sx)
    end
end
