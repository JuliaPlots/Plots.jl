module PlotlyJSExt

import PlotsBase: PlotsBase, PrecompileTools, Plot
using PlotsBase.Commons
using PlotsBase.Plotly
using PlotsBase.Plots

import PlotlyJS: PlotlyJS, WebIO

struct PlotlyJSBackend <: PlotsBase.AbstractBackend end

function PlotsBase.extension_init(::PlotlyJSBackend)
    # workaround for github.com/JuliaGizmos/Blink.jl/issues/325
    # taken from github.com/Eben60/PackageMaker.jl/commit/297219f5c14845bf75de4475cabab4dbf6e6599d 
    @eval PlotlyJS.Blink.AtomShell function init(; debug = false)
        electron() # Check path exists
        p, dp = port(), port()
        debug && inspector(dp)
        dbg = debug ? "--debug=$dp" : []
        # vvvvvvvvvvvv begin addition
        unsafe = Base.get_bool_env("PLOTSBASE_UNSAFE_ELECTRON", false) ? "--no-sandbox" : []
        cmd = `$(electron()) $unsafe $dbg $mainjs port $p`
        # ^^^^^^^^^^^^ end addition
        proc = (debug ? run_rdr : run)(cmd; wait = false)
        conn = try_connect(ip"127.0.0.1", p)
        shell = Electron(proc, conn)
        initcbs(shell)
        return shell
    end
end

PlotsBase.@extension_static PlotlyJSBackend plotlyjs

const _plotlyjs_attrs = PlotsBase.Plotly._plotly_attrs
const _plotlyjs_seriestypes = PlotsBase.Plotly._plotly_seriestypes
const _plotlyjs_styles = PlotsBase.Plotly._plotly_styles
const _plotlyjs_markers = PlotsBase.Plotly._plotly_markers
const _plotlyjs_scales = PlotsBase.Plotly._plotly_scales

function plotlyjs_syncplot(plt::Plot{PlotlyJSBackend})
    plt[:overwrite_figure] && PlotsBase.closeall()
    plt.o = PlotlyJS.plot()
    traces = PlotlyJS.GenericTrace[]
    for series_dict ∈ plotly_series(plt)
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

for (mime, fmt) ∈ (
    "application/pdf" => "pdf",
    "image/png"       => "png",
    "image/svg+xml"   => "svg",
    "image/eps"       => "eps",
)
    @eval PlotsBase._show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyJSBackend}) =
        PlotlyJS.savefig(io, plotlyjs_syncplot(plt), format = $fmt)
end

# Use the Plotly implementation for json and html:
PlotsBase._show(
    io::IO,
    mime::MIME"application/vnd.plotly.v1+json",
    plt::Plot{PlotlyJSBackend},
) = plotly_show_js(io, plt)

PlotsBase.html_head(plt::Plot{PlotlyJSBackend}) = PlotsBase.Plotly.plotly_html_head(plt)
PlotsBase.html_body(plt::Plot{PlotlyJSBackend}) = PlotsBase.Plotly.plotly_html_body(plt)

PlotsBase._show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend}) =
    write(io, PlotsBase.embeddable_html(plt))

PlotsBase._display(plt::Plot{PlotlyJSBackend}) = display(plotlyjs_syncplot(plt))

WebIO.render(plt::Plot{PlotlyJSBackend}) = WebIO.render(plotlyjs_syncplot(plt))

PlotsBase.closeall(::PlotlyJSBackend) =
    if !PlotsBase.isplotnull() && isa(PlotsBase.current().o, PlotlyJS.SyncPlot)
        close(PlotsBase.current().o)
    end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot{PlotlyJSBackend}) = true

function PlotsBase._ijulia__extra_mime_info!(plt::Plot{PlotlyJSBackend}, out::Dict)
    out["application/vnd.plotly.v1+json"] =
        Dict(:data => plotly_series(plt), :layout => plotly_layout(plt))
    out
end

PlotsBase.@precompile_backend PlotlyJS

end  # module
