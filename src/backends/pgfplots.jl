
# https://github.com/sisl/PGFPlots.jl

function _initialize_backend(::PGFPlotsBackend; kw...)
  @eval begin
    import PGFPlots
    export PGFPlots
    # TODO: other initialization that needs to be eval-ed
  end
  # TODO: other initialization
end

# ---------------------------------------------------------------------------

function _create_plot(pkg::PGFPlotsBackend; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::PGFPlotsBackend, plt::Plot; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PGFPlotsBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PGFPlotsBackend})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PGFPlotsBackend}, d::Dict)
end

function _update_plot_pos_size(plt::AbstractPlot{PGFPlotsBackend}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PGFPlotsBackend}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function Base.setindex!(plt::Plot{PGFPlotsBackend}, xy::Tuple, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PGFPlotsBackend}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PGFPlotsBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PGFPlotsBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------


# ----------------------------------------------------------------

#################  This is the important method to implement!!! #################
function _make_pgf_plot(plt::Plot{PGFPlotsBackend})
    line_type = plt.seriesargs[1][:linetype]
    if line_type == :path
        plt.o = PGFPlots.Linear(plt.seriesargs[1][:x], plt.seriesargs[1][:y])
    elseif line_type == :scatter
        plt.o = PGFPlots.Scatter(plt.seriesargs[1][:x], plt.seriesargs[1][:y])
    elseif line_type == :steppost
        plt.o = PGFPlots.Linear(plt.seriesargs[1][:x], plt.seriesargs[1][:y], style="const plot")
    elseif line_type == :hist
        plt_hist = hist(plt.seriesargs[1][:y])
        plt.o = PGFPlots.Linear(plt_hist[1][1:end-1], plt_hist[2], style="ybar,fill=green", mark="none")
    elseif line_type == :bar
        plt.o = PGFPlots.Linear(plt.seriesargs[1][:x], plt.seriesargs[1][:y], style="ybar,fill=green", mark="none")
    end
  # TODO: convert plt.plotargs and plt.seriesargs into PGFPlots calls
  # TODO: return the PGFPlots object
end

function Base.writemime(io::IO, mime::MIME"image/svg+xml", plt::AbstractPlot{PGFPlotsBackend})
  plt.o = _make_pgf_plot(plt)
  writemime(io, mime, plt.o)
end

# function Base.writemime(io::IO, ::MIME"text/html", plt::AbstractPlot{PGFPlotsBackend})
# end

function Base.display(::PlotsDisplay, plt::AbstractPlot{PGFPlotsBackend})
  plt.o = _make_pgf_plot(plt)
  display(plt.o)
end

# function Base.display(::PlotsDisplay, plt::Subplot{PGFPlotsBackend})
#   # TODO: display/show the subplot
# end
