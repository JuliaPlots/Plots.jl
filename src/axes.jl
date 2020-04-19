

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
    axissym = Symbol(letter, :axis)
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
        plotattributes[Symbol(letter,:tickfont)] = arg
        plotattributes[Symbol(letter,:guidefont)] = arg

    elseif arg in _allScales
        plotattributes[Symbol(letter,:scale)] = arg

    elseif arg in (:flip, :invert, :inverted)
        plotattributes[Symbol(letter,:flip)] = true

    elseif T <: AbstractString
        plotattributes[Symbol(letter,:guide)] = arg

    # xlims/ylims
    elseif (T <: Tuple || T <: AVec) && length(arg) == 2
        sym = typeof(arg[1]) <: Number ? :lims : :ticks
        plotattributes[Symbol(letter,sym)] = arg

    # xticks/yticks
    elseif T <: AVec
        plotattributes[Symbol(letter,:ticks)] = arg

    elseif arg === nothing
        plotattributes[Symbol(letter,:ticks)] = []

    elseif T <: Bool || arg in _allShowaxisArgs
        plotattributes[Symbol(letter,:showaxis)] = showaxis(arg, letter)

    elseif typeof(arg) <: Number
        plotattributes[Symbol(letter,:rotation)] = arg

    elseif typeof(arg) <: Function
        plotattributes[Symbol(letter,:formatter)] = arg

    elseif !handleColors!(plotattributes, arg, Symbol(letter, :foreground_color_axis))
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
    for (k,v) in kw
        if haskey(plotattributes, k)
            if k == :discrete_values
                # add these discrete values to the axis
                for vi in v
                    discrete_value!(axis, vi)
                end
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

const _label_func = Dict{Symbol,Function}(
    :log10 => x -> "10^$x",
    :log2 => x -> "2^$x",
    :ln => x -> "e^$x",
)
labelfunc(scale::Symbol, backend::AbstractBackend) = get(_label_func, scale, string)

function optimal_ticks_and_labels(sp::Subplot, axis::Axis, ticks = nothing)
    amin, amax = axis_limits(sp, axis[:letter])

    # scale the limits
    scale = axis[:scale]
    sf = RecipesPipeline.scale_func(scale)

    # If the axis input was a Date or DateTime use a special logic to find
    # "round" Date(Time)s as ticks
    # This bypasses the rest of optimal_ticks_and_labels, because
    # optimize_datetime_ticks returns ticks AND labels: the label format (Date
    # or DateTime) is chosen based on the time span between amin and amax
    # rather than on the input format
    # TODO: maybe: non-trivial scale (:ln, :log2, :log10) for date/datetime
    if ticks === nothing && scale == :identity
        if axis[:formatter] == RecipesPipeline.dateformatter
            # optimize_datetime_ticks returns ticks and labels(!) based on
            # integers/floats corresponding to the DateTime type. Thus, the axes
            # limits, which resulted from converting the Date type to integers,
            # are converted to 'DateTime integers' (actually floats) before
            # being passed to optimize_datetime_ticks.
            # (convert(Int, convert(DateTime, convert(Date, i))) == 87600000*i)
            ticks, labels = optimize_datetime_ticks(864e5 * amin, 864e5 * amax;
                k_min = 2, k_max = 4)
            # Now the ticks are converted back to floats corresponding to Dates.
            return ticks / 864e5, labels
        elseif axis[:formatter] == RecipesPipeline.datetimeformatter
            return optimize_datetime_ticks(amin, amax; k_min = 2, k_max = 4)
        end
    end

    # get a list of well-laid-out ticks
    if ticks === nothing
        scaled_ticks = optimize_ticks(
            sf(amin),
            sf(amax);
            k_min = 4, # minimum number of ticks
            k_max = 8, # maximum number of ticks
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
        )
        axis[:lims] = map(RecipesPipeline.inverse_scale_func(scale), (viewmin, viewmax))
    else
        scaled_ticks = map(sf, (filter(t -> amin <= t <= amax, ticks)))
    end
    unscaled_ticks = map(RecipesPipeline.inverse_scale_func(scale), scaled_ticks)

    labels = if any(isfinite, unscaled_ticks)
        formatter = axis[:formatter]
        if formatter == :auto
            # the default behavior is to make strings of the scaled values and then apply the labelfunc
            map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, :auto))
        elseif formatter == :plain
            # Leave the numbers in plain format
            map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, :plain))
        elseif formatter == :scientific
            Showoff.showoff(unscaled_ticks, :scientific)
	elseif formatter == :latex
	    map(x -> string("\$", replace(convert_sci_unicode(x), '×' => "\\times"), "\$"), Showoff.showoff(unscaled_ticks, :auto))
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
function get_ticks(sp::Subplot, axis::Axis)
    ticks = _transform_ticks(axis[:ticks])
    ticks in (:none, nothing, false) && return nothing

    # treat :native ticks as :auto
    ticks = ticks == :native ? :auto : ticks

    dvals = axis[:discrete_values]
    cv, dv = if typeof(ticks) <: Symbol
        if !isempty(dvals)
            # discrete ticks...
            n = length(dvals)
            rng = if ticks == :auto
                Int[round(Int,i) for i in range(1, stop=n, length=min(n,15))]
            else # if ticks == :all
                1:n
            end
            axis[:continuous_values][rng], dvals[rng]
        elseif ispolar(axis.sps[1]) && axis[:letter] == :x
            #force theta axis to be full circle
            (collect(0:pi/4:7pi/4), string.(0:45:315))
        else
            # compute optimal ticks and labels
            optimal_ticks_and_labels(sp, axis)
        end
    elseif typeof(ticks) <: Union{AVec, Int}
        if !isempty(dvals) && typeof(ticks) <: Int
            rng = Int[round(Int,i) for i in range(1, stop=length(dvals), length=ticks)]
            axis[:continuous_values][rng], dvals[rng]
        else
            # override ticks, but get the labels
            optimal_ticks_and_labels(sp, axis, ticks)
        end
    elseif typeof(ticks) <: NTuple{2, Any}
        # assuming we're passed (ticks, labels)
        ticks
    else
        error("Unknown ticks type in get_ticks: $(typeof(ticks))")
    end
    # @show ticks dvals cv dv

    return cv, dv
