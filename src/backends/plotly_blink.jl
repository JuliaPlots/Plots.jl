
# override some methods to use PlotlyJS/Blink

import PlotlyJS

function _create_plot(pkg::PlotlyPackage; kw...)
    d = Dict(kw)
    # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
    # TODO: initialize the plot... title, xlabel, bgcolor, etc
    o = PlotlyJS.Plot(PlotlyJS.GenericTrace[], PlotlyJS.Layout(),
                      Base.Random.uuid4(), PlotlyJS.ElectronDisplay())

    Plot(o, pkg, 0, d, Dict[])
end


function _add_series(::PlotlyPackage, plt::Plot; kw...)
    d = Dict(kw)

    # add to the data array
    pdict = plotly_series(d)
    typ = pop!(pdict, :type)
    gt = PlotlyJS.GenericTrace(typ; pdict...)
    push!(plt.o.data, gt)
    if PlotlyJS.isactive(plt.o._display)
        PlotlyJS.addtraces!(plt.o, gt)
    end

    push!(plt.seriesargs, d)
    plt
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyPackage}, d::Dict)
    pdict = plotly_layout(d)
    plt.o.layout = PlotlyJS.Layout(pdict)
    if PlotlyJS.isactive(plt.o._display)
        PlotlyJS.relayout!(plt.o; pdict...)
    end
end


function Base.display(::PlotsDisplay, plt::Plot{PlotlyPackage})
    dump(plt.o)
    display(plt.o)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyPackage})
    error()
end

for (mime, fmt) in PlotlyJS._mimeformats
    @eval Base.writemime(io::IO, m::MIME{symbol($mime)}, p::Plot{PlotlyPackage}) =
        writemime(io, m, p.o)
end
