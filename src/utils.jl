
function replace_image_with_heatmap(z::Array{T}) where T<:Colorant
    n, m = size(z)
    colors = palette(vec(z))
    newz = reshape(1:n*m, n, m)
    newz, colors
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
to_nan(::Type{NTuple{2,Float64}}) = (NaN, NaN)
to_nan(::Type{NTuple{3,Float64}}) = (NaN, NaN, NaN)

coords(segs::Segments{Float64}) = segs.pts
coords(segs::Segments{NTuple{2,Float64}}) = Float64[p[1] for p in segs.pts], Float64[p[2] for p in segs.pts]
coords(segs::Segments{NTuple{3,Float64}}) = Float64[p[1] for p in segs.pts], Float64[p[2] for p in segs.pts], Float64[p[3] for p in segs.pts]

function Base.push!(segments::Segments{T}, vs...) where T
    if !isempty(segments.pts)
        push!(segments.pts, to_nan(T))
    end
    for v in vs
        push!(segments.pts, convert(T,v))
    end
    segments
end

function Base.push!(segments::Segments{T}, vs::AVec) where T
    if !isempty(segments.pts)
        push!(segments.pts, to_nan(T))
    end
    for v in vs
        push!(segments.pts, convert(T,v))
    end
    segments
end


# -----------------------------------------------------
# helper to manage NaN-separated segments

mutable struct SegmentsIterator
    args::Tuple
    n1::Int
    n2::Int
end

function iter_segments(args...)
    tup = Plots.wraptuple(args)
    n1 = minimum(map(firstindex, tup))
    n2 = maximum(map(lastindex, tup))
    SegmentsIterator(tup, n1, n2)
end

function iter_segments(series::Series)
    x, y, z = series[:x], series[:y], series[:z]
    if x === nothing
        return UnitRange{Int}[]
    elseif has_attribute_segments(series)
        if series[:seriestype] in (:scatter, :scatter3d)
            return [[i] for i in eachindex(y)]
        else
            if any(isnan,y)
                return [iter_segments(y)...]
            else
                return [i:(i + 1) for i in firstindex(y):lastindex(y)-1]
            end
        end
    else
        segs = UnitRange{Int}[]
        args = RecipesPipeline.is3d(series) ? (x, y, z) : (x, y)
        for seg in iter_segments(args...)
            push!(segs, seg)
        end
        return segs
    end
end

# helpers to figure out if there are NaN values in a list of array types
anynan(i::Int, args::Tuple) = any(a -> try isnan(_cycle(a,i)) catch MethodError false end, args)
anynan(args::Tuple) = i -> anynan(i,args)
anynan(istart::Int, iend::Int, args::Tuple) = any(anynan(args), istart:iend)
allnan(istart::Int, iend::Int, args::Tuple) = all(anynan(args), istart:iend)

function Base.iterate(itr::SegmentsIterator, nextidx::Int = itr.n1)
    i = findfirst(!anynan(itr.args), nextidx:itr.n2)
    i === nothing && return nothing
    nextval = nextidx + i - 1

    j = findfirst(anynan(itr.args), nextval:itr.n2)
    nextnan = j === nothing ? itr.n2 + 1 : nextval + j - 1

    nextval:nextnan-1, nextnan
end

# Find minimal type that can contain NaN and x
# To allow use of NaN separated segments with categorical x axis

float_extended_type(x::AbstractArray{T}) where {T} = Union{T,Float64}
float_extended_type(x::AbstractArray{T}) where {T<:Real} = Float64

# ------------------------------------------------------------------------------------


nop() = nothing
notimpl() = error("This has not been implemented yet")

isnothing(x::Nothing) = true
isnothing(x) = false

_cycle(wrapper::InputWrapper, idx::Int) = wrapper.obj
_cycle(wrapper::InputWrapper, idx::AVec{Int}) = wrapper.obj

_cycle(v::AVec, idx::Int) = v[mod1(idx, length(v))]
_cycle(v::AMat, idx::Int) = size(v,1) == 1 ? v[1, mod1(idx, size(v,2))] : v[:, mod1(idx, size(v,2))]
_cycle(v, idx::Int)       = v

_cycle(v::AVec, indices::AVec{Int}) = map(i -> _cycle(v,i), indices)
_cycle(v::AMat, indices::AVec{Int}) = map(i -> _cycle(v,i), indices)
_cycle(v, indices::AVec{Int})       = fill(v, length(indices))