end

_transform_ticks(ticks) = ticks
_transform_ticks(ticks::AbstractArray{T}) where T <: Dates.TimeType = Dates.value.(ticks)
_transform_ticks(ticks::NTuple{2, Any}) = (_transform_ticks(ticks[1]), ticks[2])

function get_minor_ticks(sp, axis, ticks)
    axis[:minorticks] in (:none, nothing, false) && !axis[:minorgrid] && return nothing
    ticks = ticks[1]
    length(ticks) < 2 && return nothing

    amin, amax = axis_limits(sp, axis[:letter])
    #Add one phantom tick either side of the ticks to ensure minor ticks extend to the axis limits
    if length(ticks) > 2
        ratio = (ticks[3] - ticks[2])/(ticks[2] - ticks[1])
    elseif axis[:scale] in (:none, :identity)
        ratio = 1
    else
        return nothing
    end
    first_step = ticks[2] - ticks[1]
    last_step = ticks[end] - ticks[end-1]
    ticks =  [ticks[1] - first_step/ratio; ticks; ticks[end] + last_step*ratio]

    #Default to 5 intervals between major ticks
    n = typeof(axis[:minorticks]) <: Integer && axis[:minorticks] > 1 ? axis[:minorticks] : 5
    minorticks = typeof(ticks[1])[]
    for (i,hi) in enumerate(ticks[2:end])
        lo = ticks[i]
        if isfinite(lo) && isfinite(hi) && hi > lo
            append!(minorticks,collect(lo + (hi-lo)/n :(hi-lo)/n: hi - (hi-lo)/2n))
        end
    end
    minorticks[amin .<= minorticks .<= amax]
end

# -------------------------------------------------------------------------


