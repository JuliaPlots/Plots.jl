
# https://github.com/sisl/PGFPlots.jl

function _initialize_backend(::PGFPlotsPackage; kw...)
  @eval begin
    import PGFPlots
    export PGFPlots
    # TODO: other initialization that needs to be eval-ed
  end
  # TODO: other initialization
end

# ---------------------------------------------------------------------------

function _create_plot(pkg::PGFPlotsPackage; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::PGFPlotsPackage, plt::Plot; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PGFPlotsPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PGFPlotsPackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PGFPlotsPackage}, d::Dict)
end

function _update_plot_pos_size(plt::PlottingObject{PGFPlotsPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PGFPlotsPackage}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function Base.setindex!(plt::Plot{PGFPlotsPackage}, xy::Tuple, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PGFPlotsPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PGFPlotsPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PGFPlotsPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------


# ----------------------------------------------------------------

#################  This is the important method to implement!!! #################
function _make_pgf_plot(plt::Plot{PGFPlotsPackage})
  # TODO: convert plt.plotargs and plt.seriesargs into PGFPlots calls
  # TODO: return the PGFPlots object
end

function Base.writemime(io::IO, mime::MIME"image/png", plt::PlottingObject{PGFPlotsPackage})
  plt.o = _make_pgf_plot(plt)
  writemime(io, mime, plt.o)
end

# function Base.writemime(io::IO, ::MIME"text/html", plt::PlottingObject{PGFPlotsPackage})
# end

function Base.display(::PlotsDisplay, plt::PlottingObject{PGFPlotsPackage})
  plt.o = _make_pgf_plot(plt)
  display(plt.o)
end

# function Base.display(::PlotsDisplay, plt::Subplot{PGFPlotsPackage})
#   # TODO: display/show the subplot
# end
