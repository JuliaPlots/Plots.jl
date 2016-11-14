
# https://github.com/spencerlyon2/PlotlyJS.jl

const _plotlyjs_attr        = _plotly_attr
const _plotlyjs_seriestype  = _plotly_seriestype
const _plotlyjs_style       = _plotly_style
const _plotlyjs_marker      = _plotly_marker
const _plotlyjs_scale       = _plotly_scale

# --------------------------------------------------------------------------------------


function add_backend_string(::PlotlyJSBackend)
    """
    if !Plots.is_installed("PlotlyJS")
        Pkg.add("PlotlyJS")
    end
    if !Plots.is_installed("Rsvg")
        Pkg.add("Rsvg")
    end
    import Blink
    Blink.AtomShell.install()
    """
end


function _initialize_backend(::PlotlyJSBackend; kw...)
    @eval begin
        import PlotlyJS
        export PlotlyJS
    end

    # # override IJulia inline display
    # if isijulia()
    #     IJulia.display_dict(plt::AbstractPlot{PlotlyJSBackend}) = IJulia.display_dict(plt.o)
    # end
end

# ---------------------------------------------------------------------------


function _create_backend_figure(plt::Plot{PlotlyJSBackend})
    if !isplotnull() && plt[:overwrite_figure] && isa(current().o, PlotlyJS.SyncPlot)
        PlotlyJS.SyncPlot(PlotlyJS.Plot(), current().o.view)
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
    kw = KW(xsym => (series.d[:x],), ysym => (series.d[:y],))
    z = series[:z]
    if z != nothing
        kw[:z] = (transpose_z(series, series[:z].surf, false),)
    end
    PlotlyJS.restyle!(
        plt.o,
        findfirst(plt.series_list, series),
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

function _show(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyJSBackend})
    show(io, MIME("text/html"), plt.o)
end

function plotlyjs_save_hack(io::IO, plt::Plot{PlotlyJSBackend}, ext::String)
    tmpfn = tempname() * "." * ext
    PlotlyJS.savefig(plt.o, tmpfn)
    write(io, read(open(tmpfn)))
end
_show(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "png")
_show(io::IO, ::MIME"application/pdf", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "pdf")
_show(io::IO, ::MIME"image/eps", plt::Plot{PlotlyJSBackend}) = plotlyjs_save_hack(io, plt, "eps")

function _display(plt::Plot{PlotlyJSBackend})
    display(plt.o)
end


function closeall(::PlotlyJSBackend)
    if !isplotnull() && isa(current().o, PlotlyJS.SyncPlot)
        close(current().o)
    end
end
