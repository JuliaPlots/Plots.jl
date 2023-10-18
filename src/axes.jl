
# xaxis(args...; kw...) = Axis(:x, args...; kw...)
# yaxis(args...; kw...) = Axis(:y, args...; kw...)
# zaxis(args...; kw...) = Axis(:z, args...; kw...)

# -------------------------------------------------------------------------

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

const _label_func =
    Dict{Symbol,Function}(:log10 => x -> "10^$x", :log2 => x -> "2^$x", :ln => x -> "e^$x")
labelfunc(scale::Symbol, backend::AbstractBackend) = get(_label_func, scale, string)

const _label_func_tex = Dict{Symbol,Function}(
    :log10 => x -> "10^{$x}",
    :log2 => x -> "2^{$x}",
    :ln => x -> "e^{$x}",
)
labelfunc_tex(scale::Symbol) = get(_label_func_tex, scale, convert_sci_unicode)

function optimal_ticks_and_labels(ticks, alims, scale, formatter)
    amin, amax = alims

    # scale the limits
    sf, invsf, noop = scale_inverse_scale_func(scale)

    # If the axis input was a Date or DateTime use a special logic to find
    # "round" Date(Time)s as ticks
    # This bypasses the rest of optimal_ticks_and_labels, because
    # optimize_datetime_ticks returns ticks AND labels: the label format (Date
    # or DateTime) is chosen based on the time span between amin and amax
    # rather than on the input format
    # TODO: maybe: non-trivial scale (:ln, :log2, :log10) for date/datetime

    if ticks === nothing && noop
        if formatter == RecipesPipeline.dateformatter
            # optimize_datetime_ticks returns ticks and labels(!) based on
            # integers/floats corresponding to the DateTime type. Thus, the axes
            # limits, which resulted from converting the Date type to integers,
            # are converted to 'DateTime integers' (actually floats) before
            # being passed to optimize_datetime_ticks.
            # (convert(Int, convert(DateTime, convert(Date, i))) == 87600000*i)
            ticks, labels =
                optimize_datetime_ticks(864e5 * amin, 864e5 * amax; k_min = 2, k_max = 4)
            # Now the ticks are converted back to floats corresponding to Dates.
            return ticks / 864e5, labels
        elseif formatter == RecipesPipeline.datetimeformatter
            return optimize_datetime_ticks(amin, amax; k_min = 2, k_max = 4)
        end
    end

    # get a list of well-laid-out ticks
    scaled_ticks = if ticks === nothing
        optimize_ticks(
            sf(amin),
            sf(amax);
            k_min = scale ∈ _logScales ? 2 : 4, # minimum number of ticks
            k_max = 8, # maximum number of ticks
            scale,
        ) |> first
    elseif typeof(ticks) <: Int
        optimize_ticks(
            sf(amin),
            sf(amax);
            k_min = ticks, # minimum number of ticks
            k_max = ticks, # maximum number of ticks
            k_ideal = ticks,
            # `strict_span = false` rewards cases where the span of the
            # chosen  ticks is not too much bigger than amin - amax:
            strict_span = false,
            scale,
        ) |> first
    else
        map(sf, filter(t -> amin ≤ t ≤ amax, ticks))
    end
    unscaled_ticks = noop ? scaled_ticks : map(invsf, scaled_ticks)

    labels::Vector{String} = if any(isfinite, unscaled_ticks)
        get_labels(formatter, scaled_ticks, scale)
    else
        String[]  # no finite ticks to show...
    end

    unscaled_ticks, labels
end

function get_labels(formatter::Symbol, scaled_ticks, scale)
    if formatter in (:auto, :plain, :scientific, :engineering)
        return map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, formatter))
    elseif formatter === :latex
        return map(
            l -> string("\$", replace(convert_sci_unicode(l), '×' => "\\times"), "\$"),
            get_labels(:auto, scaled_ticks, scale),
        )
    elseif formatter === :none
        return String[]
    end
end
function get_labels(formatter::Function, scaled_ticks, scale)
    sf, invsf, _ = scale_inverse_scale_func(scale)
    fticks = map(formatter ∘ invsf, scaled_ticks)
    # extrema can extend outside the region where Categorical tick values are defined
    #   CategoricalArrays's recipe gives "missing" label to those
    filter!(!ismissing, fticks)
    eltype(fticks) <: Number && return get_labels(:auto, map(sf, fticks), scale)
    return fticks
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

