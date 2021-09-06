
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
        @warn("Skipped $(letter)axis arg $arg")
    end
end

# update an Axis object with magic args and keywords
function attr!(axis::Axis, args...; kw...)
    # first process args
    plotattributes = axis.plotattributes
    for arg in args
        process_axis_arg!(plotattributes, arg)
    end

    # then preprocess keyword arguments
    RecipesPipeline.preprocess_attributes!(KW(kw))

    # then override for any keywords... only those keywords that already exists in plotattributes
    for (k, v) in kw
        if haskey(plotattributes, k)
            if k == :discrete_values
                # add these discrete values to the axis
                for vi in v
                    discrete_value!(axis, vi)
                end
                #could perhaps use TimeType here, as Date and DateTime are both subtypes of TimeType
                # or could perhaps check if dateformatter or datetimeformatter is in use
            elseif k == :lims && isa(v, Tuple{Date,Date})
                plotattributes[k] = (v[1].instant.periods.value, v[2].instant.periods.value)
            elseif k == :lims && isa(v, Tuple{DateTime,DateTime})
                plotattributes[k] = (v[1].instant.periods.value, v[2].instant.periods.value)
            else
                plotattributes[k] = v
            end
        end
    end

    # replace scale aliases
    if haskey(_scaleAliases, plotattributes[:scale])
        plotattributes[:scale] = _scaleAliases[plotattributes[:scale]]
    end

    axis
end

# -------------------------------------------------------------------------

Base.show(io::IO, axis::Axis) = dumpdict(io, axis.plotattributes, "Axis", true)
# Base.getindex(axis::Axis, k::Symbol) = getindex(axis.plotattributes, k)
Base.setindex!(axis::Axis, v, ks::Symbol...) = setindex!(axis.plotattributes, v, ks...)
Base.haskey(axis::Axis, k::Symbol) = haskey(axis.plotattributes, k)
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
    sf = RecipesPipeline.scale_func(scale)

    # If the axis input was a Date or DateTime use a special logic to find
    # "round" Date(Time)s as ticks
    # This bypasses the rest of optimal_ticks_and_labels, because
    # optimize_datetime_ticks returns ticks AND labels: the label format (Date
    # or DateTime) is chosen based on the time span between amin and amax
    # rather than on the input format
    # TODO: maybe: non-trivial scale (:ln, :log2, :log10) for date/datetime
    if ticks === nothing && scale == :identity
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
    if ticks === nothing
        scaled_ticks = optimize_ticks(
            sf(amin),
            sf(amax);
            k_min = scale ∈ _logScales ? 2 : 4, # minimum number of ticks
            k_max = 8, # maximum number of ticks
            scale = scale,
        )[1]
    elseif typeof(ticks) <: Int
        scaled_ticks, viewmin, viewmax = optimize_ticks(
            sf(amin),
            sf(amax);
            k_min = ticks, # minimum number of ticks
            k_max = ticks, # maximum number of ticks
            k_ideal = ticks,
            # `strict_span = false` rewards cases where the span of the
            # chosen  ticks is not too much bigger than amin - amax:
            strict_span = false,
            scale = scale,
        )
        # axis[:lims] = map(RecipesPipeline.inverse_scale_func(scale), (viewmin, viewmax))
    else
        scaled_ticks = map(sf, (filter(t -> amin <= t <= amax, ticks)))
    end
    unscaled_ticks = map(RecipesPipeline.inverse_scale_func(scale), scaled_ticks)

    labels = if any(isfinite, unscaled_ticks)
        if formatter in (:auto, :plain, :scientific, :engineering)
            map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, formatter))
        elseif formatter == :latex
            map(
                x -> string("\$", replace(convert_sci_unicode(x), '×' => "\\times"), "\$"),
                Showoff.showoff(unscaled_ticks, :auto),
            )
        else
            # there was an override for the formatter... use that on the unscaled ticks
            map(formatter, unscaled_ticks)
            # if the formatter left us with numbers, still apply the default formatter
            # However it leave us with the problem of unicode number decoding by the backend
            # if eltype(unscaled_ticks) <: Number
            #     Showoff.showoff(unscaled_ticks, :auto)
            # end
        end
    else
        # no finite ticks to show...
        String[]
    end

    # @show unscaled_ticks labels
    # labels = Showoff.showoff(unscaled_ticks, scale == :log10 ? :scientific : :auto)
    unscaled_ticks, labels