function reset_extrema!(sp::Subplot)
    for asym in (:x,:y,:z)
        sp[Symbol(asym,:axis)][:extrema] = Extrema()
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
function expand_extrema!(axis::Axis, v::AVec{N}) where N<:Number
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
        if letter != :z && plotattributes[:seriestype] == :straightline && any(series[:seriestype] != :straightline for series in series_list(sp)) && data[1] != data[2]
            data = [NaN]
        end
        axis = sp[Symbol(letter, "axis")]

        if isa(data, Volume)
            expand_extrema!(sp[:xaxis], data.x_extents)
            expand_extrema!(sp[:yaxis], data.y_extents)
            expand_extrema!(sp[:zaxis], data.z_extents)
        elseif eltype(data) <: Number || (isa(data, Surface) && all(di -> isa(di, Number), data.surf))
            if !(eltype(data) <: Number)
                # huh... must have been a mis-typed surface? lets swap it out
                data = plotattributes[letter] = Surface(Matrix{Float64}(data.surf))
            end
            expand_extrema!(axis, data)
        elseif data !== nothing
            # TODO: need more here... gotta track the discrete reference value
            #       as well as any coord offset (think of boxplot shape coords... they all
            #       correspond to the same x-value)
            plotattributes[letter], plotattributes[Symbol(letter,"_discrete_indices")] = discrete_value!(axis, data)
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
            bw = plotattributes[:bar_width] = _bar_width * ignorenan_minimum(filter(x->x>0,diff(sort(data))))
        end
        axis = sp.attr[Symbol(dsym, :axis)]
        expand_extrema!(axis, ignorenan_maximum(data) + 0.5maximum(bw))
        expand_extrema!(axis, ignorenan_minimum(data) - 0.5minimum(bw))
    end

    # expand for heatmaps
    if plotattributes[:seriestype] == :heatmap
        for letter in (:x, :y)
            data = plotattributes[letter]
            axis = sp[Symbol(letter, "axis")]
            scale = get(plotattributes, Symbol(letter, "scale"), :identity)
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
    invf(f(lmin)-eps), invf(f(lmax)+eps)
end

# figure out if widening is a good idea.
const _widen_seriestypes = (:line, :path, :steppre, :steppost, :sticks, :scatter, :barbins, :barhist, :histogram, :scatterbins, :scatterhist, :stepbins, :stephist, :bins2d, :histogram2d, :bar, :shape, :path3d, :scatter3d)

function default_should_widen(axis::Axis)
    should_widen = false
    if !(is_2tuple(axis[:lims]) || axis[:lims] == :round)
        for sp in axis.sps
            for series in series_list(sp)
                if series.plotattributes[:seriestype] in _widen_seriestypes
                    should_widen = true
                end
            end
        end
    end
    should_widen
end

function round_limits(amin,amax)
    scale = 10^(1-round(log10(amax - amin)))
    amin = floor(amin*scale)/scale
    amax = ceil(amax*scale)/scale
    amin, amax
end

# using the axis extrema and limit overrides, return the min/max value for this axis
function axis_limits(sp, letter, should_widen = default_should_widen(sp[Symbol(letter, :axis)]), consider_aspect = true)
    axis = sp[Symbol(letter, :axis)]
    ex = axis[:extrema]
    amin, amax = ex.emin, ex.emax
    lims = axis[:lims]
    has_user_lims = (isa(lims, Tuple) || isa(lims, AVec)) && length(lims) == 2
    if has_user_lims
        lmin, lmax = lims
        if lmin != :auto && isfinite(lmin)
            amin = lmin
        end
        if lmax != :auto && isfinite(lmax)
            amax = lmax
        end
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
            #widen max radius so ticks dont overlap with theta axis
            0, amax + 0.1 * abs(amax - amin)
        else
            amin, amax
        end
    elseif should_widen && axis[:widen]
        widen(amin, amax, axis[:scale])
    elseif lims == :round
        round_limits(amin,amax)
    else
        amin, amax
    end

    if !has_user_lims && consider_aspect && letter in (:x, :y) && !(sp[:aspect_ratio] in (:none, :auto) || RecipesPipeline.is3d(:sp))
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
    n,m = axes(v)
    cmat = zeros(axes(v))
    discrete_indices = similar(Array{Int}, axes(v))
    for i in n, j in m
        cmat[i,j], discrete_indices[i,j] = discrete_value!(axis, v[i,j])
    end
    cmat, discrete_indices
end

function discrete_value!(axis::Axis, v::Surface)
    map(Surface, discrete_value!(axis, v.surf))
end

# -------------------------------------------------------------------------

function pie_labels(sp::Subplot, series::Series)
    plotattributes = series.plotattributes
    if haskey(plotattributes,:x_discrete_indices)
        dvals = sp.attr[:xaxis].plotattributes[:discrete_values]
        [dvals[idx] for idx in plotattributes[:x_discrete_indices]]
    else
        plotattributes[:x]
    end
end

# -------------------------------------------------------------------------

