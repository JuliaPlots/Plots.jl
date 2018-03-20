@require Revise begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "plotlywebio.jl")) 
end

# https://github.com/spencerlyon2/PlotlyWebIO.jl

const _plotlywebio_attr        = _plotly_attr
const _plotlywebio_seriestype  = _plotly_seriestype
const _plotlywebio_style       = _plotly_style
const _plotlywebio_marker      = _plotly_marker
const _plotlywebio_scale       = _plotly_scale

# --------------------------------------------------------------------------------------


function add_backend_string(::PlotlyWebIOBackend)
    """
    if !Plots.is_installed("PlotlyWebIO")
        Pkg.add("PlotlyWebIO")
    end
    if !Plots.is_installed("Rsvg")
        Pkg.add("Rsvg")
    end
    import Blink
    Blink.AtomShell.install()
    """
end


function _initialize_backend(::PlotlyWebIOBackend; kw...)
    @eval begin
        import PlotlyWebIO
        export PlotlyWebIO
    end
end

# ---------------------------------------------------------------------------


function _create_backend_figure(plt::Plot{PlotlyWebIOBackend})
    if !isplotnull() && plt[:overwrite_figure] && isa(current().o, PlotlyWebIO.WebIOPlot)
        # FIXME: Not sure what we're supposed to do here.
        PlotlyWebIO.WebIOPlot()#PlotlyWebIO.WebIOPlot(), current().o.scope)
    else
        PlotlyWebIO.WebIOPlot()
    end
end


function _series_added(plt::Plot{PlotlyWebIOBackend}, series::Series)
    webioplot = plt.o
    pdicts = plotly_series(plt, series)
    for pdict in pdicts
        typ = pop!(pdict, :type)
        gt = PlotlyWebIO.GenericTrace(typ; pdict...)
        PlotlyWebIO.addtraces!(webioplot, gt)
    end
end

function _series_updated(plt::Plot{PlotlyWebIOBackend}, series::Series)
    xsym, ysym = (ispolar(series) ? (:t,:r) : (:x,:y))
    kw = KW(xsym => (series.d[:x],), ysym => (series.d[:y],))
    z = series[:z]
    if z != nothing
        kw[:z] = (isa(z,Surface) ? transpose_z(series, series[:z].surf, false) : z,)
    end
    PlotlyWebIO.restyle!(
        plt.o,
        findfirst(plt.series_list, series),
        kw
    )
end


# ----------------------------------------------------------------

function _update_plot_object(plt::Plot{PlotlyWebIOBackend})
    pdict = plotly_layout(plt)
    webioplot = plt.o
    w,h = plt[:size]
    PlotlyWebIO.relayout!(webioplot, pdict, width = w, height = h)
end


# ----------------------------------------------------------------

function Base.show(io::IO, ::MIME"text/html", plt::Plot{PlotlyWebIOBackend})
    prepare_output(plt)
    if isijulia() && !_use_remote[]
        write(io, PlotlyWebIO.html_body(PlotlyWebIO.JupyterPlot(plt.o.scope)))
    else
        show(io, MIME("text/html"), plt.o.scope)
    end
end

function plotlywebio_save_hack(io::IO, plt::Plot{PlotlyWebIOBackend}, ext::String)
    # Temporarily disabled. FIXME
    # tmpfn = tempname() * "." * ext
    # PlotlyWebIO.savefig(plt.o, tmpfn)
    # write(io, read(open(tmpfn)))
end
_show(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyWebIOBackend}) = plotlywebio_save_hack(io, plt, "svg")
_show(io::IO, ::MIME"image/png", plt::Plot{PlotlyWebIOBackend}) = plotlywebio_save_hack(io, plt, "png")
_show(io::IO, ::MIME"application/pdf", plt::Plot{PlotlyWebIOBackend}) = plotlywebio_save_hack(io, plt, "pdf")
_show(io::IO, ::MIME"image/eps", plt::Plot{PlotlyWebIOBackend}) = plotlywebio_save_hack(io, plt, "eps")

function write_temp_html(plt::Plot{PlotlyWebIOBackend})
    filename = string(tempname(), ".html")
    savefig(plt, filename)
    filename
end

function _display(plt::Plot{PlotlyWebIOBackend})
    if get(ENV, "PLOTS_USE_ATOM_PLOTPANE", true) in (true, 1, "1", "true", "yes")
        display(plt.o)
    else
        standalone_html_window(plt)
    end
end


function closeall(::PlotlyWebIOBackend)
    if !isplotnull() && isa(current().o, PlotlyWebIO.WebIOPlot)
        close(current().o)
    end
end
