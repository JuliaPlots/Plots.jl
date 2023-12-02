module PlotsSeries

export Series, should_add_to_legend, get_colorgradient, iscontour, isfilledcontour, contour_levels, series_segments
export get_linestyle, get_linewidth, get_markerstrokealpha, get_markerstrokealpha, get_markerstrokewidth, get_linecolor, get_linealpha, get_fillstyle, get_fillcolor, get_fillalpha, get_markercolor, get_markeralpha
import Plots.Commons
using Plots.Commons: _cycle, AVec
using Plots.PlotUtils: ColorGradient, plot_color
using Plots: Plots, DefaultsDict, RecipesPipeline

mutable struct Series
    plotattributes::DefaultsDict
end

Base.getindex(series::Series, k::Symbol) = series.plotattributes[k]
Base.setindex!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)
Base.get(series::Series, k::Symbol, v) = get(series.plotattributes, k, v)
Base.push!(series::Series, args...) = extend_series!(series, args...)
Base.append!(series::Series, args...) = extend_series!(series, args...)

# TODO: consider removing
attr(series::Series, k::Symbol) = series.plotattributes[k]
attr!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)
function attr!(series::Series; kw...)
    plotattributes = KW(kw)
    Plots.Commons.preprocess_attributes!(plotattributes)
    for (k, v) in plotattributes
        if haskey(_series_defaults, k)
            series[k] = v
        else
            @warn "unused key $k in series attr"
        end
    end
    _series_updated(series[:subplot].plt, series)
    series
end

should_add_to_legend(series::Series) =
    series.plotattributes[:primary] &&
    series.plotattributes[:label] != "" &&
    series.plotattributes[:seriestype] ∉ (
        :hexbin,
        :bins2d,
        :histogram2d,
        :hline,
        :vline,
        :contour,
        :contourf,
        :contour3d,
        :surface,
        :wireframe,
        :heatmap,
        :image,
    )

Plots.get_subplot(series::Series) = series.plotattributes[:subplot]
Plots.RecipesPipeline.is3d(series::Series) = RecipesPipeline.is3d(series.plotattributes)
Plots.ispolar(series::Series) = ispolar(series.plotattributes[:subplot])
# -------------------------------------------------------
# operate on individual series

function extend_series!(series::Series, yi)
    y = extend_series_data!(series, yi, :y)
    x = extend_to_length!(series[:x], length(y))
    expand_extrema!(series[:subplot][:xaxis], x)
    x, y
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
    d
end

function copy_series!(series, letter)
    plt = series[:plot_object]
    for s in plt.series_list, l in (:x, :y, :z)
        if (s !== series || l !== letter) && s[l] === series[letter]
            series[letter] = copy(series[letter])
        end
    end
end

extend_to_length!(v::AbstractRange, n) = range(first(v), step = step(v), length = n)
function extend_to_length!(v::AbstractVector, n)
    vmax = isempty(v) ? 0 : ignorenan_maximum(v)
    extend_by_data!(v, vmax .+ (1:(n - length(v))))
end
extend_by_data!(v::AbstractVector, x) = isimmutable(v) ? vcat(v, x) : push!(v, x)
extend_by_data!(v::AbstractVector, x::AbstractVector) =
    isimmutable(v) ? vcat(v, x) : append!(v, x)

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

get_linewidth(series, i::Integer = 1) = _cycle(series[:linewidth], i)
get_linestyle(series, i::Integer = 1) = _cycle(series[:linestyle], i)
get_fillstyle(series, i::Integer = 1) = _cycle(series[:fillstyle], i)

get_markerstrokecolor(series, i::Integer = 1) =
    let msc = series[:markerstrokecolor]
        msc isa ColorGradient ? msc : _cycle(msc, i)
    end

get_markerstrokealpha(series, i::Integer = 1) = _cycle(series[:markerstrokealpha], i)
get_markerstrokewidth(series, i::Integer = 1) = _cycle(series[:markerstrokewidth], i)

function get_colorgradient(series::Series)
    if (st = series[:seriestype]) in (:surface, :heatmap) || isfilledcontour(series)
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
    levels
end
# -------------------------------------------------------
Commons.get_size(series::Series) = Commons.get_size(series.plotattributes[:subplot])
Commons.get_thickness_scaling(series::Series) =
    Commons.get_thickness_scaling(series.plotattributes[:subplot])


# -------------------------------------------------------
struct SeriesSegment
    # indexes of this segment in series data vectors
    range::UnitRange
    # index into vector-valued attributes corresponding to this segment
    attr_index::Int
end

# helper to manage NaN-separated segments
struct NaNSegmentsIterator
    args::Tuple
    n1::Int
    n2::Int
end

function Base.iterate(itr::NaNSegmentsIterator, nextidx::Int = itr.n1)
    (i = findfirst(!Plots.Commons.anynan(itr.args), nextidx:(itr.n2))) === nothing && return
    nextval = nextidx + i - 1

    j = findfirst(Plots.Commons.anynan(itr.args), nextval:(itr.n2))
    nextnan = j === nothing ? itr.n2 + 1 : nextval + j - 1

    nextval:(nextnan - 1), nextnan
end

Base.IteratorSize(::NaNSegmentsIterator) = Base.SizeUnknown()  # COV_EXCL_LINE

function iter_segments(args...)
    tup = Plots.wraptuple(args)
    n1 = minimum(map(firstindex, tup))
    n2 = maximum(map(lastindex, tup))
    NaNSegmentsIterator(tup, n1, n2)
end

# we want to check if a series needs to be split into segments just because
# of its attributes
# check relevant attributes if they have multiple inputs
has_attribute_segments(series::Series) =
    any(
        series[attr] isa AbstractVector && length(series[attr]) > 1 for
        attr in Plots.Commons._segmenting_vector_attributes
    ) || any(series[attr] isa AbstractArray for attr in Plots.Commons._segmenting_array_attributes)

function series_segments(series::Series, seriestype::Symbol = :path; check = false)
    x, y, z = series[:x], series[:y], series[:z]
    (x === nothing || isempty(x)) && return UnitRange{Int}[]

    args = RecipesPipeline.is3d(series) ? (x, y, z) : (x, y)
    nan_segments = collect(iter_segments(args...))

    if check
        scales = :xscale, :yscale, :zscale
        for (n, s) in enumerate(args)
            (scale = get(series, scales[n], :identity)) ∈ Plots.Commons._logScales || continue
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
    for attr in Plots.Commons._segmenting_vector_attributes
        if (v = get(series, attr, nothing)) isa Plots.Commons.AVec && eachindex(v) != seg_range
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
    for attr in Plots.Commons._segmenting_vector_attributes
        v = get(series, attr, nothing)
        if v isa Plots.Commons.AVec && length(unique(v[r])) > 1
            @warn "Different values of `$attr` specified for different shape vertices. Only first one will be used."
            break
        end
    end
end
end # PlotsSeries
