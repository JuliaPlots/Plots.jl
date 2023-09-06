
module Axes

export Axis, tickfont, guidefont
using Plots: Plots, Subplot, DefaultsDict, _axis_defaults_byletter, _all_axis_args
using Plots.Commons
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

    attr = DefaultsDict(explicit, _axis_defaults_byletter[letter])

    # update the defaults
    attr!(Axis([sp], attr), args...; kw...)
end


# properly retrieve from axis.attr, passing `:match` to the correct key
Base.getindex(axis::Axis, k::Symbol) =
    if (v = axis.plotattributes[k]) === :match
        if haskey(_match_map2, k)
            axis.sps[1][_match_map2[k]]
        else
            axis[_match_map[k]]
        end
    else
        v
    end
Base.setindex!(axis::Axis, v, k::Symbol)     = (axis.plotattributes[k] = v)
Base.get(axis::Axis, k::Symbol, v)     = get(axis.plotattributes, k, v)

mutable struct Extrema
    emin::Float64
    emax::Float64
end

Extrema() = Extrema(Inf, -Inf)
# -------------------------------------------------------------------------
function get_axis(sp::Subplot, letter::Symbol)
    axissym = get_attr_symbol(letter, :axis)
    if haskey(sp.attr, axissym)
        sp.attr[axissym]
    else
        sp.attr[axissym] = Axis(sp, letter)
    end::Axis
end

function process_axis_arg!(plotattributes::AKW, arg, letter = "")
    T = typeof(arg)
    arg = get(_scaleAliases, arg, arg)
    if typeof(arg) <: Font
        plotattributes[get_attr_symbol(letter, :tickfont)] = arg
        plotattributes[get_attr_symbol(letter, :guidefont)] = arg

    elseif arg in _allScales
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

    elseif arg === nothing
        plotattributes[get_attr_symbol(letter, :ticks)] = []

    elseif T <: Bool || arg in _allShowaxisArgs
        plotattributes[get_attr_symbol(letter, :showaxis)] = showaxis(arg, letter)

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

# update an Axis object with magic args and keywords
function attr!(axis::Axis, args...; kw...)
    # first process args
    plotattributes = axis.plotattributes
    foreach(arg -> process_axis_arg!(plotattributes, arg), args)

    # then preprocess keyword arguments
    Plots.preprocess_attributes!(KW(kw))

    # then override for any keywords... only those keywords that already exists in plotattributes
    for (k, v) in kw
        haskey(plotattributes, k) || continue
        if k === :discrete_values
            foreach(x -> discrete_value!(axis, x), v)  # add these discrete values to the axis
        elseif k === :lims && isa(v, NTuple{2,TimeType})
            plotattributes[k] = (v[1].instant.periods.value, v[2].instant.periods.value)
        else
            plotattributes[k] = v
        end
    end

    # replace scale aliases
    if haskey(_scaleAliases, plotattributes[:scale])
        plotattributes[:scale] = _scaleAliases[plotattributes[:scale]]
    end

    axis
end

# -------------------------------------------------------------------------

Base.show(io::IO, axis::Axis) = dumpdict(io, axis.plotattributes, "Axis")
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
    for k in _all_axis_args
        # first get the args without the letter: `tickfont = font(10)`
        # note: we don't pop because we want this to apply to all axes! (delete after all have finished)
        if haskey(plotattributes_in, k)
            kw[k] = slice_arg(plotattributes_in[k], subplot_index)
        end

        # then get those args that were passed with a leading letter: `xlabel = "X"`
        lk = get_attr_symbol(letter, k)

        if haskey(plotattributes_in, lk)
            kw[k] = slice_arg(plotattributes_in[lk], subplot_index)
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


# returns (continuous_values, discrete_values) for the ticks on this axis
function get_ticks(sp::Subplot, axis::Axis; update = true, formatter = axis[:formatter])
    if update || !haskey(axis.plotattributes, :optimized_ticks)
        dvals = axis[:discrete_values]
        ticks = _transform_ticks(axis[:ticks], axis)
        axis.plotattributes[:optimized_ticks] =
            if (
                axis[:letter] === :x &&
                ticks isa Symbol &&
                ticks !== :none &&
                !isempty(dvals) &&
                ispolar(sp)
            )
                collect(0:(π / 4):(7π / 4)), string.(0:45:315)
            else
                cvals = axis[:continuous_values]
                alims = axis_limits(sp, axis[:letter])
                get_ticks(ticks, cvals, dvals, alims, axis[:scale], formatter)
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

function Plots.expand_extrema!(ex::Extrema, v::Number)
    ex.emin = isfinite(v) ? min(v, ex.emin) : ex.emin
    ex.emax = isfinite(v) ? max(v, ex.emax) : ex.emax
    ex
end

Plots.expand_extrema!(axis::Axis, v::Number) = expand_extrema!(axis[:extrema], v)

# these shouldn't impact the extrema
Plots.expand_extrema!(axis::Axis, ::Nothing) = axis[:extrema]
Plots.expand_extrema!(axis::Axis, ::Bool) = axis[:extrema]

function Plots.expand_extrema!(axis::Axis, v::Tuple{MIN,MAX}) where {MIN<:Number,MAX<:Number}
    ex = axis[:extrema]::Extrema
    ex.emin = isfinite(v[1]) ? min(v[1], ex.emin) : ex.emin
    ex.emax = isfinite(v[2]) ? max(v[2], ex.emax) : ex.emax
    ex
end
function Plots.expand_extrema!(axis::Axis, v::AVec{N}) where {N<:Number}
    ex = axis[:extrema]::Extrema
    foreach(vi -> expand_extrema!(ex, vi), v)
    ex
end


# -------------------------------------------------------------------------


end # Axes