end

# return (continuous_values, discrete_values) for the ticks on this axis
function get_ticks(sp::Subplot, axis::Axis; update = true)
    if update || !haskey(axis.plotattributes, :optimized_ticks)
        dvals = axis[:discrete_values]
        ticks = _transform_ticks(axis[:ticks])
        axis.plotattributes[:optimized_ticks] =
            if (
                ticks isa Symbol &&
                ticks !== :none &&
                ispolar(sp) &&
                axis[:letter] === :x &&
                !isempty(dvals)
            )
                collect(0:(pi / 4):(7pi / 4)), string.(0:45:315)
            else
                cvals = axis[:continuous_values]
                alims = axis_limits(sp, axis[:letter])
                scale = axis[:scale]
                formatter = axis[:formatter]
                get_ticks(ticks, cvals, dvals, alims, scale, formatter)
            end
    end
    return axis.plotattributes[:optimized_ticks]
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
get_ticks(p::Plot, s::Symbol) = [get_ticks(sp, s) for sp in p.subplots]

function get_ticks(ticks::Symbol, cvals::T, dvals, args...) where {T}
    if ticks === :none
        return T[], String[]
    elseif !isempty(dvals)
        n = length(dvals)
        if ticks === :all || n < 16
            return cvals, string.(dvals)
        else
            Δ = ceil(Int, n / 10)
            rng = Δ:Δ:n
            return cvals[rng], string.(dvals[rng])
        end
    else
        return optimal_ticks_and_labels(nothing, args...)
    end
end
get_ticks(ticks::AVec, cvals, dvals, args...) = optimal_ticks_and_labels(ticks, args...)
function get_ticks(ticks::Int, dvals, cvals, args...)
    if !isempty(dvals)
        rng = round.(Int, range(1, stop = length(dvals), length = ticks))
        cvals[rng], string.(dvals[rng])
    else
        optimal_ticks_and_labels(ticks, args...)
    end
end
get_ticks(ticks::NTuple{2,Any}, args...) = ticks
get_ticks(::Nothing, cvals::T, args...) where {T} = T[], String[]
get_ticks(ticks::Bool, args...) =
    ticks ? get_ticks(:auto, args...) : get_ticks(nothing, args...)
get_ticks(::T, args...) where {T} = error("Unknown ticks type in get_ticks: $T")

_transform_ticks(ticks) = ticks
_transform_ticks(ticks::AbstractArray{T}) where {T<:Dates.TimeType} = Dates.value.(ticks)
_transform_ticks(ticks::NTuple{2,Any}) = (_transform_ticks(ticks[1]), ticks[2])

function get_minor_ticks(sp, axis, ticks)
    axis[:minorticks] ∈ (:none, nothing, false) && !axis[:minorgrid] && return nothing
    ticks = ticks[1]
    length(ticks) < 2 && return nothing

    amin, amax = axis_limits(sp, axis[:letter])
    scale = axis[:scale]
    log_scaled = scale ∈ _logScales
    base = get(_logScaleBases, scale, nothing)

    # add one phantom tick either side of the ticks to ensure minor ticks extend to the axis limits
    if log_scaled
        sub = round(Int, log(base, ticks[2] / ticks[1]))
        ticks = [ticks[1] / base; ticks; ticks[end] * base]
    else
        sub = 1  # unused
        ratio = length(ticks) > 2 ? (ticks[3] - ticks[2]) / (ticks[2] - ticks[1]) : 1
        first_step = ticks[2] - ticks[1]
        last_step = ticks[end] - ticks[end - 1]
        ticks = [ticks[1] - first_step / ratio; ticks; ticks[end] + last_step * ratio]
    end

    # default to 9 intervals between major ticks for log10 scale and 5 intervals otherwise
    n_default = (scale == :log10) ? 9 : 5
    n =
        typeof(axis[:minorticks]) <: Integer && axis[:minorticks] > 1 ? axis[:minorticks] :
        n_default

    minorticks = typeof(ticks[1])[]
    for (i, hi) in enumerate(ticks[2:end])
        lo = ticks[i]
        if isfinite(lo) && isfinite(hi) && hi > lo
            if log_scaled
                for e in 1:sub
                    lo_ = lo * base^(e - 1)
                    hi_ = lo_ * base
                    step = (hi_ - lo_) / n
                    append!(
                        minorticks,
                        collect(
                            (lo_ + (e > 1 ? 0 : step)):step:(hi_ - (e < sub ? 0 :
                                                                    step / 2)),
                        ),
                    )
                end
            else
                step = (hi - lo) / n
                append!(minorticks, collect((lo + step):step:(hi - step / 2)))
            end
        end
    end
    minorticks[amin .<= minorticks .<= amax]
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

