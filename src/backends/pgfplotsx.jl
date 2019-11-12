# --------------------------------------------------------------------------------------
# display calls this and then _display
function _update_plot_object(plt::Plot{PGFPlotsXBackend})
    plt.o = PGFPlotsX.Axis()
end

function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsXBackend})
    plt.o
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"image/png", plt::Plot{PGFPlotsXBackend})
    display("image/png", plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsXBackend})
    PGFPlotsX.print_tex(plt.o)
end

function _display(plt::Plot{PGFPlotsXBackend})
    plt.o
end
