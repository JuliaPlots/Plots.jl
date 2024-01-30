function plotly_traces(plt::Plot)
    traces = PlotlyBase.GenericTrace[]
    for series_dict in plotly_series(plt)
        plotly_type = pop!(series_dict, :type)
        push!(traces, PlotlyBase.GenericTrace(plotly_type; series_dict...))
    end
    return traces
end

function plotlybase_syncplot(plt::Plot)
    plt.o = PlotlyBase.Plot()
    PlotlyBase.addtraces!(plt.o, plotly_traces(plt)...)
    layout = plotly_layout(plt)
    w, h = plt[:size]
    PlotlyBase.relayout!(plt.o, layout, width = w, height = h)
    return plt.o
end

for (mime, fmt) in (
    "application/pdf" => "pdf",
    "image/png" => "png",
    "image/svg+xml" => "svg",
    "image/eps" => "eps",
)
    @eval _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyBackend}) =
        PlotlyKaleido.savefig(io, plotlybase_syncplot(plt), format = $fmt)
end
