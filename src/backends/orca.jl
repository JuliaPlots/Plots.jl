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

const _orca_mimeformats = Dict(
    "application/pdf" => "pdf",
    "image/png"       => "png",
    "image/svg+xml"   => "svg",
    "image/eps"       => "eps",
)

for (mime, fmt) in _orca_mimeformats
    @eval _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyBackend}) = ORCA.PlotlyBase.savefig(io, plotlybase_syncplot(plt), format = $fmt)
end
