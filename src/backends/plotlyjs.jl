# https://github.com/sglyon/PlotlyJS.jl

# --------------------------------------------------------------------------------------

function plotlyjs_syncplot(plt::Plot{PlotlyJSBackend})
    plt[:overwrite_figure] && closeall()
    plt.o = PlotlyJS.plot()
    traces = PlotlyJS.GenericTrace[]
    for series_dict in plotly_series(plt)
        plotly_type = pop!(series_dict, :type)
        push!(traces, PlotlyJS.GenericTrace(plotly_type; series_dict...))
    end
    PlotlyJS.addtraces!(plt.o, traces...)
    layout = plotly_layout(plt)
    w, h = plt[:size]
    PlotlyJS.relayout!(plt.o, layout, width = w, height = h)
    return plt.o
end


# function _create_backend_figure(plt::Plot{PlotlyJSBackend})
#     if !isplotnull() && plt[:overwrite_figure] && isa(current().o, PlotlyJS.SyncPlot)
#         PlotlyJS.SyncPlot(PlotlyJS.Plot(), options = current().o.options)
#     else
#         PlotlyJS.plot()
#     end
# end
#
#
# function _series_added(plt::Plot{PlotlyJSBackend}, series::Series)
#     syncplot = plt.o
#     pdicts = plotly_series(plt, series)
#     for pdict in pdicts
#         typ = pop!(pdict, :type)
#         gt = PlotlyJS.GenericTrace(typ; pdict...)
#         PlotlyJS.addtraces!(syncplot, gt)
#     end
# end
#
# function _series_updated(plt::Plot{PlotlyJSBackend}, series::Series)
#     xsym, ysym = (ispolar(series) ? (:t,:r) : (:x,:y))
#     kw = KW(xsym => (series.plotattributes[:x],), ysym => (series.plotattributes[:y],))
#     z = series[:z]
#     if z != nothing
#         kw[:z] = (isa(z,Surface) ? transpose_z(series, series[:z].surf, false) : z,)
#     end
#     PlotlyJS.restyle!(
#         plt.o,
#         findfirst(isequal(series), plt.series_list),
#         kw
#     )
# end
#
#
# # ----------------------------------------------------------------
#
# function _update_plot_object(plt::Plot{PlotlyJSBackend})
#     pdict = plotly_layout(plt)
#     syncplot = plt.o
#     w,h = plt[:size]
#     PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
# end


# ----------------------------------------------------------------

const _plotlyjs_mimeformats = Dict(
    "application/pdf" => "pdf",
    "image/png"       => "png",
    "image/svg+xml"   => "svg",
    "image/eps"       => "eps",
)

for (mime, fmt) in _plotlyjs_mimeformats
    @eval _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PlotlyJSBackend}) = PlotlyJS.savefig(io, plotlyjs_syncplot(plt), format = $fmt)
end

const _plotlyjs_showformats = ["text/html", "application/vnd.plotly.v1+json"]

# for mime in ["text/html", "application/vnd.plotly.v1+json"]
#     @eval _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{PlotlyJSBackend}) = show(io, mime, plotlyjs_syncplot(plt))
# end

# Use the Plotly implementation for json and html:
_show(io::IO, mime::MIME"application/vnd.plotly.v1+json", plt::Plot{PlotlyJSBackend}) = plotly_show_js(io, plot)

html_head(plt::Plot{PlotlyJSBackend}) = plotly_html_head(plt)
html_body(plt::Plot{PlotlyJSBackend}) = plotly_html_body(plt)

_show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend}) = write(io, standalone_html(plt))

# _show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend}) = show(io, ::MIME"text/html", plt.o)
# _show(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyJSBackend}) = PlotlyJS.savefig(io, plt.o, format="svg")
# _show(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend}) = PlotlyJS.savefig(io, plt.o, format="png")
# _show(io::IO, ::MIME"application/pdf", plt::Plot{PlotlyJSBackend}) = PlotlyJS.savefig(io, plt.o, format="pdf")
# _show(io::IO, ::MIME"image/eps", plt::Plot{PlotlyJSBackend}) = PlotlyJS.savefig(io, plt.o, format="eps")

# function _show(io::IO, m::MIME"application/vnd.plotly.v1+json", plt::Plot{PlotlyJSBackend})
#     show(io, m, plt.o)
# end


# function write_temp_html(plt::Plot{PlotlyJSBackend})
#     filename = string(tempname(), ".html")
#     savefig(plt, filename)
#     filename
# end

_display(plt::Plot{PlotlyJSBackend}) = display(plotlyjs_syncplot(plt))

# function _display(plt::Plot{PlotlyJSBackend})
#     if get(ENV, "PLOTS_USE_ATOM_PLOTPANE", true) in (true, 1, "1", "true", "yes")
#         display(plt.o)
#     else
#         standalone_html_window(plt)
#     end
# end

@require WebIO = "0f1e0344-ec1d-5b48-a673-e5cf874b6c29" begin
    function WebIO.render(plt::Plot{PlotlyJSBackend})
        prepare_output(plt)
        WebIO.render(plt.o)
    end
end

function closeall(::PlotlyJSBackend)
    if !isplotnull() && isa(current().o, PlotlyJS.SyncPlot)
        close(current().o)
    end
end
