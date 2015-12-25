
# https://github.com/jheinen/GR.jl

function _create_plot(pkg::GRPackage; kw...)
  d = Dict(kw)
  GR.title(d[:title])
  GR.xlabel(d[:xlabel])
  GR.ylabel(d[:ylabel])
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::GRPackage, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package
  GR.plot(d[:x], d[:y])
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{GRPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{GRPackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{GRPackage}, d::Dict)
end

function _update_plot_pos_size(plt::PlottingObject{GRPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{GRPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{GRPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{GRPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{GRPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{GRPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{GRPackage})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{GRPackage})
  # TODO: display/show the plot
end

function Base.display(::PlotsDisplay, plt::Subplot{GRPackage})
  # TODO: display/show the subplot
end
