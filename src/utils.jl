import NaNMath # define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum(x::AbstractArray{<:AbstractFloat}) = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum(x::AbstractArray{<:AbstractFloat}) = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean(x::AbstractArray{<:AbstractFloat}) = NaNMath.mean(x)
ignorenan_mean(x) = Statistics.mean(x)
ignorenan_extrema(x::AbstractArray{<:AbstractFloat}) = NaNMath.extrema(x)
ignorenan_extrema(x) = Base.extrema(x)

# ---------------------------------------------------------------
bool_env(x, default)::Bool =
    try
        return parse(Bool, get(ENV, x, default))
    catch e
        @warn e
        return false
    end

treats_y_as_x(seriestype) =
    seriestype in (:vline, :vspan, :histogram, :barhist, :stephist, :scatterhist)

function replace_image_with_heatmap(z::AbstractMatrix{<:Colorant})
    n, m = size(z)
    colors = palette(vec(z))
    reshape(1:(n * m), n, m), colors
end

# ---------------------------------------------------------------

"Build line segments for plotting"
mutable struct Segments{T}
    pts::Vector{T}
end

# Segments() = Segments{Float64}(zeros(0))

Segments() = Segments(Float64)
Segments(::Type{T}) where {T} = Segments(T[])
Segments(p::Int) = Segments(NTuple{p,Float64}[])

# Segments() = Segments(zeros(0))

to_nan(::Type{Float64}) = NaN
to_nan(::Type{NTuple{2,Float64}}) = (NaN, NaN)
to_nan(::Type{NTuple{3,Float64}}) = (NaN, NaN, NaN)

Commons.coords(segs::Segments{Float64}) = segs.pts
Commons.coords(segs::Segments{NTuple{2,Float64}}) =
    (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts))
Commons.coords(segs::Segments{NTuple{3,Float64}}) =
    (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts), map(p -> p[3], segs.pts))

function Base.push!(segments::Segments{T}, vs...) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    segments
end

function Base.push!(segments::Segments{T}, vs::AVec) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    segments
end

struct SeriesSegment
    # indexes of this segment in series data vectors
    range::UnitRange
    # index into vector-valued attributes corresponding to this segment
    attr_index::Int
end

# -----------------------------------------------------
# helper to manage NaN-separated segments
struct NaNSegmentsIterator
    args::Tuple
    n1::Int
    n2::Int
end

function iter_segments(args...)
    tup = Plots.wraptuple(args)
    n1 = minimum(map(firstindex, tup))
    n2 = maximum(map(lastindex, tup))
    NaNSegmentsIterator(tup, n1, n2)
end

"floor number x in base b, note this is different from using Base.round(...; base=b) !"
floor_base(x, b) = round_base(x, b, RoundDown)

"ceil number x in base b"
ceil_base(x, b) = round_base(x, b, RoundUp)

round_base(x::T, b, ::RoundingMode{:Down}) where {T} = T(b^floor(log(b, x)))
round_base(x::T, b, ::RoundingMode{:Up}) where {T} = T(b^ceil(log(b, x)))

ignorenan_min_max(::Any, ex) = ex
function ignorenan_min_max(x::AbstractArray{<:AbstractFloat}, ex::Tuple)
    mn, mx = ignorenan_extrema(x)
    NaNMath.min(ex[1], mn), NaNMath.max(ex[2], mx)
end

function series_segments(series::Series, seriestype::Symbol = :path; check = false)
    x, y, z = series[:x], series[:y], series[:z]
    (x === nothing || isempty(x)) && return UnitRange{Int}[]

    args = RecipesPipeline.is3d(series) ? (x, y, z) : (x, y)
    nan_segments = collect(iter_segments(args...))

    if check
        scales = :xscale, :yscale, :zscale
        for (n, s) in enumerate(args)
            (scale = get(series, scales[n], :identity)) ∈ _logScales || continue
            for (i, v) in enumerate(s)
                if v <= 0
                    @warn "Invalid negative or zero value $v found at series index $i for $scale based $(scales[n])"
                    @debug "" exception = (DomainError(v), stacktrace())
                    break
                end
            end
        end
    end

    segments = if has_attribute_segments(series)
        map(nan_segments) do r
            if seriestype === :shape
                warn_on_inconsistent_shape_attr(series, x, y, z, r)
                (SeriesSegment(r, first(r)),)
            elseif seriestype in (:scatter, :scatter3d)
                (SeriesSegment(i:i, i) for i in r)
            else
                (SeriesSegment(i:(i + 1), i) for i in first(r):(last(r) - 1))
            end
        end |> Iterators.flatten
    else
        (SeriesSegment(r, 1) for r in nan_segments)
    end

    warn_on_attr_dim_mismatch(series, x, y, z, segments)
    segments
end

