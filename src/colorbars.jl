process_clims(lims::Tuple{<:Number,<:Number}) =
    (zlims -> ifelse.(isfinite.(lims), lims, zlims)) ∘ finite_extrema
process_clims(::Union{Symbol,Nothing,Missing}) = finite_extrema
# don't specialize on ::Function otherwise python functions won't work
process_clims(f) = f

get_clims(sp::Subplot) = sp.color_extrema
get_clims(series::Series) = series.color_extrema
get_clims(sp::Subplot, series::Series) =
    series[:colorbar_entry] ? get_clims(sp) : get_clims(series)

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
        clims = clims.emin, clims.emax
        scale = sp[:colorbar_scale]
        sp.attr[:colorbar_optimized_ticks] =
            get_ticks(ticks, cvals, dvals, clims, scale, formatter)
    end
    return sp.attr[:colorbar_optimized_ticks]
end

# Dynamic callback from the pipeline if needed
function _update_subplot_colorbar_extrema(sp::Subplot, series::Series, op = process_clims(sp[:clims]))
    ex = sp.color_extrema
    old_emin = ex.emin
    old_emax = ex.emax
    seriesex = expand_colorbar_extrema!(series, op)
    if series[:colorbar_entry]::Bool
        expand_colorbar_extrema!(sp, (seriesex.emin, seriesex.emax))
    end
    if ex.emin != old_emin || ex.emax != old_emax
        # expanded, need to update other series
        for s in series_list(sp)
            s.color_extrema = ex
        end
    end
    nothing
end

function expand_colorbar_extrema!(series::Series, op)
    if haskey(_z_colored_series, series[:seriestype]) && series[:z] !== nothing
        expand_colorbar_extrema!(series, series[:z], op)
    end
    expand_colorbar_extrema!(series, series[:line_z], op)
    expand_colorbar_extrema!(series, series[:marker_z], op)
    expand_colorbar_extrema!(series, series[:fill_z], op)
end

function expand_colorbar_extrema!(series::Series, v::AbstractArray{<:Number}, op)
    vex = if length(v) > 1024
        vex = op(@view v[1:1000])
        stride = length(v) ÷ 1024 + 1
        vex2 = op(@view v[1001:stride:end])
        finitemin(vex[1], vex2[1]), finitemax(vex[2], vex2[2])
    else
        op(v)
    end
    expand_colorbar_extrema!(series, vex)
end

expand_colorbar_extrema!(series::Series, ::Nothing, ::Any) = series.color_extrema

function expand_colorbar_extrema!(series::Series, v::Tuple{<:Number, <:Number})
    ex = series.color_extrema
    ex.emin = finitemin(v[1], ex.emin)
    ex.emax = finitemax(v[2], ex.emax)
    ex
end

function expand_colorbar_extrema!(sp::Subplot, v::Tuple{<:Number, <:Number})
    ex = sp.color_extrema
    ex.emin = finitemin(v[1], ex.emin)
    ex.emax = finitemax(v[2], ex.emax)
    ex
end

expand_colorbar_extrema!(series::Series, v::Number, ::Any) = expand_extrema!(series.color_extrema, v)

expand_colorbar_extrema!(series::Series, surf::Surface, op) =
    expand_colorbar_extrema!(series, surf.surf, op)