_cycle(cl::PlotUtils.AbstractColorList, idx::Int) = cl[mod1(idx, end)]
_cycle(cl::PlotUtils.AbstractColorList, idx::AVec{Int}) = cl[mod1.(idx, end)]

_as_gradient(grad) = grad
_as_gradient(v::AbstractVector{<:Colorant}) = cgrad(v)
_as_gradient(cp::ColorPalette) = cgrad(cp, categorical = true)
_as_gradient(c::Colorant) = cgrad([c, c])

makevec(v::AVec) = v
makevec(v::T) where {T} = T[v]

"duplicate a single value, or pass the 2-tuple through"
maketuple(x::Real)                     = (x,x)
maketuple(x::Tuple{T,S}) where {T,S} = x

for i in 2:4
    @eval begin
        RecipesPipeline.unzip(v::Union{AVec{<:Tuple{Vararg{T,$i} where T}},
                   AVec{<:GeometryTypes.Point{$i}}}) = $(Expr(:tuple, (:([t[$j] for t in v]) for j=1:i)...))
    end
end

RecipesPipeline.unzip(v::Union{AVec{<:GeometryTypes.Point{N}},
               AVec{<:Tuple{Vararg{T,N} where T}}}) where N = error("$N-dimensional unzip not implemented.")
RecipesPipeline.unzip(v::Union{AVec{<:GeometryTypes.Point},
               AVec{<:Tuple}}) = error("Can't unzip points of different dimensions.")

# given 2-element lims and a vector of data x, widen lims to account for the extrema of x
function _expand_limits(lims, x)
    try
        e1, e2 = ignorenan_extrema(x)
        lims[1] = NaNMath.min(lims[1], e1)
        lims[2] = NaNMath.max(lims[2], e2)
    catch
    end
    nothing
end

expand_data(v, n::Integer) = [_cycle(v, i) for i=1:n]

# if the type exists in a list, replace the first occurence.  otherwise add it to the end
function addOrReplace(v::AbstractVector, t::DataType, args...; kw...)
    for (i,vi) in enumerate(v)
        if isa(vi, t)
            v[i] = t(args...; kw...)
            return
        end
    end
    push!(v, t(args...; kw...))
    return
end

function replaceType(vec, val)
    filter!(x -> !isa(x, typeof(val)), vec)
    push!(vec, val)
end

function replaceAlias!(plotattributes::AKW, k::Symbol, aliases::Dict{Symbol,Symbol})
    if haskey(aliases, k)
        plotattributes[aliases[k]] = RecipesPipeline.pop_kw!(plotattributes, k)
    end
end

function replaceAliases!(plotattributes::AKW, aliases::Dict{Symbol,Symbol})
    ks = collect(keys(plotattributes))
    for k in ks
        replaceAlias!(plotattributes, k, aliases)
    end
end

createSegments(z) = collect(repeat(reshape(z,1,:),2,1))[2:end]

Base.first(c::Colorant) = c
Base.first(x::Symbol) = x


sortedkeys(plotattributes::Dict) = sort(collect(keys(plotattributes)))

function _heatmap_edges(v::AVec, isedges::Bool = false)
    length(v) == 1 && return v[1] .+ [-0.5, 0.5]
    if isedges return v end
    # `isedges = true` means that v is a vector which already describes edges
    # and does not need to be extended.
    vmin, vmax = ignorenan_extrema(v)
    extra_min = (v[2] - v[1]) / 2
    extra_max = (v[end] - v[end - 1]) / 2
    vcat(vmin-extra_min, 0.5 * (v[1:end-1] + v[2:end]), vmax+extra_max)
end

"create an (n+1) list of the outsides of heatmap rectangles"
function heatmap_edges(v::AVec, scale::Symbol = :identity, isedges::Bool = false)
    f, invf = RecipesPipeline.scale_func(scale), RecipesPipeline.inverse_scale_func(scale)
    map(invf, _heatmap_edges(map(f,v), isedges))
end

function heatmap_edges(x::AVec, xscale::Symbol, y::AVec, yscale::Symbol, z_size::Tuple{Int, Int})
    nx, ny = length(x), length(y)
    # ismidpoints = z_size == (ny, nx) # This fails some tests, but would actually be
    # the correct check, since (4, 3) != (3, 4) and a missleading plot is produced.
    ismidpoints = prod(z_size) == (ny * nx)
    isedges = z_size == (ny - 1, nx - 1)
    if !ismidpoints && !isedges
        error("""Length of x & y does not match the size of z.
                Must be either `size(z) == (length(y), length(x))` (x & y define midpoints)
                or `size(z) == (length(y)+1, length(x)+1))` (x & y define edges).""")
    end
    x, y = heatmap_edges(x, xscale, isedges),
           heatmap_edges(y, yscale, isedges)
    return x, y