# compute the line segments which should be drawn for this axis
function axis_drawing_info(sp::Subplot)
    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    xmin, xmax = axis_limits(sp, :x)
    ymin, ymax = axis_limits(sp, :y)
    xticks = get_ticks(sp, xaxis)
    yticks = get_ticks(sp, yaxis)
    xminorticks = get_minor_ticks(sp, xaxis, xticks)
    yminorticks = get_minor_ticks(sp, yaxis, yticks)
    xaxis_segs = Segments(2)
    yaxis_segs = Segments(2)
    xtick_segs = Segments(2)
    ytick_segs = Segments(2)
    xgrid_segs = Segments(2)
    ygrid_segs = Segments(2)
    xminorgrid_segs = Segments(2)
    yminorgrid_segs = Segments(2)
    xborder_segs = Segments(2)
    yborder_segs = Segments(2)

    if sp[:framestyle] != :none
        # xaxis
        y1, y2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(xaxis[:mirror], yaxis[:flip]) ? (ymax, ymin) : (ymin, ymax)
        end
        if xaxis[:showaxis]
            if sp[:framestyle] != :grid
                push!(xaxis_segs, (xmin, y1), (xmax, y1))
                # don't show the 0 tick label for the origin framestyle
                if sp[:framestyle] == :origin && !(xticks in (:none, nothing, false)) && length(xticks) > 1
                    showticks = xticks[1] .!= 0
                    xticks = (xticks[1][showticks], xticks[2][showticks])
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(xborder_segs, (xmin, y2), (xmax, y2)) # top spine
        end
        if !(xaxis[:ticks] in (:none, nothing, false))
            f = RecipesPipeline.scale_func(yaxis[:scale])
            invf = RecipesPipeline.inverse_scale_func(yaxis[:scale])
            tick_start, tick_stop = if sp[:framestyle] == :origin
                t = invf(f(0) + 0.012 * (f(ymax) - f(ymin)))
                (-t, t)
            else
                ticks_in = xaxis[:tick_direction] == :out ? -1 : 1
                t = invf(f(y1) + 0.012 * (f(y2) - f(y1)) * ticks_in)
                (y1, t)
            end

            for xtick in xticks[1]
                if xaxis[:showaxis]
                    push!(xtick_segs, (xtick, tick_start), (xtick, tick_stop)) # bottom tick
                end
                xaxis[:grid] && push!(xgrid_segs, (xtick, ymin), (xtick, ymax)) # vertical grid
            end

            if !(xaxis[:minorticks] in (:none, nothing, false)) || xaxis[:minorgrid]
                tick_start, tick_stop = if sp[:framestyle] == :origin
                    t = invf(f(0) + 0.006 * (f(ymax) - f(ymin)))
                    (-t, t)
                else
                    t = invf(f(y1) + 0.006 * (f(y2) - f(y1)) * ticks_in)
                    (y1, t)
                end
                for xtick in xminorticks
                    if xaxis[:showaxis]
                        push!(xtick_segs, (xtick, tick_start), (xtick, tick_stop)) # bottom tick
                    end
                    xaxis[:minorgrid] && push!(xminorgrid_segs, (xtick, ymin), (xtick, ymax)) # vertical grid
                end
            end
        end


        # yaxis
        x1, x2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(yaxis[:mirror], xaxis[:flip]) ? (xmax, xmin) : (xmin, xmax)
        end
        if yaxis[:showaxis]
            if sp[:framestyle] != :grid
                push!(yaxis_segs, (x1, ymin), (x1, ymax))
                # don't show the 0 tick label for the origin framestyle
                if sp[:framestyle] == :origin && !(yticks in (:none, nothing,false)) && length(yticks) > 1
                    showticks = yticks[1] .!= 0
                    yticks = (yticks[1][showticks], yticks[2][showticks])
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(yborder_segs, (x2, ymin), (x2, ymax)) # right spine
        end
        if !(yaxis[:ticks] in (:none, nothing, false))
            f = RecipesPipeline.scale_func(xaxis[:scale])
            invf = RecipesPipeline.inverse_scale_func(xaxis[:scale])
            tick_start, tick_stop = if sp[:framestyle] == :origin
                t = invf(f(0) + 0.012 * (f(xmax) - f(xmin)))
                (-t, t)
            else
                ticks_in = yaxis[:tick_direction] == :out ? -1 : 1
                t = invf(f(x1) + 0.012 * (f(x2) - f(x1)) * ticks_in)
                (x1, t)
            end

            for ytick in yticks[1]
                if yaxis[:showaxis]
                    push!(ytick_segs, (tick_start, ytick), (tick_stop, ytick)) # left tick
                end
                yaxis[:grid] && push!(ygrid_segs, (xmin, ytick), (xmax, ytick)) # horizontal grid
            end

            if !(yaxis[:minorticks] in (:none, nothing, false)) || yaxis[:minorgrid]
                tick_start, tick_stop = if sp[:framestyle] == :origin
                    t = invf(f(0) + 0.006 * (f(xmax) - f(xmin)))
                    (-t, t)
                else
                    t = invf(f(x1) + 0.006 * (f(x2) - f(x1)) * ticks_in)
                    (x1, t)
                end
                for ytick in yminorticks
                    if yaxis[:showaxis]
                        push!(ytick_segs, (tick_start, ytick), (tick_stop, ytick)) # left tick
                    end
                    yaxis[:minorgrid] && push!(yminorgrid_segs, (xmin, ytick), (xmax, ytick)) # horizontal grid
                end
            end
        end
    end

    xticks, yticks, xaxis_segs, yaxis_segs, xtick_segs, ytick_segs, xgrid_segs, ygrid_segs, xminorgrid_segs, yminorgrid_segs, xborder_segs, yborder_segs
