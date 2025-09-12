# ---------------------------------------------------------------
function bool_env(x, default)::Bool
    try
        return parse(Bool, get(ENV, x, default))
    catch e
        @warn e
        return false
    end
end

treats_y_as_x(seriestype) =
    seriestype in (:vline, :vspan, :histogram, :barhist, :stephist, :scatterhist)

function replace_image_with_heatmap(z::AbstractMatrix{<:Colorant})
    n, m = size(z)
    colors = palette(vec(z))
    return reshape(1:(n * m), n, m), colors
end

# ---------------------------------------------------------------

"Build line segments for plotting"
mutable struct Segments{T}
    pts::Vector{T}
end

# Segments() = Segments{Float64}(zeros(0))

Segments() = Segments(Float64)
Segments(::Type{T}) where {T} = Segments(T[])
Segments(p::Int) = Segments(NTuple{p, Float64}[])

# Segments() = Segments(zeros(0))

to_nan(::Type{Float64}) = NaN
to_nan(::Type{NTuple{2, Float64}}) = (NaN, NaN)
to_nan(::Type{NTuple{3, Float64}}) = (NaN, NaN, NaN)

coords(segs::Segments{Float64}) = segs.pts
coords(segs::Segments{NTuple{2, Float64}}) = (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts))
coords(segs::Segments{NTuple{3, Float64}}) = (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts), map(p -> p[3], segs.pts))

function Base.push!(segments::Segments{T}, vs...) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    return segments
end

function Base.push!(segments::Segments{T}, vs::AVec) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    return segments
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
    return NaNSegmentsIterator(tup, n1, n2)
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
    return NaNMath.min(ex[1], mn), NaNMath.max(ex[2], mx)
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
        (
            if seriestype === :shape
                    # warn_on_inconsistent_shape_attr(series, x, y, z, r)
                    (SeriesSegment(segment, j),)
            elseif seriestype in (:scatter, :scatter3d)
                    (SeriesSegment(i:i, i) for i in segment)
            else
                    (SeriesSegment(i:(i + 1), i) for i in first(segment):(last(segment) - 1))
            end for (j, segment) in enumerate(nan_segments)
        ) |> Iterators.flatten
    else
        (SeriesSegment(r, 1) for r in nan_segments)
    end

    # warn_on_attr_dim_mismatch(series, x, y, z, segments)
    return segments
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
    return
end

function warn_on_inconsistent_shape_attr(series, x, y, z, r)
    for attr in _segmenting_vector_attributes
        v = get(series, attr, nothing)
        if v isa AVec && length(unique(v[r])) > 1
            @warn "Different values of `$attr` specified for different shape vertices. Only first one will be used."
            break
        end
    end
    return
end

# helpers to figure out if there are NaN values in a list of array types
anynan(i::Int, args::Tuple) = any(
    a -> try
        isnan(_cycle(a, i))
    catch MethodError
        false
    end, args
)
anynan(args::Tuple) = i -> anynan(i, args)
anynan(istart::Int, iend::Int, args::Tuple) = any(anynan(args), istart:iend)
allnan(istart::Int, iend::Int, args::Tuple) = all(anynan(args), istart:iend)

function Base.iterate(itr::NaNSegmentsIterator, nextidx::Int = itr.n1)
    (i = findfirst(!anynan(itr.args), nextidx:(itr.n2))) === nothing && return
    nextval = nextidx + i - 1

    j = findfirst(anynan(itr.args), nextval:(itr.n2))
    nextnan = j === nothing ? itr.n2 + 1 : nextval + j - 1

    return nextval:(nextnan - 1), nextnan
end
Base.IteratorSize(::NaNSegmentsIterator) = Base.SizeUnknown()  # COV_EXCL_LINE

# Find minimal type that can contain NaN and x
# To allow use of NaN separated segments with categorical x axis

float_extended_type(x::AbstractArray{T}) where {T} = Union{T, Float64}
float_extended_type(x::AbstractArray{Real}) = Float64

# ------------------------------------------------------------------------------------
_cycle(wrapper::InputWrapper, idx::Int) = wrapper.obj
_cycle(wrapper::InputWrapper, idx::AVec{Int}) = wrapper.obj

