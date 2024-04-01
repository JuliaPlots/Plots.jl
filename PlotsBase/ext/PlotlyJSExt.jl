module PlotlyJSExt


import PlotsBase: PlotsBase, Plot, isijulia
using PlotsBase.PlotsPlots
using PlotsBase.Commons
using PlotsBase.Plotly

import PlotlyJS: PlotlyJS, WebIO

# unrolling the old # init_backend macro by hand case by case
# this is not a macro for the backend maintainers and explicit control
const package_str = "PlotlyJS"
const str = lowercase(package_str)
const sym = Symbol(str)

struct PlotlyJSBackend <: PlotsBase.AbstractBackend end
const T = PlotlyJSBackend

get_concrete_backend() = T  # opposite to abstract

function __init__()
    @debug "Initializing $package_str backend in PlotsBase; run `$str()` to activate it."
    PlotsBase._backendType[sym] = get_concrete_backend()
    PlotsBase._backendSymbol[T] = sym

    push!(PlotsBase._initialized_backends, sym)
end

PlotsBase.backend_name(::T) = sym
PlotsBase.backend_package_name(::T) = PlotsBase.backend_package_name(sym)

const _plotlyjs_attrs = PlotsBase.Plotly._plotly_attrs
const _plotlyjs_seriestypes = PlotsBase.Plotly._plotly_seriestypes
const _plotlyjs_styles = PlotsBase.Plotly._plotly_styles
const _plotlyjs_markers = PlotsBase.Plotly._plotly_markers
const _plotlyjs_scales = PlotsBase.Plotly._plotly_scales

# -----------------------------------------------------------------------------
# Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods
# defined in abstract_backend.jl

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    v = Symbol("_$(str)_", s, "s")
    quote
        PlotsBase.$f1(::T, $s::Symbol) = $s in $v
        PlotsBase.$f2(::T) = sort(collect($v))
    end |> eval
end

## results in:
# PlotsBase.is_attr_supported(::GRbackend, attrname) -> Bool
# ...
# PlotsBase.supported_attrs(::GRbackend) -> ::Vector{Symbol}
# ...
# PlotsBase.supported_scales(::GRbackend) -> ::Vector{Symbol}
# -----------------------------------------------------------------------------
# https://github.com/JuliaPlots/PlotlyJS.jl

# ------------------------------------------------------------------------------

function plotlyjs_syncplot(plt::Plot{PlotlyJSBackend})
    plt[:overwrite_figure] && PlotsBase.closeall()
    plt.o = PlotlyJS.plot()
    traces = PlotlyJS.GenericTrace[]
    for series_dict in plotly_series(plt)
        plotly_type = pop!(series_dict, :type)
        series_dict[:transpose] = false
        push!(traces, PlotlyJS.GenericTrace(plotly_type; series_dict...))
    end
    PlotlyJS.addtraces!(plt.o, traces...)
    layout = plotly_layout(plt)
    w, h = plt[:size]
    PlotlyJS.relayout!(plt.o, layout, width = w, height = h)
    plt.o
end

# ------------------------------------------------------------------------------

for (mime, fmt) in (
    "application/pdf" => "pdf",
    "image/png"       => "png",
    "image/svg+xml"   => "svg",
    "image/eps"       => "eps",
)
    @eval PlotsBase._show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyJSBackend}) =
        PlotlyJS.savefig(io, plotlyjs_syncplot(plt), format = $fmt)
end

# Use the Plotly implementation for json and html:
PlotsBase._show(io::IO, mime::MIME"application/vnd.plotly.v1+json", plt::Plot{PlotlyJSBackend}) =
    plotly_show_js(io, plt)

PlotsBase.html_head(plt::Plot{PlotlyJSBackend}) = PlotsBase.Plotly.plotly_html_head(plt)
PlotsBase.html_body(plt::Plot{PlotlyJSBackend}) = PlotsBase.Plotly.plotly_html_body(plt)

PlotsBase._show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend}) =
    write(io, PlotsBase.embeddable_html(plt))

PlotsBase._display(plt::Plot{PlotlyJSBackend}) = display(plotlyjs_syncplot(plt))

WebIO.render(plt::Plot{PlotlyJSBackend}) =
    WebIO.render(plotlyjs_syncplot(plt))

PlotsBase.closeall(::PlotlyJSBackend) =
    if !PlotsBase.isplotnull() && isa(PlotsBase.current().o, PlotlyJS.SyncPlot)
        close(PlotsBase.current().o)
    end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot{PlotlyJSBackend}) = true

end # module
