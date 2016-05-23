
# TODO: find/replace all [PkgName] with CamelCase

# [ADD BACKEND WEBSITE]

function _initialize_backend(::[PkgName]AbstractBackend; kw...)
    @eval begin
        import [PkgName]
        export [PkgName]
        # todo: other initialization that needs to be eval-ed
    end
    # todo: other initialization
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{[PkgName]Backend})
    nothing
end

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{PyPlotBackend}, sp::Subplot{PyPlotBackend})
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{[PkgName]Backend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end

# Use the bounding boxes (and methods left/top/right/bottom/width/height) `sp.bbox` and `sp.plotarea` to
# position the subplot in the backend.
function _update_position!(sp::Subplot{[PkgName]Backend})
end

# ----------------------------------------------------------------

# This is called before series processing... use it if you need to make the backend object current or something.
function _before_update(plt::Plot{[PkgName]AbstractBackend})
end


# Add one series to the underlying backend object.
function _series_added(plt::Plot{[PkgName]Backend}, series::Series)
end


# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot(plt::Plot{[PkgName]AbstractBackend}, d::KW)
end

# ----------------------------------------------------------------

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{[PkgName]AbstractBackend}, series::Series)
end

# ----------------------------------------------------------------

# Write a png to io.  You could define methods for:
    # "application/eps"         => "eps",
    # "image/eps"               => "eps",
    # "application/pdf"         => "pdf",
    # "image/png"               => "png",
    # "application/postscript"  => "ps",
    # "image/svg+xml"           => "svg"
function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{[PkgName]AbstractBackend})
end

# Display/show the plot (open a GUI window, or browser page, for example).
function Base.display(::PlotsDisplay, plt::Plot{[PkgName]AbstractBackend})
end
