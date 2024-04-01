module Axes

export Axis, Extrema, tickfont, guidefont, widen_factor, scale_inverse_scale_func
export sort_3d_axes, axes_letters, process_axis_arg!, has_ticks, get_axis

import ..PlotsBase
import ..PlotsBase: Subplot, DefaultsDict, TimeType, attr!

using ..RecipesPipeline
using ..Commons
using ..Ticks
using ..Fonts

const default_widen_factor = Ref(1.06)
const _widen_seriestypes = (
    :line,
    :path,
    :steppre,
    :stepmid,
    :steppost,
    :sticks,
    :scatter,
    :barbins,
    :barhist,
    :histogram,
    :scatterbins,
    :scatterhist,
    :stepbins,
    :stephist,
    :bins2d,
    :histogram2d,
    :bar,
    :shape,
    :path3d,
    :scatter3d,
)

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
mutable struct Axis
    sps::Vector{Subplot}
    plotattributes::DefaultsDict
end
function Axis(sp::Subplot, letter::Symbol, args...; kw...)
    explicit = KW(
        :letter => letter,
        :extrema => Extrema(),
        :discrete_map => Dict(),   # map discrete values to discrete indices
        :continuous_values => zeros(0),
        :discrete_values => [],
        :use_minor => false,
        :show => true,  # show or hide the axis? (useful for linked subplots)
    )

    attr = DefaultsDict(explicit, Commons._axis_defaults_byletter[letter])

    # update the defaults
    attr!(Axis([sp], attr), args...; kw...)
end

# properly retrieve from axis.attr, passing `:match` to the correct key
Base.getindex(axis::Axis, k::Symbol) =
    if (v = axis.plotattributes[k]) ≡ :match
        if haskey(Commons._match_map2, k)
            axis.sps[1][Commons._match_map2[k]]
        else
            axis[Commons._match_map[k]]
        end
    else
        v
    end
Base.setindex!(axis::Axis, v, k::Symbol) = (axis.plotattributes[k] = v)
Base.get(axis::Axis, k::Symbol, v) = get(axis.plotattributes, k, v)

mutable struct Extrema
    emin::Float64
    emax::Float64
end

Extrema() = Extrema(Inf, -Inf)
# -------------------------------------------------------------------------
sort_3d_axes(x, y, z, letter) =
    if letter ≡ :x
        x, y, z
    elseif letter ≡ :y
        y, x, z
    else
        z, y, x
    end

axes_letters(sp, letter) =
    if RecipesPipeline.is3d(sp)
        sort_3d_axes(:x, :y, :z, letter)
    else
        letter ≡ :x ? (:x, :y) : (:y, :x)
    end

scale_inverse_scale_func(scale::Symbol) = (
    RecipesPipeline.scale_func(scale),
    RecipesPipeline.inverse_scale_func(scale),
    scale ≡ :identity,
)
function get_axis(sp::Subplot, letter::Symbol)
    axissym = get_attr_symbol(letter, :axis)
    if haskey(sp.attr, axissym)
        sp.attr[axissym]
    else
        sp.attr[axissym] = Axis(sp, letter)
    end::Axis
end

