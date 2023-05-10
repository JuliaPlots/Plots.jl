# These functions return an operator for use in `get_clims(::Seres, op)`
process_clims(lims::Tuple{<:Number,<:Number}) =
    (zlims -> ifelse.(isfinite.(lims), lims, zlims)) ∘ ignorenan_extrema
process_clims(s::Union{Symbol,Nothing,Missing}) = ignorenan_extrema
# don't specialize on ::Function otherwise python functions won't work
process_clims(f) = f

get_clims(sp::Subplot)::Tuple{Float64,Float64} =
    haskey(sp.attr, :clims_calculated) ? sp[:clims_calculated] : update_clims(sp)
get_clims(series::Series)::Tuple{Float64,Float64} =
    haskey(series.plotattributes, :clims_calculated) ?
    series[:clims_calculated]::Tuple{Float64,Float64} : update_clims(series)
get_clims(sp::Subplot, series::Series)::Tuple{Float64,Float64} =
    series[:colorbar_entry] ? get_clims(sp) : get_clims(series)

function update_clims(sp::Subplot, op = process_clims(sp[:clims]))::Tuple{Float64,Float64}
    zmin, zmax = Inf, -Inf
    for series in series_list(sp)
        if series[:colorbar_entry]::Bool
            # Avoid calling the inner `update_clims` if at all possible; dynamic dispatch hell
            if (series[:seriestype] ∈ _z_colored_series && series[:z] !== nothing) ||
               series[:line_z] !== nothing ||
               series[:marker_z] !== nothing ||
               series[:fill_z] !== nothing
                zmin, zmax = _update_clims(zmin, zmax, update_clims(series, op)...)
            else
                zmin, zmax = _update_clims(zmin, zmax, NaN, NaN)
            end
        else
            update_clims(series, op)
        end
    end
    return sp[:clims_calculated] = zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

function update_clims(
    sp::Subplot,
    series::Series,
    op = process_clims(sp[:clims]),
)::Tuple{Float64,Float64}
    zmin, zmax = get_clims(sp)
    old_zmin, old_zmax = zmin, zmax
    if series[:colorbar_entry]::Bool
        zmin, zmax = _update_clims(zmin, zmax, update_clims(series, op)...)
    else
        update_clims(series, op)
    end
    isnan(zmin) && isnan(old_zmin) && isnan(zmax) && isnan(old_zmax) ||
        zmin == old_zmin && zmax == old_zmax ||
        update_clims(sp)
    return zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

"""
    update_clims(::Series, op=Plots.ignorenan_extrema)
Finds the limits for the colorbar by taking the "z-values" for the series and passing them into `op`,
which must return the tuple `(zmin, zmax)`. The default op is the extrema of the finite
values of the input. The value is stored as a series property, which is retrieved by `get_clims`.
"""
function update_clims(series::Series, op = ignorenan_extrema)::Tuple{Float64,Float64}
    zmin, zmax = Inf, -Inf

    # keeping this unrolled has higher performance
    if series[:seriestype] ∈ _z_colored_series && series[:z] !== nothing
        zmin, zmax = update_clims(zmin, zmax, series[:z], op)
    end
    if series[:line_z] !== nothing
        zmin, zmax = update_clims(zmin, zmax, series[:line_z], op)
    end
    if series[:marker_z] !== nothing
        zmin, zmax = update_clims(zmin, zmax, series[:marker_z], op)
    end
    if series[:fill_z] !== nothing
        zmin, zmax = update_clims(zmin, zmax, series[:fill_z], op)
    end
    return series[:clims_calculated] = zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

update_clims(zmin, zmax, vals::AbstractSurface, op)::Tuple{Float64,Float64} =
    update_clims(zmin, zmax, vals.surf, op)
update_clims(zmin, zmax, vals::Any, op)::Tuple{Float64,Float64} =
    _update_clims(zmin, zmax, op(vals)...)
update_clims(zmin, zmax, ::Nothing, ::Any)::Tuple{Float64,Float64} = zmin, zmax

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
    elseif series[:seriestype] ∈ (:heatmap, :surface) ||
           any(series[z] !== nothing for z in (:marker_z, :line_z, :fill_z))
        cbar_gradient
    else
        nothing
    end
end

hascolorbar(series::Series) = colorbar_style(series) !== nothing
hascolorbar(sp::Subplot) =
    sp[:colorbar] !== :none && any(hascolorbar(s) for s in series_list(sp))

function get_colorbar_ticks(sp::Subplot; update = true, formatter = sp[:colorbar_formatter])
    if update || !haskey(sp.attr, :colorbar_optimized_ticks)
        ticks = _transform_ticks(sp[:colorbar_ticks], sp[:colorbar_title])
        cvals = sp[:colorbar_continuous_values]
        dvals = sp[:colorbar_discrete_values]
        clims = get_clims(sp)
        scale = sp[:colorbar_scale]
        sp.attr[:colorbar_optimized_ticks] =
            get_ticks(ticks, cvals, dvals, clims, scale, formatter)
    end
    return sp.attr[:colorbar_optimized_ticks]
end

# Dynamic callback from the pipeline if needed
_update_subplot_colorbars(sp::Subplot) = update_clims(sp)
_update_subplot_colorbars(sp::Subplot, series::Series) = update_clims(sp, series)
