
# https://github.com/spencerlyon2/PlotlyJS.jl

function _initialize_backend(::PlotlyJSPackage; kw...)
    @eval begin
        import PlotlyJS
        export PlotlyJS
    end

    for (mime, fmt) in PlotlyJS._mimeformats
        @eval Base.writemime(io::IO, m::MIME{symbol($mime)}, p::Plot{PlotlyJSPackage}) = writemime(io, m, p.o.plot)
    end
end

# ---------------------------------------------------------------------------

function _create_plot(pkg::PlotlyJSPackage; kw...)
    d = Dict(kw)
    # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
    # TODO: initialize the plot... title, xlabel, bgcolor, etc
    # o = PlotlyJS.Plot(PlotlyJS.GenericTrace[], PlotlyJS.Layout(),
    #                   Base.Random.uuid4(), PlotlyJS.ElectronDisplay())
    # T = isijulia() ? PlotlyJS.JupyterPlot : PlotlyJS.ElectronPlot
    # o = T(PlotlyJS.Plot())
    o = PlotlyJS.plot()

    Plot(o, pkg, 0, d, Dict[])
end


function _add_series(::PlotlyJSPackage, plt::Plot; kw...)
    d = Dict(kw)
    syncplot = plt.o

    dumpdict(d, "addseries", true)

    # add to the data array
    pdict = plotly_series(d)
    typ = pop!(pdict, :type)
    gt = PlotlyJS.GenericTrace(typ; pdict...)
    PlotlyJS.addtraces!(syncplot, gt)

    push!(plt.seriesargs, d)
    plt
end


# ---------------------------------------------------------------------------


function _add_annotations{X,Y,V}(plt::Plot{PlotlyJSPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PlotlyJSPackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyJSPackage}, d::Dict)
    pdict = plotly_layout(d)
    dumpdict(pdict, "pdict updateplot", true)
    syncplot = plt.o
    w,h = d[:size]
    PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
end


function _update_plot_pos_size(plt::PlottingObject{PlotlyJSPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PlotlyJSPackage}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function Base.setindex!(plt::Plot{PlotlyJSPackage}, xy::Tuple, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PlotlyJSPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PlotlyJSPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PlotlyJSPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, m::MIME"text/html", plt::PlottingObject{PlotlyJSPackage})
    Base.writemime(io, m, plt.o)
end

function Base.display(::PlotsDisplay, plt::Plot{PlotlyJSPackage})
    display(plt.o)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyJSPackage})
    error()
end