function Commons.axis_limits(
    sp,
    letter,
    lims_factor = widen_factor(get_axis(sp, letter)),
    consider_aspect = true,
)
    axis = get_axis(sp, letter)
    ex = axis[:extrema]
    amin, amax = ex.emin, ex.emax
    lims = process_limits(axis[:lims], axis)
    lims ≡ nothing && warn_invalid_limits(axis[:lims], letter)

    if (has_user_lims = lims isa Tuple)
        lmin, lmax = lims
        if lmin isa Number && isfinite(lmin)
            amin = lmin
        elseif lmin isa Symbol
            lmin ≡ :auto || @warn "Invalid min $(letter)limit" lmin
        end
        if lmax isa Number && isfinite(lmax)
            amax = lmax
        elseif lmax isa Symbol
            lmax ≡ :auto || @warn "Invalid max $(letter)limit" lmax
        end
    end
    if lims ≡ :symmetric
        amax = max(abs(amin), abs(amax))
        amin = -amax
    end
    if amax ≤ amin && isfinite(amin)
        amax = amin + 1.0
    end
    if !isfinite(amin) && !isfinite(amax)
        amin, amax = zero(amin), one(amax)
    end
    if ispolar(axis.sps[1])
        if axis[:letter] ≡ :x
            amin, amax = 0, 2π
        elseif lims ≡ :auto
            # widen max radius so ticks dont overlap with theta axis
            amin, amax = 0, amax + 0.1abs(amax - amin)
        end
    elseif lims_factor ≢ nothing
        amin, amax = scale_lims(amin, amax, lims_factor, axis[:scale])
    elseif lims ≡ :round
        amin, amax = round_limits(amin, amax, axis[:scale])
    end

    aspect_ratio = get_aspect_ratio(sp)
    if (
        !has_user_lims &&
        consider_aspect &&
        letter in (:x, :y) &&
        !(aspect_ratio ≡ :none || RecipesPipeline.is3d(:sp))
    )
        aspect_ratio = aspect_ratio isa Number ? aspect_ratio : 1
        area = PlotsBase.plotarea(sp)
        plot_ratio = PlotsBase.height(area) / PlotsBase.width(area)
        dist = amax - amin

        factor = if letter ≡ :x
            ydist, = axis_limits(sp, :y, widen_factor(sp[:yaxis]), false) |> collect |> diff
            axis_ratio = aspect_ratio * ydist / dist
            axis_ratio / plot_ratio
        else
            xdist, = axis_limits(sp, :x, widen_factor(sp[:xaxis]), false) |> collect |> diff
            axis_ratio = aspect_ratio * dist / xdist
            plot_ratio / axis_ratio
        end

        if factor > 1
            center = (amin + amax) / 2
            amin = center + factor * (amin - center)
            amax = center + factor * (amax - center)
        end
    end

    amin, amax
end

"""
factor to widen axis limits by, or `nothing` if axis widening should be skipped
"""
function widen_factor(axis::Axis; factor = default_widen_factor[])
    if (widen = axis[:widen]) isa Bool
        return widen ? factor : nothing
    elseif widen isa Number
        return widen
    else
        widen ≡ :auto || @warn "Invalid value specified for `widen`: $widen"
    end

    # automatic behavior: widen if limits aren't specified and series type is appropriate
    lims = process_limits(axis[:lims], axis)
    (lims isa Tuple || lims ≡ :round) && return
    for sp in axis.sps, series in series_list(sp)
        series.plotattributes[:seriestype] in _widen_seriestypes && return factor
    end
    nothing
end

function round_limits(amin, amax, scale)
    base = get(_log_scale_bases, scale, 10.0)
    factor = base^(1 - round(log(base, amax - amin)))
    amin = floor(amin * factor) / factor
    amax = ceil(amax * factor) / factor
    amin, amax
end

# NOTE: cannot use `NTuple` here ↓
process_limits(lims::Tuple{<:Union{Symbol,Real},<:Union{Symbol,Real}}, axis) = lims
process_limits(lims::Symbol, axis) = lims
process_limits(lims::AVec, axis) =
    length(lims) == 2 && all(map(x -> x isa Union{Symbol,Real}, lims)) ? Tuple(lims) :
    nothing
process_limits(lims, axis) = nothing

warn_invalid_limits(lims, letter) = @warn """
        Invalid limits for $letter axis. Limits should be a symbol, or a two-element tuple or vector of numbers.
        $(letter)lims = $lims
        """
function scale_lims(from, to, factor)
    mid, span = (from + to) / 2, (to - from) / 2
    mid .+ (-span, span) .* factor
end

_scale_lims(::Val{true}, ::Function, ::Function, from, to, factor) =
    scale_lims(from, to, factor)
_scale_lims(::Val{false}, f::Function, invf::Function, from, to, factor) =
    invf.(scale_lims(f(from), f(to), factor))