function warn_on_attr_dim_mismatch(series, x, y, z, segments)
    isempty(segments) && return
    seg_range = UnitRange(
        minimum(map(seg -> first(seg.range), segments)),
        maximum(map(seg -> last(seg.range), segments)),
    )
    for attr in _segmenting_vector_attributes
        if (v = get(series, attr, nothing)) isa AVec && eachindex(v) != seg_range
            @warn "Indices $(eachindex(v)) of attribute `$attr` does not match data indices $seg_range."
            if any(v -> !isnothing(v) && any(isnan, v), (x, y, z))
                @info """Data contains NaNs or missing values, and indices of `$attr` vector do not match data indices.
                    If you intend elements of `$attr` to apply to individual NaN-separated segments in the data,
                    pass each segment in a separate vector instead, and use a row vector for `$attr`. Legend entries
                    may be suppressed by passing an empty label.
                    For example,
                        plot([1:2,1:3], [[4,5],[3,4,5]], label=["y" ""], $attr=[1 2])
                    """
            end
        end
    end
end

function warn_on_inconsistent_shape_attr(series, x, y, z, r)
    for attr in _segmenting_vector_attributes
        v = get(series, attr, nothing)
        if v isa AVec && length(unique(v[r])) > 1
            @warn "Different values of `$attr` specified for different shape vertices. Only first one will be used."
            break
        end
    end
end

# helpers to figure out if there are NaN values in a list of array types
anynan(i::Int, args::Tuple) = any(a -> try
    isnan(_cycle(a, i))
catch MethodError
    false
end, args)
anynan(args::Tuple) = i -> anynan(i, args)
anynan(istart::Int, iend::Int, args::Tuple) = any(anynan(args), istart:iend)
allnan(istart::Int, iend::Int, args::Tuple) = all(anynan(args), istart:iend)

function Base.iterate(itr::NaNSegmentsIterator, nextidx::Int = itr.n1)
    (i = findfirst(!anynan(itr.args), nextidx:(itr.n2))) === nothing && return
    nextval = nextidx + i - 1

    j = findfirst(anynan(itr.args), nextval:(itr.n2))
    nextnan = j === nothing ? itr.n2 + 1 : nextval + j - 1

    nextval:(nextnan - 1), nextnan
end
Base.IteratorSize(::NaNSegmentsIterator) = Base.SizeUnknown()  # COV_EXCL_LINE

# Find minimal type that can contain NaN and x
# To allow use of NaN separated segments with categorical x axis

float_extended_type(x::AbstractArray{T}) where {T} = Union{T,Float64}
float_extended_type(x::AbstractArray{Real}) = Float64

function _update_series_attributes!(plotattributes::AKW, plt::Plot, sp::Subplot)
    pkg = plt.backend
    globalIndex = plotattributes[:series_plotindex]
    plotIndex = Commons._series_index(plotattributes, sp)

    Commons.aliasesAndAutopick(
        plotattributes,
        :linestyle,
        Commons._styleAliases,
        supported_styles(pkg),
        plotIndex,
    )
    Commons.aliasesAndAutopick(
        plotattributes,
        :markershape,
        Commons._markerAliases,
        supported_markers(pkg),
        plotIndex,
    )

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if plotattributes[asym] === nothing
            plotattributes[asym] = plotattributes[:seriesalpha]
        end
    end
    if plotattributes[:markerstrokealpha] === nothing
        plotattributes[:markerstrokealpha] = plotattributes[:markeralpha]
    end

    # update series color
    scolor = plotattributes[:seriescolor]
    stype = plotattributes[:seriestype]
    plotattributes[:seriescolor] = scolor = get_series_color(scolor, sp, plotIndex, stype)

    # update other colors (`linecolor`, `markercolor`, `fillcolor`) <- for grep
    for s in (:line, :marker, :fill)
        csym, asym = Symbol(s, :color), Symbol(s, :alpha)
        plotattributes[csym] = if plotattributes[csym] === :auto
            plot_color(if Commons.has_black_border_for_default(stype) && s === :line
                sp[:foreground_color_subplot]
            else
                scolor
            end)
        elseif plotattributes[csym] === :match
            plot_color(scolor)
        else
            get_series_color(plotattributes[csym], sp, plotIndex, stype)
        end
    end

    # update markerstrokecolor
    plotattributes[:markerstrokecolor] = if plotattributes[:markerstrokecolor] === :match
        plot_color(sp[:foreground_color_subplot])
    elseif plotattributes[:markerstrokecolor] === :auto
        get_series_color(plotattributes[:markercolor], sp, plotIndex, stype)
    else
        get_series_color(plotattributes[:markerstrokecolor], sp, plotIndex, stype)
    end

    # if marker_z, fill_z or line_z are set, ensure we have a gradient
    if plotattributes[:marker_z] !== nothing
        ensure_gradient!(plotattributes, :markercolor, :markeralpha)
    end
    if plotattributes[:line_z] !== nothing
        ensure_gradient!(plotattributes, :linecolor, :linealpha)
    end
    if plotattributes[:fill_z] !== nothing
        ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    end

    # scatter plots don't have a line, but must have a shape
    if plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d)
        plotattributes[:linewidth] = 0
        if plotattributes[:markershape] === :none
            plotattributes[:markershape] = :circle
        end
    end

    # set label
    plotattributes[:label] = Commons.label_to_string.(plotattributes[:label], globalIndex)

    Commons._replace_linewidth(plotattributes)
    plotattributes
end
"""
1-row matrices will give an element
multi-row matrices will give a column
anything else is returned as-is
"""
function slice_arg(v::AMat, idx::Int)
    isempty(v) && return v
    c = mod1(idx, size(v, 2))
    m, n = axes(v)
    size(v, 1) == 1 ? v[first(m), n[c]] : v[:, n[c]]
