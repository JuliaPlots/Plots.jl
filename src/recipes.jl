const _series_recipe_deps = Dict()

series_recipe_dependencies(st::Symbol, deps::Symbol...) = _series_recipe_deps[st] = deps  # COV_EXCL_LINE

seriestype_supported(st::Symbol) = seriestype_supported(backend(), st)

# returns :no, :native, or :recipe depending on how it's supported
function seriestype_supported(pkg::AbstractBackend, st::Symbol)
    # is it natively supported
    is_seriestype_supported(pkg, st) && return :native

    haskey(_series_recipe_deps, st) || return :no

    supported = true
    for dep in _series_recipe_deps[st]
        if seriestype_supported(pkg, dep) === :no
            supported = false
            break
        end
    end
    return supported ? :recipe : :no
end

macro deps(st, args...)
    return :(Plots.series_recipe_dependencies($(quot(st)), $(map(quot, args)...)))
end

# get a list of all seriestypes
function all_seriestypes()
    sts = Set{Symbol}(keys(_series_recipe_deps))
    for bsym in backends()
        btype = _backendType[bsym]
        sts = union(sts, Set{Symbol}(supported_seriestypes(btype())))
    end
    return sts |> collect |> sort
end

# ----------------------------------------------------------------------------------
RecipesBase.apply_recipe(plotattributes::AKW, ::Type{T}, plt::AbstractPlot) where {T} =
    nothing

# ---------------------------------------------------------------------------

# for seriestype `line`, need to sort by x values

const POTENTIAL_VECTOR_ARGUMENTS = [
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linealpha,
    :linewidth,
    :linestyle,
    :line_z,
    :fillcolor,
    :fillalpha,
    :fill_z,
    :markercolor,
    :markeralpha,
    :markershape,
    :marker_z,
    :markerstrokecolor,
    :markerstrokealpha,
    :xerror,
    :yerror,
    :zerror,
    :series_annotations,
    :fillrange,
]

@nospecialize

@recipe function f(::Type{Val{:line}}, x, y, z)  # COV_EXCL_LINE
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
        typeof(lower) <: AVec && (lower = _cycle(lower, indices))
        typeof(upper) <: AVec && (upper = _cycle(upper, indices))
        plotattributes[:fillrange] = (lower, upper)
    end

    typeof(z) <: AVec && (z := z[indices])
    seriestype := :path
    ()
end
@deps line path

@recipe function f(::Type{Val{:hline}}, x, y, z)  # COV_EXCL_LINE
    n = length(y)
    newx = repeat(Float64[1, 2, NaN], n)
    newy = vec(Float64[yi for i in 1:3, yi in y])
    x := newx
    y := newy
    seriestype := :straightline
    ()
end
@deps hline straightline

@recipe function f(::Type{Val{:vline}}, x, y, z)  # COV_EXCL_LINE
    n = length(y)
    newx = vec(Float64[yi for i in 1:3, yi in y])
    x := newx
    y := repeat(Float64[1, 2, NaN], n)
    seriestype := :straightline
    ()
end
@deps vline straightline

@recipe function f(::Type{Val{:hspan}}, x, y, z)  # COV_EXCL_LINE
    n = div(length(y), 2)
    newx = repeat([-Inf, Inf, Inf, -Inf, NaN], outer = n)
    newy = vcat(map(i -> [y[2i - 1], y[2i - 1], y[2i], y[2i], NaN], 1:n)...)
    linewidth --> 0
    x := newx
    y := newy
    seriestype := :shape
    ()
end
@deps hspan shape

@recipe function f(::Type{Val{:vspan}}, x, y, z)  # COV_EXCL_LINE
    n = div(length(y), 2)
    newx = vcat(map(i -> [y[2i - 1], y[2i - 1], y[2i], y[2i], NaN], 1:n)...)
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
@recipe function f(::Type{Val{:scatterpath}}, x, y, z)  # COV_EXCL_LINE
    x := x
    y := y
    seriestype := :scatter
    @series begin
        ()
    end
    @series begin
        seriestype := :path
        label := ""
        primary := false
        ()
    end
    primary := false
    ()
end
@deps scatterpath path scatter

# ---------------------------------------------------------------------------
# regression line and scatter

# plots line corresponding to linear regression of y on a constant and x
@recipe function f(::Type{Val{:linearfit}}, x, y, z)  # COV_EXCL_LINE
    x := x
    y := y
    seriestype := :scatter
    @series begin
        ()
    end
    @series begin
        y := mean(y) .+ cov(x, y) / var(x) .* (x .- mean(x))
        seriestype := :path
        label := ""
        primary := false
        ()
    end
    primary := false
    ()
end

@specialize

# ---------------------------------------------------------------------------
# steps

make_steps(x, st, even) = x
function make_steps(x::AbstractArray, st, even)
    n = length(x)
    n == 0 && return zeros(0)
    newx = zeros(2n - (even ? 0 : 1))
    xstartindex = firstindex(x)
    newx[1] = x[xstartindex]
    for i in 2:n
        xindex = xstartindex - 1 + i
        idx = 2i - 1
        if st === :mid
            newx[idx] = newx[idx - 1] = (x[xindex] + x[xindex - 1]) / 2
        else
            newx[idx] = x[xindex]
            newx[idx - 1] = x[st === :pre ? xindex : xindex - 1]
        end
    end
    even && (newx[end] = x[end])
    return newx
end
make_steps(t::Tuple, st, even) = Tuple(make_steps(ti, st, even) for ti in t)

@nospecialize

# create a path from steps
@recipe function f(::Type{Val{:steppre}}, x, y, z)  # COV_EXCL_LINE
    plotattributes[:x] = make_steps(x, :post, false)
    plotattributes[:y] = make_steps(y, :pre, false)
    seriestype := :path

    # handle fillrange
    plotattributes[:fillrange] = make_steps(plotattributes[:fillrange], :pre, false)

    # create a secondary series for the markers
    if plotattributes[:markershape] !== :none
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
@recipe function f(::Type{Val{:stepmid}}, x, y, z)  # COV_EXCL_LINE
    plotattributes[:x] = make_steps(x, :mid, true)
    plotattributes[:y] = make_steps(y, :post, true)
    seriestype := :path

    # handle fillrange
    plotattributes[:fillrange] = make_steps(plotattributes[:fillrange], :post, true)

    # create a secondary series for the markers
    if plotattributes[:markershape] !== :none
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
@deps stepmid path scatter

