
# TODO: find/replace all [PkgName] with CamelCase, all [pkgname] with lowercase

# [WEBSITE]

# ---------------------------------------------------------------------------

# supportedArgs(::[PkgName]Package) = _allArgs
supportedArgs(::[PkgName]Package) = [
    :annotation,
    # :args,
    :axis,
    :background_color,
    :color,
    :fillrange,
    :fillcolor,
    :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedAxes(::[PkgName]Package) = _allAxes
supportedTypes(::[PkgName]Package) = _allTypes
supportedStyles(::[PkgName]Package) = _allStyles
supportedMarkers(::[PkgName]Package) = _allMarkers
supportedScales(::[PkgName]Package) = _allScales
subplotSupported(::[PkgName]Package) = false

# ---------------------------------------------------------------------------

function plot(pkg::[PkgName]Package; kw...)
  d = Dict(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(o, pkg, 0, d, Dict[])
end


function plot!(::[PkgName]Package, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

# ----------------------------------------------------------------

# TODO: override this to update plot items (title, xlabel, etc) after creation
function updatePlotItems(plt::Plot{[PkgName]Package}, d::Dict)
end

function updatePositionAndSize(plt::PlottingObject{[PkgName]Package}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{[PkgName]Package}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{[PkgName]Package}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function addAnnotations{X,Y,V}(plt::Plot{[PkgName]Package}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function buildSubplotObject!(subplt::Subplot{[PkgName]Package})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function expandLimits!(lims, plt::Plot{[PkgName]Package}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function handleLinkInner(plt::Plot{[PkgName]Package}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{[PkgName]Package})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{[PkgName]Package})
  # TODO: display/show the plot
end

function Base.display(::PlotsDisplay, plt::Subplot{[PkgName]Package})
  # TODO: display/show the subplot
end