function expand_extrema!(axis::Axis, v::Number)
    expand_extrema!(axis[:extrema], v)
end

# these shouldn't impact the extrema
expand_extrema!(axis::Axis, ::Nothing) = axis[:extrema]
expand_extrema!(axis::Axis, ::Bool) = axis[:extrema]

function expand_extrema!(axis::Axis, v::Tuple{MIN,MAX}) where {MIN<:Number,MAX<:Number}
    ex = axis[:extrema]
    ex.emin = isfinite(v[1]) ? min(v[1], ex.emin) : ex.emin
    ex.emax = isfinite(v[2]) ? max(v[2], ex.emax) : ex.emax
    ex
end
function expand_extrema!(axis::Axis, v::AVec{N}) where {N<:Number}
    ex = axis[:extrema]
    for vi in v
        expand_extrema!(ex, vi)
    end
    ex
end

function expand_extrema!(sp::Subplot, plotattributes::AKW)
    vert = isvertical(plotattributes)

    # first expand for the data
    for letter in (:x, :y, :z)
        data = plotattributes[if vert
            letter
        else
            letter == :x ? :y : letter == :y ? :x : :z
        end]
        if (
            letter != :z &&
            plotattributes[:seriestype] == :straightline &&
            any(series[:seriestype] != :straightline for series in series_list(sp)) &&
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
    if fr === nothing && plotattributes[:seriestype] == :bar
        fr = 0.0
    end
    if fr !== nothing && !RecipesPipeline.is3d(plotattributes)
        axis = sp.attr[vert ? :yaxis : :xaxis]
        if typeof(fr) <: Tuple
            for fri in fr
                expand_extrema!(axis, fri)
            end
        else
            expand_extrema!(axis, fr)
        end
    end

    # expand for bar_width
    if plotattributes[:seriestype] == :bar
        dsym = vert ? :x : :y
        data = plotattributes[dsym]

        bw = plotattributes[:bar_width]
        if bw === nothing
            bw =
                plotattributes[:bar_width] =
                    _bar_width * ignorenan_minimum(filter(x -> x > 0, diff(sort(data))))
        end
        axis = sp.attr[get_attr_symbol(dsym, :axis)]
        expand_extrema!(axis, ignorenan_maximum(data) + 0.5maximum(bw))
        expand_extrema!(axis, ignorenan_minimum(data) - 0.5minimum(bw))
    end

    # expand for heatmaps
    if plotattributes[:seriestype] == :heatmap
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

# push the limits out slightly
function widen(lmin, lmax, scale = :identity)
    f, invf = RecipesPipeline.scale_func(scale), RecipesPipeline.inverse_scale_func(scale)
    span = f(lmax) - f(lmin)
    # eps = NaNMath.max(1e-16, min(1e-2span, 1e-10))
    eps = NaNMath.max(1e-16, 0.03span)
    invf(f(lmin) - eps), invf(f(lmax) + eps)
end

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

function default_should_widen(axis::Axis)
    if axis[:widen] isa Bool
        return axis[:widen]
    end
    # automatic behavior: widen if limits aren't specified and series type is appropriate
    (is_2tuple(axis[:lims]) || axis[:lims] == :round) && return false
    for sp in axis.sps
        for series in series_list(sp)
            if series.plotattributes[:seriestype] in _widen_seriestypes
                return true
            end
        end
    end
    false
end

function round_limits(amin, amax, scale)
    base = get(_logScaleBases, scale, 10.0)
    factor = base^(1 - round(log(base, amax - amin)))
    amin = floor(amin * factor) / factor
    amax = ceil(amax * factor) / factor
    amin, amax
end

# using the axis extrema and limit overrides, return the min/max value for this axis
function axis_limits(
    sp,
    letter,
    should_widen = default_should_widen(sp[get_attr_symbol(letter, :axis)]),
    consider_aspect = true,
)
    axis = sp[get_attr_symbol(letter, :axis)]
    ex = axis[:extrema]
    amin, amax = ex.emin, ex.emax
    lims = axis[:lims]
    has_user_lims = (isa(lims, Tuple) || isa(lims, AVec)) && length(lims) == 2
    if has_user_lims
        lmin, lmax = lims
        if lmin == :auto
        elseif isfinite(lmin)
            amin = lmin
        end
        if lmax == :auto
        elseif isfinite(lmax)
            amax = lmax
        end
    end
    if lims == :symmetric
        aval = max(abs(amin), abs(amax))
        amin = -aval
        amax = aval
    end
    if amax <= amin && isfinite(amin)
        amax = amin + 1.0
    end
    if !isfinite(amin) && !isfinite(amax)
        amin, amax = 0.0, 1.0
    end
    amin, amax = if ispolar(axis.sps[1])
        if axis[:letter] == :x
            amin, amax = 0, 2pi
        elseif lims == :auto
            # widen max radius so ticks dont overlap with theta axis
            0, amax + 0.1 * abs(amax - amin)
        else
            amin, amax
        end
    elseif should_widen
        widen(amin, amax, axis[:scale])
    elseif lims == :round
        round_limits(amin, amax, axis[:scale])
    else
        amin, amax
    end

    if (
        !has_user_lims &&
        consider_aspect &&
        letter in (:x, :y) &&
        !(sp[:aspect_ratio] in (:none, :auto) || RecipesPipeline.is3d(:sp))
    )
        aspect_ratio = isa(sp[:aspect_ratio], Number) ? sp[:aspect_ratio] : 1
        plot_ratio = height(plotarea(sp)) / width(plotarea(sp))
        dist = amax - amin

        if letter == :x
            yamin, yamax = axis_limits(sp, :y, default_should_widen(sp[:yaxis]), false)
            ydist = yamax - yamin
            axis_ratio = aspect_ratio * ydist / dist
            factor = axis_ratio / plot_ratio
        else
            xamin, xamax = axis_limits(sp, :x, default_should_widen(sp[:xaxis]), false)
            xdist = xamax - xamin
            axis_ratio = aspect_ratio * dist / xdist
            factor = plot_ratio / axis_ratio
        end

        if factor > 1
            center = (amin + amax) / 2
            amin = center + factor * (amin - center)
            amax = center + factor * (amax - center)
        end
    end

    return amin, amax
end

# -------------------------------------------------------------------------

# these methods track the discrete (categorical) values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return (continuous_value, discrete_index)
function discrete_value!(axis::Axis, dv)
    cv_idx = get(axis[:discrete_map], dv, -1)
    # @show axis[:discrete_map], axis[:discrete_values], dv
    if cv_idx == -1
        ex = axis[:extrema]
        cv = NaNMath.max(0.5, ex.emax + 1.0)
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
end

# continuous value... just pass back with axis negative index
function discrete_value!(axis::Axis, cv::Number)
    cv, -1
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AVec)
    n = eachindex(v)
    cvec = zeros(axes(v))
    discrete_indices = similar(Array{Int}, axes(v))
    for i in n
        cvec[i], discrete_indices[i] = discrete_value!(axis, v[i])
    end
    cvec, discrete_indices
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AMat)
    n, m = axes(v)
    cmat = zeros(axes(v))
    discrete_indices = similar(Array{Int}, axes(v))
    for i in n, j in m
        cmat[i, j], discrete_indices[i, j] = discrete_value!(axis, v[i, j])
    end
    cmat, discrete_indices