end

function is_uniformly_spaced(v; tol=1e-6)
    dv = diff(v)
    maximum(dv) - minimum(dv) < tol * mean(abs.(dv))
end

function convert_to_polar(theta, r, r_extrema = ignorenan_extrema(r))
    rmin, rmax = r_extrema
    r = (r .- rmin) ./ (rmax .- rmin)
    x = r.*cos.(theta)
    y = r.*sin.(theta)
    x, y
end

function fakedata(sz...)
    y = zeros(sz...)
    for r in 2:size(y,1)
        y[r,:] = 0.95 * vec(y[r-1,:]) + randn(size(y,2))
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


isvertical(plotattributes::AKW) = get(plotattributes, :orientation, :vertical) in (:vertical, :v, :vert)
isvertical(series::Series) = isvertical(series.plotattributes)


ticksType(ticks::AVec{T}) where {T<:Real}                      = :ticks
ticksType(ticks::AVec{T}) where {T<:AbstractString}            = :labels
ticksType(ticks::Tuple{T,S}) where {T<:Union{AVec,Tuple},S<:Union{AVec,Tuple}} = :ticks_and_labels
ticksType(ticks)                                        = :invalid

limsType(lims::Tuple{T,S}) where {T<:Real,S<:Real}    = :limits
limsType(lims::Symbol)                                  = lims == :auto ? :auto : :invalid
limsType(lims)                                          = :invalid

# axis_Symbol(letter, postfix) = Symbol(letter * postfix)
# axis_symbols(letter, postfix...) = map(s -> axis_Symbol(letter, s), postfix)

Base.convert(::Type{Vector{T}}, rng::AbstractRange{T}) where {T<:Real}         = T[x for x in rng]
Base.convert(::Type{Vector{T}}, rng::AbstractRange{S}) where {T<:Real,S<:Real} = T[x for x in rng]

Base.merge(a::AbstractVector, b::AbstractVector) = sort(unique(vcat(a,b)))

nanpush!(a::AbstractVector, b) = (push!(a, NaN); push!(a, b))
nanappend!(a::AbstractVector, b) = (push!(a, NaN); append!(a, b))

function nansplit(v::AVec)
    vs = Vector{eltype(v)}[]
    while true
        idx = findfirst(isnan, v)
        if idx <= 0
            # no nans
            push!(vs, v)
            break
        elseif idx > 1
            push!(vs, v[1:idx-1])
        end
        v = v[idx+1:end]
    end
    vs
end

function nanvcat(vs::AVec)
    v_out = zeros(0)
    for v in vs
        nanappend!(v_out, v)
    end
    v_out
end

# given an array of discrete values, turn it into an array of indices of the unique values
# returns the array of indices (znew) and a vector of unique values (vals)
function indices_and_unique_values(z::AbstractArray)
    vals = sort(unique(z))
    vmap = Dict([(v,i) for (i,v) in enumerate(vals)])
    newz = map(zi -> vmap[zi], z)
    newz, vals
end

# this is a helper function to determine whether we need to transpose a surface matrix.
# it depends on whether the backend matches rows to x (transpose_on_match == true) or vice versa
# for example: PyPlot sends rows to y, so transpose_on_match should be true
function transpose_z(plotattributes, z, transpose_on_match::Bool = true)
    if plotattributes[:match_dimensions] == transpose_on_match
        # z'
        permutedims(z, [2,1])
    else
        z
    end
end

function ok(x::Number, y::Number, z::Number = 0)
    isfinite(x) && isfinite(y) && isfinite(z)
end
ok(tup::Tuple) = ok(tup...)

# compute one side of a fill range from a ribbon
function make_fillrange_side(y, rib)
    frs = zeros(length(y))
    for (i, (yi, ri)) in enumerate(zip(y, Base.Iterators.cycle(rib)))
        frs[i] = yi + ri
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
function concatenate_fillrange(x,y::Tuple)
    rib1, rib2 = first(y), last(y)
    yline = vcat(rib1,(rib2)[end:-1:1])
    xline = vcat(x,x[end:-1:1])
    return xline, yline
end

function get_sp_lims(sp::Subplot, letter::Symbol)
    axis_limits(sp, letter)
end

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