_cycle(v::AVec, idx::Int) = v[mod(idx, axes(v, 1))]
_cycle(v::AMat, idx::Int) =
    size(v, 1) == 1 ? v[end, mod(idx, axes(v, 2))] : v[:, mod(idx, axes(v, 2))]
_cycle(v, idx::Int) = v

_cycle(v::AVec, indices::AVec{Int}) = map(i -> _cycle(v, i), indices)
_cycle(v::AMat, indices::AVec{Int}) = map(i -> _cycle(v, i), indices)
_cycle(v, indices::AVec{Int}) = fill(v, length(indices))

_cycle(cl::PlotUtils.AbstractColorList, idx::Int) = cl[mod1(idx, end)]
_cycle(cl::PlotUtils.AbstractColorList, idx::AVec{Int}) = cl[mod1.(idx, end)]

_as_gradient(grad) = grad
_as_gradient(v::AbstractVector{<:Colorant}) = cgrad(v)
_as_gradient(cp::ColorPalette) = cgrad(cp, categorical = true)
_as_gradient(c::Colorant) = cgrad([c, c])

makevec(v::AVec) = v
makevec(v::T) where {T} = T[v]

"duplicate a single value, or pass the 2-tuple through"
maketuple(x::Real) = (x, x)
maketuple(x::Tuple) = x

RecipesPipeline.unzip(v) = Unzip.unzip(v)  # COV_EXCL_LINE

"collect into columns (convenience for `unzip` from `Unzip.jl`)"
unzip(v) = RecipesPipeline.unzip(v)

replaceAlias!(plotattributes::AKW, k::Symbol, aliases::Dict{Symbol, Symbol}) =
if haskey(aliases, k)
    plotattributes[aliases[k]] = RecipesPipeline.pop_kw!(plotattributes, k)
end

replaceAliases!(plotattributes::AKW, aliases::Dict{Symbol, Symbol}) =
    foreach(k -> replaceAlias!(plotattributes, k, aliases), collect(keys(plotattributes)))

scale_inverse_scale_func(scale::Symbol) = (
    RecipesPipeline.scale_func(scale),
    RecipesPipeline.inverse_scale_func(scale),
    scale === :identity,
)

function __heatmap_edges(v::AVec, isedges::Bool, ispolar::Bool)
    (n = length(v)) == 1 && return v[1] .+ [ispolar ? max(-v[1], -0.5) : -0.5, 0.5]
    isedges && return v
    # `isedges = true` means that v is a vector which already describes edges
    # and does not need to be extended.
    vmin, vmax = ignorenan_extrema(v)
    extra_min = ispolar ? min(v[1], 0.5(v[2] - v[1])) : 0.5(v[2] - v[1])
    extra_max = 0.5(v[n] - v[n - 1])
    return vcat(vmin - extra_min, 0.5(v[1:(n - 1)] + v[2:n]), vmax + extra_max)
end

_heatmap_edges(::Val{true}, v::AVec, ::Symbol, isedges::Bool, ispolar::Bool) =
    __heatmap_edges(v, isedges, ispolar)

function _heatmap_edges(::Val{false}, v::AVec, scale::Symbol, isedges::Bool, ispolar::Bool)
    f, invf = scale_inverse_scale_func(scale)
    return invf.(__heatmap_edges(f.(v), isedges, ispolar))
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
        z_size::NTuple{2, Int},
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
    return (
        _heatmap_edges(Val(xscale === :identity), x, xscale, isedges, false),
        _heatmap_edges(Val(yscale === :identity), y, yscale, isedges, ispolar),  # special handle for `r` in polar plots
    )
end

is_uniformly_spaced(v; tol = 1.0e-6) =
let dv = diff(v)
    maximum(dv) - minimum(dv) < tol * mean(abs.(dv))
end

function convert_to_polar(theta, r, r_extrema = ignorenan_extrema(r))
    rmin, rmax = r_extrema
    r = @. (r - rmin) / (rmax - rmin)
    x = @. r * cos(theta)
    y = @. r * sin(theta)
    return x, y
end

fakedata(sz::Int...) = fakedata(Random.seed!(PLOTS_SEED), sz...)