# Ticks getter functions
for l in (:x, :y, :z)
    axis = string(l, "-axis")  # "x-axis"
    ticks = string(l, "ticks") # "xticks"
    f = Symbol(ticks)          # :xticks
    @eval begin
        """
            $($f)(p::Plot)

        returns a vector of the $($axis) ticks of the subplots of `p`.

        Example use:

        ```jldoctest
        julia> p = plot(1:5, $($ticks)=[1,2])

        julia> $($f)(p)
        1-element Vector{Tuple{Vector{Float64}, Vector{String}}}:
         ([1.0, 2.0], ["1", "2"])
        ```

        If `p` consists of a single subplot, you might want to grab
        only the first element, via

        ```jldoctest
        julia> $($f)(p)[1]
        ([1.0, 2.0], ["1", "2"])
        ```

        or you can call $($f) on the first (only) subplot of `p` via

        ```jldoctest
        julia> $($f)(p[1])
        ([1.0, 2.0], ["1", "2"])
        ```
        """
        $f(p::Plot) = get_ticks(p, $(Meta.quot(l)))
        """
            $($f)(sp::Subplot)

        returns the $($axis) ticks of the subplot `sp`.

        Note that the ticks are returned as tuples of values and labels:

        ```jldoctest
        julia> sp = plot(1:5, $($ticks)=[1,2]).subplots[1]
        Subplot{1}

        julia> $($f)(sp)
        ([1.0, 2.0], ["1", "2"])
        ```
        """
        $f(sp::Subplot) = get_ticks(sp, $(Meta.quot(l)))
        export $f
    end
end
# get_ticks from axis symbol :x, :y, or :z
get_ticks(sp::Subplot, s::Symbol) = get_ticks(sp, sp[get_attr_symbol(s, :axis)])
get_ticks(p::Plot, s::Symbol) = map(sp -> get_ticks(sp, s), p.subplots)

get_ticks(ticks::Symbol, cvals::T, dvals, args...) where {T} =
    if ticks === :none
        T[], String[]
    elseif !isempty(dvals)
        n = length(dvals)
        if ticks === :all || n < 16
            cvals, string.(dvals)
        else
            Δ = ceil(Int, n / 10)
            rng = Δ:Δ:n
            cvals[rng], string.(dvals[rng])
        end
    else
        optimal_ticks_and_labels(nothing, args...)
    end

get_ticks(ticks::AVec, cvals, dvals, args...) = optimal_ticks_and_labels(ticks, args...)
get_ticks(ticks::Int, dvals, cvals, args...) =
    if isempty(dvals)
        optimal_ticks_and_labels(ticks, args...)
    else
        rng = round.(Int, range(1, stop = length(dvals), length = ticks))
        cvals[rng], string.(dvals[rng])
    end
get_ticks(ticks::NTuple{2,Any}, args...) = ticks
get_ticks(::Nothing, cvals::T, args...) where {T} = T[], String[]
get_ticks(ticks::Bool, args...) =
    ticks ? get_ticks(:auto, args...) : get_ticks(nothing, args...)
get_ticks(::T, args...) where {T} =
    throw(ArgumentError("Unknown ticks type in get_ticks: $T"))

# do not specify array item type to also catch e.g. "xlabel=[]" and "xlabel=([],[])"
_has_ticks(v::AVec) = !isempty(v)
_has_ticks(t::Tuple{AVec,AVec}) = !isempty(t[1])
_has_ticks(s::Symbol) = s !== :none
_has_ticks(b::Bool) = b
_has_ticks(::Nothing) = false
_has_ticks(::Any) = true

has_ticks(axis::Axis) = get(axis, :ticks, nothing) |> _has_ticks

_transform_ticks(ticks, axis) = ticks
_transform_ticks(ticks::AbstractArray{T}, axis) where {T<:Dates.TimeType} =
    Dates.value.(ticks)
_transform_ticks(ticks::NTuple{2,Any}, axis) = (_transform_ticks(ticks[1], axis), ticks[2])

const DEFAULT_MINOR_INTERVALS = Ref(5)  # 5 intervals -> 4 ticks