function scale_lims(from, to, factor, scale)
    f, invf, noop = scale_inverse_scale_func(scale)
    _scale_lims(Val(noop), f, invf, from, to, factor)
end

"""
    scale_lims!([plt], [letter], factor)

Scale the limits of the axis specified by `letter` (one of `:x`, `:y`, `:z`) by the
given `factor` around the limits' middle point.
If `letter` is omitted, all axes are affected.
"""
function Commons.scale_lims!(sp::Subplot, letter, factor)
    axis = get_axis(sp, letter)
    from, to = PlotsBase.get_sp_lims(sp, letter)
    axis[:lims] = scale_lims(from, to, factor, axis[:scale])
end
Commons.scale_lims!(factor::Number) = scale_lims!(PlotsBase.current(), factor)
Commons.scale_lims!(letter::Symbol, factor) =
    scale_lims!(PlotsBase.current(), letter, factor)

#----------------------------------------------------------------------
function process_axis_arg!(plotattributes::AKW, arg, letter = "")
    T = typeof(arg)
    arg = get(_scale_aliases, arg, arg)
    if typeof(arg) <: Font
        plotattributes[get_attr_symbol(letter, :tickfont)] = arg
        plotattributes[get_attr_symbol(letter, :guidefont)] = arg

    elseif arg in _all_scales
        plotattributes[get_attr_symbol(letter, :scale)] = arg

    elseif arg in (:flip, :invert, :inverted)
        plotattributes[get_attr_symbol(letter, :flip)] = true

    elseif T <: AbstractString
        plotattributes[get_attr_symbol(letter, :guide)] = arg

        # xlims/ylims
    elseif (T <: Tuple || T <: AVec) && length(arg) == 2
        sym = typeof(arg[1]) <: Number ? :lims : :ticks
        plotattributes[get_attr_symbol(letter, sym)] = arg

        # xticks/yticks
    elseif T <: AVec
        plotattributes[get_attr_symbol(letter, :ticks)] = arg

    elseif arg ≡ nothing
        plotattributes[get_attr_symbol(letter, :ticks)] = []

    elseif T <: Bool || arg in Commons._all_showaxis_attrs
        plotattributes[get_attr_symbol(letter, :showaxis)] = Commons.showaxis(arg, letter)

    elseif typeof(arg) <: Number
        plotattributes[get_attr_symbol(letter, :rotation)] = arg

    elseif typeof(arg) <: Function
        plotattributes[get_attr_symbol(letter, :formatter)] = arg

    elseif !handleColors!(
        plotattributes,
        arg,
        get_attr_symbol(letter, :foreground_color_axis),
    )
        @warn "Skipped $(letter)axis arg $arg"
    end
end

has_ticks(axis::Axis) = _has_ticks(get(axis, :ticks, nothing))

# update an Axis object with magic args and keywords
function PlotsBase.attr!(axis::Axis, args...; kw...)
    # first process args
    plotattributes = axis.plotattributes
    foreach(arg -> process_axis_arg!(plotattributes, arg), args)

    # then preprocess keyword arguments
    PlotsBase.Commons.preprocess_attributes!(KW(kw))

    # then override for any keywords... only those keywords that already exists in plotattributes
    for (k, v) in kw
        haskey(plotattributes, k) || continue
        if k ≡ :discrete_values
            foreach(x -> discrete_value!(axis, x), v)  # add these discrete values to the axis
        elseif k ≡ :lims && isa(v, NTuple{2,TimeType})
            plotattributes[k] = (v[1].instant.periods.value, v[2].instant.periods.value)
        else
            plotattributes[k] = v
        end
    end

    # replace scale aliases
    if haskey(_scale_aliases, plotattributes[:scale])
        plotattributes[:scale] = _scale_aliases[plotattributes[:scale]]
    end

    axis
end

# -------------------------------------------------------------------------

Base.show(io::IO, axis::Axis) = Commons.dumpdict(io, axis.plotattributes, "Axis")
ignorenan_extrema(axis::Axis) = (ex = axis[:extrema]; (ex.emin, ex.emax))

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