function fakedata(rng::AbstractRNG, sz...)
    y = zeros(sz...)
    for r in 2:size(y, 1)
        y[r, :] = 0.95vec(y[r - 1, :]) + randn(rng, size(y, 2))
    end
    return y
end

isijulia() = :IJulia in nameof.(collect(values(Base.loaded_modules)))
isatom() = :Atom in nameof.(collect(values(Base.loaded_modules)))

istuple(::Tuple) = true
istuple(::Any) = false
isvector(::AVec) = true
isvector(::Any) = false
ismatrix(::AMat) = true
ismatrix(::Any) = false
isscalar(::Real) = true
isscalar(::Any) = false

is_2tuple(v) = typeof(v) <: Tuple && length(v) == 2

isvertical(plotattributes::AKW) =
    get(plotattributes, :orientation, :vertical) in (:vertical, :v, :vert)
isvertical(series::Series) = isvertical(series.plotattributes)

ticksType(ticks::AVec{<:Real}) = :ticks
ticksType(ticks::AVec{<:AbstractString}) = :labels
ticksType(ticks::Tuple{<:Union{AVec, Tuple}, <:Union{AVec, Tuple}}) = :ticks_and_labels
ticksType(ticks) = :invalid

limsType(lims::Tuple{<:Real, <:Real}) = :limits
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
    return vs
end

function nanvcat(vs::AVec)
    v_out = zeros(0)
    foreach(v -> nanappend!(v_out, v), vs)
    return v_out
end

function sort_3d_axes(x, y, z, letter)
    return if letter === :x
        x, y, z
    elseif letter === :y
        y, x, z
    else
        z, y, x
    end
end

function axes_letters(sp, letter)
    return if RecipesPipeline.is3d(sp)
        sort_3d_axes(:x, :y, :z, letter)
    else
        letter === :x ? (:x, :y) : (:y, :x)
    end
end

handle_surface(z) = z
handle_surface(z::Surface) = permutedims(z.surf)

ok(x::Number, y::Number, z::Number = 0) = isfinite(x) && isfinite(y) && isfinite(z)
ok(tup::Tuple) = ok(tup...)

# compute one side of a fill range from a ribbon
function make_fillrange_side(y::AVec, rib)
    frs = zeros(axes(y))
    for (i, yi) in pairs(y)
        frs[i] = yi + _cycle(rib, i)
    end
    return frs
end

# turn a ribbon into a fillrange
function make_fillrange_from_ribbon(kw::AKW)
    y, rib = kw[:y], kw[:ribbon]
    rib = wraptuple(rib)
    rib1, rib2 = -first(rib), last(rib)
    # kw[:ribbon] = nothing
    kw[:fillrange] = make_fillrange_side(y, rib1), make_fillrange_side(y, rib2)
    return (get(kw, :fillalpha, nothing) === nothing) && (kw[:fillalpha] = 0.5)
end

#turn tuple of fillranges to one path
function concatenate_fillrange(x, y::Tuple)
    rib1, rib2 = collect(first(y)), collect(last(y)) # collect needed until https://github.com/JuliaLang/julia/pull/37629 is merged
    return vcat(x, reverse(x)), vcat(rib1, reverse(rib2))  # x, y
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

iscontour(series::Series) = series[:seriestype] in (:contour, :contour3d)
isfilledcontour(series::Series) = iscontour(series) && series[:fillrange] !== nothing

function contour_levels(series::Series, clims)
    iscontour(series) || error("Not a contour series")
    zmin, zmax = clims
    levels = series[:levels]
    if levels isa Integer
        levels = range(zmin, stop = zmax, length = levels + 2)
        isfilledcontour(series) || (levels = levels[2:(end - 1)])
    end
    return levels
end

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
            return if z === nothing
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
            return if series[$Symbol($comp_z)] === nothing
                $get_compcolor(series, 0, 1, i, s)
            else
                $get_compcolor(series, get_clims(series[:subplot]), i, s)
            end
        end

        $get_compcolor(series, clims::NTuple{2, <:Number}, args...) =
            $get_compcolor(series, clims[1], clims[2], args...)

        $get_compalpha(series, i::Integer = 1) = _cycle(series[$Symbol($compalpha)], i)
    end
