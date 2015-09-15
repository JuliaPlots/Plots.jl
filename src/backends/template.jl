
# TODO: find/replace all [PkgName] with CamelCase, all [pkgname] with lowercase

# [WEBSITE]

immutable [PkgName]Package <: PlottingPackage end

[pkgname]!() = plotter!(:[pkgname])



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


function Base.display(::[PkgName]Package, plt::Plot)
  # TODO: display/show the plot
end

# -------------------------------

function savepng(::[PkgName]Package, plt::PlottingObject, fn::String; kw...)
  # TODO: save a PNG of the underlying plot/subplot object
end


# -------------------------------

function buildSubplotObject!(::[PkgName]Package, subplt::Subplot)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end


function Base.display(::[PkgName]Package, subplt::Subplot)
  # TODO: display/show the Subplot object
end