# These functions return an operator for use in `get_clims(::Seres, op)`
process_clims(lims::NTuple{2,<:Number}) = (zlims -> ifelse.(isfinite.(lims), lims, zlims)) ∘ ignorenan_extrema
process_clims(s::Union{Symbol,Nothing,Missing}) = ignorenan_extrema
# don't specialize on ::Function otherwise python functions won't work
process_clims(f) = f

function get_clims(sp::Subplot, op=process_clims(sp[:clims]))
    zmin, zmax = Inf, -Inf
    for series in series_list(sp)
        if series[:colorbar_entry]
            zmin, zmax = _update_clims(zmin, zmax, get_clims(series, op)...)
        end
    end
    return zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

function get_clims(sp::Subplot, series::Series, op=process_clims(sp[:clims]))
    zmin, zmax = if series[:colorbar_entry]
        get_clims(sp, op)
    else
        get_clims(series, op)
    end
    return zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

"""
    get_clims(::Series, op=Plots.ignorenan_extrema)

Finds the limits for the colorbar by taking the "z-values" for the series and passing them into `op`,
which must return the tuple `(zmin, zmax)`. The default op is the extrema of the finite
values of the input.
"""
function get_clims(series::Series, op=ignorenan_extrema)
    zmin, zmax = Inf, -Inf
    z_colored_series = (:contour, :contour3d, :heatmap, :histogram2d, :surface)
    for vals in (series[:seriestype] in z_colored_series ? series[:z] : nothing, series[:line_z], series[:marker_z], series[:fill_z])
        if (typeof(vals) <: AbstractSurface) && (eltype(vals.surf) <: Union{Missing, Real})
            zmin, zmax = _update_clims(zmin, zmax, op(vals.surf)...)
        elseif (vals !== nothing) && (eltype(vals) <: Union{Missing, Real})
            zmin, zmax = _update_clims(zmin, zmax, op(vals)...)
        end
    end
    return zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

_update_clims(zmin, zmax, emin, emax) = NaNMath.min(zmin, emin), NaNMath.max(zmax, emax)

@enum ColorbarStyle cbar_gradient cbar_fill cbar_lines

function colorbar_style(series::Series)
    colorbar_entry = series[:colorbar_entry]
    if !(colorbar_entry isa Bool)
        @warn "Non-boolean colorbar_entry ignored."
        colorbar_entry = true
    end

    if !colorbar_entry
        nothing
    elseif isfilledcontour(series)
        cbar_fill
    elseif iscontour(series)
        cbar_lines
    elseif series[:seriestype] ∈ (:heatmap,:surface) ||
            any(series[z] !== nothing for z ∈ [:marker_z,:line_z,:fill_z])
        cbar_gradient
    else
        nothing
    end
end

hascolorbar(series::Series) = colorbar_style(series) !== nothing
hascolorbar(sp::Subplot) = sp[:colorbar] != :none && any(hascolorbar(s) for s in series_list(sp))

iscontour(series::Series) = series[:seriestype] == :contour
isfilledcontour(series::Series) = iscontour(series) && series[:fillrange] !== nothing

function contour_levels(series::Series, clims)
    iscontour(series) || error("Not a contour series")
    zmin, zmax = clims
    levels = series[:levels]
    if levels isa Integer
        levels = range(zmin, stop=zmax, length=levels+2)
        if !isfilledcontour(series)
            levels = levels[2:end-1]
        end
    end
    levels
end



for comp in (:line, :fill, :marker)

    compcolor = string(comp, :color)
    get_compcolor = Symbol(:get_, compcolor)
    comp_z = string(comp, :_z)

    compalpha = string(comp, :alpha)
    get_compalpha = Symbol(:get_, compalpha)

    @eval begin

        function $get_compcolor(series, cmin::Real, cmax::Real, i::Int = 1)
            c = series[$Symbol($compcolor)]
            z = series[$Symbol($comp_z)]
            if z === nothing
                isa(c, ColorGradient) ? c : plot_color(_cycle(c, i))
            else
                get(get_gradient(c), z[i], (cmin, cmax))
            end
        end

        $get_compcolor(series, clims, i::Int = 1) = $get_compcolor(series, clims[1], clims[2], i)

        function $get_compcolor(series, i::Int = 1)
            if series[$Symbol($comp_z)] === nothing
                $get_compcolor(series, 0, 1, i)
            else
                $get_compcolor(series, get_clims(series[:subplot]), i)
            end
        end

        $get_compalpha(series, i::Int = 1) = _cycle(series[$Symbol($compalpha)], i)
    end