end
slice_arg(v::NTuple{2,AMat}, idx::Int) = slice_arg(v[1], idx), slice_arg(v[2], idx)
slice_arg(v, idx) = v

"""
given an argument key `k`, extract the argument value for this index,
and set into plotattributes[k]. Matrices are sliced by column.
if nothing is set (or container is empty), return the existing value.
"""
function slice_arg!(
    plotattributes_in,
    plotattributes_out,
    k::Symbol,
    idx::Int,
    remove_pair::Bool,
)
    v = get(plotattributes_in, k, plotattributes_out[k])
    plotattributes_out[k] = if haskey(plotattributes_in, k) && k ∉ Commons._plot_args
        slice_arg(v, idx)
    else
        v
    end
    remove_pair && RecipesPipeline.reset_kw!(plotattributes_in, k)
    nothing
end

function _slice_series_args!(plotattributes::AKW, plt::Plot, sp::Subplot, commandIndex::Int)
    for k in keys(_series_defaults)
        haskey(plotattributes, k) &&
            slice_arg!(plotattributes, plotattributes, k, commandIndex, false)
    end
    plotattributes
end
# -----------------------------------------------------------------------------

function __heatmap_edges(v::AVec, isedges::Bool, ispolar::Bool)
    (n = length(v)) == 1 && return v[1] .+ [ispolar ? max(-v[1], -0.5) : -0.5, 0.5]
    isedges && return v
    # `isedges = true` means that v is a vector which already describes edges
    # and does not need to be extended.
    vmin, vmax = ignorenan_extrema(v)
    extra_min = ispolar ? min(v[1], 0.5(v[2] - v[1])) : 0.5(v[2] - v[1])
    extra_max = 0.5(v[n] - v[n - 1])
    vcat(vmin - extra_min, 0.5(v[1:(n - 1)] + v[2:n]), vmax + extra_max)
end

_heatmap_edges(::Val{true}, v::AVec, ::Symbol, isedges::Bool, ispolar::Bool) =
    __heatmap_edges(v, isedges, ispolar)

function _heatmap_edges(::Val{false}, v::AVec, scale::Symbol, isedges::Bool, ispolar::Bool)
    f, invf = scale_inverse_scale_func(scale)
    invf.(__heatmap_edges(f.(v), isedges, ispolar))
end

"create an (n+1) list of the outsides of heatmap rectangles"
heatmap_edges(
    v::AVec,
    scale::Symbol = :identity,
    isedges::Bool = false,
    ispolar::Bool = false,
) = _heatmap_edges(Val(scale === :identity), v, scale, isedges, ispolar)

function heatmap_edges(
    x::AVec,
    xscale::Symbol,
    y::AVec,
    yscale::Symbol,
    z_size::NTuple{2,Int},
    ispolar::Bool = false,
)
    nx, ny = length(x), length(y)
    # ismidpoints = z_size == (ny, nx) # This fails some tests, but would actually be
    # the correct check, since (4, 3) != (3, 4) and a missleading plot is produced.
    ismidpoints = prod(z_size) == (ny * nx)
    isedges = z_size == (ny - 1, nx - 1)
    (ismidpoints || isedges) ||
        """
        Length of x & y does not match the size of z.
        Must be either `size(z) == (length(y), length(x))` (x & y define midpoints)
        or `size(z) == (length(y)+1, length(x)+1))` (x & y define edges).
        """ |>
        ArgumentError |>
        throw
    (
        _heatmap_edges(Val(xscale === :identity), x, xscale, isedges, false),
        _heatmap_edges(Val(yscale === :identity), y, yscale, isedges, ispolar),  # special handle for `r` in polar plots
    )
end

is_uniformly_spaced(v; tol = 1e-6) =
    let dv = diff(v)
        maximum(dv) - minimum(dv) < tol * mean(abs.(dv))
    end

function convert_to_polar(theta, r, r_extrema = ignorenan_extrema(r))
    rmin, rmax = r_extrema
    r = @. (r - rmin) / (rmax - rmin)
    x = @. r * cos(theta)
    y = @. r * sin(theta)
    x, y
end

fakedata(sz::Int...) = fakedata(Random.seed!(PLOTS_SEED), sz...)

function fakedata(rng::AbstractRNG, sz...)
    y = zeros(sz...)
    for r in 2:size(y, 1)
        y[r, :] = 0.95vec(y[r - 1, :]) + randn(rng, size(y, 2))
    end
    y
end

isijulia() = :IJulia in nameof.(collect(values(Base.loaded_modules)))
isatom() = :Atom in nameof.(collect(values(Base.loaded_modules)))

istuple(::Tuple) = true
istuple(::Any)   = false
isvector(::AVec) = true
isvector(::Any)  = false
ismatrix(::AMat) = true
ismatrix(::Any)  = false
isscalar(::Real) = true
isscalar(::Any)  = false

is_2tuple(v) = typeof(v) <: Tuple && length(v) == 2

ticksType(ticks::AVec{<:Real}) = :ticks
ticksType(ticks::AVec{<:AbstractString}) = :labels
ticksType(ticks::Tuple{<:Union{AVec,Tuple},<:Union{AVec,Tuple}}) = :ticks_and_labels
ticksType(ticks) = :invalid

