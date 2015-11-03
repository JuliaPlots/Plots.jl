
# https://github.com/bokeh/Bokeh.jl

# ---------------------------------------------------------------------------

function plot(pkg::BokehPackage; kw...)
  d = Dict(kw)

  dumpdict(d, "plot", true)

  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  datacolumns = Bokeh.BokehDataSet[]
  tools = Bokeh.tools()
  filename = tempname() * ".html"
  title = d[:title]
  w, h = d[:size]
  xaxis_type = :auto
  yaxis_type = :auto
  # legend = d[:legend] ? xxxx : nothing
  legend = nothing
  bplt = Bokeh.Plot(datacolumns, tools, filename, title, w, h, xaxis_type, yaxis_type, legend)

  Plot(bplt, pkg, 0, d, Dict[])
end


function plot!(::BokehPackage, plt::Plot; kw...)
  d = Dict(kw)

  dumpdict(d, "plot!", true)

  # TODO: add one series to the underlying package


  push!(plt.seriesargs, d)
  plt
end

# ----------------------------------------------------------------

# TODO: override this to update plot items (title, xlabel, etc) after creation
function updatePlotItems(plt::Plot{BokehPackage}, d::Dict)
end

function updatePositionAndSize(plt::PlottingObject{BokehPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{BokehPackage}, i::Int)
  # TODO
  # series = plt.o.lines[i]
  # series.x, series.y
end

function Base.setindex!(plt::Plot{BokehPackage}, xy::Tuple, i::Integer)
  # TODO
  # series = plt.o.lines[i]
  # series.x, series.y = xy
  plt
end


# ----------------------------------------------------------------

function addAnnotations{X,Y,V}(plt::Plot{BokehPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function buildSubplotObject!(subplt::Subplot{BokehPackage})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end


function expandLimits!(lims, plt::Plot{BokehPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function handleLinkInner(plt::Plot{BokehPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{BokehPackage})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{BokehPackage})
  # TODO: display/show the plot
end

function Base.display(::PlotsDisplay, plt::Subplot{BokehPackage})
  # TODO: display/show the subplot
end