# create a path from steps
@recipe function f(::Type{Val{:steppost}}, x, y, z)  # COV_EXCL_LINE
    plotattributes[:x] = make_steps(x, :pre, false)
    plotattributes[:y] = make_steps(y, :post, false)
    seriestype := :path

    # handle fillrange
    plotattributes[:fillrange] = make_steps(plotattributes[:fillrange], :post, false)

    # create a secondary series for the markers
    if plotattributes[:markershape] !== :none
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
@recipe function f(::Type{Val{:sticks}}, x, y, z)  # COV_EXCL_LINE
    n = length(x)
    if (fr = plotattributes[:fillrange]) === nothing
        sp = plotattributes[:subplot]
        fr = if sp[:yaxis][:scale] === :identity
            0.0
        else
            NaNMath.min(axis_limits(sp, :y)[1], ignorenan_minimum(y))
        end
    end
    newx, newy, newz = zeros(3n), zeros(3n), z !== nothing ? zeros(3n) : nothing
    for (i, (xi, yi, zi)) in enumerate(zip(x, y, z !== nothing ? z : 1:n))
        rng = (3i - 2):(3i)
        newx[rng] = [xi, xi, NaN]
        if z !== nothing
            newy[rng] = [yi, yi, NaN]
            newz[rng] = [_cycle(fr, i), zi, NaN]
        else
            newy[rng] = [_cycle(fr, i), yi, NaN]
        end
    end
    x := newx
    y := newy
    if z !== nothing
        z := newz
    end
    fillrange := nothing
    seriestype := :path
    if (
            plotattributes[:linecolor] === :auto &&
                plotattributes[:marker_z] !== nothing &&
                plotattributes[:line_z] === nothing
        )
        line_z := plotattributes[:marker_z]
    end

    # create a primary series for the markers
    if plotattributes[:markershape] !== :none
        primary := false
        @series begin
            seriestype := :scatter
            x := x
            y := y
            if z !== nothing
                z := z
            end
            primary := true
            ()
        end
        markershape := :none
    end
    ()
end
@deps sticks path scatter

@specialize

# ---------------------------------------------------------------------------
# bezier curves

# get the value of the curve point at position t
function bezier_value(pts::AVec, t::Real)
    val = 0.0
    n = length(pts) - 1
    for (i, p) in enumerate(pts)
        val += p * binomial(n, i - 1) * (1 - t)^(n - i + 1) * t^(i - 1)
    end
    return val
end

@nospecialize

# create segmented bezier curves in place of line segments
@recipe function f(::Type{Val{:curves}}, x, y, z; npoints = 30)  # COV_EXCL_LINE
    args = z !== nothing ? (x, y, z) : (x, y)
    newx, newy = zeros(0), zeros(0)
    newfr = (fr = plotattributes[:fillrange]) !== nothing ? zeros(0) : nothing
    newz = z !== nothing ? zeros(0) : nothing

    # for each line segment (point series with no NaNs), convert it into a bezier curve
    # where the points are the control points of the curve
    for rng in iter_segments(args...)
        length(rng) < 2 && continue
        ts = range(0, stop = 1, length = npoints)
        nanappend!(newx, map(t -> bezier_value(_cycle(x, rng), t), ts))
        nanappend!(newy, map(t -> bezier_value(_cycle(y, rng), t), ts))
        if z !== nothing
            nanappend!(newz, map(t -> bezier_value(_cycle(z, rng), t), ts))
        end
        if fr !== nothing
            nanappend!(newfr, map(t -> bezier_value(_cycle(fr, rng), t), ts))
        end
    end

    x := newx
    y := newy
    if z === nothing
        seriestype := :path
    else
        seriestype := :path3d
        z := newz
    end
    if fr !== nothing
        fillrange := newfr
    end
    ()
end
@deps curves path

# ---------------------------------------------------------------------------

# create a bar plot as a filled step function
@recipe function f(::Type{Val{:bar}}, x, y, z)  # COV_EXCL_LINE
    ywiden --> false
    procx, procy, xscale, yscale, _ = _preprocess_barlike(plotattributes, x, y)
    nx, ny = length(procx), length(procy)
    axis = plotattributes[:subplot][isvertical(plotattributes) ? :xaxis : :yaxis]
    cv = map(xi -> discrete_value!(plotattributes, :x, xi)[1], procx)
    procx = if nx == ny
        cv
    elseif nx == ny + 1
        0.5diff(cv) + @view(cv[1:(end - 1)])
    else
        error(
            "bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))",
        )
    end

    # compute half-width of bars
    bw = plotattributes[:bar_width]
    hw = if bw === nothing
        0.5_bar_width * if nx > 1
            ignorenan_minimum(filter(x -> x > 0, diff(sort(procx))))
        else
            1
        end
    else
        map(i -> 0.5_cycle(bw, i), eachindex(procx))
    end

    # make fillto a vector... default fills to 0
    if (fillto = plotattributes[:fillrange]) === nothing
        fillto = 0
    end
    if yscale in _logScales && !all(_is_positive, fillto)
        # github.com/JuliaPlots/Plots.jl/issues/4502
        # https://github.com/JuliaPlots/Plots.jl/issues/4774
        T = float(eltype(y))
        min_y = NaNMath.minimum(y)
        base = _logScaleBases[yscale]
        baseline = floor_base(min_y, base)
        if min_y == baseline
            baseline /= base
        end
        fillto = map(x -> _is_positive(x) ? T(x) : T(baseline), fillto)
    end

    xseg, yseg = map(_ -> Segments(), 1:2)
    valid_i = isfinite.(procx) .& isfinite.(procy)
    for i in 1:ny
        valid_i[i] || continue
        yi = procy[i]
        center = procx[i]
        hwi = _cycle(hw, i)
        fi = _cycle(fillto, i)
        push!(xseg, center - hwi, center - hwi, center + hwi, center + hwi, center - hwi)
        push!(yseg, yi, fi, fi, yi, yi)
    end

    # widen limits out a bit
    expand_extrema!(axis, scale_lims(ignorenan_extrema(xseg.pts)..., default_widen_factor))

    # switch back
    if !isvertical(plotattributes)
        xseg, yseg = yseg, xseg
        x, y = y, x
    end

    # reset orientation
    orientation := default(:orientation)

    # draw the bar shapes
    @series begin
        seriestype := :shape
        series_annotations := nothing
        primary := true
        x := xseg.pts
        y := yseg.pts
        # expand attributes to match indices in new series data
        for k in _segmenting_vector_attributes ∪ _segmenting_array_attributes
            # if (v = get(plotattributes, k, nothing)) isa AVec
            #     if eachindex(v) != eachindex(y)
            #         @warn "Indices $(eachindex(v)) of attribute `$k` do not match data indices $(eachindex(y))."
            #     end
            #     # Each segment is 6 elements long, including the NaN separator.
            #     # One segment is created for each non-NaN element of `procy`.
            #     # There is no trailing NaN, so the last repetition is dropped.
            #     plotattributes[k] = @views repeat(v[valid_i]; inner = 6)[1:(end - 1)]
            # end
        end
        ()
    end

    # add empty series
    primary := false
    seriestype := :scatter
    markersize := 0
    markeralpha := 0
    fillrange := nothing
    x := procx
    y := procy
    ()
