import Plots: backend_name, backend_package_name, is_marker_supported

# unrolling the old # init_backend macro by hand case by case
const package_str = "PythonPlot"
const str = "pythonplot"
const sym = :pythonplot

struct PythonPlotBackend <: Plots.AbstractBackend end
const T = PythonPlotBackend

get_concrete_backend() = T

function __init__()
    @info "Initializing $package_str backend in Plots; run `$str()` to activate it."
    Plots._backendType[sym] = get_concrete_backend()
    Plots._backendSymbol[T] = sym
    Plots._backend_packages[sym] = Symbol(package_str)

    push!(Plots._initialized_backends, sym)


  if PythonPlot.version < v"3.4"
    @warn """You are using Matplotlib $(PythonPlot.version), which is no longer
    officially supported by the Plots community. To ensure smooth Plots.jl
    integration update your Matplotlib library to a version ≥ 3.4.0
    """
  end

    # PythonCall.pycopy!(mpl, PythonCall.pyimport("matplotlib"))
    PythonCall.pycopy!(mpl_toolkits, PythonCall.pyimport("mpl_toolkits"))
    PythonCall.pycopy!(numpy, PythonCall.pyimport("numpy"))
    # PythonCall.pyimport("mpl_toolkits.axes_grid1")
    numpy.seterr(invalid = "ignore")
    PythonPlot.ioff() # we don't want every command to update the figure

end
# Make pythonplot known to Plots
backend_name(::T) = sym
backend_package_name(::T) = backend_package_name(sym)

const _pythonplot_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :foreground_color_grid,
    :legend_foreground_color,
    :foreground_color_title,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_guide,
    :foreground_color_text,
    :label,
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
    :bar_width,
    :bar_edges,
    :bar_position,
    :title,
    :titlelocation,
    :titlefont,
    :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :titlefontfamily,
    :titlefontsize,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_entry,
    :colorbar_ticks,
    :colorbar_tickfontfamily,
    :colorbar_tickfontsize,
    :colorbar_tickfonthalign,
    :colorbar_tickfontvalign,
    :colorbar_tickfontrotation,
    :colorbar_tickfontcolor,
    :colorbar_titlefontcolor,
    :colorbar_titlefontsize,
    :colorbar_scale,
    :marker_z,
    :line,
    :line_z,
    :fill,
    :fill_z,
    :fontfamily,
    :fontfamily_subplot,
    :legend_column,
    :legend_font,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_pointsize,
    :levels,
    :ribbon,
    :quiver,
    :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize,
    :weights,
    :contours,
    :aspect_ratio,
    :clims,
    :inset_subplots,
    :dpi,
    :stride,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
    :connections,
])

const _pythonplot_seriestype = [
    :path,
    :steppre,
    :stepmid,
    :steppost,
    :shape,
    :straightline,
    :scatter,
    :hexbin,
    :heatmap,
    :image,
    :contour,
    :contour3d,
    :path3d,
    :scatter3d,
    :mesh3d,
    :surface,
    :wireframe,
]

const _pythonplot_style = [:auto, :solid, :dash, :dot, :dashdot]
const _pythonplot_marker = vcat(_allMarkers, :pixel)
const _pythonplot_scale = [:identity, :ln, :log2, :log10]


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
