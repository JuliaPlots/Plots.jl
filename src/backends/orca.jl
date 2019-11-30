function plotlybase_syncplot(plt::Plot)
    plt.o = ORCA.PlotlyBase.Plot()
    traces = ORCA.PlotlyBase.GenericTrace[]
    for series_dict in plotly_series(plt)
        plotly_type = pop!(series_dict, :type)
        push!(traces, ORCA.PlotlyBase.GenericTrace(plotly_type; series_dict...))
    end
    ORCA.PlotlyBase.addtraces!(plt.o, traces...)
    layout = plotly_layout(plt)
    w, h = plt[:size]
    ORCA.PlotlyBase.relayout!(plt.o, layout, width = w, height = h)
    return plt.o
end

_show(io::IO, ::MIME{Symbol("image/png")}, plt::Plot{PlotlyBackend}) = ORCA.PlotlyBase.savefig(io, plotlybase_syncplot(plt), format = "png")