end

function get_colorgradient(series::Series)
    st = series[:seriestype]
    if st in (:surface, :heatmap) || isfilledcontour(series)
        series[:fillcolor]
    elseif st in (:contour, :wireframe)
        series[:linecolor]
    elseif series[:marker_z] !== nothing
        series[:markercolor]
    elseif series[:line_z] !==  nothing
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

function get_linewidth(series, i::Int = 1)
    _cycle(series[:linewidth], i)
end

function get_linestyle(series, i::Int = 1)
    _cycle(series[:linestyle], i)
end

function get_markerstrokecolor(series, i::Int = 1)
    msc = series[:markerstrokecolor]
    isa(msc, ColorGradient) ? msc : _cycle(msc, i)
end

function get_markerstrokealpha(series, i::Int = 1)
    _cycle(series[:markerstrokealpha], i)
end

function get_markerstrokewidth(series, i::Int = 1)
    _cycle(series[:markerstrokewidth], i)
end

function has_attribute_segments(series::Series)
    # we want to check if a series needs to be split into segments just because
    # of its attributes
    for letter in (:x, :y, :z)
        # If we have NaNs in the data they define the segments and
        # SegmentsIterator is used
        series[letter] !== nothing && NaN in collect(series[letter]) && return false
    end
    series[:seriestype] == :shape && return false
    # ... else we check relevant attributes if they have multiple inputs
    return any(
        (typeof(series[attr]) <: AbstractVector && length(series[attr]) > 1)
        for
        attr in [
            :seriescolor,
            :seriesalpha,
            :linecolor,
            :linealpha,
            :linewidth,
            :linestyle,
            :fillcolor,
            :fillalpha,
            :markercolor,
            :markeralpha,
            :markersize,
            :markerstrokecolor,
            :markerstrokealpha,
            :markerstrokewidth,
        ]
    ) || any(
        typeof(series[attr]) <: AbstractArray for attr in (:line_z, :fill_z, :marker_z)
    )
end

function get_aspect_ratio(sp)
    aspect_ratio = sp[:aspect_ratio]
    if aspect_ratio == :auto
        aspect_ratio = :none
        for series in series_list(sp)
            if series[:seriestype] == :image
                aspect_ratio = :equal
            end
        end
    end
    return aspect_ratio
end

get_size(kw) = get(kw, :size, default(:size))
get_size(plt::Plot) = get_size(plt.attr)
get_size(sp::Subplot) = get_size(sp.plt)
get_size(series::Series) = get_size(series.plotattributes[:subplot])

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

allLineTypes(arg)   = trueOrAllTrue(a -> get(_typeAliases, a, a) in _allTypes, arg)
allStyles(arg)      = trueOrAllTrue(a -> get(_styleAliases, a, a) in _allStyles, arg)
allShapes(arg)      = trueOrAllTrue(a -> is_marker_supported(get(_markerAliases, a, a)), arg) ||
                        trueOrAllTrue(a -> isa(a, Shape), arg)
allAlphas(arg)      = trueOrAllTrue(a -> (typeof(a) <: Real && a > 0 && a < 1) ||
                        (typeof(a) <: AbstractFloat && (a == zero(typeof(a)) || a == one(typeof(a)))), arg)
allReals(arg)       = trueOrAllTrue(a -> typeof(a) <: Real, arg)
allFunctions(arg)   = trueOrAllTrue(a -> isa(a, Function), arg)

# ---------------------------------------------------------------
# ---------------------------------------------------------------


"""
Allows temporary setting of backend and defaults for Plots. Settings apply only for the `do` block.  Example:
```
with(:gr, size=(400,400), type=:histogram) do
  plot(rand(10))
  plot(rand(10))
end
```
"""
function with(f::Function, args...; kw...)
    newdefs = KW(kw)

    if :canvas in args
        newdefs[:xticks] = nothing
        newdefs[:yticks] = nothing
        newdefs[:grid] = false
        newdefs[:legend] = false
    end

    # dict to store old and new keyword args for anything that changes
    olddefs = KW()
    for k in keys(newdefs)
        olddefs[k] = default(k)
    end

    # save the backend
    if CURRENT_BACKEND.sym == :none
        _pick_default_backend()
    end
    oldbackend = CURRENT_BACKEND.sym

    for arg in args

        # change backend?
        if arg in backends()
            backend(arg)
        end

        # TODO: generalize this strategy to allow args as much as possible
        #       as in:  with(:gr, :scatter, :legend, :grid) do; ...; end
        # TODO: can we generalize this enough to also do something similar in the plot commands??

        # k = :seriestype
        # if arg in _allTypes
        #     olddefs[k] = default(k)
        #     newdefs[k] = arg
        # elseif haskey(_typeAliases, arg)
        #     olddefs[k] = default(k)
        #     newdefs[k] = _typeAliases[arg]
        # end

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

    # display(olddefs)
    # display(newdefs)

    # now set all those defaults
    default(; newdefs...)

    # call the function
    ret = f()

    # put the defaults back
    default(; olddefs...)

    # revert the backend
    if CURRENT_BACKEND.sym != oldbackend
        backend(oldbackend)
    end

    # return the result of the function
    ret