function num_minor_intervals(axis)
    # FIXME: `minorticks` should be fixed in `2.0` to be the number of ticks, not intervals
    # see github.com/JuliaPlots/Plots.jl/pull/4528
    n_intervals = axis[:minorticks]
    if !(n_intervals isa Bool) && n_intervals isa Integer && n_intervals ≥ 0
        max(1, n_intervals)  # 0 intervals makes no sense
    else   # `:auto` or `true`
        if (base = get(_logScaleBases, axis[:scale], nothing)) == 10
            Int(base - 1)
        else
            DEFAULT_MINOR_INTERVALS[]
        end
    end::Int
end

no_minor_intervals(axis) =
    if (n_intervals = axis[:minorticks]) === false
        true  # must be tested with `===` since Bool <: Integer
    elseif n_intervals ∈ (:none, nothing)
        true
    elseif (n_intervals === :auto && !axis[:minorgrid])
        true
    else
        false
    end

function get_minor_ticks(sp, axis, ticks_and_labels)
    no_minor_intervals(axis) && return
    ticks = first(ticks_and_labels)
    length(ticks) < 2 && return

    amin, amax = axis_limits(sp, axis[:letter])
    scale = axis[:scale]
    base = get(_logScaleBases, scale, nothing)

    # add one phantom tick either side of the ticks to ensure minor ticks extend to the axis limits
    if (log_scaled = scale ∈ _logScales)
        sub = round(Int, log(base, ticks[2] / ticks[1]))
        ticks = [ticks[1] / base; ticks; ticks[end] * base]
    else
        sub = 1  # unused
        ratio = length(ticks) > 2 ? (ticks[3] - ticks[2]) / (ticks[2] - ticks[1]) : 1
        first_step = ticks[2] - ticks[1]
        last_step = ticks[end] - ticks[end - 1]
        ticks = [ticks[1] - first_step / ratio; ticks; ticks[end] + last_step * ratio]
    end

    n_minor_intervals = num_minor_intervals(axis)
    minorticks = sizehint!(eltype(ticks)[], n_minor_intervals * sub * length(ticks))
    for i in 2:length(ticks)
        lo = ticks[i - 1]
        hi = ticks[i]
        (isfinite(lo) && isfinite(hi) && hi > lo) || continue
        if log_scaled
            for e in 1:sub
                lo_ = lo * base^(e - 1)
                hi_ = lo_ * base
                step = (hi_ - lo_) / n_minor_intervals
                rng = (lo_ + (e > 1 ? 0 : step)):step:(hi_ - (e < sub ? 0 : step / 2))
                append!(minorticks, collect(rng))
            end
        else
            step = (hi - lo) / n_minor_intervals
            append!(minorticks, collect((lo + step):step:(hi - step / 2)))
        end
    end
    minorticks[amin .≤ minorticks .≤ amax]
end

# -------------------------------------------------------------------------

function reset_extrema!(sp::Subplot)
    for asym in (:x, :y, :z)
        sp[get_attr_symbol(asym, :axis)][:extrema] = Extrema()
    end
    for series in sp.series_list
        expand_extrema!(sp, series.plotattributes)
    end
end

function expand_extrema!(ex::Extrema, v::Number)
    ex.emin = isfinite(v) ? min(v, ex.emin) : ex.emin
    ex.emax = isfinite(v) ? max(v, ex.emax) : ex.emax
    ex
end

expand_extrema!(axis::Axis, v::Number) = expand_extrema!(axis[:extrema], v)

# these shouldn't impact the extrema
expand_extrema!(axis::Axis, ::Nothing) = axis[:extrema]
expand_extrema!(axis::Axis, ::Bool) = axis[:extrema]

function expand_extrema!(axis::Axis, v::Tuple{MIN,MAX}) where {MIN<:Number,MAX<:Number}
    ex = axis[:extrema]::Extrema
    ex.emin = isfinite(v[1]) ? min(v[1], ex.emin) : ex.emin
    ex.emax = isfinite(v[2]) ? max(v[2], ex.emax) : ex.emax
    ex
end
function expand_extrema!(axis::Axis, v::AVec{N}) where {N<:Number}
    ex = axis[:extrema]::Extrema
    foreach(vi -> expand_extrema!(ex, vi), v)
    ex
end