end

function discrete_value!(axis::Axis, v::Surface)
    map(Surface, discrete_value!(axis, v.surf))
end

# -------------------------------------------------------------------------

# compute the line segments which should be drawn for this axis
function axis_drawing_info(sp, letter)
    # find out which axis we are dealing with
    asym = get_attr_symbol(letter, :axis)
    isy = letter === :y
    oletter = isy ? :x : :y
    oasym = get_attr_symbol(oletter, :axis)

    # get axis objects, ticks and minor ticks
    ax, oax = sp[asym], sp[oasym]
    amin, amax = axis_limits(sp, letter)
    oamin, oamax = axis_limits(sp, oletter)
    ticks = get_ticks(sp, ax, update = false)
    minor_ticks = get_minor_ticks(sp, ax, ticks)

    # initialize the segments
    segments = Segments(2)
    tick_segments = Segments(2)
    grid_segments = Segments(2)
    minorgrid_segments = Segments(2)
    border_segments = Segments(2)

    if sp[:framestyle] != :none
        oa1, oa2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(ax[:mirror], oax[:flip]) ? (oamax, oamin) : (oamin, oamax)
        end
        if ax[:showaxis]
            if sp[:framestyle] != :grid
                push!(segments, reverse_if((amin, oa1), isy), reverse_if((amax, oa1), isy))
                # don't show the 0 tick label for the origin framestyle
                if (
                    sp[:framestyle] == :origin &&
                    !(ticks in (:none, nothing, false)) &&
                    length(ticks) > 1
                )
                    i = findfirst(==(0), ticks[1])
                    if i !== nothing
                        deleteat!(ticks[1], i)
                        deleteat!(ticks[2], i)
                    end
                end
            end
            if sp[:framestyle] in (:semi, :box) # top spine
                push!(
                    border_segments,
                    reverse_if((amin, oa2), isy),
                    reverse_if((amax, oa2), isy),
                )
            end
        end
        if ax[:ticks] ∉ (:none, nothing, false)
            f = RecipesPipeline.scale_func(oax[:scale])
            invf = RecipesPipeline.inverse_scale_func(oax[:scale])

            add_major_or_minor_segments(ticks, grid, segments, factor, cond) = begin
                ticks === nothing && return
                if cond
                    tick_start, tick_stop = if sp[:framestyle] == :origin
                        t = invf(f(0) + factor * (f(oamax) - f(oamin)))
                        (-t, t)
                    else
                        ticks_in = ax[:tick_direction] == :out ? -1 : 1
                        t = invf(f(oa1) + factor * (f(oa2) - f(oa1)) * ticks_in)
                        (oa1, t)
                    end
                end

                for tick in ticks
                    if ax[:showaxis] && cond
                        push!(
                            tick_segments,
                            reverse_if((tick, tick_start), isy),
                            reverse_if((tick, tick_stop), isy),
                        )
                    end
                    if grid
                        push!(
                            segments,
                            reverse_if((tick, oamin), isy),
                            reverse_if((tick, oamax), isy),
                        )
                    end
                end
            end

            ax_length = letter === :x ? height(sp.plotarea).value : width(sp.plotarea).value

            # add major grid segments
            add_major_or_minor_segments(
                ticks[1],
                ax[:grid],
                grid_segments,
                1.2 / ax_length,
                ax[:tick_direction] !== :none,
            )

            # add minor grid segments
            if ax[:minorticks] ∉ (:none, nothing, false) || ax[:minorgrid]
                add_major_or_minor_segments(
                    minor_ticks,
                    ax[:minorgrid],
                    minorgrid_segments,
                    0.6 / ax_length,
                    true,
                )
            end
        end
    end

    return (
        ticks = ticks,
        segments = segments,
        tick_segments = tick_segments,
        grid_segments = grid_segments,
        minorgrid_segments = minorgrid_segments,
        border_segments = border_segments,
    )
