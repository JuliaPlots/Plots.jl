# https://github.com/JuliaPlots/PlotlyJS.jl

# ------------------------------------------------------------------------------
include(_path(:plotly))

function plotlyjs_syncplot(plt::Plot{PlotlyJSBackend})
    plt[:overwrite_figure] && closeall()
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
    return plt.o
end

# ------------------------------------------------------------------------------

for (mime, fmt) in (
        "application/pdf" => "pdf",
        "image/png" => "png",
        "image/svg+xml" => "svg",
        "image/eps" => "eps",
    )
    @eval _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyJSBackend}) =
        PlotlyJS.savefig(io, plotlyjs_syncplot(plt), format = $fmt)
end

# Use the Plotly implementation for json and html:
_show(io::IO, mime::MIME"application/vnd.plotly.v1+json", plt::Plot{PlotlyJSBackend}) =
    plotly_show_js(io, plt)

html_head(plt::Plot{PlotlyJSBackend}) = plotly_html_head(plt)
html_body(plt::Plot{PlotlyJSBackend}) = plotly_html_body(plt)

_show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend}) =
    write(io, embeddable_html(plt))

_display(plt::Plot{PlotlyJSBackend}) = display(plotlyjs_syncplot(plt))

PlotlyJS.WebIO.render(plt::Plot{PlotlyJSBackend}) =
    PlotlyJS.WebIO.render(plotlyjs_syncplot(plt))

closeall(::PlotlyJSBackend) =
if !isplotnull() && isa(current().o, PlotlyJS.SyncPlot)
    close(current().o)
end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot{PlotlyJSBackend}) = true