end

function get_colorgradient(series::Series)
    return if (st = series[:seriestype]) in (:surface, :heatmap) || isfilledcontour(series)
        series[:fillcolor]
    elseif st in (:contour, :wireframe, :contour3d)
        series[:linecolor]
    elseif series[:marker_z] !== nothing
        series[:markercolor]
    elseif series[:line_z] !== nothing
        series[:linecolor]
    elseif series[:fill_z] !== nothing
        series[:fillcolor]
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

check_aspect_ratio(ar::AbstractVector) = nothing  # for PyPlot
check_aspect_ratio(ar::Number) = nothing
check_aspect_ratio(ar::Symbol) =
    ar in (:none, :equal, :auto) || throw(ArgumentError("Invalid `aspect_ratio` = $ar"))
check_aspect_ratio(ar::T) where {T} =
    throw(ArgumentError("Invalid `aspect_ratio`::$T = $ar "))

function get_aspect_ratio(sp)
    ar = sp[:aspect_ratio]
    check_aspect_ratio(ar)
    if ar === :auto
        ar = :none
        for series in series_list(sp)
            if series[:seriestype] === :image
                ar = :equal
            end
        end
    end
    ar isa Bool && (ar = Int(ar))  # NOTE: Bool <: ... <: Number
    return ar
end

get_size(series::Series) = get_size(series.plotattributes[:subplot])
get_size(kw) = get(kw, :size, default(:size))
get_size(plt::Plot) = get_size(plt.attr)
get_size(sp::Subplot) = get_size(sp.plt)

get_thickness_scaling(kw) = get(kw, :thickness_scaling, default(:thickness_scaling))
get_thickness_scaling(plt::Plot) = get_thickness_scaling(plt.attr)
get_thickness_scaling(sp::Subplot) = get_thickness_scaling(sp.plt)
get_thickness_scaling(series::Series) =
    get_thickness_scaling(series.plotattributes[:subplot])

# ---------------------------------------------------------------
makekw(; kw...) = KW(kw)

wraptuple(x::Tuple) = x
wraptuple(x) = (x,)

trueOrAllTrue(f::Function, x::AbstractArray) = all(f, x)
trueOrAllTrue(f::Function, x) = f(x)

allLineTypes(arg) = trueOrAllTrue(a -> get(_typeAliases, a, a) in _allTypes, arg)
allStyles(arg) = trueOrAllTrue(a -> get(_styleAliases, a, a) in _allStyles, arg)
allShapes(arg) =
    (trueOrAllTrue(a -> get(_markerAliases, a, a) in _allMarkers || a isa Shape, arg))
allAlphas(arg) = trueOrAllTrue(
    a ->
    (typeof(a) <: Real && a > 0 && a < 1) || (
        typeof(a) <: AbstractFloat && (a == zero(typeof(a)) || a == one(typeof(a)))
    ),
    arg,
)
allReals(arg) = trueOrAllTrue(a -> typeof(a) <: Real, arg)
allFunctions(arg) = trueOrAllTrue(a -> isa(a, Function), arg)

# ---------------------------------------------------------------

