

include("backends/qwt.jl")
include("backends/gadfly.jl")
include("backends/unicodeplots.jl")


# ---------------------------------------------------------


plot(pkg::PlottingPackage; kw...) = error("plot($pkg; kw...) is not implemented")
plot!(pkg::PlottingPackage, plt::Plot; kw...) = error("plot!($pkg, plt; kw...) is not implemented")
Base.display(pkg::PlottingPackage, plt::Plot) = error("display($pkg, plt) is not implemented")

# ---------------------------------------------------------


const AVAILABLE_PACKAGES = [:qwt, :gadfly, :unicodeplots]
const INITIALIZED_PACKAGES = Set{Symbol}()
backends() = AVAILABLE_PACKAGES


type CurrentPackage
  sym::Symbol
  pkg::PlottingPackage
end
const CURRENT_PACKAGE = CurrentPackage(:gadfly, GadflyPackage())


doc"""
Returns the current plotting package name.  Initializes package on first call.
"""
function plotter()

  currentPackageSymbol = CURRENT_PACKAGE.sym
  if !(currentPackageSymbol in INITIALIZED_PACKAGES)

    # initialize
    println("[Plots.jl] Initializing package: $CURRENT_PACKAGE... ")
    if currentPackageSymbol == :qwt
      try
        @eval import Qwt
      catch
        error("Couldn't import Qwt.  Install it with: Pkg.clone(\"https://github.com/tbreloff/Qwt.jl.git\")\n  (Note: also requires pyqt and pyqwt)")
      end
    elseif currentPackageSymbol == :gadfly
      try
        @eval import Gadfly
      catch
        error("Couldn't import Gadfly.  Install it with: Pkg.add(\"Gadfly\")")
      end
    elseif currentPackageSymbol == :unicodeplots
      try
        @eval import UnicodePlots
      catch
        error("Couldn't import UnicodePlots.  Install it with: Pkg.add(\"UnicodePlots\")")
      end
    else
      error("Unknown plotter $currentPackageSymbol.  Choose from: $AVAILABLE_PACKAGES")
    end
    push!(INITIALIZED_PACKAGES, currentPackageSymbol)
    println("[Plots.jl] done.")

  end
  CURRENT_PACKAGE.pkg
end

doc"""
Set the plot backend.  Choose from:  :qwt, :gadfly, :unicodeplots
"""
function plotter!(modname)
  
  # set the PlottingPackage
  if modname == :qwt
    CURRENT_PACKAGE.pkg = QwtPackage()
  elseif modname == :gadfly
    CURRENT_PACKAGE.pkg = GadflyPackage()
  elseif modname == :unicodeplots
    CURRENT_PACKAGE.pkg = UnicodePlotsPackage()
  else
    error("Unknown plotter $modname.  Choose from: $AVAILABLE_PACKAGES")
  end

  # update the symbol
  CURRENT_PACKAGE.sym = modname

  # return the package
  CURRENT_PACKAGE.pkg
end
