const _label_func =
    Dict{Symbol,Function}(:log10 => x -> "10^$x", :log2 => x -> "2^$x", :ln => x -> "e^$x")
labelfunc(scale::Symbol, ::AbstractBackend) = get(_label_func, scale, string)

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
            k_min = scale ∈ _log_scales ? 2 : 4, # minimum number of ticks
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

Ticks.get_ticks(ticks::Symbol, cvals::T, dvals, args...) where {T} =
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

Ticks.get_ticks(ticks::AVec, cvals, dvals, args...) =
    optimal_ticks_and_labels(ticks, args...)
Ticks.get_ticks(ticks::Int, dvals, cvals, args...) =
    if isempty(dvals)
        optimal_ticks_and_labels(ticks, args...)
    else
        rng = round.(Int, range(1, stop = length(dvals), length = ticks))
        cvals[rng], string.(dvals[rng])
    end

get_labels(formatter::Symbol, scaled_ticks, scale) =
    if formatter in (:auto, :plain, :scientific, :engineering)
        map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, formatter))
    elseif formatter === :latex
        map(
            l -> string("\$", replace(convert_sci_unicode(l), '×' => "\\times"), "\$"),
            get_labels(:auto, scaled_ticks, scale),
        )
    elseif formatter === :none
        String[]
    end

function get_labels(formatter::Function, scaled_ticks, scale)
    sf, invsf, _ = scale_inverse_scale_func(scale)
    fticks = map(formatter ∘ invsf, scaled_ticks)
    # extrema can extend outside the region where Categorical tick values are defined
    #   CategoricalArrays's recipe gives "missing" label to those
    filter!(!ismissing, fticks)
    eltype(fticks) <: Number && return get_labels(:auto, map(sf, fticks), scale)
    fticks
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

# -------------------------------------------------------------------------

# using the axis extrema and limit overrides, return the min/max value for this axis

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
