
# TODO: find/replace all [PkgName] with CamelCase

# [ADD BACKEND WEBSITE]

function _initialize_backend(::[PkgName]Backend; kw...)
    @eval begin
        topimport(:[PkgName])
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

# # this is called early in the pipeline, use it to make the plot current or something
# function _prepare_plot_object(plt::Plot{[PkgName]Backend})
# end

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{[PkgName]Backend}, sp::Subplot{[PkgName]Backend})
end

# ---------------------------------------------------------------------------

# Add one series to the underlying backend object.
function _series_added(plt::Plot{[PkgName]Backend}, series::Series)
end

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{[PkgName]Backend}, series::Series)
end

# ---------------------------------------------------------------------------

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{[PkgName]Backend})
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{[PkgName]Backend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end


# ----------------------------------------------------------------

# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot_object(plt::Plot{[PkgName]Backend})
end

# ----------------------------------------------------------------

# Write a png to io.  You could define methods for:
    # "application/eps"         => "eps",
    # "image/eps"               => "eps",
    # "application/pdf"         => "pdf",
    # "image/png"               => "png",
    # "application/postscript"  => "ps",
    # "image/svg+xml"           => "svg"
function _show(io::IO, ::MIME"image/png", plt::Plot{[PkgName]Backend})
end

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{[PkgName]Backend})
end
