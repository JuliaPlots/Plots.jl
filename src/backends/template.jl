
# TODO: find/replace all [PkgName] with CamelCase, all [pkgname] with lowercase

# [WEBSITE]

immutable [PkgName]Package <: PlottingPackage end

export [pkgname]
[pkgname]() = backend(:[pkgname])

# ---------------------------------------------------------------------------

# supportedArgs(::[PkgName]Package) = _allArgs
supportedArgs(::[PkgName]Package) = [
    :annotation,
    :args,
    :axis,
    :background_color,
    :color,
    :fillto,
    :foreground_color,
    :group,
    # :heatmap_c,
    :kwargs,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :marker,
    :markercolor,
    :markersize,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    :reg,
    # :ribbon,
    :show,
    :size,
    :title,
    :width,
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
  ]
supportedAxes(::[PkgName]Package) = _allAxes
supportedTypes(::[PkgName]Package) = _allTypes
supportedStyles(::[PkgName]Package) = _allStyles
supportedMarkers(::[PkgName]Package) = _allMarkers
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

# ----------------------------------------------------------------

function buildSubplotObject!(subplt::Subplot{[PkgName]Package})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
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