end
@deps bar shape

# ---------------------------------------------------------------------------
# Plots Heatmap
@recipe function f(::Type{Val{:plots_heatmap}}, x, y, z)  # COV_EXCL_LINE
    xe, ye = heatmap_edges(x), heatmap_edges(y)
    m, n = size(z.surf)
    x_pts, y_pts = fill(NaN, 6m * n), fill(NaN, 6m * n)
    fz = zeros(m * n)
    for i in 1:m, j in 1:n  # i ≡ y, j ≡ x
        k = (j - 1) * m + i
        inds = (6(k - 1) + 1):(6k - 1)
        x_pts[inds] .= [xe[j], xe[j + 1], xe[j + 1], xe[j], xe[j]]
        y_pts[inds] .= [ye[i], ye[i], ye[i + 1], ye[i + 1], ye[i]]
        fz[k] = z.surf[i, j]
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

@specialize

is_3d(::Type{Val{:plots_heatmap}}) = true
RecipesPipeline.is_surface(::Type{Val{:plots_heatmap}}) = true
RecipesPipeline.is_surface(::Type{Val{:hexbin}}) = true
# ---------------------------------------------------------------------------
# Histograms

_bin_centers(v::AVec) = (@view(v[1:(end - 1)]) + @view(v[2:end])) / 2

_is_positive(x) = (x > 0) && !(x ≈ 0)

_positive_else_nan(::Type{T}, x::Real) where {T} = _is_positive(x) ? T(x) : T(NaN)

_scale_adjusted_values(
    ::Type{T},
    V::AbstractVector,
    scale::Symbol,
) where {T <: AbstractFloat} = scale in _logScales ? _positive_else_nan.(T, V) : T.(V)

_binbarlike_baseline(min_value::T, scale::Symbol) where {T <: Real} =
if scale in _logScales
    isnan(min_value) ? T(1.0e-3) : floor_base(min_value, _logScaleBases[scale])
else
    zero(T)
end

function _preprocess_binbarlike_weights(
        ::Type{T},
        w,
        wscale::Symbol,
    ) where {T <: AbstractFloat}
    w_adj = _scale_adjusted_values(T, w, wscale)
    w_min = ignorenan_minimum(w_adj)
    w_max = ignorenan_maximum(w_adj)
    baseline = _binbarlike_baseline(w_min, wscale)
    return w_adj, baseline
end

function _preprocess_barlike(plotattributes, x, y)
    xscale = get(plotattributes, :xscale, :identity)
    yscale = get(plotattributes, :yscale, :identity)
    weights, baseline = _preprocess_binbarlike_weights(float(eltype(y)), y, yscale)
    return x, weights, xscale, yscale, baseline
end

function _preprocess_binlike(plotattributes, x, y)
    xscale = get(plotattributes, :xscale, :identity)
    yscale = get(plotattributes, :yscale, :identity)
    T = float(promote_type(eltype(x), eltype(y)))
    edge = T.(x)
    weights, baseline = _preprocess_binbarlike_weights(T, y, yscale)
    return edge, weights, xscale, yscale, baseline
end

@nospecialize

@recipe function f(::Type{Val{:barbins}}, x, y, z)  # COV_EXCL_LINE
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)
    if plotattributes[:bar_width] === nothing
        bar_width := diff(edge)
    end
    x := _bin_centers(edge)
    y := weights
    seriestype := :bar
    ()
end
@deps barbins bar

@recipe function f(::Type{Val{:scatterbins}}, x, y, z)  # COV_EXCL_LINE
    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)
    @series begin
        x := _bin_centers(edge)
        xerror := diff(edge) / 2
        primary := false
        seriestype := :xerror
        ()
    end
    x := _bin_centers(edge)
    y := weights
    seriestype := :scatter
    ()
end
@deps scatterbins xerror scatter

@specialize

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

    while it_tuple_e !== nothing && it_tuple_w !== nothing
        b, it_state_e = it_tuple_e
        w, it_state_w = it_tuple_w

        if log_scale_x && a ≈ 0
            a = oftype(a, b / _logScaleBases[xscale]^3)
        end

        if isnan(w)
            if !isnan(last_w)
                push!(x, a, NaN)
                push!(y, baseline, NaN)
            end
        else
            if isnan(last_w)
                push!(x, a)
                push!(y, baseline)
            end
            push!(x, a, b)
            push!(y, w, w)
        end

        a = oftype(a, b)
        last_w = oftype(last_w, w)

        it_tuple_e = iterate(edge, it_state_e)
        it_tuple_w = iterate(weights, it_state_w)
    end
    if (last_w != baseline)
        push!(x, a)
        push!(y, baseline)
    end

    return (x, y)
