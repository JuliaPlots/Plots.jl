# unrolling the old # init_backend macro by hand case by case

const package_str = "GR"
const str = "gr"
const sym = :gr
const T = :GRBackend

struct GRBackend <: Plots.AbstractBackend end

get_concrete_backend() = GRBackend  # opposite to abstract

# Make GR know to Plots
Plots.backend_name(::GRBackend) = sym
Plots.backend_package_name(::GRBackend) = Plots.backend_package_name(sym)
Plots._backendType[sym] = get_concrete_backend()
Plots._backendSymbol[GRBackend] = sym
Plots._backend_packages[sym] = Symbol(package_str)

push!(Plots._backends, sym)
push!(Plots._initialized_backends, sym)

_post_imports(::GRBackend) = nothing

# quote
#     struct $T <: AbstractBackend end
#     export $sym
#     $sym(; kw...) = (default(; reset = false, kw...); backend($T()))
#     backend_name(::$T) = Symbol($str)
#     backend_package_name(::$T) = backend_package_name(Symbol($str))
#     push!(_backends, Symbol($str))
#     _backendType[Symbol($str)] = $T
#     _backendSymbol[$T] = Symbol($str)
#     _backend_packages[Symbol($str)] = Symbol($package_str)
# end |> esc

const _gr_attr = Plots.merge_with_base_supported([
    :annotations,
    :annotationrotation,
    :annotationhalign,
    :annotationfontsize,
    :annotationfontfamily,
    :annotationcolor,
    :annotationvalign,
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
    :fillstyle,
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
    :colorbar_titlefont,
    :colorbar_titlefontsize,
    :colorbar_titlefontrotation,
    :colorbar_titlefontcolor,
    :colorbar_entry,
    :colorbar_scale,
    :clims,
    :fill,
    :fill_z,
    :fontfamily,
    :fontfamily_subplot,
    :line_z,
    :marker_z,
    :legend_column,
    :legend_font,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_rotation,
    :legend_title_font_pointsize,
    :legend_title_font_valigm,
    :levels,
    :line,
    :ribbon,
    :quiver,
    :overwrite_figure,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontfamily,
    :plot_titlefontrotation,
    :plot_titlefontsize,
    :plot_titlelocation,
    :plot_titlevspan,
    :polar,
    :aspect_ratio,
    :normalize,
    :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
    :connections,
    :axis,
    :thickness_scaling,
    :minorgrid,
    :minorgridalpha,
    :minorgridlinewidth,
    :minorgridstyle,
    :minorticks,
    :mirror,
    :rotation,
    :showaxis,
    :tickfonthalign,
    :formatter,
    :mirror,
    :guidefont,
])
const _gr_seriestype = [
    :path,
    :scatter,
    :straightline,
    :heatmap,
    :image,
    :contour,
    :path3d,
    :scatter3d,
    :surface,
    :wireframe,
    :mesh3d,
    :volume,
    :shape,
]
const _gr_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _gr_marker = vcat(Commons._allMarkers, :pixel)
const _gr_scale = [:identity, :ln, :log2, :log10]

# -----------------------------------------------------------------------------
# Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods
# defined in abstract_backend.jl

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    v = Symbol("_gr_", s)
    @eval begin
        $f1(::GRBackend, $s::Symbol) = $s in $v
        $f2(::GRBackend) = sort(collect($v))
    end
end

## results in:
# is_attr_supported(::GRbackend, attrname) -> Bool
# ...
# supported_attrs(::GRbackend) -> ::Vector{Symbol}
# ...
# supported_scales(::GRbackend) -> ::Vector{Symbol}
# -----------------------------------------------------------------------------

is_marker_supported(::GRBackend, shape::Shape) = true

# From, delete this later
# https://github.com/JuliaLang/Pkg.jl/pull/3552/files#diff-1af5f877eb4497fc1f22daf47044d0958aa02ab39cc6da8ef052624870d75d28R393
