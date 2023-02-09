module FileIOExt

import Plots: Plots, Plot, @ext_imp_use
@ext_imp_use :import FileIO

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

for be in (
    Plots.PGFPlotsBackend,  # NOTE: I guess this can be removed in Plots@2.0
)
    showable(MIME"image/png"(), Plot{be}) && continue
    @eval Plots._show(io::IO, mime::MIME"image/png", plt::Plot{$be}) =
        _show_pdfbackends(io, mime, plt)
end

end  # module
