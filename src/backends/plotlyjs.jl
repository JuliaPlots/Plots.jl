
# https://github.com/spencerlyon2/PlotlyJS.jl

supported_args(::PlotlyJSBackend) = supported_args(PlotlyBackend())
supported_types(::PlotlyJSBackend) = supported_types(PlotlyBackend())
supported_styles(::PlotlyJSBackend) = supported_styles(PlotlyBackend())
supported_markers(::PlotlyJSBackend) = supported_markers(PlotlyBackend())
supported_scales(::PlotlyJSBackend) = supported_scales(PlotlyBackend())
is_subplot_supported(::PlotlyJSBackend) = true
is_string_supported(::PlotlyJSBackend) = true

# --------------------------------------------------------------------------------------

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
    PlotlyJS.plot()
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
    PlotlyJS.restyle!(
        plt.o,
        findfirst(plt.series_list, series),
        KW(xsym => (series.d[:x],), ysym => (series.d[:y],))
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

function _writemime(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyJSBackend})
    writemime(io, MIME("text/html"), plt.o)
end

function _writemime(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend})
    tmpfn = tempname() * ".png"
    PlotlyJS.savefig(plt.o, tmpfn)
    write(io, read(open(tmpfn)))
end

function _display(plt::Plot{PlotlyJSBackend})
    display(plt.o)
end