end

# ---------------------------------------------------------------
# ---------------------------------------------------------------

mutable struct DebugMode
    on::Bool
end
const _debugMode = DebugMode(false)

function debugplots(on = true)
    _debugMode.on = on
end

debugshow(io, x) = show(io, x)
debugshow(io, x::AbstractArray) = print(io, summary(x))

function dumpdict(io::IO, plotattributes::AKW, prefix = "", alwaysshow = false)
    _debugMode.on || alwaysshow || return
    println(io)
    if prefix != ""
        println(io, prefix, ":")
    end
    for k in sort(collect(keys(plotattributes)))
        @printf("%14s: ", k)
        debugshow(io, plotattributes[k])
        println(io)
    end
    println(io)
end
DD(io::IO, plotattributes::AKW, prefix = "") = dumpdict(io, plotattributes, prefix, true)
DD(plotattributes::AKW, prefix = "") = DD(stdout, plotattributes, prefix)

function dumpcallstack()
    error()  # well... you wanted the stacktrace, didn't you?!?
end

# -------------------------------------------------------
# NOTE: backends should implement the following methods to get/set the x/y/z data objects

tovec(v::AbstractVector) = v
tovec(v::Nothing) = zeros(0)

function getxy(plt::Plot, i::Integer)
    plotattributes = plt.series_list[i].plotattributes
    tovec(plotattributes[:x]), tovec(plotattributes[:y])
end
function getxyz(plt::Plot, i::Integer)
    plotattributes = plt.series_list[i].plotattributes
    tovec(plotattributes[:x]), tovec(plotattributes[:y]), tovec(plotattributes[:z])
end

function setxy!(plt::Plot, xy::Tuple{X,Y}, i::Integer) where {X,Y}
    series = plt.series_list[i]
    series.plotattributes[:x], series.plotattributes[:y] = xy
    sp = series.plotattributes[:subplot]
    reset_extrema!(sp)
    _series_updated(plt, series)
end
function setxyz!(plt::Plot, xyz::Tuple{X,Y,Z}, i::Integer) where {X,Y,Z}
    series = plt.series_list[i]
    series.plotattributes[:x], series.plotattributes[:y], series.plotattributes[:z] = xyz
    sp = series.plotattributes[:subplot]
    reset_extrema!(sp)
    _series_updated(plt, series)
end

function setxyz!(plt::Plot, xyz::Tuple{X,Y,Z}, i::Integer) where {X,Y,Z<:AbstractMatrix}
    setxyz!(plt, (xyz[1], xyz[2], Surface(xyz[3])), i)
end


# -------------------------------------------------------
# indexing notation

# Base.getindex(plt::Plot, i::Integer) = getxy(plt, i)
Base.setindex!(plt::Plot, xy::Tuple{X,Y}, i::Integer) where {X,Y} = (setxy!(plt, xy, i); plt)
Base.setindex!(plt::Plot, xyz::Tuple{X,Y,Z}, i::Integer) where {X,Y,Z} = (setxyz!(plt, xyz, i); plt)

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

function extend_series!(series::Series, xi, yi)
    x = extend_series_data!(series, xi, :x)
    y = extend_series_data!(series, yi, :y)
    return x, y
end

function extend_series!(series::Series, xi, yi, zi)
    x = extend_series_data!(series, xi, :x)
    y = extend_series_data!(series, yi, :y)
    z = extend_series_data!(series, zi, :z)
    return x, y, z
end

function extend_series_data!(series::Series, v, letter)
    copy_series!(series, letter)
    d = extend_by_data!(series[letter], v)
    expand_extrema!(series[:subplot][Symbol(letter, :axis)], d)
    return d
end

