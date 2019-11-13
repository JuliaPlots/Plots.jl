using PGFPlotsX: PGFPlotsX
# --------------------------------------------------------------------------------------
# display calls this and then _display, its called 3 times for plot(1:5)
function _update_plot_object(plt::Plot{PGFPlotsXBackend})
    plt.o = PGFPlotsX.GroupPlot()

    local axis
    for sp in plt.subplots
        axis = PGFPlotsX.Axis()
        for series in series_list(sp)
            series_plot = PGFPlotsX.Plot(PGFPlotsX.Coordinates(series[:x],series[:y]))
            push!( axis, series_plot )
        end
    end
    push!( plt.o, axis )
end

function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"image/png", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsXBackend})
    PGFPlotsX.print_tex(plt.o)
end

function _display(plt::Plot{PGFPlotsXBackend})
    # fn = string(tempname(),".svg")
    # PGFPlotsX.pgfsave(fn, plt.o)
    # open_browser_window(fn)
    plt.o
end
