

# [WEBSITE]

supportedArgs(::GLVisualizeBackend) = [
    # :annotations,
    # :axis,
    # :background_color,
    # :color_palette,
    # :fillrange,
    # :fillcolor,
    # :fillalpha,
    # :foreground_color,
    # :group,
    # :label,
    # :layout,
    # :legend,
    # :linecolor,
    # :linestyle,
     :seriestype
    #  :seriescolor, :seriesalpha,
    # :linewidth,
    # :linealpha,
    # :markershape,
    # :markercolor,
    # :markersize,
    # :markeralpha,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    # :bins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    # :size,
    # :title,
    # :window_title,
    # :x,
    # :xguide,
    # :xlims,
    # :xticks,
    # :y,
    # :yguide,
    # :ylims,
    # :yrightlabel,
    # :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
    # :tickfont,
    # :guidefont,
    # :legendfont,
    # :grid,
    # :surface
    # :levels,
  ]
supportedAxes(::GLVisualizeBackend) = [:auto, :left]
supportedTypes(::GLVisualizeBackend) = [:surface] #, :path, :scatter ,:steppre, :steppost, :sticks, :heatmap, :hexbin, :histogram, :bar, :hline, :vline, :contour]
supportedStyles(::GLVisualizeBackend) = [:auto, :solid] #, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GLVisualizeBackend) = [:none, :auto, :ellipse] #, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::GLVisualizeBackend) = [:identity] #, :log, :log2, :log10, :asinh, :sqrt]
subplotSupported(::GLVisualizeBackend) = false

# --------------------------------------------------------------------------------------


function _initialize_backend(::GLVisualizeBackend; kw...)
  @eval begin
    import GLVisualize
    export GLVisualize
  end
end

# ---------------------------------------------------------------------------

immutable GLScreenWrapper
    window
end

# function _create_plot(pkg::GLVisualizeBackend, d::KW)
function _create_backend_figure(plt::Plot{GLVisualizeBackend})
  # TODO: create the window/canvas/context that is the plot within the backend
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  # TODO: this should be moved to the display method?
  w=GLVisualize.glscreen()
  @async GLVisualize.renderloop(w)
  GLScreenWrapper(w)
  # Plot(GLScreenWrapper(w), pkg, 0, d, KW[])
end


# ----------------------------------------------------------------

function _series_added(plt::Plot{GLVisualizeBackend}, series::Series)
  # TODO: add one series to the underlying package
  # TODO: this should be moved to the display method?
  x, y, z = map(Float32, series.d[:x]), map(Float32, series.d[:y]), map(Float32, series.d[:z].surf)
  GLVisualize.view(GLVisualize.visualize((x*ones(y)', ones(x)*y', z), :surface), plt.o.window)
  # plt
end


# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{GLVisualizeBackend}, series::Series)
    # TODO
end

# ----------------------------------------------------------------


# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot_object(plt::Plot{GLVisualizeBackend})
    # TODO
end


# ----------------------------------------------------------------

function _writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{GLVisualizeBackend})
  # TODO: write a png to io
end

function _display(plt::Plot{GLVisualizeBackend})
  # TODO: display/show the plot

  # NOTE: I think maybe this should be empty?  We can start with the assumption that creating
  #       and adding to a plot will automatically open a window and draw to it, then the display
  #       wouldn't actually need to do anything
end