function copy_series!(series, letter)
    plt = series[:plot_object]
    for s in plt.series_list
        for l in (:x, :y, :z)
            if s !== series || l !== letter
                if s[l] === series[letter]
                    series[letter] = copy(series[letter])
                end
            end
        end
    end
end

extend_to_length!(v::AbstractRange, n) = range(first(v), step = step(v), length = n)
function extend_to_length!(v::AbstractVector, n)
    vmax = isempty(v) ? 0 : ignorenan_maximum(v)
    extend_by_data!(v, vmax .+ (1:(n - length(v))))
end
extend_by_data!(v::AbstractVector, x) = isimmutable(v) ? vcat(v, x) : push!(v, x)
function extend_by_data!(v::AbstractVector, x::AbstractVector)
    isimmutable(v) ? vcat(v, x) : append!(v, x)
end

# -------------------------------------------------------

function attr!(series::Series; kw...)
    plotattributes = KW(kw)
    RecipesPipeline.preprocess_attributes!(plotattributes)
    for (k,v) in plotattributes
        if haskey(_series_defaults, k)
            series[k] = v
        else
            @warn("unused key $k in series attr")
        end
    end
    _series_updated(series[:subplot].plt, series)
    series
end

function attr!(sp::Subplot; kw...)
    plotattributes = KW(kw)
    RecipesPipeline.preprocess_attributes!(plotattributes)
    for (k,v) in plotattributes
        if haskey(_subplot_defaults, k)
            sp[k] = v
        else
            @warn("unused key $k in subplot attr")
        end
    end
    sp
end

# -------------------------------------------------------
# push/append for one series

Base.push!(plt::Plot, args::Real...) = push!(plt, 1, args...)
Base.push!(plt::Plot, i::Integer, args::Real...) = push!(plt.series_list[i], args...)
Base.append!(plt::Plot, args::AbstractVector...) = append!(plt, 1, args...)
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
    for i in 1:plt.n
        push!(plt, i, y[mod1(i,ny)])
    end
    plt
end

# push y[i] to the ith series
# same x for each series
function Base.push!(plt::Plot, x::Real, y::AVec)
    push!(plt, [x], y)
end

# push (x[i], y[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec)
    nx = length(x)
    ny = length(y)
    for i in 1:plt.n
        push!(plt, i, x[mod1(i,nx)], y[mod1(i,ny)])
    end
    plt
end

# push (x[i], y[i], z[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec, z::AVec)
    nx = length(x)
    ny = length(y)
    nz = length(z)
    for i in 1:plt.n
        push!(plt, i, x[mod1(i,nx)], y[mod1(i,ny)], z[mod1(i,nz)])
    end
    plt
end




# ---------------------------------------------------------------


# Some conversion functions
# note: I borrowed these conversion constants from Compose.jl's Measure

const PX_PER_INCH   = 100
const DPI           = PX_PER_INCH
const MM_PER_INCH   = 25.4
const MM_PER_PX     = MM_PER_INCH / PX_PER_INCH

inch2px(inches::Real)   = float(inches * PX_PER_INCH)
px2inch(px::Real)       = float(px / PX_PER_INCH)
inch2mm(inches::Real)   = float(inches * MM_PER_INCH)
mm2inch(mm::Real)       = float(mm / MM_PER_INCH)
px2mm(px::Real)         = float(px * MM_PER_PX)
mm2px(mm::Real)         = float(px / MM_PER_PX)


"Smallest x in plot"
xmin(plt::Plot) = ignorenan_minimum([ignorenan_minimum(series.plotattributes[:x]) for series in plt.series_list])
"Largest x in plot"
xmax(plt::Plot) = ignorenan_maximum([ignorenan_maximum(series.plotattributes[:x]) for series in plt.series_list])

"Extrema of x-values in plot"
ignorenan_extrema(plt::Plot) = (xmin(plt), xmax(plt))


# ---------------------------------------------------------------
# get fonts from objects:

titlefont(sp::Subplot) = font(
    sp[:titlefontfamily],
    sp[:titlefontsize],
    sp[:titlefontvalign],
    sp[:titlefonthalign],
    sp[:titlefontrotation],
    sp[:titlefontcolor],
)

legendfont(sp::Subplot) = font(
    sp[:legendfontfamily],
    sp[:legendfontsize],
    sp[:legendfontvalign],
    sp[:legendfonthalign],
    sp[:legendfontrotation],
    sp[:legendfontcolor],
)

