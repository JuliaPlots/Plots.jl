
# https://github.com/spencerlyon2/PlotlyJS.jl

# --------------------------------------------------------------------------------------


function _create_backend_figure(plt::Plot{PlotlyJSBackend})
    if !isplotnull() && plt[:overwrite_figure] && isa(current().o, PlotlyJS.SyncPlot)
        PlotlyJS.SyncPlot(PlotlyJS.Plot(),
            events = current().o.events,
            options = current().o.options,
        )
    else
        PlotlyJS.plot()
    end
end


function _series_added(plt::Plot{PlotlyJSBackend}, series::Series)
    syncplot = plt.o
    pdicts = plotly_series(plt, series)
    for pdict in pdicts
        typ = pop!(pdict, :type)
        gt = PlotlyJS.GenericTrace(typ; pdict...)
        PlotlyJS.addtraces!(syncplot, gt)
    end
end

function _series_updated(plt::Plot{PlotlyJSBackend}, series::Series)
    xsym, ysym = (ispolar(series) ? (:t,:r) : (:x,:y))
    kw = KW(xsym => (series.plotattributes[:x],), ysym => (series.plotattributes[:y],))
    z = series[:z]
    if z != nothing
        kw[:z] = (isa(z,Surface) ? transpose_z(series, series[:z].surf, false) : z,)
    end
    PlotlyJS.restyle!(
        plt.o,
        findfirst(isequal(series), plt.series_list),
        kw
    )
end


# ----------------------------------------------------------------

function _update_plot_object(plt::Plot{PlotlyJSBackend})
    pdict = plotly_layout(plt)
    syncplot = plt.o
    w,h = plt[:size]
    PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
end


# ----------------------------------------------------------------

function _show(io::IO, ::MIME"text/html", plt::Plot{PlotlyJSBackend})
    if isijulia() && !_use_remote[]
        write(io, PlotlyJS.html_body(PlotlyJS.JupyterPlot(plt.o)))
    else
        show(io, MIME("text/html"), plt.o)
    end
end

function plotlyjs_save_hack(io::IO, plt::Plot{PlotlyJSBackend}, ext::String)
    tmpfn = tempname() * "." * ext
    PlotlyJS.savefig(plt.o, tmpfn)
    write(io, read(open(tmpfn)))
end
_show(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "svg")
_show(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "png")
_show(io::IO, ::MIME"application/pdf", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "pdf")
_show(io::IO, ::MIME"image/eps", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "eps")

function write_temp_html(plt::Plot{PlotlyJSBackend})
    filename = string(tempname(), ".html")
    savefig(plt, filename)
    filename
end

function _display(plt::Plot{PlotlyJSBackend})
    if get(ENV, "PLOTS_USE_ATOM_PLOTPANE", true) in (true, 1, "1", "true", "yes")
        display(plt.o)
    else
        standalone_html_window(plt)
    end
end

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
