

# [WEBSITE]

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

function _create_plot(pkg::GLVisualizeBackend; kw...)
  d = KW(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  # TODO: this should be moved to the display method?
  w=GLVisualize.glscreen()
  @async GLVisualize.renderloop(w)
  Plot(GLScreenWrapper(w), pkg, 0, d, Dict[])
end


function _add_series(::GLVisualizeBackend, plt::Plot; kw...)
  d = KW(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  # TODO: this should be moved to the display method?
  x,y,z=map(Float32,d[:x]), map(Float32,d[:y]), map(Float32,d[:z].surf)
  GLVisualize.view(GLVisualize.visualize((x*ones(y)', ones(x)*y', z), :surface),plt.o.window)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GLVisualizeBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GLVisualizeBackend})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{GLVisualizeBackend}, d::Dict)
end

function _update_plot_pos_size(plt::AbstractPlot{GLVisualizeBackend}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{GLVisualizeBackend}, i::Int)
  # TODO:
  # series = plt.o.lines[i]
  # series.x, series.y
  nothing, nothing
end

function Base.setindex!(plt::Plot{GLVisualizeBackend}, xy::Tuple, i::Integer)
  # TODO:
  # series = plt.o.lines[i]
  # series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GLVisualizeBackend})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{GLVisualizeBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GLVisualizeBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{GLVisualizeBackend})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{GLVisualizeBackend})
  # TODO: display/show the plot

  # NOTE: I think maybe this should be empty?  We can start with the assumption that creating
  #       and adding to a plot will automatically open a window and draw to it, then the display
  #       wouldn't actually need to do anything
end

function Base.display(::PlotsDisplay, plt::Subplot{GLVisualizeBackend})
  # TODO: display/show the subplot
end