legendtitlefont(sp::Subplot) = font(
    sp[:legendtitlefontfamily],
    sp[:legendtitlefontsize],
    sp[:legendtitlefontvalign],
    sp[:legendtitlefonthalign],
    sp[:legendtitlefontrotation],
    sp[:legendtitlefontcolor],
)

tickfont(ax::Axis) = font(
    ax[:tickfontfamily],
    ax[:tickfontsize],
    ax[:tickfontvalign],
    ax[:tickfonthalign],
    ax[:tickfontrotation],
    ax[:tickfontcolor],
)

guidefont(ax::Axis) = font(
    ax[:guidefontfamily],
    ax[:guidefontsize],
    ax[:guidefontvalign],
    ax[:guidefonthalign],
    ax[:guidefontrotation],
    ax[:guidefontcolor],
)

# ---------------------------------------------------------------
# converts unicode scientific notation unsupported by pgfplots and gr
# into a format that works

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

function straightline_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = isvertical(series) ? (xlims(sp), ylims(sp)) : (ylims(sp), xlims(sp))
    x, y = series[:x], series[:y]
    n = length(x)
    if n == 2
        return straightline_data(xl, yl, x, y, expansion_factor)
    else
        k, r = divrem(n, 3)
        if r == 0
            xdata, ydata = fill(NaN, n), fill(NaN, n)
            for i in 1:k
                inds = (3 * i - 2):(3 * i - 1)
                xdata[inds], ydata[inds] = straightline_data(xl, yl, x[inds], y[inds], expansion_factor)
            end
            return xdata, ydata
        else
            error("Misformed data. `straightline_data` either accepts vectors of length 2 or 3k. The provided series has length $n")
        end
    end
end

function straightline_data(xl, yl, x, y, expansion_factor = 1)
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
        xdata = [clamp(x[1] + (x[1] - x[2]) * (ylim - y[1]) / (y[1] - y[2]), xl...) for ylim in yl]

        xdata, a .* xdata .+ b
    end
    # expand the data outside the axis limits, by a certain factor too improve
    # plotly(js) and interactive behaviour
    x_vals = x_vals .+ (x_vals[2] - x_vals[1]) .* expansion_factor .* [-1, 1]
    y_vals = y_vals .+ (y_vals[2] - y_vals[1]) .* expansion_factor .* [-1, 1]
    return x_vals, y_vals
end

function shape_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = isvertical(series) ? (xlims(sp), ylims(sp)) : (ylims(sp), xlims(sp))
    x, y = copy(series[:x]), copy(series[:y])
    factor = 100
    for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xl[1] - expansion_factor * (xl[2] - xl[1])
        elseif x[i] == Inf
            x[i] = xl[2] + expansion_factor * (xl[2] - xl[1])
        end
    end
    for i in eachindex(y)
        if y[i] == -Inf
            y[i] = yl[1] - expansion_factor * (yl[2] - yl[1])
        elseif y[i] == Inf
            y[i] = yl[2] + expansion_factor * (yl[2] - yl[1])
        end
    end
    return x, y
end

function construct_categorical_data(x::AbstractArray, axis::Axis)
    map(xi -> axis[:discrete_values][searchsortedfirst(axis[:continuous_values], xi)], x)
end

_fmt_paragraph(paragraph::AbstractString;kwargs...) = _fmt_paragraph(IOBuffer(),paragraph,0;kwargs...)

function _fmt_paragraph(io::IOBuffer,
                        remaining_text::AbstractString,
                        column_count::Integer;
                        fillwidth=60,
                        leadingspaces=0)

    kwargs = (fillwidth = fillwidth, leadingspaces = leadingspaces)

    m = match(r"(.*?) (.*)",remaining_text)
    if isa(m,Nothing)
        if column_count + length(remaining_text) ≤ fillwidth
            print(io,remaining_text)
            String(take!(io))
        else
            print(io,"\n"*" "^leadingspaces*remaining_text)
            String(take!(io))
        end
    else
        if column_count + length(m[1]) ≤ fillwidth
            print(io,"$(m[1]) ")
            _fmt_paragraph(io,m[2],column_count + length(m[1]) + 1;kwargs...)
        else
            print(io,"\n"*" "^leadingspaces*"$(m[1]) ")
            _fmt_paragraph(io,m[2],leadingspaces;kwargs...)
        end
    end
end

function _document_argument(S::AbstractString)
    _fmt_paragraph("`$S`: "*_arg_desc[Symbol(S)],leadingspaces = 6 + length(S))
end