end

function sort_3d_axes(a, b, c, letter)
    if letter === :x
        a, b, c
    elseif letter === :y
        b, a, c
    else
        c, b, a
    end
end

function axis_drawing_info_3d(sp, letter)
    near_letter = letter in (:x, :z) ? :y : :x
    far_letter = letter in (:x, :y) ? :z : :x

    ax = sp[get_attr_symbol(letter, :axis)]
    nax = sp[get_attr_symbol(near_letter, :axis)]
    fax = sp[get_attr_symbol(far_letter, :axis)]

    amin, amax = axis_limits(sp, letter)
    namin, namax = axis_limits(sp, near_letter)
    famin, famax = axis_limits(sp, far_letter)

    ticks = get_ticks(sp, ax, update = false)
    minor_ticks = get_minor_ticks(sp, ax, ticks)

    # initialize the segments
    segments = Segments(3)
    tick_segments = Segments(3)
    grid_segments = Segments(3)
    minorgrid_segments = Segments(3)
    border_segments = Segments(3)

    if sp[:framestyle] != :none  # && letter === :x
        na0, na1 = if sp[:framestyle] in (:origin, :zerolines)
            0, 0
        else
            # reverse_if((namin, namax), xor(ax[:mirror], nax[:flip]))
            reverse_if(reverse_if((namin, namax), letter === :y), xor(ax[:mirror], nax[:flip]))
        end
        fa0, fa1 = if sp[:framestyle] in (:origin, :zerolines)
            0, 0
        else
            reverse_if((famin, famax), xor(ax[:mirror], fax[:flip]))
        end
        if ax[:showaxis]
            if sp[:framestyle] != :grid
                push!(
                    segments,
                    sort_3d_axes(amin, na0, fa0, letter),
                    sort_3d_axes(amax, na0, fa0, letter),
                )
                # don't show the 0 tick label for the origin framestyle
                if (
                    sp[:framestyle] == :origin &&
                    !(ticks in (:none, nothing, false)) &&
                    length(ticks) > 1
                )
                    i0 = findfirst(==(0), ticks[1])
                    if i0 !== nothing
                        deleteat!(ticks[1], i0)
                        deleteat!(ticks[2], i0)
                    end
                end
            end
            if sp[:framestyle] in (:semi, :box)
                push!(
                    border_segments,
                    sort_3d_axes(amin, na1, fa1, letter),
                    sort_3d_axes(amax, na1, fa1, letter),
                )
            end
        end

        if ax[:ticks] ∉ (:none, nothing, false)
            f = RecipesPipeline.scale_func(nax[:scale])
            invf = RecipesPipeline.inverse_scale_func(nax[:scale])
            ga0, ga1 =
                sp[:framestyle] in (:origin, :zerolines) ? (namin, namax) : (na0, na1)

            add_major_or_minor_segments(ticks, grid, segments, factor, cond) = begin
                ticks === nothing && return
                if cond
                    tick_start, tick_stop = if sp[:framestyle] == :origin
                        t = invf(f(0) + factor * (f(namax) - f(namin)))
                        (-t, t)
                    else
                        ticks_in = ax[:tick_direction] == :out ? -1 : 1
                        t = invf(f(na0) + factor * (f(na1) - f(na0)) * ticks_in)
                        (na0, t)
                    end
                end

                for tick in ticks
                    if ax[:showaxis] && cond
                        push!(
                            tick_segments,
                            sort_3d_axes(tick, tick_start, fa0, letter),
                            sort_3d_axes(tick, tick_stop, fa0, letter),
                        )
                    end
                    if grid
                        fa0_, fa1_ = reverse_if((fa0, fa1), ax[:mirror])
                        ga0_, ga1_ = reverse_if((ga0, ga1), ax[:mirror])
                        push!(
                            segments,
                            sort_3d_axes(tick, ga0_, fa0_, letter),
                            sort_3d_axes(tick, ga1_, fa0_, letter),
                        )
                        push!(
                            segments,
                            sort_3d_axes(tick, ga1_, fa0_, letter),
                            sort_3d_axes(tick, ga1_, fa1_, letter),
                        )
                    end
                end
            end

            # add major grid segments
            add_major_or_minor_segments(
                ticks[1],
                ax[:grid],
                grid_segments,
                0.012,
                ax[:tick_direction] !== :none,
            )

            # add minor grid segments
            if ax[:minorticks] ∉ (:none, nothing, false) || ax[:minorgrid]
                add_major_or_minor_segments(
                    minor_ticks,
                    ax[:minorgrid],
                    minorgrid_segments,
                    0.006,
                    true,
                )
            end
        end
    end

    return (
        ticks = ticks,
        segments = segments,
        tick_segments = tick_segments,
        grid_segments = grid_segments,
        minorgrid_segments = minorgrid_segments,
        border_segments = border_segments,
    )
end

reverse_if(x, cond) = cond ? reverse(x) : x
axis_tuple(x, y, letter) = reverse_if((x, y), letter === :y)

axes_shift(t, i) = i % 3 == 0 ? t : i % 3 == 1 ? (t[3], t[1], t[2]) : (t[2], t[3], t[1])