function _update_axis(
    axis::Axis,
    plotattributes_in::AKW,
    letter::Symbol,
    subplot_index::Int,
)
    # build the KW of arguments from the letter version (i.e. xticks --> ticks)
    kw = KW()
    for k in Commons._all_axis_attrs
        # first get the args without the letter: `tickfont = font(10)`
        # note: we don't pop because we want this to apply to all axes! (delete after all have finished)
        if haskey(plotattributes_in, k)
            kw[k] = PlotsBase.slice_arg(plotattributes_in[k], subplot_index)
        end

        # then get those args that were passed with a leading letter: `xlabel = "X"`
        lk = get_attr_symbol(letter, k)

        if haskey(plotattributes_in, lk)
            kw[k] = PlotsBase.slice_arg(plotattributes_in[lk], subplot_index)
        end
    end

    # update the axis
    attr!(axis; kw...)
    nothing
end

function _update_axis_colors(axis::Axis)
    # # update the axis colors
    color_or_nothing!(axis.plotattributes, :foreground_color_axis)
    color_or_nothing!(axis.plotattributes, :foreground_color_border)
    color_or_nothing!(axis.plotattributes, :foreground_color_guide)
    color_or_nothing!(axis.plotattributes, :foreground_color_text)
    color_or_nothing!(axis.plotattributes, :foreground_color_grid)
    color_or_nothing!(axis.plotattributes, :foreground_color_minor_grid)
    nothing
end

"""
returns (continuous_values, discrete_values) for the ticks on this axis
"""
function Commons.get_ticks(
    sp::Subplot,
    axis::Axis;
    update = true,
    formatter = axis[:formatter],
)
    if update || !haskey(axis.plotattributes, :optimized_ticks)
        dvals = axis[:discrete_values]
        ticks = _transform_ticks(axis[:ticks], axis)
        axis.plotattributes[:optimized_ticks] =
            if (
                axis[:letter] ≡ :x &&
                ticks isa Symbol &&
                ticks ≢ :none &&
                !isempty(dvals) &&
                ispolar(sp)
            )
                collect(0:(π / 4):(7π / 4)), string.(0:45:315)
            else
                cvals = axis[:continuous_values]
                alims = axis_limits(sp, axis[:letter])
                Commons.get_ticks(ticks, cvals, dvals, alims, axis[:scale], formatter)
            end
    end
    axis.plotattributes[:optimized_ticks]
end

function reset_extrema!(sp::Subplot)
    for asym in (:x, :y, :z)
        sp[get_attr_symbol(asym, :axis)][:extrema] = Extrema()
    end
    for series in sp.series_list
        expand_extrema!(sp, series.plotattributes)
    end
end

function PlotsBase.expand_extrema!(ex::Extrema, v::Number)
    ex.emin = isfinite(v) ? min(v, ex.emin) : ex.emin
    ex.emax = isfinite(v) ? max(v, ex.emax) : ex.emax
    ex
end

PlotsBase.expand_extrema!(axis::Axis, v::Number) = expand_extrema!(axis[:extrema], v)

# these shouldn't impact the extrema
PlotsBase.expand_extrema!(axis::Axis, ::Nothing) = axis[:extrema]
PlotsBase.expand_extrema!(axis::Axis, ::Bool) = axis[:extrema]

function PlotsBase.expand_extrema!(
    axis::Axis,
    v::Tuple{MIN,MAX},
) where {MIN<:Number,MAX<:Number}
    ex = axis[:extrema]::Extrema
    ex.emin = isfinite(v[1]) ? min(v[1], ex.emin) : ex.emin
    ex.emax = isfinite(v[2]) ? max(v[2], ex.emax) : ex.emax
    ex
end
function PlotsBase.expand_extrema!(axis::Axis, v::AVec{N}) where {N<:Number}
    ex = axis[:extrema]::Extrema
    foreach(vi -> expand_extrema!(ex, vi), v)
    ex
end

end # Axes

# -------------------------------------------------------------------------

using .Axes