function expand_extrema!(sp::Subplot, plotattributes::AKW)
    vert = isvertical(plotattributes)

    # first expand for the data
    for letter in (:x, :y, :z)
        data = plotattributes[if vert
            letter
        else
            letter === :x ? :y : letter === :y ? :x : :z
        end]
        if (
            letter !== :z &&
            plotattributes[:seriestype] === :straightline &&
            any(series[:seriestype] !== :straightline for series in series_list(sp)) &&
            length(data) > 1 &&
            data[1] != data[2]
        )
            data = [NaN]
        end
        axis = sp[get_attr_symbol(letter, :axis)]

        if isa(data, Volume)
            expand_extrema!(sp[:xaxis], data.x_extents)
            expand_extrema!(sp[:yaxis], data.y_extents)
            expand_extrema!(sp[:zaxis], data.z_extents)
        elseif eltype(data) <: Number ||
               (isa(data, Surface) && all(di -> isa(di, Number), data.surf))
            if !(eltype(data) <: Number)
                # huh... must have been a mis-typed surface? lets swap it out
                data = plotattributes[letter] = Surface(Matrix{Float64}(data.surf))
            end
            expand_extrema!(axis, data)
        elseif data !== nothing
            # TODO: need more here... gotta track the discrete reference value
            #       as well as any coord offset (think of boxplot shape coords... they all
            #       correspond to the same x-value)
            plotattributes[letter],
            plotattributes[get_attr_symbol(letter, :(_discrete_indices))] =
                discrete_value!(axis, data)
            expand_extrema!(axis, plotattributes[letter])
        end
    end

    # # expand for fillrange/bar_width
    # fillaxis, baraxis = sp.attr[:yaxis], sp.attr[:xaxis]
    # if isvertical(plotattributes)
    #     fillaxis, baraxis = baraxis, fillaxis
    # end

    # expand for fillrange
    fr = plotattributes[:fillrange]
    if fr === nothing && plotattributes[:seriestype] === :bar
        fr = 0.0
    end
    if fr !== nothing && !RecipesPipeline.is3d(plotattributes)
        axis = sp.attr[vert ? :yaxis : :xaxis]
        if typeof(fr) <: Tuple
            foreach(x -> expand_extrema!(axis, x), fr)
        else
            expand_extrema!(axis, fr)
        end
    end

    # expand for bar_width
    if plotattributes[:seriestype] === :bar
        dsym = vert ? :x : :y
        data = plotattributes[dsym]

        if (bw = plotattributes[:bar_width]) === nothing
            pos = filter(>(0), diff(sort(data)))
            plotattributes[:bar_width] = bw = _bar_width * ignorenan_minimum(pos)
        end
        axis = sp.attr[get_attr_symbol(dsym, :axis)]
        expand_extrema!(axis, ignorenan_maximum(data) + 0.5maximum(bw))
        expand_extrema!(axis, ignorenan_minimum(data) - 0.5minimum(bw))
    end

    # expand for heatmaps
    if plotattributes[:seriestype] === :heatmap
        for letter in (:x, :y)
            data = plotattributes[letter]
            axis = sp[get_attr_symbol(letter, :axis)]
            scale = get(plotattributes, get_attr_symbol(letter, :scale), :identity)
            expand_extrema!(axis, heatmap_edges(data, scale))
        end
    end
end

function expand_extrema!(sp::Subplot, xmin, xmax, ymin, ymax)
    expand_extrema!(sp[:xaxis], (xmin, xmax))
    expand_extrema!(sp[:yaxis], (ymin, ymax))
end

# -------------------------------------------------------------------------

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
function scale_lims!(sp::Subplot, letter, factor)
    axis = Plots.get_axis(sp, letter)
    from, to = Plots.get_sp_lims(sp, letter)
    axis[:lims] = scale_lims(from, to, factor, axis[:scale])
end
function scale_lims!(plt::Plot, letter, factor)
    foreach(sp -> scale_lims!(sp, letter, factor), plt.subplots)
    plt
end
scale_lims!(letter::Symbol, factor) = scale_lims!(current(), letter, factor)
function scale_lims!(plt::Union{Plot,Subplot}, factor)
    foreach(letter -> scale_lims!(plt, letter, factor), (:x, :y, :z))
    plt
end
scale_lims!(factor::Number) = scale_lims!(current(), factor)

# figure out if widening is a good idea.
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

const default_widen_factor = Ref(1.06)

# factor to widen axis limits by, or `nothing` if axis widening should be skipped
function widen_factor(axis::Axis; factor = default_widen_factor[])
    if (widen = axis[:widen]) isa Bool
        return widen ? factor : nothing
    elseif widen isa Number
        return widen
    else
        widen === :auto || @warn "Invalid value specified for `widen`: $widen"
    end

    # automatic behavior: widen if limits aren't specified and series type is appropriate
    lims = process_limits(axis[:lims], axis)
    (lims isa Tuple || lims === :round) && return
    for sp in axis.sps, series in series_list(sp)
        series.plotattributes[:seriestype] in _widen_seriestypes && return factor
    end
    nothing
