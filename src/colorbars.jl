# These functions return an operator for use in `get_clims(::Seres, op)`
process_clims(lims::Tuple{<:Number,<:Number}) =
    (zlims -> ifelse.(isfinite.(lims), lims, zlims)) ∘ ignorenan_extrema
process_clims(s::Union{Symbol,Nothing,Missing}) = ignorenan_extrema
# don't specialize on ::Function otherwise python functions won't work
process_clims(f) = f

function update_clims(sp::Subplot, op = process_clims(sp[:clims]))::Tuple{Float64, Float64}
    zmin, zmax = Inf, -Inf
    for series in series_list(sp)
        if series[:colorbar_entry]
            zmin, zmax = _update_clims(zmin, zmax, get_clims(series, op)...)
        end
    end

    sp[:clims] = zmin <= zmax ? (zmin, zmax) : (NaN, NaN)
end

get_clims(sp::Subplot, op = nothing)::Tuple{Float64, Float64} = sp[:colorbar_limits]

function get_clims(sp::Subplot, series::Series, op = process_clims(sp[:clims]))::Tuple{Float64, Float64}
    zmin, zmax = if series[:colorbar_entry]
        sp[:clims]
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
function get_clims(series::Series, op = ignorenan_extrema)::Tuple{Float64, Float64}
    zmin, zmax = Inf, -Inf
    z_colored_series = (:contour, :contour3d, :heatmap, :histogram2d, :surface, :hexbin)
    for vals in (
        series[:seriestype] in z_colored_series ? series[:z] : nothing,
        series[:line_z],
        series[:marker_z],
        series[:fill_z],
    )
        if (typeof(vals) <: AbstractSurface) && (eltype(vals.surf) <: Union{Missing,Real})
            zmin, zmax = _update_clims(zmin, zmax, op(vals.surf)...)
        elseif (vals !== nothing) && (eltype(vals) <: Union{Missing,Real})
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
    elseif series[:seriestype] ∈ (:heatmap, :surface) ||
           any(series[z] !== nothing for z in [:marker_z, :line_z, :fill_z])
        cbar_gradient
    else
        nothing
    end
end

hascolorbar(series::Series) = colorbar_style(series) !== nothing
hascolorbar(sp::Subplot) =
    sp[:colorbar] != :none && any(hascolorbar(s) for s in series_list(sp))

function get_colorbar_ticks(sp::Subplot; update = true)
    if update || !haskey(sp.attr, :colorbar_optimized_ticks)
        ticks = _transform_ticks(sp[:colorbar_ticks])
        cvals = sp[:colorbar_continuous_values]
        dvals = sp[:colorbar_discrete_values]
        clims = get_clims(sp)
        scale = sp[:colorbar_scale]
        formatter = sp[:colorbar_formatter]
        sp.attr[:colorbar_optimized_ticks] =
            get_ticks(ticks, cvals, dvals, clims, scale, formatter)
    end
    return sp.attr[:colorbar_optimized_ticks]
end

function _update_subplot_colorbars(sp::Subplot)
    # Dynamic callback from the pipeline if needed
end
