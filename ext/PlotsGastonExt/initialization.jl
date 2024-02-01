# unrolling the old # init_backend macro by hand case by case
# this is not a macro for the backend maintainers and explicit control

const package_str = "Gaston"
const str = lowercase(package_str)
const sym = Symbol(str)

struct GastonBackend <: Plots.AbstractBackend end
const T = GastonBackend

get_concrete_backend() = T  # opposite to abstract

function __init__()
    @info "Initializing $package_str backend in Plots; run `$str()` to activate it."
    Plots._backendType[sym] = get_concrete_backend()
    Plots._backendSymbol[T] = sym
    

    push!(Plots._initialized_backends, sym)

    # Additional setup required by the backend:

end

Plots.backend_name(::T) = sym
Plots.backend_package_name(::T) = Plots.backend_package_name(sym)

const _gaston_attrs = Plots.merge_with_base_supported([
    :annotations,
    # :background_color_legend,
    # :background_color_inside,
    # :background_color_outside,
    # :foreground_color_legend,
    # :foreground_color_grid, :foreground_color_axis,
    # :foreground_color_text, :foreground_color_border,
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
    # :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    # :fillrange, :fillcolor, :fillalpha,
    # :bins,
    # :bar_width, :bar_edges,
    :title,
    :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :legend,
    # :colorbar, :colorbar_title,
    # :fill_z, :line_z, :marker_z, :levels,
    # :ribbon,
    :quiver,
    :arrow,
    # :orientation, :overwrite_figure,
    :polar,
    # :normalize, :weights, :contours,
    :aspect_ratio,
    :tick_direction,
    # :framestyle,
    # :camera,
    # :contour_labels,
    :connections,
])

const _gaston_seriestypes = [
    :path,
    :path3d,
    :scatter,
    :steppre,
    :stepmid,
    :steppost,
    :ysticks,
    :xsticks,
    :contour,
    :shape,
    :straightline,
    :scatter3d,
    :contour3d,
    :wireframe,
    :heatmap,
    :surface,
    :mesh3d,
    :image,
]

const _gaston_styles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]

const _gaston_markers = [
    :none,
    :auto,
    :pixel,
    :cross,
    :xcross,
    :+,
    :x,
    :star5,
    :rect,
    :circle,
    :utriangle,
    :dtriangle,
    :diamond,
    :pentagon,
    # :hline,
    # :vline,
]

const _gaston_scales = [:identity, :ln, :log2, :log10]

# -----------------------------------------------------------------------------
# Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods
# defined in abstract_backend.jl

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    v = Symbol("_$(str)_", s, "s")
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