end

function round_limits(amin, amax, scale)
    base = get(_logScaleBases, scale, 10.0)
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

# using the axis extrema and limit overrides, return the min/max value for this axis
function axis_limits(
    sp,
    letter,
    lims_factor = widen_factor(get_axis(sp, letter)),
    consider_aspect = true,
)
    axis = get_axis(sp, letter)
    ex = axis[:extrema]
    amin, amax = ex.emin, ex.emax
    lims = process_limits(axis[:lims], axis)
    lims === nothing && warn_invalid_limits(axis[:lims], letter)

    if (has_user_lims = lims isa Tuple)
        lmin, lmax = lims
        if lmin isa Number && isfinite(lmin)
            amin = lmin
        elseif lmin isa Symbol
            lmin === :auto || @warn "Invalid min $(letter)limit" lmin
        end
        if lmax isa Number && isfinite(lmax)
            amax = lmax
        elseif lmax isa Symbol
            lmax === :auto || @warn "Invalid max $(letter)limit" lmax
        end
    end
    if lims === :symmetric
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
        if axis[:letter] === :x
            amin, amax = 0, 2π
        elseif lims === :auto
            # widen max radius so ticks dont overlap with theta axis
            amin, amax = 0, amax + 0.1abs(amax - amin)
        end
    elseif lims_factor !== nothing
        amin, amax = scale_lims(amin, amax, lims_factor, axis[:scale])
    elseif lims === :round
        amin, amax = round_limits(amin, amax, axis[:scale])
    end

    aspect_ratio = get_aspect_ratio(sp)
    if (
        !has_user_lims &&
        consider_aspect &&
        letter in (:x, :y) &&
        !(aspect_ratio === :none || RecipesPipeline.is3d(:sp))
    )
        aspect_ratio = aspect_ratio isa Number ? aspect_ratio : 1
        area = plotarea(sp)
        plot_ratio = height(area) / width(area)
        dist = amax - amin

        factor = if letter === :x
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

# -------------------------------------------------------------------------

# these methods track the discrete (categorical) values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return (continuous_value, discrete_index)
discrete_value!(plotattributes, letter::Symbol, dv) =
    let l = if plotattributes[:permute] !== :none
            filter(!=(letter), plotattributes[:permute]) |> only
        else
            letter
        end
        discrete_value!(plotattributes[:subplot][get_attr_symbol(l, :axis)], dv)
    end

discrete_value!(axis::Axis, dv) =
    if (cv_idx = get(axis[:discrete_map], dv, -1)) == -1
        ex = axis[:extrema]
        cv = NaNMath.max(0.5, ex.emax + 1)
        expand_extrema!(axis, cv)
        push!(axis[:discrete_values], dv)
        push!(axis[:continuous_values], cv)
        cv_idx = length(axis[:discrete_values])
        axis[:discrete_map][dv] = cv_idx
        cv, cv_idx
    else
        cv = axis[:continuous_values][cv_idx]
        cv, cv_idx
    end

# continuous value... just pass back with axis negative index
discrete_value!(axis::Axis, cv::Number) = (cv, -1)

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AVec)
    cvec = zeros(axes(v))
    discrete_indices = similar(Array{Int}, axes(v))
    for i in eachindex(v)
        cvec[i], discrete_indices[i] = discrete_value!(axis, v[i])
    end
    cvec, discrete_indices
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AMat)
    cmat = zeros(axes(v))
    discrete_indices = similar(Array{Int}, axes(v))
    for I in eachindex(v)
        cmat[I], discrete_indices[I] = discrete_value!(axis, v[I])
    end
    cmat, discrete_indices
end

discrete_value!(axis::Axis, v::Surface) = map(Surface, discrete_value!(axis, v.surf))

# -------------------------------------------------------------------------

const grid_factor_2d = Ref(1.2)
const grid_factor_3d = Ref(grid_factor_2d[] / 100)

