

# these are the plotting packages you can load.  we use lazymod so that we
# don't "import" the module until we want it
@lazymod Qwt
@lazymod Gadfly

plot(pkg::PlottingPackage; kw...) = error("plot($pkg; kw...) is not implemented")
plot!(pkg::PlottingPackage, plt::Plot; kw...) = error("plot!($pkg, plt; kw...) is not implemented")
Base.display(pkg::PlottingPackage, plt::Plot) = error("display($pkg, plt) is not implemented")

# ---------------------------------------------------------


const AVAILABLE_PACKAGES = [:qwt, :gadfly]
const INITIALIZED_PACKAGES = Set{Symbol}()

type CurrentPackage
  pkg::Nullable{PlottingPackage}
end
const CURRENT_PACKAGE = CurrentPackage(Nullable{PlottingPackage}())


doc"""Returns the current plotting package name."""
function plotter()
  if isnull(CURRENT_PACKAGE.pkg)
    error("Must choose a plotter.  Example: `plotter!(:qwt)`")
  end
  get(CURRENT_PACKAGE.pkg)
end

doc"""
Setup the plot environment.
`plotter!(:qwt)` will load package Qwt.jl and map all subsequent plot commands to that package.
Same for `plotter!(:gadfly)`, etc.
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