limsType(lims::Tuple{<:Real,<:Real}) = :limits
limsType(lims::Symbol) = lims === :auto ? :auto : :invalid
limsType(lims) = :invalid

isautop(sp::Subplot) = sp[:projection_type] === :auto
isortho(sp::Subplot) = sp[:projection_type] ∈ (:ortho, :orthographic)
ispersp(sp::Subplot) = sp[:projection_type] ∈ (:persp, :perspective)

# recursively merge kw-dicts, e.g. for merging extra_kwargs / extra_plot_kwargs in plotly)
recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
# if values are not AbstractDicts, take the last definition (as does merge)
recursive_merge(x...) = x[end]

nanpush!(a::AbstractVector, b) = (push!(a, NaN); push!(a, b); nothing)
nanappend!(a::AbstractVector, b) = (push!(a, NaN); append!(a, b); nothing)

function nansplit(v::AVec)
    vs = Vector{eltype(v)}[]
    while true
        if (idx = findfirst(isnan, v)) === nothing
            # no nans
            push!(vs, v)
            break
        elseif idx > 1
            push!(vs, v[1:(idx - 1)])
        end
        v = v[(idx + 1):end]
    end
    vs
end

function nanvcat(vs::AVec)
    v_out = zeros(0)
    foreach(v -> nanappend!(v_out, v), vs)
    v_out
end

sort_3d_axes(x, y, z, letter) =
    if letter === :x
        x, y, z
    elseif letter === :y
        y, x, z
    else
        z, y, x
    end

axes_letters(sp, letter) =
    if RecipesPipeline.is3d(sp)
        sort_3d_axes(:x, :y, :z, letter)
    else
        letter === :x ? (:x, :y) : (:y, :x)
    end


# compute one side of a fill range from a ribbon
function make_fillrange_side(y::AVec, rib)
    frs = zeros(axes(y))
    for (i, yi) in pairs(y)
        frs[i] = yi + _cycle(rib, i)
    end
    frs
end

# turn a ribbon into a fillrange
function make_fillrange_from_ribbon(kw::AKW)
    y, rib = kw[:y], kw[:ribbon]
    rib = wraptuple(rib)
    rib1, rib2 = -first(rib), last(rib)
    # kw[:ribbon] = nothing
    kw[:fillrange] = make_fillrange_side(y, rib1), make_fillrange_side(y, rib2)
    (get(kw, :fillalpha, nothing) === nothing) && (kw[:fillalpha] = 0.5)
end

#turn tuple of fillranges to one path
function concatenate_fillrange(x, y::Tuple)
    rib1, rib2 = collect(first(y)), collect(last(y)) # collect needed until https://github.com/JuliaLang/julia/pull/37629 is merged
    vcat(x, reverse(x)), vcat(rib1, reverse(rib2))  # x, y
end

get_sp_lims(sp::Subplot, letter::Symbol) = axis_limits(sp, letter)

"""
    xlims([plt])

Returns the x axis limits of the current plot or subplot
"""
xlims(sp::Subplot) = get_sp_lims(sp, :x)

"""
    ylims([plt])

Returns the y axis limits of the current plot or subplot
"""
ylims(sp::Subplot) = get_sp_lims(sp, :y)

"""
    zlims([plt])

Returns the z axis limits of the current plot or subplot
"""
zlims(sp::Subplot) = get_sp_lims(sp, :z)

xlims(plt::Plot, sp_idx::Int = 1) = xlims(plt[sp_idx])
ylims(plt::Plot, sp_idx::Int = 1) = ylims(plt[sp_idx])
zlims(plt::Plot, sp_idx::Int = 1) = zlims(plt[sp_idx])
xlims(sp_idx::Int = 1) = xlims(current(), sp_idx)
ylims(sp_idx::Int = 1) = ylims(current(), sp_idx)
zlims(sp_idx::Int = 1) = zlims(current(), sp_idx)


for comp in (:line, :fill, :marker)
    compcolor = string(comp, :color)
    get_compcolor = Symbol(:get_, compcolor)
    comp_z = string(comp, :_z)

    compalpha = string(comp, :alpha)
    get_compalpha = Symbol(:get_, compalpha)

    @eval begin
        # defines `get_linecolor`, `get_fillcolor` and `get_markercolor` <- for grep
        function $get_compcolor(
            series,
            cmin::Real,
            cmax::Real,
            i::Integer = 1,
            s::Symbol = :identity,
        )
            c = series[$Symbol($compcolor)]  # series[:linecolor], series[:fillcolor], series[:markercolor]
            z = series[$Symbol($comp_z)]  # series[:line_z], series[:fill_z], series[:marker_z]
            if z === nothing
                isa(c, ColorGradient) ? c : plot_color(_cycle(c, i))
            else
                grad = get_gradient(c)
                if s === :identity
                    get(grad, z[i], (cmin, cmax))
                else
                    base = _logScaleBases[s]
                    get(grad, log(base, z[i]), (log(base, cmin), log(base, cmax)))
                end
            end
        end

        function $get_compcolor(series, i::Integer = 1, s::Symbol = :identity)
            if series[$Symbol($comp_z)] === nothing
                $get_compcolor(series, 0, 1, i, s)
            else
                $get_compcolor(series, get_clims(series[:subplot]), i, s)
            end
        end

        $get_compcolor(series, clims::NTuple{2,<:Number}, args...) =
            $get_compcolor(series, clims[1], clims[2], args...)

        $get_compalpha(series, i::Integer = 1) = _cycle(series[$Symbol($compalpha)], i)
    end