end


function axis_drawing_info_3d(sp::Subplot)
    xaxis, yaxis, zaxis = sp[:xaxis], sp[:yaxis], sp[:zaxis]
    xmin, xmax = axis_limits(sp, :x)
    ymin, ymax = axis_limits(sp, :y)
    zmin, zmax = axis_limits(sp, :z)
    xticks = get_ticks(sp, xaxis)
    yticks = get_ticks(sp, yaxis)
    zticks = get_ticks(sp, zaxis)
    xminorticks = get_minor_ticks(sp, xaxis, xticks)
    yminorticks = get_minor_ticks(sp, yaxis, yticks)
    zminorticks = get_minor_ticks(sp, zaxis, zticks)
    xaxis_segs = Segments(3)
    yaxis_segs = Segments(3)
    zaxis_segs = Segments(3)
    xtick_segs = Segments(3)
    ytick_segs = Segments(3)
    ztick_segs = Segments(3)
    xgrid_segs = Segments(3)
    ygrid_segs = Segments(3)
    zgrid_segs = Segments(3)
    xminorgrid_segs = Segments(3)
    yminorgrid_segs = Segments(3)
    zminorgrid_segs = Segments(3)
    xborder_segs = Segments(3)
    yborder_segs = Segments(3)
    zborder_segs = Segments(3)

    if sp[:framestyle] != :none

        # xaxis
        y1, y2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(xaxis[:mirror], yaxis[:flip]) ? (ymax, ymin) : (ymin, ymax)
        end
        z1, z2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(xaxis[:mirror], zaxis[:flip]) ? (zmax, zmin) : (zmin, zmax)
        end
        if xaxis[:showaxis]
            if sp[:framestyle] != :grid
                push!(xaxis_segs, (xmin, y1, z1), (xmax, y1, z1))
                # don't show the 0 tick label for the origin framestyle
                if sp[:framestyle] == :origin && !(xticks in (:none, nothing, false)) && length(xticks) > 1
                    showticks = xticks[1] .!= 0
                    xticks = (xticks[1][showticks], xticks[2][showticks])
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(xborder_segs, (xmin, y2, z2), (xmax, y2, z2)) # top spine
        end
        if !(xaxis[:ticks] in (:none, nothing, false))
            f = RecipesPipeline.scale_func(yaxis[:scale])
            invf = RecipesPipeline.inverse_scale_func(yaxis[:scale])
            tick_start, tick_stop = if sp[:framestyle] == :origin
                t = invf(f(0) + 0.012 * (f(ymax) - f(ymin)))
                (-t, t)
            else
                ticks_in = xaxis[:tick_direction] == :out ? -1 : 1
                t = invf(f(y1) + 0.012 * (f(y2) - f(y1)) * ticks_in)
                (y1, t)
            end

            for xtick in xticks[1]
                if xaxis[:showaxis]
                    push!(xtick_segs, (xtick, tick_start, z1), (xtick, tick_stop, z1)) # bottom tick
                end
                if xaxis[:grid]
                    if sp[:framestyle] in (:origin, :zerolines)
                        push!(xgrid_segs, (xtick, ymin, 0.0), (xtick, ymax, 0.0))
                        push!(xgrid_segs, (xtick, 0.0, zmin), (xtick, 0.0, zmax))
                    else
                        push!(xgrid_segs, (xtick, y1, z1), (xtick, y2, z1))
                        push!(xgrid_segs, (xtick, y2, z1), (xtick, y2, z2))
                    end
                end
            end

            if !(xaxis[:minorticks] in (:none, nothing, false)) || xaxis[:minorgrid]
                tick_start, tick_stop = if sp[:framestyle] == :origin
                    t = invf(f(0) + 0.006 * (f(ymax) - f(ymin)))
                    (-t, t)
                else
                    t = invf(f(y1) + 0.006 * (f(y2) - f(y1)) * ticks_in)
                    (y1, t)
                end
                for xtick in xminorticks
                    if xaxis[:showaxis]
                        push!(xtick_segs, (xtick, tick_start, z1), (xtick, tick_stop, z1)) # bottom tick
                    end
                    if xaxis[:minorgrid]
                        if sp[:framestyle] in (:origin, :zerolines)
                            push!(xminorgrid_segs, (xtick, ymin, 0.0), (xtick, ymax, 0.0))
                            push!(xminorgrid_segs, (xtick, 0.0, zmin), (xtick, 0.0, zmax))
                        else
                            push!(xminorgrid_segs, (xtick, y1, z1), (xtick, y2, z1))
                            push!(xminorgrid_segs, (xtick, y2, z1), (xtick, y2, z2))
                        end
                    end
                end
            end
        end


        # yaxis
        x1, x2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(yaxis[:mirror], xaxis[:flip]) ? (xmin, xmax) : (xmax, xmin)
        end
        z1, z2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(yaxis[:mirror], zaxis[:flip]) ? (zmax, zmin) : (zmin, zmax)
        end
        if yaxis[:showaxis]
            if sp[:framestyle] != :grid
                push!(yaxis_segs, (x1, ymin, z1), (x1, ymax, z1))
                # don't show the 0 tick label for the origin framestyle
                if sp[:framestyle] == :origin && !(yticks in (:none, nothing,false)) && length(yticks) > 1
                    showticks = yticks[1] .!= 0
                    yticks = (yticks[1][showticks], yticks[2][showticks])
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(yborder_segs, (x2, ymin, z2), (x2, ymax, z2)) # right spine
        end
        if !(yaxis[:ticks] in (:none, nothing, false))
            f = RecipesPipeline.scale_func(xaxis[:scale])
            invf = RecipesPipeline.inverse_scale_func(xaxis[:scale])
            tick_start, tick_stop = if sp[:framestyle] == :origin
                t = invf(f(0) + 0.012 * (f(xmax) - f(xmin)))
                (-t, t)
            else
                ticks_in = yaxis[:tick_direction] == :out ? -1 : 1
                t = invf(f(x1) + 0.012 * (f(x2) - f(x1)) * ticks_in)
                (x1, t)
            end

            for ytick in yticks[1]
                if yaxis[:showaxis]
                    push!(ytick_segs, (tick_start, ytick, z1), (tick_stop, ytick, z1)) # left tick
                end
                if yaxis[:grid]
                    if sp[:framestyle] in (:origin, :zerolines)
                        push!(ygrid_segs, (xmin, ytick, 0.0), (xmax, ytick, 0.0))
                        push!(ygrid_segs, (0.0, ytick, zmin), (0.0, ytick, zmax))
                    else
                        push!(ygrid_segs, (x1, ytick, z1), (x2, ytick, z1))
                        push!(ygrid_segs, (x2, ytick, z1), (x2, ytick, z2))
                    end
                end
            end

            if !(yaxis[:minorticks] in (:none, nothing, false)) || yaxis[:minorgrid]
                tick_start, tick_stop = if sp[:framestyle] == :origin
                    t = invf(f(0) + 0.006 * (f(xmax) - f(xmin)))
                    (-t, t)
                else
                    t = invf(f(x1) + 0.006 * (f(x2) - f(x1)) * ticks_in)
                    (x1, t)
                end
                for ytick in yminorticks
                    if yaxis[:showaxis]
                        push!(ytick_segs, (tick_start, ytick, z1), (tick_stop, ytick, z1)) # left tick
                    end
                    if yaxis[:minorgrid]
                        if sp[:framestyle] in (:origin, :zerolines)
                            push!(yminorgrid_segs, (xmin, ytick, 0.0), (xmax, ytick, 0.0))
                            push!(yminorgrid_segs, (0.0, ytick, zmin), (0.0, ytick, zmax))
                        else
                            push!(yminorgrid_segs, (x1, ytick, z1), (x2, ytick, z1))
                            push!(yminorgrid_segs, (x2, ytick, z1), (x2, ytick, z2))
                        end
                    end
                end
            end
        end


        # zaxis
        x1, x2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(zaxis[:mirror], xaxis[:flip]) ? (xmax, xmin) : (xmin, xmax)
        end
        y1, y2 = if sp[:framestyle] in (:origin, :zerolines)
            0.0, 0.0
        else
            xor(zaxis[:mirror], yaxis[:flip]) ? (ymax, ymin) : (ymin, ymax)
        end
        if zaxis[:showaxis]
            if sp[:framestyle] != :grid
                push!(zaxis_segs, (x1, y1, zmin), (x1, y1, zmax))
                # don't show the 0 tick label for the origin framestyle
                if sp[:framestyle] == :origin && !(zticks in (:none, nothing,false)) && length(zticks) > 1
                    showticks = zticks[1] .!= 0
                    zticks = (zticks[1][showticks], zticks[2][showticks])
                end
            end
            sp[:framestyle] in (:semi, :box) && push!(zborder_segs, (x2, y2, zmin), (x2, y2, zmax))
        end
        if !(zaxis[:ticks] in (:none, nothing, false))
            f = RecipesPipeline.scale_func(xaxis[:scale])
            invf = RecipesPipeline.inverse_scale_func(xaxis[:scale])
            tick_start, tick_stop = if sp[:framestyle] == :origin
                t = invf(f(0) + 0.012 * (f(ymax) - f(ymin)))
                (-t, t)
            else
                ticks_in = zaxis[:tick_direction] == :out ? -1 : 1
                t = invf(f(y1) + 0.012 * (f(y2) - f(y1)) * ticks_in)
                (y1, t)
            end

            for ztick in zticks[1]
                if zaxis[:showaxis]
                    push!(ztick_segs, (x1, tick_start, ztick), (x1, tick_stop, ztick)) # left tick
                end
                if zaxis[:grid]
                    if sp[:framestyle] in (:origin, :zerolines)
                        push!(zgrid_segs, (xmin, 0.0, ztick), (xmax, 0.0, ztick))
                        push!(ygrid_segs, (0.0, ymin, ztick), (0.0, ymax, ztick))
                    else
                        push!(ygrid_segs, (x1, y1, ztick), (x1, y2, ztick))
                        push!(ygrid_segs, (x1, y2, ztick), (x2, y2, ztick))
                    end
                end
            end

            if !(zaxis[:minorticks] in (:none, nothing, false)) || zaxis[:minorgrid]
                tick_start, tick_stop = if sp[:framestyle] == :origin
                    t = invf(f(0) + 0.006 * (f(ymax) - f(ymin)))
                    (-t, t)
                else
                    t = invf(f(y1) + 0.006 * (f(y2) - f(y1)) * ticks_in)
                    (y1, t)
                end
                for ztick in zminorticks
                    if zaxis[:showaxis]
                        push!(ztick_segs, (x1, tick_start, ztick), (x1, tick_stop, ztick)) # left tick
                    end
                    if zaxis[:minorgrid]
                        if sp[:framestyle] in (:origin, :zerolines)
                            push!(zminorgrid_segs, (xmin, 0.0, ztick), (xmax, 0.0, ztick))
                            push!(zminorgrid_segs, (0.0, ymin, ztick), (0.0, ymax, ztick))
                        else
                            push!(zminorgrid_segs, (x1, y1, ztick), (x1, y2, ztick))
                            push!(zminorgrid_segs, (x1, y2, ztick), (x2, y2, ztick))
                        end
                    end
                end
            end
        end
    end

    xticks, yticks, zticks, xaxis_segs, yaxis_segs, zaxis_segs, xtick_segs, ytick_segs, ztick_segs, xgrid_segs, ygrid_segs, zgrid_segs, xminorgrid_segs, yminorgrid_segs, zminorgrid_segs, xborder_segs, yborder_segs, zborder_segs
end
