# unrolling the old # init_backend macro by hand case by case

const package_str = "UnicodePlots"
const str = "unicodeplots"
const sym = :unicodeplots

struct UnicodePlotsBackend <: Plots.AbstractBackend end
const T = UnicodePlotsBackend

get_concrete_backend() = UnicodePlotsBackend  # opposite to abstract

function __init__()
    @info "Initializing $package_str backend in Plots; run `$str()` to activate it."
    Plots._backendType[sym] = get_concrete_backend()
    Plots._backendSymbol[T] = sym
    Plots._backend_packages[sym] = Symbol(package_str)

    push!(Plots._initialized_backends, sym)
end
# Make unicodeplots know to Plots
Plots.backend_name(::UnicodePlotsBackend) = sym
Plots.backend_package_name(::UnicodePlotsBackend) = Plots.backend_package_name(sym)

const _unicodeplots_attr = Plots.merge_with_base_supported([
    :annotations,
    :bins,
    :guide,
    :widen,
    :grid,
    :label,
    :layout,
    :legend,
    :legend_title_font_color,
    :lims,
    :line,
    :linealpha,
    :linecolor,
    :linestyle,
    :markershape,
    :plot_title,
    :quiver,
    :arrow,
    :seriesalpha,
    :seriescolor,
    :scale,
    :flip,
    :title,
    # :marker_z,
    :line_z,
])
const _unicodeplots_seriestype = [
    :path,
    :path3d,
    :scatter,
    :scatter3d,
    :straightline,
    # :bar,
    :shape,
    :histogram2d,
    :heatmap,
    :contour,
    # :contour3d,
    :image,
    :spy,
    :surface,
    :wireframe,
    :mesh3d,
]
const _unicodeplots_style = [:auto, :solid]
const _unicodeplots_marker = [
    :none,
    :auto,
    :pixel,
    # vvvvvvvvvv shapes
    :circle,
    :rect,
    :star5,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :rtriangle,
    :ltriangle,
    :pentagon,
    # :heptagon,
    # :octagon,
    :star4,
    :star6,
    # :star7,
    :star8,
    :vline,
    :hline,
    :+,
    :x,
]
const _unicodeplots_scale = [:identity, :ln, :log2, :log10]
# -----------------------------------------------------------------------------
# Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods
# defined in abstract_backend.jl

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    v = Symbol("_$(str)_", s)
    eval(quote
        Plots.$f1(::UnicodePlotsBackend, $s::Symbol) = $s in $v
        Plots.$f2(::UnicodePlotsBackend) = sort(collect($v))
    end)
end

## results in:
# Plots.is_attr_supported(::GRbackend, attrname) -> Bool
# ...
# Plots.supported_attrs(::GRbackend) -> ::Vector{Symbol}
# ...
# Plots.supported_scales(::GRbackend) -> ::Vector{Symbol}
# -----------------------------------------------------------------------------