end

single_color(c, v = 0.5) = c
single_color(grad::ColorGradient, v = 0.5) = grad[v]

get_gradient(c) = cgrad()
get_gradient(cg::ColorGradient) = cg
get_gradient(cp::ColorPalette) = cgrad(cp, categorical = true)

get_linewidth(series, i::Integer = 1) = _cycle(series[:linewidth], i)
get_linestyle(series, i::Integer = 1) = _cycle(series[:linestyle], i)
get_fillstyle(series, i::Integer = 1) = _cycle(series[:fillstyle], i)

get_markerstrokecolor(series, i::Integer = 1) =
    let msc = series[:markerstrokecolor]
        msc isa ColorGradient ? msc : _cycle(msc, i)
    end

get_markerstrokealpha(series, i::Integer = 1) = _cycle(series[:markerstrokealpha], i)
get_markerstrokewidth(series, i::Integer = 1) = _cycle(series[:markerstrokewidth], i)

const _segmenting_vector_attributes = (
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linealpha,
    :linewidth,
    :linestyle,
    :fillcolor,
    :fillalpha,
    :fillstyle,
    :markercolor,
    :markeralpha,
    :markersize,
    :markerstrokecolor,
    :markerstrokealpha,
    :markerstrokewidth,
    :markershape,
)

const _segmenting_array_attributes = :line_z, :fill_z, :marker_z

# we want to check if a series needs to be split into segments just because
# of its attributes
# check relevant attributes if they have multiple inputs
has_attribute_segments(series::Series) =
    any(
        series[attr] isa AbstractVector && length(series[attr]) > 1 for
        attr in _segmenting_vector_attributes
    ) || any(series[attr] isa AbstractArray for attr in _segmenting_array_attributes)



