# unrolling the old # init_backend macro by hand case by case
# this is not a macro for the backend maintainers and explicit control

const package_str = "PGFPlotsX"
const str = "pgfplotsx"
const sym = :pgfplotsx

struct PGFPlotsXBackend <: Plots.AbstractBackend end
const T = PGFPlotsXBackend

get_concrete_backend() = T  # opposite to abstract

function __init__()
    @info "Initializing $package_str backend in Plots; run `$str()` to activate it."
    Plots._backendType[sym] = get_concrete_backend()
    Plots._backendSymbol[T] = sym
    Plots._backend_packages[sym] = Symbol(package_str)

    push!(Plots._backends, sym)
    push!(Plots._initialized_backends, sym)

    # Additional setup required by the backend:

end

Plots.backend_name(::T) = sym
Plots.backend_package_name(::T) = Plots.backend_package_name(sym)


const _pgfplotsx_attr = merge_with_base_supported([
    :annotations,
    :annotationrotation,
    :annotationhalign,
    :annotationfontsize,
    :annotationfontfamily,
    :annotationcolor,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :legend_foreground_color,
    :foreground_color_grid,
    :foreground_color_axis,
    :foreground_color_text,
    :foreground_color_border,
    :label,
    :seriescolor,
    :seriesalpha,
    :line,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :bins,
    :layout,
    :title,
    :window_title,
    :guide,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :titlefontfamily,
    :titlefontsize,
    :titlefonthalign,
    :titlefontvalign,
    :titlefontrotation,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_halign,
    :legend_font_valign,
    :legend_font_rotation,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfonthalign,
    :tickfontvalign,
    :tickfontrotation,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefonthalign,
    :guidefontvalign,
    :guidefontrotation,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_titlefontsize,
    :colorbar_titlefontcolor,
    :colorbar_titlefontrotation,
    :colorbar_entry,
    :fill,
    :fill_z,
    :line_z,
    :marker_z,
    :levels,
    :legend_column,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_pointsize,
    :ribbon,
    :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontrotation,
    :plot_titlefontsize,
    :plot_titlevspan,
    :aspect_ratio,
    :normalize,
    :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :thickness_scaling,
    :camera,
    :contour_labels,
    :connections,
    :thickness_scaling,
    :axis,
    :draw_arrow,
    :minorgrid,
    :minorgridalpha,
    :minorgridlinewidth,
    :minorgridstyle,
    :minorticks,
    :mirror,
    :rotation,
    :showaxis,
    :tickfontrotation,
    :draw_arrow,
])
const _pgfplotsx_seriestype = [
    :path,
    :scatter,
    :straightline,
    :path3d,
    :scatter3d,
    :surface,
    :wireframe,
    :heatmap,
    :mesh3d,
    :contour,
    :contour3d,
    :quiver,
    :shape,
    :steppre,
    :stepmid,
    :steppost,
    :ysticks,
    :xsticks,
]
const _pgfplotsx_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplotsx_marker = [
    :none,
    :auto,
    :circle,
    :rect,
    :diamond,
    :utriangle,
    :dtriangle,
    :ltriangle,
    :rtriangle,
    :cross,
    :xcross,
    :x,
    :+,
    :star5,
    :star6,
    :pentagon,
    :hline,
    :vline,
]
const _pgfplotsx_scale = [:identity, :ln, :log2, :log10]
is_marker_supported(::PGFPlotsXBackend, shape::Shape) = true

# additional constants
const _pgfplotsx_series_ids = KW()

# -----------------------------------------------------------------------------
# Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods
# defined in abstract_backend.jl

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    v = Symbol("_$(str)_", s)
    eval(quote
        Plots.$f1(::T, $s::Symbol) = $s in $v
        Plots.$f2(::T) = sort(collect($v))
    end)
end

## results in:
# Plots.is_attr_supported(::GRbackend, attrname) -> Bool
# ...
# Plots.supported_attrs(::GRbackend) -> ::Vector{Symbol}
# ...
# Plots.supported_scales(::GRbackend) -> ::Vector{Symbol}
# -----------------------------------------------------------------------------