function add_major_or_minor_segments_2d(
    sp,
    ax,
    oax,
    oas,
    oamM,
    ticks,
    grid,
    tick_segments,
    segments,
    factor,
    cond,
)
    ticks === nothing && return
    if cond
        f, invf = scale_inverse_scale_func(oax[:scale])
        tick_start, tick_stop = if sp[:framestyle] === :origin
            oamin, oamax = oamM
            t = invf(f(0) + factor * (f(oamax) - f(oamin)))
            (-t, t)
        else
            ticks_in = ax[:tick_direction] === :out ? -1 : 1
            oa1, oa2 = oas
            t = invf(f(oa1) + factor * (f(oa2) - f(oa1)) * ticks_in)
            (oa1, t)
        end
    end
    isy = ax[:letter] === :y
    for tick in ticks
        (ax[:showaxis] && cond) && push!(
            tick_segments,
            reverse_if((tick, tick_start), isy),
            reverse_if((tick, tick_stop), isy),
        )
        grid && push!(
            segments,
            reverse_if((tick, first(oamM)), isy),
            reverse_if((tick, last(oamM)), isy),
        )
    end
end

# compute the line segments which should be drawn for this axis
function axis_drawing_info(sp, letter)
    # get axis objects, ticks and minor ticks
    letters = axes_letters(sp, letter)
    ax, oax = map(l -> sp[get_attr_symbol(l, :axis)], letters)
    (amin, amax), oamM = map(l -> axis_limits(sp, l), letters)

    ticks = get_ticks(sp, ax, update = false)
    minor_ticks = get_minor_ticks(sp, ax, ticks)

    # initialize the segments
    segments, tick_segments, grid_segments, minorgrid_segments, border_segments =
        map(_ -> Segments(2), 1:5)

    if sp[:framestyle] !== :none
        isy = letter === :y
        oa1, oa2 = oas = if sp[:framestyle] in (:origin, :zerolines)
            0, 0
        else
            xor(ax[:mirror], oax[:flip]) ? reverse(oamM) : oamM
        end
        if ax[:showaxis]
            if sp[:framestyle] !== :grid
                push!(segments, reverse_if((amin, oa1), isy), reverse_if((amax, oa1), isy))
                # don't show the 0 tick label for the origin framestyle
                if (
                    sp[:framestyle] === :origin &&
                    ticks ∉ (:none, nothing, false) &&
                    length(ticks) > 1
                )
                    if (i = findfirst(==(0), ticks[1])) !== nothing
                        deleteat!(ticks[1], i)
                        deleteat!(ticks[2], i)
                    end
                end
            end
            # top spine
            sp[:framestyle] in (:semi, :box) && push!(
                border_segments,
                reverse_if((amin, oa2), isy),
                reverse_if((amax, oa2), isy),
            )
        end
        if ax[:ticks] ∉ (:none, nothing, false)
            ax_length = letter === :x ? height(sp.plotarea).value : width(sp.plotarea).value

            # add major grid segments
            add_major_or_minor_segments_2d(
                sp,
                ax,
                oax,
                oas,
                oamM,
                first(ticks),
                ax[:grid],
                tick_segments,
                grid_segments,
                grid_factor_2d[] / ax_length,
                ax[:tick_direction] !== :none,
            )
            if sp[:framestyle] === :box
                add_major_or_minor_segments_2d(
                    sp,
                    ax,
                    oax,
                    reverse(oas),
                    oamM,
                    first(ticks),
                    ax[:grid],
                    tick_segments,
                    grid_segments,
                    grid_factor_2d[] / ax_length,
                    ax[:tick_direction] !== :none,
                )
            end

            # add minor grid segments
            if ax[:minorticks] ∉ (:none, nothing, false) || ax[:minorgrid]
                add_major_or_minor_segments_2d(
                    sp,
                    ax,
                    oax,
                    oas,
                    oamM,
                    minor_ticks,
                    ax[:minorgrid],
                    tick_segments,
                    minorgrid_segments,
                    grid_factor_2d[] / 2ax_length,
                    true,
                )
                if sp[:framestyle] === :box
                    add_major_or_minor_segments_2d(
                        sp,
                        ax,
                        oax,
                        reverse(oas),
                        oamM,
                        minor_ticks,
                        ax[:minorgrid],
                        tick_segments,
                        minorgrid_segments,
                        grid_factor_2d[] / 2ax_length,
                        true,
                    )
                end
            end
        end
    end

    (
        ticks = ticks,
        segments = segments,
        tick_segments = tick_segments,
        grid_segments = grid_segments,
        minorgrid_segments = minorgrid_segments,
        border_segments = border_segments,
    )
end

