
# https://github.com/spencerlyon2/PlotlyJS.jl

supported_args(::PlotlyJSBackend) = supported_args(PlotlyBackend())
supported_types(::PlotlyJSBackend) = supported_types(PlotlyBackend())
supported_styles(::PlotlyJSBackend) = supported_styles(PlotlyBackend())
supported_markers(::PlotlyJSBackend) = supported_markers(PlotlyBackend())
is_subplot_supported(::PlotlyJSBackend) = true
is_string_supported(::PlotlyJSBackend) = true

# --------------------------------------------------------------------------------------

function _initialize_backend(::PlotlyJSBackend; kw...)
    @eval begin
        import PlotlyJS
        export PlotlyJS
    end

    # for (mime, fmt) in PlotlyJS._mimeformats
    #     # mime == "image/png" && continue  # don't use plotlyjs's writemime for png
    #     @eval Base.writemime(io::IO, m::MIME{Symbol($mime)}, p::Plot{PlotlyJSBackend}) = writemime(io, m, p.o)
    # end

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
    pdict = plotly_series(plt, series)
    typ = pop!(pdict, :type)
    gt = PlotlyJS.GenericTrace(typ; pdict...)
    PlotlyJS.addtraces!(syncplot, gt)
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

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot_object(plt::Plot{PlotlyJSBackend})
    pdict = plotly_layout(plt)
    syncplot = plt.o
    w,h = plt[:size]
    PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
end


# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{PlotlyJSBackend}, i::Int)
#   d = plt.seriesargs[i]
#   d[:x], d[:y]
# end

# function setxy!{X,Y}(plt::Plot{PlotlyJSBackend}, xy::Tuple{X,Y}, i::Integer)
#   d = plt.seriesargs[i]
#   ispolar = get(plt.attr, :polar, false)
#   xsym = ispolar ? :t : :x
#   ysym = ispolar ? :r : :y
#   d[xsym], d[ysym] = xy
#   # TODO: this is likely ineffecient... we should make a call that ONLY changes the plot data
#   PlotlyJS.restyle!(plt.o, i, KW(xsym=>(d[xsym],), ysym=>(d[ysym],)))
#   plt
# end


# ----------------------------------------------------------------

function _writemime(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyJSBackend})
    writemime(io, MIME("text/html"), plt.o)
end

function _writemime(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend})
    tmpfn = tempname() * "png"
    PlotlyJS.savefig(plt.o, tmpfn)
    write(io, read(open(tmpfn)))
end

function _display(plt::Plot{PlotlyJSBackend})
    display(plt.o)
end