end

@recipe function f(::Type{Val{:stepbins}}, x, y, z)  # COV_EXCL_LINE
    @nospecialize
    axis = plotattributes[:subplot][Plots.isvertical(plotattributes) ? :xaxis : :yaxis]

    edge, weights, xscale, yscale, baseline = _preprocess_binlike(plotattributes, x, y)

    xpts, ypts = _stepbins_path(edge, weights, baseline, xscale, yscale)
    if !isvertical(plotattributes)
        xpts, ypts = ypts, xpts
    end

    # create a secondary series for the markers
    if plotattributes[:markershape] !== :none
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
@deps stepbins path

function wand_edges(x...)
    @warn """"
    Load the StatsPlots package in order to use :wand bins.
    Defaulting to :auto
    """ once = true
    return :auto
end

function _auto_binning_nbins(
        vs::NTuple{N, AbstractVector},
        dim::Integer;
        mode::Symbol = :auto,
    ) where {N}
    max_bins = 10_000
    _cl(x) = min(ceil(Int, max(x, one(x))), max_bins)
    _iqr(v) = (q = quantile(v, 0.75) - quantile(v, 0.25); q > 0 ? q : oftype(q, 1))
    _span(v) = maximum(v) - minimum(v)

    n_samples = length(LinearIndices(first(vs)))

    # The nd estimator is the key to most automatic binning methods, and is modified for twodimensional histograms to include correlation
    nd = n_samples^(1 / (2 + N))
    nd = if N == 2
        min(n_samples^(1 / (2 + N)), nd / (1 - cor(first(vs), last(vs))^2)^(3 // 8))
    else # the >2-dimensional case does not have a nice solution to correlations
        nd
    end

    v = vs[dim]
    mode === :auto && (mode = :fd)

    return if mode === :sqrt  # Square-root choice
        _cl(sqrt(n_samples))
    elseif mode === :sturges  # Sturges' formula
        _cl(log2(n_samples) + 1)
    elseif mode === :rice  # Rice Rule
        _cl(2 * nd)
    elseif mode === :scott  # Scott's normal reference rule
        _cl(_span(v) / (3.5 * std(v) / nd))
    elseif mode === :fd  # Freedman–Diaconis rule
        _cl(_span(v) / (2 * _iqr(v) / nd))
    elseif mode === :wand
        wand_edges(v)  # this makes this function not type stable, but the type instability does not propagate
    else
        error("Unknown auto-binning mode $mode")
    end
end

_hist_edge(vs::NTuple{N, AbstractVector}, dim::Integer, binning::Integer) where {N} =
    StatsBase.histrange(vs[dim], binning, :left)
_hist_edge(vs::NTuple{N, AbstractVector}, dim::Integer, binning::Symbol) where {N} =
    _hist_edge(vs, dim, _auto_binning_nbins(vs, dim, mode = binning))
_hist_edge(vs::NTuple{N, AbstractVector}, dim::Integer, binning::AbstractVector) where {N} =
    binning

_hist_edges(vs::NTuple{N, AbstractVector}, binning::NTuple{N, Any}) where {N} =
    map(dim -> _hist_edge(vs, dim, binning[dim]), Tuple(1:N))

_hist_edges(
    vs::NTuple{N, AbstractVector},
    binning::Union{Integer, Symbol, AbstractVector},
) where {N} = map(dim -> _hist_edge(vs, dim, binning), Tuple(1:N))

_hist_norm_mode(mode::Symbol) = mode
_hist_norm_mode(mode::Bool) = mode ? :pdf : :none

_filternans(vs::NTuple{1, AbstractVector}) = filter!.(isfinite, vs)
function _filternans(vs::NTuple{N, AbstractVector}) where {N}
    _invertedindex(v, not) = [j for (i, j) in enumerate(v) if !(i ∈ not)]
    nots = union(Set.(findall.(!isfinite, vs))...)
    return _invertedindex.(vs, Ref(nots))
end

function _make_hist(
        vs::NTuple{N, AbstractVector},
        binning;
        normed = false,
        weights = nothing,
    ) where {N}
    localvs = _filternans(vs)
    edges = _hist_edges(localvs, binning)
    h = float(
        weights === nothing ?
            StatsBase.fit(StatsBase.Histogram, localvs, edges, closed = :left) :
            StatsBase.fit(
                StatsBase.Histogram,
                localvs,
                StatsBase.Weights(weights),
                edges,
                closed = :left,
            ),
    )
    return normalize!(h, mode = _hist_norm_mode(normed))
end

@nospecialize

@recipe function f(::Type{Val{:histogram}}, x, y, z)  # COV_EXCL_LINE
    seriestype := length(y) > 1.0e6 ? :stephist : :barhist
    ()
end
@deps histogram barhist

@recipe function f(::Type{Val{:barhist}}, x, y, z)  # COV_EXCL_LINE
    h = _make_hist(
        tuple(y),
        plotattributes[:bins],
        normed = plotattributes[:normalize],
        weights = plotattributes[:weights],
    )
    x := h.edges[1]
    y := h.weights
    seriestype := :barbins
    ()
end
@deps barhist barbins

@recipe function f(::Type{Val{:stephist}}, x, y, z)  # COV_EXCL_LINE
    h = _make_hist(
        tuple(y),
        plotattributes[:bins],
        normed = plotattributes[:normalize],
        weights = plotattributes[:weights],
    )
    x := h.edges[1]
    y := h.weights
    seriestype := :stepbins
    ()
end
@deps stephist stepbins

@recipe function f(::Type{Val{:scatterhist}}, x, y, z)  # COV_EXCL_LINE
    h = _make_hist(
        tuple(y),
        plotattributes[:bins],
        normed = plotattributes[:normalize],
        weights = plotattributes[:weights],
    )
    x := h.edges[1]
    y := h.weights
    seriestype := :scatterbins
    ()
end
@deps scatterhist scatterbins

@recipe function f(h::StatsBase.Histogram{T, 1, E}) where {T, E}  # COV_EXCL_LINE
    seriestype --> :barbins

    st_map = Dict(
        :bar => :barbins,
        :scatter => :scatterbins,
        :step => :stepbins,
        :steppost => :stepbins, # :step can be mapped to :steppost in pre-processing
    )
    seriestype := get(st_map, plotattributes[:seriestype], plotattributes[:seriestype])

    if plotattributes[:seriestype] === :scatterbins
        # Workaround, error bars currently not set correctly by scatterbins
        edge, weights, xscale, yscale, baseline =
            _preprocess_binlike(plotattributes, h.edges[1], h.weights)
        xerror --> diff(h.edges[1]) / 2
        seriestype := :scatter
        (Plots._bin_centers(edge), weights)
    else
        (h.edges[1], h.weights)
    end
end

@recipe f(hv::AbstractVector{H}) where {H <: StatsBase.Histogram} =  # COV_EXCL_LINE
    for h in hv
    @series begin
        h
    end
end

# ---------------------------------------------------------------------------
# Histogram 2D

@recipe function f(::Type{Val{:bins2d}}, x, y, z)  # COV_EXCL_LINE
    edge_x, edge_y, weights = x, y, z.surf

    float_weights = float(weights)
    if !plotattributes[:show_empty_bins]
        if float_weights === weights
            float_weights = deepcopy(float_weights)
        end
        for (i, c) in enumerate(float_weights)
            c == 0 && (float_weights[i] = NaN)
        end
    end

    x := Plots._bin_centers(edge_x)
    y := Plots._bin_centers(edge_y)
    z := Surface(permutedims(float_weights))
    seriestype := :heatmap
    ()
end
Plots.@deps bins2d heatmap

@recipe function f(::Type{Val{:histogram2d}}, x, y, z)  # COV_EXCL_LINE
    h = _make_hist(
        (x, y),
        plotattributes[:bins],
        normed = plotattributes[:normalize],
        weights = plotattributes[:weights],
    )
    x := h.edges[1]
    y := h.edges[2]
    z := Surface(h.weights)
    seriestype := :bins2d
    ()
end
@deps histogram2d bins2d

@recipe function f(h::StatsBase.Histogram{T, 2, E}) where {T, E}  # COV_EXCL_LINE
    seriestype --> :bins2d
    (h.edges[1], h.edges[2], Surface(h.weights))
end

# ---------------------------------------------------------------------------
# pie
@recipe function f(::Type{Val{:pie}}, x, y, z)  # COV_EXCL_LINE
    framestyle --> :none
    aspect_ratio --> 1
    s = sum(y)
    θ = 0
    colors = plotattributes[:seriescolor]
    for i in eachindex(y)
        θ_new = θ + 2π * y[i] / s
        coords = [(0.0, 0.0); partialcircle(θ, θ_new, 50)]
        @series begin
            seriescolor := _cycle(colors, i)
            seriestype := :shape
            label --> string(x[i])
            x := first.(coords)
            y := last.(coords)
        end
        θ = θ_new
    end
end
@deps pie shape

# ---------------------------------------------------------------------------
# mesh 3d replacement for non-plotly backends

@recipe function f(::Type{Val{:mesh3d}}, x, y, z)  # COV_EXCL_LINE
    # As long as no i,j,k are supplied this should work with PyPlot and GR
    seriestype := :surface
    if plotattributes[:connections] !== nothing
        "Giving triangles using the connections argument is only supported on Plotly backend." |>
            ArgumentError |>
            throw
    end
    ()
end

# ---------------------------------------------------------------------------
# scatter 3d

@recipe function f(::Type{Val{:scatter3d}}, x, y, z)  # COV_EXCL_LINE
    seriestype := :path3d
    if plotattributes[:markershape] === :none
        markershape := :circle
    end
    linewidth := 0
    linealpha := 0
    ()
end

# note: don't add dependencies because this really isn't a drop-in replacement

# ---------------------------------------------------------------------------
# lens! - magnify a region of a plot
lens!(args...; kwargs...) = plot!(args...; seriestype = :lens, kwargs...)
export lens!
@recipe function f(::Type{Val{:lens}}, plt::AbstractPlot)  # COV_EXCL_LINE
    sp_index, inset_bbox = plotattributes[:inset_subplots]
    width(inset_bbox) isa Measures.Length{:w, <:Real} ||
        throw(ArgumentError("Inset bounding box needs to in relative coordinates."))
    sp = plt.subplots[sp_index]
    xscale = sp[:xaxis][:scale]
    yscale = sp[:yaxis][:scale]
    xl1, xl2 = xlims(sp)
    xls1, xls2 = RecipesPipeline.scale_func(xscale).((xl1, xl2))
    bbx1 = xls1 + left(inset_bbox).value * (xls2 - xls1)
    bbx2 = bbx1 + width(inset_bbox).value * (xls2 - xls1)
    yl1, yl2 = ylims(sp)
    yls1, yls2 = RecipesPipeline.scale_func(yscale).((yl1, yl2))
    bby1 = yls1 + (1 - bottom(inset_bbox).value) * (yls2 - yls1)
    bby2 = bby1 + height(inset_bbox).value * (yls2 - yls1)
    bbx = bbx1 + width(inset_bbox).value * (xls2 - xls1) / 2 * (sp[:xaxis][:flip] ? -1 : 1)
    bby = bby1 + height(inset_bbox).value * (yls2 - yls1) / 2 * (sp[:yaxis][:flip] ? -1 : 1)
    lens_index = last(plt.subplots)[:subplot_index] + 1
    x1, x2 = plotattributes[:x]
    y1, y2 = plotattributes[:y]
    xs1, xs2 = RecipesPipeline.scale_func(xscale).((x1, x2))
    ys1, ys2 = RecipesPipeline.scale_func(yscale).((y1, y2))

    backup = copy(plotattributes)
    empty!(plotattributes)

    series_plotindex := backup[:series_plotindex]
    seriestype := :path
    primary := false
    linecolor := get(backup, :linecolor, :lightgray)
    if haskey(backup, :linestyle)
        linestyle := backup[:linestyle]
    end
    if haskey(backup, :linewidth)
        linewidth := backup[:linewidth]
    end
    bbx_mag = (xs1 + xs2) / 2
    bby_mag = (ys1 + ys2) / 2
    xi_lens, yi_lens =
        intersection_point(bbx_mag, bby_mag, bbx, bby, abs(bby2 - bby1), abs(bbx2 - bbx1))
    xi_mag, yi_mag =
        intersection_point(bbx, bby, bbx_mag, bby_mag, abs(y2 - y1), abs(x2 - x1))
    xi_mag, xi_lens = RecipesPipeline.inverse_scale_func(xscale).((xi_mag, xi_lens))
    yi_mag, yi_lens = RecipesPipeline.inverse_scale_func(yscale).((yi_mag, yi_lens))
    # add lines
    if xl1 < xi_lens < xl2 && yl1 < yi_lens < yl2
        @series begin
            primary := false
            subplot := sp_index
            x := [xi_mag, xi_lens]
            y := [yi_mag, yi_lens]
            ()
        end
    end
    # add magnification shape
    @series begin
        primary := false
        subplot := sp_index
        x := [x1, x1, x2, x2, x1]
        y := [y1, y2, y2, y1, y1]
        ()
    end
    # add subplot
    for series in sp.series_list
        @series begin
            plotattributes = merge(backup, copy(series.plotattributes))
            subplot := lens_index
            primary := false
            xlims := (x1, x2)
            ylims := (y1, y2)
            ()
        end
    end
    nothing
end

@specialize

function intersection_point(xA, yA, xB, yB, h, w)
    s = (yA - yB) / (xA - xB)
    hh, hw = h / 2, w / 2
    # left or right?
    return if -hh <= s * hw <= hh
        if xA > xB  # right
            xB + hw, yB + s * hw
        else  # left
            xB - hw, yB - s * hw
        end
        # top or bot?
    elseif -hw <= hh / s <= hw
        if yA > yB  # top
            xB + hh / s, yB + hh
        else  # bottom
            xB - hh / s, yB - hh
        end
    end
end
# ---------------------------------------------------------------------------
# contourf - filled contours

@recipe function f(::Type{Val{:contourf}}, x, y, z)  # COV_EXCL_LINE
    @nospecialize
    fillrange := true
    seriestype := :contour
    ()
end

# ---------------------------------------------------------------------------
# Error Bars

@attributes function error_style!(plotattributes::AKW)
    # errorbar color should soley determined by markerstrokecolor
    haskey(plotattributes, :marker_z) && reset_kw!(plotattributes, :marker_z)
    haskey(plotattributes, :line_z) && reset_kw!(plotattributes, :line_z)

    msc = if (msc = plotattributes[:markerstrokecolor]) === :match
        plotattributes[:subplot][:foreground_color_subplot]
    elseif msc === :auto
        get_series_color(
            plotattributes[:linecolor],
            plotattributes[:subplot],
            plotattributes[:series_plotindex],
            plotattributes[:seriestype],
        )
    else
        msc
    end

    seriestype := :path
    markerstrokecolor --> msc
    markercolor --> msc
    linecolor --> msc
    linewidth --> plotattributes[:markerstrokewidth]
    label --> ""
end

# if we're passed a tuple of vectors, convert to a vector of tuples
error_zipit(ebar) = istuple(ebar) ? collect(zip(ebar...)) : ebar

error_tuple(x) = x, x
error_tuple(x::Tuple) = x

function error_coords(errorbar, errordata, otherdata...)
    ed = Vector{float_extended_type(errordata)}(undef, 0)
    od = map(odi -> Vector{float_extended_type(odi)}(undef, 0), otherdata)
    for (i, edi) in enumerate(errordata)
        for (j, odj) in enumerate(otherdata)
            odi = _cycle(odj, i)
            nanappend!(od[j], [odi, odi])
        end
        e1, e2 = error_tuple(_cycle(errorbar, i))
        nanappend!(ed, [edi - e1, edi + e2])
    end
    return (ed, od...)
end

# clamp non-NaN values in an array to Base.eps(Float64) for log-scale plots
clamp_to_eps!(ary) = (replace!(x -> x <= 0.0 ? Base.eps(Float64) : x, ary); nothing)

# we will create a series of path segments, where each point represents one
# side of an errorbar

@nospecialize

@recipe function f(::Type{Val{:xerror}}, x, y, z)  # COV_EXCL_LINE
    error_style!(plotattributes)
    markershape := :vline
    xerr = error_zipit(plotattributes[:xerror])
    if z === nothing
        plotattributes[:x], plotattributes[:y] = error_coords(xerr, x, y)
    else
        plotattributes[:x], plotattributes[:y], plotattributes[:z] =
            error_coords(xerr, x, y, z)
    end
    if :xscale ∈ keys(plotattributes) && plotattributes[:xscale] === :log10
        clamp_to_eps!(plotattributes[:x])
    end
    ()
end
@deps xerror path

@recipe function f(::Type{Val{:yerror}}, x, y, z)  # COV_EXCL_LINE
    error_style!(plotattributes)
    markershape := :hline
    yerr = error_zipit(plotattributes[:yerror])
    if z === nothing
        plotattributes[:y], plotattributes[:x] = error_coords(yerr, y, x)
    else
        plotattributes[:y], plotattributes[:x], plotattributes[:z] =
            error_coords(yerr, y, x, z)
    end
    if :yscale ∈ keys(plotattributes) && plotattributes[:yscale] === :log10
        clamp_to_eps!(plotattributes[:y])
    end
    ()
end
@deps yerror path

@recipe function f(::Type{Val{:zerror}}, x, y, z)  # COV_EXCL_LINE
    error_style!(plotattributes)
    markershape := :hline
    if z !== nothing
        zerr = error_zipit(plotattributes[:zerror])
        plotattributes[:z], plotattributes[:x], plotattributes[:y] =
            error_coords(zerr, z, x, y)
    end
    if :zscale ∈ keys(plotattributes) && plotattributes[:zscale] === :log10
        clamp_to_eps!(plotattributes[:z])
    end
    ()
end
@deps zerror path

@specialize

# TODO: move quiver to PlotRecipes

# ---------------------------------------------------------------------------
# quiver

# function apply_series_recipe(plotattributes::AKW, ::Type{Val{:quiver}})
function quiver_using_arrows(plotattributes::AKW)
    plotattributes[:label] = ""
    plotattributes[:seriestype] = :path
    isa(plotattributes[:arrow], Arrow) || (plotattributes[:arrow] = arrow())
    is_3d = haskey(plotattributes, :z) && !isnothing(plotattributes[:z])
    velocity = error_zipit(plotattributes[:quiver])
    xorig, yorig = plotattributes[:x], plotattributes[:y]
    zorig = is_3d ? plotattributes[:z] : []

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    x, y = zeros(0), zeros(0)
    is_3d && (z = zeros(0))
    for i in 1:max(length(xorig), length(yorig), is_3d ? 0 : length(zorig))
        # get the starting position
        xi = _cycle(xorig, i)
        yi = _cycle(yorig, i)
        zi = is_3d ? _cycle(zorig, i) : 0
        # get the velocity
        vi = _cycle(velocity, i)
        if is_3d
            vx, vy, vz = if istuple(vi)
                vi[1], vi[2], vi[3]
            elseif isscalar(vi)
                vi, vi, vi
            elseif isa(vi, Function)
                vi(xi, yi, zi)
            else
                error("unexpected vi type $(typeof(vi)) for quiver: $vi")
            end
        else # 2D quiver
            vx, vy = if istuple(vi)
                first(vi), last(vi)
            elseif isscalar(vi)
                vi, vi
            elseif isa(vi, Function)
                vi(xi, yi)
            else
                error("unexpected vi type $(typeof(vi)) for quiver: $vi")
            end
        end
        # add the points
        nanappend!(x, [xi, xi + vx, NaN])
        nanappend!(y, [yi, yi + vy, NaN])
        is_3d && nanappend!(z, [zi, zi + vz, NaN])
    end
    plotattributes[:x], plotattributes[:y] = x, y
    return is_3d && (plotattributes[:z] = z)
    # KW[plotattributes]
end

# function apply_series_recipe(plotattributes::AKW, ::Type{Val{:quiver}})
function quiver_using_hack(plotattributes::AKW)
    plotattributes[:label] = ""
    plotattributes[:seriestype] = :shape

    velocity = error_zipit(plotattributes[:quiver])
    xorig, yorig = plotattributes[:x], plotattributes[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    pts = P2[]
    for i in 1:max(length(xorig), length(yorig))

        # get the starting position
        xi = _cycle(xorig, i)
        yi = _cycle(yorig, i)
        p = P2((xi, yi))

        # get the velocity
        vi = _cycle(velocity, i)
        vx, vy = if istuple(vi)
            first(vi), last(vi)
        elseif isscalar(vi)
            vi, vi
        elseif isa(vi, Function)
            vi(xi, yi)
        else
            error("unexpected vi type $(typeof(vi)) for quiver: $vi")
        end
        v = P2((vx, vy))

        dist = norm(v)
        arrow_h = 0.1dist          # height of arrowhead
        arrow_w = 0.5arrow_h       # halfwidth of arrowhead
        U1 = v ./ dist             # vector of arrowhead height
        U2 = P2((-U1[2], U1[1]))   # vector of arrowhead halfwidth
        U1 = U1 .* arrow_h
        U2 = U2 .* arrow_w

        ppv = p .+ v
        nanappend!(pts, P2[p, ppv .- U1, ppv .- U1 .+ U2, ppv, ppv .- U1 .- U2, ppv .- U1])
    end

    return plotattributes[:x], plotattributes[:y] = RecipesPipeline.unzip(pts[2:end])
end

# function apply_series_recipe(plotattributes::AKW, ::Type{Val{:quiver}})
@recipe function f(::Type{Val{:quiver}}, x, y, z)  # COV_EXCL_LINE
    @nospecialize
    if :arrow in supported_attrs()
        quiver_using_arrows(plotattributes)
    else
        quiver_using_hack(plotattributes)
    end
    ()
end
@deps quiver shape path

# --------------------------------------------------------------------
# 1 argument
# --------------------------------------------------------------------

# images - grays
function clamp_greys!(mat::AMat{<:Gray})
    for i in eachindex(mat)
        mat[i].val < 0 && (mat[i] = Gray(0))
        mat[i].val > 1 && (mat[i] = Gray(1))
    end
    return mat
end

@recipe function f(mat::AMat{<:Gray})  # COV_EXCL_LINE
    n, m = map(a -> range(first(a) - 0.5, stop = last(a) + 0.5), axes(mat))

    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(clamp_greys!(mat))
    else
        seriestype := :heatmap
        yflip --> true
        colorbar --> false
        fillcolor --> cgrad([:black, :white])
        SliceIt, m, n, Surface(clamp!(convert(Matrix{Float64}, mat), 0.0, 1.0))
    end
end

@nospecialize

# images - colors
@recipe function f(mat::AMat{T}) where {T <: Colorant}  # COV_EXCL_LINE
    n, m = map(a -> range(first(a) - 0.5, stop = last(a) + 0.5), axes(mat))

    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        colorbar --> false
        aspect_ratio --> :equal
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, m, n, Surface(z)
    end
end

# plotting arbitrary shapes/polygons

@recipe function f(shape::Shape)  # COV_EXCL_LINE
    seriestype --> :shape
    coords(shape)
end

@recipe function f(shapes::AVec{<:Shape})  # COV_EXCL_LINE
    seriestype --> :shape
    # For backwards compatibility, column vectors of segmenting attributes are
    # interpreted as having one element per shape
    for attr in union(_segmenting_array_attributes, _segmenting_vector_attributes)
        v = get(plotattributes, attr, nothing)
        if v isa AVec || v isa AMat && size(v, 2) == 1
            @warn """
            Column vector attribute `$attr` reinterpreted as row vector (one value per shape).
            Pass a row vector instead (e.g. using `permutedims`) to suppress this warning.
            """
            plotattributes[attr] = permutedims(v)
        end
    end
    coords(shapes)
end

@recipe function f(shapes::AMat{<:Shape})  # COV_EXCL_LINE
    seriestype --> :shape
    for j in axes(shapes, 2)
        @series coords(vec(shapes[:, j]))
    end
end

# --------------------------------------------------------------------
# 3 arguments
# --------------------------------------------------------------------

# images - grays
@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where {T <: Gray}  # COV_EXCL_LINE
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        colorbar --> false
        fillcolor --> cgrad([:black, :white])
        SliceIt, x, y, Surface(convert(Matrix{Float64}, mat))
    end
end

# images - colors
@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where {T <: Colorant}  # COV_EXCL_LINE
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        colorbar --> false
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, x, y, Surface(z)
    end
end

@specialize

# -------------------------------------------------

# TODO: move OHLC to PlotRecipes finance.jl

"Represent Open High Low Close data (used in finance)"
mutable struct OHLC{T <: Real}
    open::T
    high::T
    low::T
    close::T
end
Base.convert(::Type{OHLC}, tup::Tuple) = OHLC(tup...)
# Base.tuple(ohlc::OHLC) = (ohlc.open, ohlc.high, ohlc.low, ohlc.close)

# get one OHLC path
function get_xy(o::OHLC, x, xdiff)
    xl, xm, xr = x - xdiff, x, x + xdiff
    ox = [xl, xm, NaN, xm, xm, NaN, xm, xr]
    oy = [o.open, o.open, NaN, o.low, o.high, NaN, o.close, o.close]
    return ox, oy
end

# get the joined vector
function get_xy(v::AVec{OHLC}, x = eachindex(v))
    xdiff = 0.3ignorenan_mean(abs.(diff(x)))
    x_out, y_out = zeros(0), zeros(0)
    for (i, ohlc) in enumerate(v)
        ox, oy = get_xy(ohlc, x[i], xdiff)
        nanappend!(x_out, ox)
        nanappend!(y_out, oy)
    end
    return x_out, y_out
end

# these are for passing in a vector of OHLC objects
# TODO: when I allow `@recipe f(::Type{T}, v::T) = ...` definitions to replace convertToAnyVector,
#       then I should replace these with one definition to convert to a vector of 4-tuples

@nospecialize

@recipe f(x::AVec, ohlc::AVec{NTuple{N, <:Number}}) where {N} = x, map(t -> OHLC(t...), ohlc)

@recipe f(xyuv::AVec{NTuple}) =
    get(plotattributes, :seriestype, :path) === :ohlc ? map(t -> OHLC(t...), xyuv) :
    RecipesPipeline.unzip(xyuv)

@recipe function f(x::AVec, v::AVec{OHLC})  # COV_EXCL_LINE
    seriestype := :path
    get_xy(v, x)
end

@recipe function f(v::AVec{OHLC})  # COV_EXCL_LINE
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

@recipe function f(g::Spy)  # COV_EXCL_LINE
    @assert length(g.args) == 1 && typeof(g.args[1]) <: AbstractMatrix
    seriestype := :spy
    mat = g.args[1]
    n, m = axes(mat)
    SliceIt, m, n, Surface(mat)
end

@recipe function f(::Type{Val{:spy}}, x, y, z)  # COV_EXCL_LINE
    yflip := true
    aspect_ratio := 1
    rs, cs, zs = findnz(z.surf)
    xlims := ignorenan_extrema(cs)
    ylims := ignorenan_extrema(rs)
    widen --> true

    markershape --> :circle
    markersize --> 1
    markerstrokewidth := 0
    if length(unique(zs)) == 1
        seriescolor --> :black
    else
        marker_z := zs
    end
    label := ""
    x := cs
    y := rs
    z := nothing
    seriestype := :scatter
    grid --> false
    ()
end

@specialize

findnz(A::AbstractSparseMatrix) = SparseArrays.findnz(A)

# fallback function for finding non-zero elements of non-sparse matrices
function findnz(A::AbstractMatrix)
    keysnz = findall(!iszero, A)
    rs = map(k -> k[1], keysnz)
    cs = map(k -> k[2], keysnz)
    zs = A[keysnz]
    return rs, cs, zs
end

# -------------------------------------------------

@nospecialize

abline!(plt::Plot, a, b; kw...) =
    plot!(plt, [0, 1], [b, b + a]; seriestype = :straightline, kw...)

abline!(args...; kw...) = abline!(current(), args...; kw...)

# -------------------------------------------------
# Complex Numbers

@recipe function f(A::AbstractArray{Complex{T}}) where {T <: Number}  # COV_EXCL_LINE
    xguide --> "Re(x)"
    yguide --> "Im(x)"
    real.(A), imag.(A)
end

# Splits a complex matrix to its real and complex parts
# Reals defaults solid, imaginary defaults dashed
# Label defaults are changed to match the real-imaginary reference / indexing
@recipe function f(x::AbstractArray{Real}, y::AbstractMatrix{Complex})  # COV_EXCL_LINE
    ylabel --> "Re(y)"
    zlabel --> "Im(y)"
    x, real.(y), imag.(y)
end

# Moved in from PlotRecipes - see: http://stackoverflow.com/a/37732384/5075246
@userplot PortfolioComposition

# this shows the shifting composition of a basket of something over a variable
# - "returns" are the dependent variable
# - "weights" are a matrix where the ith column is the composition for returns[i]
# - since each polygon is its own series, you can assign labels easily
@recipe function f(pc::PortfolioComposition)  # COV_EXCL_LINE
    weights, returns = pc.args
    n = length(returns)
    weights = cumsum(weights, dims = 2)
    seriestype := :shape

    # create a filled polygon for each item
    for c in axes(weights, 2)
        sx = vcat(weights[:, c], c == 1 ? zeros(n) : reverse(weights[:, c - 1]))
        sy = vcat(returns, reverse(returns))
        @series Plots.isvertical(plotattributes) ? (sx, sy) : (sy, sx)
    end
end

@userplot AreaPlot

@recipe function f(a::AreaPlot; seriestype = :line)  # COV_EXCL_LINE
    data = cumsum(a.args[end], dims = 2)
    x = length(a.args) == 1 ? (axes(data, 1)) : a.args[1]
    for i in axes(data, 2)
        @series begin
            fillrange := i > 1 ? data[:, i - 1] : 0
            x, data[:, i]
        end
    end
end

@specialize