function add_major_or_minor_segments_3d(
    sp,
    ax,
    nax,
    nas,
    fas,
    namM,
    ticks,
    grid,
    tick_segments,
    segments,
    factor,
    cond,
)
    ticks === nothing && return
    if cond
        f, invf = scale_inverse_scale_func(nax[:scale])
        tick_start, tick_stop = if sp[:framestyle] === :origin
            namin, namax = namM
            t = invf(f(0) + factor * (f(namax) - f(namin)))
            (-t, t)
        else
            na0, na1 = nas
            ticks_in = ax[:tick_direction] === :out ? -1 : 1
            t = invf(f(na0) + factor * (f(na1) - f(na0)) * ticks_in)
            (na0, t)
        end
    end
    if grid
        gas = sp[:framestyle] in (:origin, :zerolines) ? namM : nas
        fa0_, fa1_ = reverse_if(fas, ax[:mirror])
        ga0_, ga1_ = reverse_if(gas, ax[:mirror])
    end
    letter = ax[:letter]
    for tick in ticks
        (ax[:showaxis] && cond) && push!(
            tick_segments,
            sort_3d_axes(tick, tick_start, first(fas), letter),
            sort_3d_axes(tick, tick_stop, first(fas), letter),
        )
        grid && push!(
            segments,
            sort_3d_axes(tick, ga0_, fa0_, letter),
            sort_3d_axes(tick, ga1_, fa0_, letter),
            sort_3d_axes(tick, ga1_, fa0_, letter),
            sort_3d_axes(tick, ga1_, fa1_, letter),
        )
    end
end

function axis_drawing_info_3d(sp, letter)
    letters = axes_letters(sp, letter)
    ax, nax, fax = map(l -> sp[get_attr_symbol(l, :axis)], letters)
    (amin, amax), namM, famM = map(l -> axis_limits(sp, l), letters)

    ticks = get_ticks(sp, ax, update = false)
    minor_ticks = get_minor_ticks(sp, ax, ticks)

    # initialize the segments
    segments, tick_segments, grid_segments, minorgrid_segments, border_segments =
        map(_ -> Segments(3), 1:5)

    if sp[:framestyle] !== :none  # && letter === :x
        na0, na1 =
            nas = if sp[:framestyle] in (:origin, :zerolines)
                0, 0
            else
                reverse_if(reverse_if(namM, letter === :y), xor(ax[:mirror], nax[:flip]))
            end
        fa0, fa1 = fas = if sp[:framestyle] in (:origin, :zerolines)
            0, 0
        else
            reverse_if(famM, xor(ax[:mirror], fax[:flip]))
        end
        if ax[:showaxis]
            if sp[:framestyle] !== :grid
                push!(
                    segments,
                    sort_3d_axes(amin, na0, fa0, letter),
                    sort_3d_axes(amax, na0, fa0, letter),
                )
                # don't show the 0 tick label for the origin framestyle
                if (
                    sp[:framestyle] === :origin &&
                    ticks ∉ (:none, nothing, false) &&
                    length(ticks) > 1
                )
                    if (i = findfirst(==(0), ticks[1])) !== nothing
                        deleteat!(ticks[1], i)
                        deleteat!(ticks[2], i)
                    end
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(
                border_segments,
                sort_3d_axes(amin, na1, fa1, letter),
                sort_3d_axes(amax, na1, fa1, letter),
            )
        end

        if ax[:ticks] ∉ (:none, nothing, false)
            # add major grid segments
            add_major_or_minor_segments_3d(
                sp,
                ax,
                nax,
                nas,
                fas,
                namM,
                first(ticks),
                ax[:grid],
                tick_segments,
                grid_segments,
                grid_factor_3d[],
                ax[:tick_direction] !== :none,
            )

            # add minor grid segments
            if ax[:minorticks] ∉ (:none, nothing, false) || ax[:minorgrid]
                add_major_or_minor_segments_3d(
                    sp,
                    ax,
                    nax,
                    nas,
                    fas,
                    namM,
                    minor_ticks,
                    ax[:minorgrid],
                    tick_segments,
                    minorgrid_segments,
                    grid_factor_3d[] / 2,
                    true,
                )
            end
        end
    end

    (
        ticks = ticks,
        segments = segments,
        tick_segments = tick_segments,
        grid_segments = grid_segments,
        minorgrid_segments = minorgrid_segments,
        border_segments = border_segments,
    )
end

reverse_if(x, cond) = cond ? reverse(x) : x
