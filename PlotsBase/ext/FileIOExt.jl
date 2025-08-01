module FileIOExt

import PlotsBase: PlotsBase, Plot
import FileIO

_fileio_load(@nospecialize(filename::AbstractString)) =
    FileIO.load(filename::AbstractString)
_fileio_save(@nospecialize(filename::AbstractString), @nospecialize(x)) =
    FileIO.save(filename::AbstractString, x)

function _show_pdfbackends(io::IO, ::MIME"image/png", plt::Plot)
    fn = tempname()

    # first save a pdf file
    PlotsBase.pdf(plt, fn)

    # load that pdf into a FileIO Stream
    s = _fileio_load("$fn.pdf")

    # save a png
    pngfn = "$fn.png"
    _fileio_save(pngfn, s)

    # now write from the file
    write(io, read(open(pngfn), String))

    # cleanup
    rm("$fn.pdf")
    rm("$fn.png")
    return nothing
end

# Possibly need to create another extension that has both pgfplotsx and showio
# delete for now, as testing for pgfplotsx is hard; TODO restore later at @2.0
# for be in (
#     PlotsBase.PGFPlotsBackend,  # NOTE: I guess this can be removed in PlotsBase@2.0
# )
#     showable(MIME"image/png"(), Plot{be}) && continue
#     @eval PlotsBase._show(io::IO, mime::MIME"image/png", plt::Plot{$be}) =
#         _show_pdfbackends(io, mime, plt)
# end

end
