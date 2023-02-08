module FileIOExt
import Plots
Plots.@ext_imp_use :import FileIO

const PDFBackends = Union{
    Plots.PGFPlotsBackend,
    Plots.PlotlyJSBackend,
    Plots.PyPlotBackend,
    Plots.PythonPlotBackend,
    Plots.InspectDRBackend,
    Plots.GRBackend,
}

_fileio_load(@nospecialize(filename::AbstractString)) =
    FileIO.load(filename::AbstractString)
_fileio_save(@nospecialize(filename::AbstractString), @nospecialize(x)) =
    FileIO.save(filename::AbstractString, x)

function _show_pdfbackends(io::IO, ::MIME"image/png", plt::Plot)
    fn = tempname()

    # first save a pdf file
    Plots.pdf(plt, fn)

    # load that pdf into a FileIO Stream
    s = _fileio_load("$fn.pdf")

    # save a png
    pngfn = "$fn.png"
    _fileio_save(pngfn, s)

    # now write from the file
    write(io, read(open(pngfn), String))
end

Plots._show(io::IO, mime::MIME"image/png", plt::Plots.Plot{<:PDFBackends}) =
    _show_pdfbackends(io, mime, plt)
end
