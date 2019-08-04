# ---------------------------------------------------------
# A backup, if no PNG generation is defined, is to try to make a PDF and use FileIO to convert

_fileio_load(@nospecialize(filename::AbstractString)) = FileIO.load(filename::AbstractString)
_fileio_save(@nospecialize(filename::AbstractString), @nospecialize(x)) = FileIO.save(filename::AbstractString, x)

function _show_pdfbackends(io::IO, ::MIME"image/png", plt::Plot)
    fn = tempname()

    # first save a pdf file
    pdf(plt, fn)

    # load that pdf into a FileIO Stream
    s = _fileio_load(fn * ".pdf")

    # save a png
    pngfn = fn * ".png"
    _fileio_save(pngfn, s)

    # now write from the file
    write(io, read(open(pngfn), String))
end

const PDFBackends = Union{PGFPlotsBackend,PlotlyJSBackend,PyPlotBackend,InspectDRBackend,GRBackend}
