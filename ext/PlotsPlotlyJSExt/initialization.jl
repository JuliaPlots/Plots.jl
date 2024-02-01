# unrolling the old # init_backend macro by hand case by case
# this is not a macro for the backend maintainers and explicit control

const package_str = "PlotlyJS"
const str = lowercase(package_str)
const sym = Symbol(str)

struct PlotlyJSBackend <: Plots.AbstractBackend end
const T = PlotlyJSBackend

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

const _plotlyjs_attrs = Plots._plotly_attrs
const _plotlyjs_seriestypes = Plots._plotly_seriestypes
const _plotlyjs_styles = Plots._plotly_styles
const _plotlyjs_markers = Plots._plotly_markers
const _plotlyjs_scales = Plots._plotly_scales

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
