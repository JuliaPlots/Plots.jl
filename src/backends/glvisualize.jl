

# [WEBSITE]

# ---------------------------------------------------------------------------

immutable GLScreenWrapper
    window
end

function _create_plot(pkg::GLVisualizePackage; kw...)
  d = Dict(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  w=GLVisualize.glscreen()
  @async GLVisualize.renderloop(w)
  Plot(GLScreenWrapper(w), pkg, 0, d, Dict[])
end


function _add_series(::GLVisualizePackage, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  x,y,z=map(Float32,d[:x]), map(Float32,d[:y]), map(Float32,d[:z].surf)
  GLVisualize.view(GLVisualize.visualize((x*ones(y)', ones(x)*y', z), :surface),plt.o.window)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GLVisualizePackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GLVisualizePackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{GLVisualizePackage}, d::Dict)
end

function _update_plot_pos_size(plt::PlottingObject{GLVisualizePackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{GLVisualizePackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{GLVisualizePackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GLVisualizePackage})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{GLVisualizePackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GLVisualizePackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{GLVisualizePackage})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{GLVisualizePackage})
  # TODO: display/show the plot
end

function Base.display(::PlotsDisplay, plt::Subplot{GLVisualizePackage})
  # TODO: display/show the subplot
end