"""
Allows temporary setting of backend and defaults for Plots. Settings apply only for the `do` block.  Example:
```
Plots.with(:gr, size=(400,400), type=:histogram) do
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
    return ret
end

# ---------------------------------------------------------------

const _debug = Ref(false)

debug!(on = true) = _debug[] = on
debugshow(io, x) = show(io, x)
debugshow(io, x::AbstractArray) = print(io, summary(x))

function dumpdict(io::IO, plotattributes::AKW, prefix = "")
    _debug[] || return
    println(io)
    prefix == "" || println(io, prefix, ":")
    for k in sort(collect(keys(plotattributes)))
        @printf(io, "%14s: ", k)
        debugshow(io, plotattributes[k])
        println(io)
    end
    return println(io)
end

# -------------------------------------------------------
# indexing notation

Base.setindex!(plt::Plot, xy::NTuple{2}, i::Integer) = (setxy!(plt, xy, i); plt)
Base.setindex!(plt::Plot, xyz::Tuple{3}, i::Integer) = (setxyz!(plt, xyz, i); plt)

# -------------------------------------------------------
# operate on individual series

Base.push!(series::Series, args...) = extend_series!(series, args...)
Base.append!(series::Series, args...) = extend_series!(series, args...)

function extend_series!(series::Series, yi)
    y = extend_series_data!(series, yi, :y)
    x = extend_to_length!(series[:x], length(y))
    expand_extrema!(series[:subplot][:xaxis], x)
    return x, y
end

extend_series!(series::Series, xi, yi) =
    (extend_series_data!(series, xi, :x), extend_series_data!(series, yi, :y))

extend_series!(series::Series, xi, yi, zi) = (
    extend_series_data!(series, xi, :x),
    extend_series_data!(series, yi, :y),
    extend_series_data!(series, zi, :z),
)

function extend_series_data!(series::Series, v, letter)
    copy_series!(series, letter)
    d = extend_by_data!(series[letter], v)
    expand_extrema!(series[:subplot][get_attr_symbol(letter, :axis)], d)
    return d
end

function copy_series!(series, letter)
    plt = series[:plot_object]
    for s in plt.series_list, l in (:x, :y, :z)
        if (s !== series || l !== letter) && s[l] === series[letter]
            series[letter] = copy(series[letter])
        end
    end
    return
end

extend_to_length!(v::AbstractRange, n) = range(first(v), step = step(v), length = n)
function extend_to_length!(v::AbstractVector, n)
    vmax = isempty(v) ? 0 : ignorenan_maximum(v)
    return extend_by_data!(v, vmax .+ (1:(n - length(v))))
end
extend_by_data!(v::AbstractVector, x) = isimmutable(v) ? vcat(v, x) : push!(v, x)
extend_by_data!(v::AbstractVector, x::AbstractVector) =
    isimmutable(v) ? vcat(v, x) : append!(v, x)

# -------------------------------------------------------

function attr!(series::Series; kw...)
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)
    for (k, v) in plotattributes
        if haskey(_series_defaults, k)
            series[k] = v
        else
            @warn "unused key $k in series attr"
        end
    end
    _series_updated(series[:subplot].plt, series)
    return series
end

function attr!(sp::Subplot; kw...)
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)
    for (k, v) in plotattributes
        if haskey(_subplot_defaults, k)
            sp[k] = v
        else
            @warn "unused key $k in subplot attr"
        end
    end
    return sp
end

# -------------------------------------------------------
# push/append for one series

Base.push!(plt::Plot, args::Real...) = push!(plt, 1, args...)
Base.push!(plt::Plot, i::Integer, args::Real...) = push!(plt.series_list[i], args...)
Base.append!(plt::Plot, args::AbstractVector) = append!(plt, 1, args...)
Base.append!(plt::Plot, i::Integer, args::Real...) = append!(plt.series_list[i], args...)

# tuples
Base.push!(plt::Plot, t::Tuple) = push!(plt, 1, t...)
Base.push!(plt::Plot, i::Integer, t::Tuple) = push!(plt, i, t...)
Base.append!(plt::Plot, t::Tuple) = append!(plt, 1, t...)
Base.append!(plt::Plot, i::Integer, t::Tuple) = append!(plt, i, t...)

# -------------------------------------------------------
# push/append for all series

# push y[i] to the ith series
function Base.push!(plt::Plot, y::AVec)
    ny = length(y)
    for i in 1:(plt.n)
        push!(plt, i, y[mod1(i, ny)])
    end
    return plt
end

# push y[i] to the ith series
# same x for each series
Base.push!(plt::Plot, x::Real, y::AVec) = push!(plt, [x], y)

# push (x[i], y[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec)
    nx = length(x)
    ny = length(y)
    for i in 1:(plt.n)
        push!(plt, i, x[mod1(i, nx)], y[mod1(i, ny)])
    end
    return plt
end

# push (x[i], y[i], z[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec, z::AVec)
    nx = length(x)
    ny = length(y)
    nz = length(z)
    for i in 1:(plt.n)
        push!(plt, i, x[mod1(i, nx)], y[mod1(i, ny)], z[mod1(i, nz)])
    end
    return plt
end

# ---------------------------------------------------------------

# Some conversion functions
# note: I borrowed these conversion constants from Compose.jl's Measure

inch2px(inches::Real) = float(inches * PX_PER_INCH)
px2inch(px::Real) = float(px / PX_PER_INCH)
inch2mm(inches::Real) = float(inches * MM_PER_INCH)
mm2inch(mm::Real) = float(mm / MM_PER_INCH)
px2mm(px::Real) = float(px * MM_PER_PX)
mm2px(mm::Real) = float(mm / MM_PER_PX)

"Smallest x in plot"
xmin(plt::Plot) = ignorenan_minimum(
    [
        ignorenan_minimum(series.plotattributes[:x]) for series in plt.series_list
    ]
)
"Largest x in plot"
xmax(plt::Plot) = ignorenan_maximum(
    [
        ignorenan_maximum(series.plotattributes[:x]) for series in plt.series_list
    ]
)

"Extrema of x-values in plot"
ignorenan_extrema(plt::Plot) = (xmin(plt), xmax(plt))

# ---------------------------------------------------------------
# get fonts from objects:

plottitlefont(p::Plot) = font(;
    family = p[:plot_titlefontfamily],
    pointsize = p[:plot_titlefontsize],
    valign = p[:plot_titlefontvalign],
    halign = p[:plot_titlefonthalign],
    rotation = p[:plot_titlefontrotation],
    color = p[:plot_titlefontcolor],
)

colorbartitlefont(sp::Subplot) = font(;
    family = sp[:colorbar_titlefontfamily],
    pointsize = sp[:colorbar_titlefontsize],
    valign = sp[:colorbar_titlefontvalign],
    halign = sp[:colorbar_titlefonthalign],
    rotation = sp[:colorbar_titlefontrotation],
    color = sp[:colorbar_titlefontcolor],
)

titlefont(sp::Subplot) = font(;
    family = sp[:titlefontfamily],
    pointsize = sp[:titlefontsize],
    valign = sp[:titlefontvalign],
    halign = sp[:titlefonthalign],
    rotation = sp[:titlefontrotation],
    color = sp[:titlefontcolor],
)

legendfont(sp::Subplot) = font(;
    family = sp[:legend_font_family],
    pointsize = sp[:legend_font_pointsize],
    valign = sp[:legend_font_valign],
    halign = sp[:legend_font_halign],
    rotation = sp[:legend_font_rotation],
    color = sp[:legend_font_color],
)

legendtitlefont(sp::Subplot) = font(;
    family = sp[:legend_title_font_family],
    pointsize = sp[:legend_title_font_pointsize],
    valign = sp[:legend_title_font_valign],
    halign = sp[:legend_title_font_halign],
    rotation = sp[:legend_title_font_rotation],
    color = sp[:legend_title_font_color],
)

tickfont(ax::Axis) = font(;
    family = ax[:tickfontfamily],
    pointsize = ax[:tickfontsize],
    valign = ax[:tickfontvalign],
    halign = ax[:tickfonthalign],
    rotation = ax[:tickfontrotation],
    color = ax[:tickfontcolor],
)

guidefont(ax::Axis) = font(;
    family = ax[:guidefontfamily],
    pointsize = ax[:guidefontsize],
    valign = ax[:guidefontvalign],
    halign = ax[:guidefonthalign],
    rotation = ax[:guidefontrotation],
    color = ax[:guidefontcolor],
)

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
    return label
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
    return (
        x_vals .+ (x_vals[2] - x_vals[1]) .* exp_fact,
        y_vals .+ (y_vals[2] - y_vals[1]) .* exp_fact,
    )
end

function __straightline_data(xl, yl, x, y, exp_fact)
    return if (n = length(x)) == 2
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
    return xinvf.(xdata), yinvf.(ydata)
end

function straightline_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = isvertical(series) ? (xlims(sp), ylims(sp)) : (ylims(sp), xlims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    return _straightline_data(
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
    return x
end

function _shape_data!(::Val{true}, ::Function, ::Function, x, xl, exp_fact)
    @inbounds for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xl[1] - exp_fact * (xl[2] - xl[1])
        elseif x[i] == +Inf
            x[i] = xl[2] + exp_fact * (xl[2] - xl[1])
        end
    end
    return x
end

function shape_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = isvertical(series) ? (xlims(sp), ylims(sp)) : (ylims(sp), xlims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    return (
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
    return nothing
end

function mesh3d_triangles(x, y, z, cns::Tuple{Array, Array, Array})
    ci, cj, ck = cns
    length(ci) == length(cj) == length(ck) ||
        throw(ArgumentError("Argument connections must consist of equally sized arrays."))
    X = zeros(eltype(x), 4length(ci))
    Y = zeros(eltype(y), 4length(cj))
    Z = zeros(eltype(z), 4length(ck))
    @inbounds for I in eachindex(ci)  # connections are 0-based
        _add_triangle!(I, ci[I] + 1, cj[I] + 1, ck[I] + 1, x, y, z, X, Y, Z)
    end
    return X, Y, Z
end

function mesh3d_triangles(x, y, z, cns::AbstractVector{NTuple{3, Int}})
    X = zeros(eltype(x), 4length(cns))
    Y = zeros(eltype(y), 4length(cns))
    Z = zeros(eltype(z), 4length(cns))
    @inbounds for I in eachindex(cns)  # connections are 1-based
        _add_triangle!(I, cns[I]..., x, y, z, X, Y, Z)
    end
    return X, Y, Z
end

# cache joined symbols so they can be looked up instead of constructed each time
const _attrsymbolcache = Dict{Symbol, Dict{Symbol, Symbol}}()

get_attr_symbol(letter::Symbol, keyword::String) = get_attr_symbol(letter, Symbol(keyword))
get_attr_symbol(letter::Symbol, keyword::Symbol) = _attrsymbolcache[letter][keyword]

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

    return if (m = match(r"(.*?) (.*)", remaining_text)) isa Nothing
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
    aliases = if (al = Plots.aliases(s)) |> length > 0
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
    return d
end
# Function barrier because lims are type-unstable
function _guess_best_legend_position(xl, yl, plt, weight = 100)
    scale = (maximum(xl) - minimum(xl), maximum(yl) - minimum(yl))
    u = zeros(4) # faster than tuple
    # Quadrants where the points will be tested
    quadrants = (
        ((0.0, 0.25), (0.0, 0.25)),   # bottomleft
        ((0.75, 1.0), (0.0, 0.25)),   # bottomright
        ((0.0, 0.25), (0.75, 1.0)),   # topleft
        ((0.75, 1.0), (0.75, 1.0)),   # topright
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
    return _guess_best_legend_position(xlims(plt), ylims(plt), plt)
end

macro ext_imp_use(imp_use::QuoteNode, mod::Symbol, args...)
    dots = ntuple(_ -> :., isdefined(Base, :get_extension) ? 1 : 3)
    ex = if length(args) > 0
        Expr(:(:), Expr(dots..., mod), Expr.(:., args)...)
    else
        Expr(dots..., mod)
    end
    return Expr(imp_use.value, ex) |> esc
end

# for UnitfulExt
abstract type AbstractProtectedString <: AbstractString end
struct ProtectedString{S} <: AbstractProtectedString
    content::S
end
const APS = AbstractProtectedString
# Minimum required AbstractString interface to work with PlotsBase
Base.iterate(n::APS) = iterate(n.content)
Base.iterate(n::APS, i::Integer) = iterate(n.content, i)
Base.codeunit(n::APS) = codeunit(n.content)
Base.ncodeunits(n::APS) = ncodeunits(n.content)
Base.isvalid(n::APS, i::Integer) = isvalid(n.content, i)
Base.pointer(n::APS) = pointer(n.content)
Base.pointer(n::APS, i::Integer) = pointer(n.content, i)
function protectedstring(s)
    Base.depwarn(
        """
        `protectedstring` and the `P_str` macro (used for Unitful plots) are deprecated,
        and will be dropped in Plots.jl 2.0 .

        To suppress all axis labels, pass an empty string to `xlabel`, etc.
        To suppress units in axis labels pass `unitformat = :nounit` or `unitformat=(l,u)->l`
        (equivalently for `xunitformat`, `yunitformat`, etc.).
            """,
        :protectedstring,
        force = true,
    )
    return ProtectedString(s)
end

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
