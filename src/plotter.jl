
using Requires

# these are the plotting packages you can load.  we use lazymod so that we
# don't "import" the module until we want it
@lazymod Qwt
@lazymod Gadfly

# ---------------------------------------------------------

abstract PlottingPackage


const AVAILABLE_PACKAGES = [:Qwt, :Gadfly]
const INITIALIZED_PACKAGES = Set{Symbol}()

type CurrentPackage
  pkg::Nullable{PlottingPackage}
end
const CURRENT_PACKAGE = CurrentPackage(Nullable{PlottingPackage}())


doc"""Returns the current plotting package name."""
function plotter()
  if isnull(CURRENT_PACKAGE.pkg)
    error("Must choose a plotter.  Example: `plotter(:Qwt)`")
  end
  get(CURRENT_PACKAGE.pkg)
end

doc"""
Setup the plot environment.
`plotter(:Qwt)` will load package Qwt.jl and map all subsequent plot commands to that package.
Same for `plotter(:Gadfly)`, etc.
"""
function plotter!(modname)
  
  if modname == :qwt
    if !(modname in INITIALIZED_PACKAGES)
      qwt()
      push!(INITIALIZED_PACKAGES, modname)
    end
    global Qwt = Main.Qwt
    CURRENT_PACKAGE.pkg = Nullable(QwtPackage())
    return

  elseif modname == :gadfly
    if !(modname in INITIALIZED_PACKAGES)
      gadfly()
      push!(INITIALIZED_PACKAGES, modname)
    end
    global Gadfly = Main.Gadfly
    CURRENT_PACKAGE.pkg = Nullable(GadflyPackage())
    return
  
  end
  error("Unknown plotter $modname.  Choose from: $AVAILABLE_PACKAGES")
end
