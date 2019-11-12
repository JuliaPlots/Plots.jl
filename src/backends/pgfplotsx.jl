# --------------------------------------------------------------------------------------
function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsXBackend})
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsXBackend})
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsXBackend})
end

function _display(plt::Plot{PGFPlotsXBackend})

end
