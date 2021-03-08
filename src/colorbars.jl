# These functions return an operator for use in `get_clims(::Seres, op)`
process_clims(lims::Tuple{<:Number,<:Number}) = (zlims -> ifelse.(isfinite.(lims), lims, zlims)) ∘ ignorenan_extrema
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
    z_colored_series = (:contour, :contour3d, :heatmap, :histogram2d, :surface, :hexbin)
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

function optimal_colorbar_ticks_and_labels(sp::Subplot, ticks = nothing)
    amin, amax = get_clims(sp)

    # scale the limits
    scale = sp[:colorbar_scale]
    sf = RecipesPipeline.scale_func(scale)

    # Taken from optimal_ticks_and_labels, but needs a different method as there can only be 1 colorbar per subplot
    #
    # If the axis input was a Date or DateTime use a special logic to find
    # "round" Date(Time)s as ticks
    # This bypasses the rest of optimal_ticks_and_labels, because
    # optimize_datetime_ticks returns ticks AND labels: the label format (Date
    # or DateTime) is chosen based on the time span between amin and amax
    # rather than on the input format
    # TODO: maybe: non-trivial scale (:ln, :log2, :log10) for date/datetime
    if ticks === nothing && scale == :identity
        if sp[:colorbar_formatter] == RecipesPipeline.dateformatter
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
        elseif sp[:colorbar_formatter] == RecipesPipeline.datetimeformatter
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
        sp[:clims] = map(RecipesPipeline.inverse_scale_func(scale), (viewmin, viewmax))
    else
        scaled_ticks = map(sf, (filter(t -> amin <= t <= amax, ticks)))
    end
    unscaled_ticks = map(RecipesPipeline.inverse_scale_func(scale), scaled_ticks)

    labels = if any(isfinite, unscaled_ticks)
        formatter = ap[:colorbar_formatter]
        if formatter in (:auto, :plain, :scientific, :engineering)
            map(labelfunc(scale, backend()), Showoff.showoff(scaled_ticks, formatter))
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
function get_colorbar_ticks(sp::Subplot; update = true)
    if update || !haskey(sp.attr, :colorbar_optimized_ticks)
        ticks = _transform_ticks(sp[:colorbar_ticks])
        if ticks in (:none, nothing, false)
            sp.attr[:colorbar_optimized_ticks] = nothing
        else
            # treat :native ticks as :auto
            ticks = ticks == :native ? :auto : ticks

            dvals = sp[:colorbar_discrete_values]
            cv, dv = if typeof(ticks) <: Symbol
                if !isempty(dvals)
                    # discrete ticks...
                    n = length(dvals)
                    rng = if ticks == :auto && n > 15
                        Δ = ceil(Int, n / 10)
                        Δ:Δ:n
                    else # if ticks == :all
                        1:n
                    end
                    sp[:colorbar_continuous_values][rng], dvals[rng]
                else
                    # compute optimal ticks and labels
                    optimal_colorbar_ticks_and_labels(sp)
                end
            elseif typeof(ticks) <: Union{AVec, Int}
                if !isempty(dvals) && typeof(ticks) <: Int
                    rng = Int[round(Int,i) for i in range(1, stop=length(dvals), length=ticks)]
                    sp[:colorbar_continuous_values][rng], dvals[rng]
                else
                    # override ticks, but get the labels
                    optimal_colorbar_ticks_and_labels(sp, ticks)
                end
            elseif typeof(ticks) <: NTuple{2, Any}
                # assuming we're passed (ticks, labels)
                ticks
            else
                error("Unknown ticks type in get_ticks: $(typeof(ticks))")
            end
            sp.attr[:colorbar_optimized_ticks] = (cv, dv)
        end
    end
    sp.attr[:colorbar_optimized_ticks]
end

_transform_ticks(ticks) = ticks
_transform_ticks(ticks::AbstractArray{T}) where T <: Dates.TimeType = Dates.value.(ticks)
_transform_ticks(ticks::NTuple{2, Any}) = (_transform_ticks(ticks[1]), ticks[2])

function _update_subplot_colorbars(sp::Subplot)

end
