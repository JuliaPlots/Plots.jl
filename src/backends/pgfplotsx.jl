using PGFPlotsX: PGFPlotsX
# --------------------------------------------------------------------------------------
# display calls this and then _display
function _update_plot_object(plt::Plot{PGFPlotsXBackend})
    plt.o = PGFPlotsX.Axis()
    push!( plt.o,  PGFPlotsX.Plot(PGFPlotsX.Coordinates(1:5,1:5)) )
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
    plt.o
end