"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function Commons.preprocess_attributes!(plotattributes::AKW)
    Commons.replaceAliases!(plotattributes, Commons._keyAliases)

    # handle axis args common to all axis
    args = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :axis, ()))
    showarg = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :showaxis, ()))
    for arg in wraptuple((args..., showarg...))
        for letter in (:x, :y, :z)
            process_axis_arg!(plotattributes, arg, letter)
        end
    end
    # handle axis args
    for letter in (:x, :y, :z)
        asym = get_attr_symbol(letter, :axis)
        args = RecipesPipeline.pop_kw!(plotattributes, asym, ())
        if !(typeof(args) <: Axis)
            for arg in wraptuple(args)
                process_axis_arg!(plotattributes, arg, letter)
            end
        end
    end

    # vline and others accesses the y argument but actually maps it to the x axis.
    # Hence, we have to take care of formatters
    if treats_y_as_x(get(plotattributes, :seriestype, :path))
        xformatter = get(plotattributes, :xformatter, :auto)
        yformatter = get(plotattributes, :yformatter, :auto)
        yformatter !== :auto && (plotattributes[:xformatter] = yformatter)
        xformatter === :auto &&
            haskey(plotattributes, :yformatter) &&
            pop!(plotattributes, :yformatter)
    end

    # handle grid args common to all axes
    args = RecipesPipeline.pop_kw!(plotattributes, :grid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :grid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle minor grid args common to all axes
    args = RecipesPipeline.pop_kw!(plotattributes, :minorgrid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :minorgrid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # handle font args common to all axes
    for fontname in (:tickfont, :guidefont)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            for letter in (:x, :y, :z)
                processFontArg!(plotattributes, get_attr_symbol(letter, fontname), arg)
            end
        end
    end
    # handle individual axes font args
    for letter in (:x, :y, :z)
        for fontname in (:tickfont, :guidefont)
            args = RecipesPipeline.pop_kw!(
                plotattributes,
                get_attr_symbol(letter, fontname),
                (),
            )
            for arg in wraptuple(args)
                processFontArg!(plotattributes, get_attr_symbol(letter, fontname), arg)
            end
        end
    end
    # handle axes args
    for k in Commons._axis_args
        if haskey(plotattributes, k) && k !== :link
            v = plotattributes[k]
            for letter in (:x, :y, :z)
                lk = get_attr_symbol(letter, k)
                if !is_explicit(plotattributes, lk)
                    plotattributes[lk] = v
                end
            end
        end
    end

    # fonts
    for fontname in
        (:titlefont, :legend_title_font, :plot_titlefont, :colorbar_titlefont, :legend_font)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            processFontArg!(plotattributes, fontname, arg)
        end
    end

    # handle line args
    for arg in wraptuple(RecipesPipeline.pop_kw!(plotattributes, :line, ()))
        processLineArg(plotattributes, arg)
    end

    if haskey(plotattributes, :seriestype) &&
       haskey(_typeAliases, plotattributes[:seriestype])
        plotattributes[:seriestype] = _typeAliases[plotattributes[:seriestype]]
    end

    # handle marker args... default to ellipse if shape not set
    anymarker = false
    for arg in wraptuple(get(plotattributes, :marker, ()))
        processMarkerArg(plotattributes, arg)
        anymarker = true
    end
    RecipesPipeline.reset_kw!(plotattributes, :marker)
    if haskey(plotattributes, :markershape)
        plotattributes[:markershape] = _replace_markershape(plotattributes[:markershape])
        if plotattributes[:markershape] === :none &&
           get(plotattributes, :seriestype, :path) in
           (:scatter, :scatterbins, :scatterhist, :scatter3d) #the default should be :auto, not :none, so that :none can be set explicitly and would be respected
            plotattributes[:markershape] = :circle
        end
    elseif anymarker
        plotattributes[:markershape_to_add] = :circle  # add it after _apply_recipe
    end

    # handle fill
    for arg in wraptuple(get(plotattributes, :fill, ()))
        processFillArg(plotattributes, arg)
    end
    RecipesPipeline.reset_kw!(plotattributes, :fill)

    # handle series annotations
    if haskey(plotattributes, :series_annotations)
        plotattributes[:series_annotations] =
            series_annotations(wraptuple(plotattributes[:series_annotations])...)
    end

    # convert into strokes and brushes

    if haskey(plotattributes, :arrow)
        a = plotattributes[:arrow]
        plotattributes[:arrow] = if a == true
            arrow()
        elseif a in (false, nothing, :none)
            nothing
        elseif !(typeof(a) <: Arrow || typeof(a) <: AbstractArray{Arrow})
            arrow(wraptuple(a)...)
        else
            a
        end
    end

    # legends - defaults are set in `src/components.jl` (see `@add_attributes`)
    if haskey(plotattributes, :legend_position)
        plotattributes[:legend_position] =
            Commons.convert_legend_value(plotattributes[:legend_position])
    end
    if haskey(plotattributes, :colorbar)
        plotattributes[:colorbar] = Commons.convert_legend_value(plotattributes[:colorbar])
    end

    # framestyle
    if haskey(plotattributes, :framestyle) &&
       haskey(Commons._framestyleAliases, plotattributes[:framestyle])
        plotattributes[:framestyle] = Commons._framestyleAliases[plotattributes[:framestyle]]
    end

    # contours
    if haskey(plotattributes, :levels)
        Commons.check_contour_levels(plotattributes[:levels])
    end

    # warnings for moved recipes
    st = get(plotattributes, :seriestype, :path)
    if st in (:boxplot, :violin, :density) &&
       !haskey(
        Base.loaded_modules,
        Base.PkgId(Base.UUID("f3b207a7-027a-5e70-b257-86293d7955fd"), "StatsPlots"),
    )
        @warn "seriestype $st has been moved to StatsPlots.  To use: \`Pkg.add(\"StatsPlots\"); using StatsPlots\`"
    end
    nothing
end

"""
Allows temporary setting of backend and defaults for Plots. Settings apply only for the `do` block.  Example:
```
with(:gr, size=(400,400), type=:histogram) do
  plot(rand(10))
  plot(rand(10))
end
```
"""
function with(f::Function, args...; scalefonts = nothing, kw...)
    newdefs = KW(kw)

    if :canvas in args
        newdefs[:xticks] = nothing
        newdefs[:yticks] = nothing
        newdefs[:grid] = false
        newdefs[:legend_position] = false
    end

    # dict to store old and new keyword args for anything that changes
    olddefs = KW()
    for k in keys(newdefs)
        olddefs[k] = default(k)
    end

    # save the backend
    CURRENT_BACKEND.sym === :none && _pick_default_backend()
    oldbackend = CURRENT_BACKEND.sym

    for arg in args
        # change backend?
        arg in backends() && backend(arg)

        # TODO: generalize this strategy to allow args as much as possible
        #       as in:  with(:gr, :scatter, :legend, :grid) do; ...; end
        # TODO: can we generalize this enough to also do something similar in the plot commands??

        k = :legend
        if arg in (k, :leg)
            olddefs[k] = default(k)
            newdefs[k] = true
        end

        k = :grid
        if arg == k
            olddefs[k] = default(k)
            newdefs[k] = true
        end
    end

    # now set all those defaults
    default(; newdefs...)
    scalefonts ≡ nothing || scalefontsizes(scalefonts)

    # call the function
    ret = f()

    # put the defaults back
    scalefonts ≡ nothing || resetfontsizes()
    default(; olddefs...)

    # revert the backend
    CURRENT_BACKEND.sym != oldbackend && backend(oldbackend)

    # return the result of the function
    ret
end

# ---------------------------------------------------------------

# converts unicode scientific notation, as returned by Showoff,
# to a tex-like format (supported by gr, pyplot, and pgfplots).

function convert_sci_unicode(label::AbstractString)
    unicode_dict = Dict(
        '⁰' => "0",
        '¹' => "1",
        '²' => "2",
        '³' => "3",
        '⁴' => "4",
        '⁵' => "5",
        '⁶' => "6",
        '⁷' => "7",
        '⁸' => "8",
        '⁹' => "9",
        '⁻' => "-",
        "×10" => "×10^{",
    )
    for key in keys(unicode_dict)
        label = replace(label, key => unicode_dict[key])
    end
    if occursin("×10^{", label)
        label = string(label, "}")
    end
    label
end

function ___straightline_data(xl, yl, x, y, exp_fact)
    x_vals, y_vals = if y[1] == y[2]
        if x[1] == x[2]
            error("Two identical points cannot be used to describe a straight line.")
        else
            [xl[1], xl[2]], [y[1], y[2]]
        end
    elseif x[1] == x[2]
        [x[1], x[2]], [yl[1], yl[2]]
    else
        # get a and b from the line y = a * x + b through the points given by
        # the coordinates x and x
        b = y[1] - (y[1] - y[2]) * x[1] / (x[1] - x[2])
        a = (y[1] - y[2]) / (x[1] - x[2])
        # get the data values
        xdata = [
            clamp(x[1] + (x[1] - x[2]) * (ylim - y[1]) / (y[1] - y[2]), xl...) for
            ylim in yl
        ]

        xdata, a .* xdata .+ b
    end
    # expand the data outside the axis limits, by a certain factor too improve
    # plotly(js) and interactive behaviour
    (
        x_vals .+ (x_vals[2] - x_vals[1]) .* exp_fact,
        y_vals .+ (y_vals[2] - y_vals[1]) .* exp_fact,
    )
end

__straightline_data(xl, yl, x, y, exp_fact) =
    if (n = length(x)) == 2
        ___straightline_data(xl, yl, x, y, exp_fact)
    else
        k, r = divrem(n, 3)
        @assert r == 0 "Misformed data. `straightline_data` either accepts vectors of length 2 or 3k. The provided series has length $n"
        xdata, ydata = fill(NaN, n), fill(NaN, n)
        for i in 1:k
            inds = (3i - 2):(3i - 1)
            xdata[inds], ydata[inds] =
                ___straightline_data(xl, yl, x[inds], y[inds], exp_fact)
        end
        xdata, ydata
    end

_straightline_data(::Val{true}, ::Function, ::Function, ::Function, ::Function, args...) =
    __straightline_data(args...)

function _straightline_data(
    ::Val{false},
    xf::Function,
    xinvf::Function,
    yf::Function,
    yinvf::Function,
    xl,
    yl,
    x,
    y,
    exp_fact,
)
    xdata, ydata = __straightline_data(xf.(xl), yf.(yl), xf.(x), yf.(y), exp_fact)
    xinvf.(xdata), yinvf.(ydata)
end

function straightline_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = (xlims(sp), ylims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    _straightline_data(
        Val(xnoop && ynoop),
        xf,
        xinvf,
        yf,
        yinvf,
        xl,
        yl,
        series[:x],
        series[:y],
        [-expansion_factor, +expansion_factor],
    )
end

function _shape_data!(::Val{false}, xf::Function, xinvf::Function, x, xl, exp_fact)
    @inbounds for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xinvf(xf(xl[1]) - exp_fact * (xf(xl[2]) - xf(xl[1])))
        elseif x[i] == +Inf
            x[i] = xinvf(xf(xl[2]) + exp_fact * (xf(xl[2]) - xf(xl[1])))
        end
    end
    x
end

function _shape_data!(::Val{true}, ::Function, ::Function, x, xl, exp_fact)
    @inbounds for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xl[1] - exp_fact * (xl[2] - xl[1])
        elseif x[i] == +Inf
            x[i] = xl[2] + exp_fact * (xl[2] - xl[1])
        end
    end
    x
end

function shape_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = (xlims(sp), ylims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    (
        _shape_data!(Val(xnoop), xf, xinvf, copy(series[:x]), xl, expansion_factor),
        _shape_data!(Val(ynoop), yf, yinvf, copy(series[:y]), yl, expansion_factor),
    )
end

function _add_triangle!(I::Int, i::Int, j::Int, k::Int, x, y, z, X, Y, Z)
    m = 4(I - 1) + 1
    n = m + 1
    o = m + 2
    p = m + 3
    X[m] = X[p] = x[i]
    Y[m] = Y[p] = y[i]
    Z[m] = Z[p] = z[i]
    X[n] = x[j]
    Y[n] = y[j]
    Z[n] = z[j]
    X[o] = x[k]
    Y[o] = y[k]
    Z[o] = z[k]
    nothing
end

function mesh3d_triangles(x, y, z, cns::Tuple{Array,Array,Array})
    ci, cj, ck = cns
    length(ci) == length(cj) == length(ck) ||
        throw(ArgumentError("Argument connections must consist of equally sized arrays."))
    X = zeros(eltype(x), 4length(ci))
    Y = zeros(eltype(y), 4length(cj))
    Z = zeros(eltype(z), 4length(ck))
    @inbounds for I in eachindex(ci)  # connections are 0-based
        _add_triangle!(I, ci[I] + 1, cj[I] + 1, ck[I] + 1, x, y, z, X, Y, Z)
    end
    X, Y, Z
end

function mesh3d_triangles(x, y, z, cns::AbstractVector{NTuple{3,Int}})
    X = zeros(eltype(x), 4length(cns))
    Y = zeros(eltype(y), 4length(cns))
    Z = zeros(eltype(z), 4length(cns))
    @inbounds for I in eachindex(cns)  # connections are 1-based
        _add_triangle!(I, cns[I]..., x, y, z, X, Y, Z)
    end
    X, Y, Z
end

texmath2unicode(s::AbstractString, pat = r"\$([^$]+)\$") =
    replace(s, pat => m -> UnicodeFun.to_latex(m[2:(length(m) - 1)]))

_fmt_paragraph(paragraph::AbstractString; kw...) =
    _fmt_paragraph(PipeBuffer(), paragraph, 0; kw...)

function _fmt_paragraph(
    io::IOBuffer,
    remaining_text::AbstractString,
    column_count::Integer;
    fillwidth = 60,
    leadingspaces = 0,
)
    kw = (; fillwidth, leadingspaces)

    if (m = match(r"(.*?) (.*)", remaining_text)) isa Nothing
        if column_count + length(remaining_text) ≤ fillwidth
            print(io, remaining_text)
        else
            print(io, '\n', ' '^leadingspaces, remaining_text)
        end
        read(io, String)
    else
        if column_count + length(m[1]) ≤ fillwidth
            print(io, m[1], ' ')
            _fmt_paragraph(io, m[2], column_count + length(m[1]) + 1; kw...)
        else
            print(io, '\n', ' '^leadingspaces, m[1], ' ')
            _fmt_paragraph(io, m[2], leadingspaces; kw...)
        end
    end
end

_argument_description(s::Symbol) =
    if s ∈ keys(_arg_desc)
        aliases = if (al = Plots.Commons.aliases(s)) |> length > 0
            " Aliases: " * string(Tuple(al)) * '.'
        else
            ""
        end
        "`$s::$(_arg_desc[s][1])`: $(rstrip(replace(_arg_desc[s][2], '\n' => ' '), '.'))." *
        aliases
    else
        ""
    end

_document_argument(s::Symbol) =
    _fmt_paragraph(_argument_description(s), leadingspaces = 6 + length(string(s)))

# The following functions implement the guess of the optimal legend position,
# from the data series.
function d_point(x, y, lim, scale)
    p_scaled = (x / scale[1], y / scale[2])
    d = sum(abs2, lim .- p_scaled)
    isnan(d) && return 0.0
    d
end
# Function barrier because lims are type-unstable
function _guess_best_legend_position(xl, yl, plt, weight = 100)
    scale = (maximum(xl) - minimum(xl), maximum(yl) - minimum(yl))
    u = zeros(4) # faster than tuple
    # Quadrants where the points will be tested
    quadrants = (
        ((0.00, 0.25), (0.00, 0.25)),   # bottomleft
        ((0.75, 1.00), (0.00, 0.25)),   # bottomright
        ((0.00, 0.25), (0.75, 1.00)),   # topleft
        ((0.75, 1.00), (0.75, 1.00)),   # topright
    )
    for series in plt.series_list
        x = series[:x]
        y = series[:y]
        yoffset = firstindex(y) - firstindex(x)
        for (i, lim) in enumerate(Iterators.product(xl, yl))
            lim = lim ./ scale
            for ix in eachindex(x)
                xi, yi = x[ix], _cycle(y, ix + yoffset)
                # ignore y points outside quadrant visible quadrant
                xi < xl[1] + quadrants[i][1][1] * (xl[2] - xl[1]) && continue
                xi > xl[1] + quadrants[i][1][2] * (xl[2] - xl[1]) && continue
                yi < yl[1] + quadrants[i][2][1] * (yl[2] - yl[1]) && continue
                yi > yl[1] + quadrants[i][2][2] * (yl[2] - yl[1]) && continue
                u[i] += inv(1 + weight * d_point(xi, yi, lim, scale))
            end
        end
    end
    # return in the preferred order in case of draws
    ibest = findmin(u)[2]
    u[ibest] ≈ u[4] && return :topright
    u[ibest] ≈ u[3] && return :topleft
    u[ibest] ≈ u[2] && return :bottomright
    return :bottomleft
end

"""
Computes the distances of the plot limits to a sample of points at the extremes of
the ranges, and places the legend at the corner where the maximum distance to the limits is found.
"""
function _guess_best_legend_position(lp::Symbol, plt)
    lp === :best || return lp
    _guess_best_legend_position(xlims(plt), ylims(plt), plt)
end

macro ext_imp_use(imp_use::QuoteNode, mod::Symbol, args...)
    dots = ntuple(_ -> :., isdefined(Base, :get_extension) ? 1 : 3)
    ex = if length(args) > 0
        Expr(:(:), Expr(dots..., mod), Expr.(:., args)...)
    else
        Expr(dots..., mod)
    end
    Expr(imp_use.value, ex) |> esc
end

_generate_doclist(attributes) =
    replace(join(sort(collect(attributes)), "\n- "), "_" => "\\_")

# for UnitfulExt - cannot reside in `UnitfulExt` (macro)
function protectedstring end  # COV_EXCL_LINE

"""
    P_str(s)

(Unitful extension only).
Creates a string that will be Protected from recipe passes.

Example:
```julia
julia> using Unitful
julia> plot([0,1]u"m", [1,2]u"m/s^2", xlabel=P"This label will NOT display units")
julia> plot([0,1]u"m", [1,2]u"m/s^2", xlabel="This label will display units")
```
"""
macro P_str(s)
    return protectedstring(s)
end

# for `PGFPlotsx` together with `UnitfulExt`
function pgfx_sanitize_string end  # COV_EXCL_LINE
