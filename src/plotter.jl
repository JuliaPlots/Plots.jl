

plot(pkg::PlottingPackage; kw...) = error("plot($pkg; kw...) is not implemented")
plot!(pkg::PlottingPackage, plt::Plot; kw...) = error("plot!($pkg, plt; kw...) is not implemented")
Base.display(pkg::PlottingPackage, plt::Plot) = error("display($pkg, plt) is not implemented")

# ---------------------------------------------------------


const AVAILABLE_PACKAGES = [:qwt, :gadfly]
const INITIALIZED_PACKAGES = Set{Symbol}()

type CurrentPackage
  sym::Symbol
  pkg::PlottingPackage
end
const CURRENT_PACKAGE = CurrentPackage(:qwt, QwtPackage())


doc"""
Returns the current plotting package name.  Initializes package on first call.
"""
function plotter()

  currentPackageSymbol = CURRENT_PACKAGE.sym
  if !(currentPackageSymbol in INITIALIZED_PACKAGES)

    # initialize
    print("Initializing package: $CURRENT_PACKAGE... ")
    if currentPackageSymbol == :qwt
      @eval import Qwt
    elseif currentPackageSymbol == :gadfly
      @eval import Gadfly
    else
      error("Unknown plotter $currentPackageSymbol.  Choose from: $AVAILABLE_PACKAGES")
    end
    push!(INITIALIZED_PACKAGES, currentPackageSymbol)
    println("done.")

  end
  CURRENT_PACKAGE.pkg
end

doc"""
Set the plot backend.  Choose from:  :qwt, :gadfly
"""
function plotter!(modname)
  
  # set the PlottingPackage
  if modname == :qwt
    CURRENT_PACKAGE.pkg = QwtPackage()
  elseif modname == :gadfly
    CURRENT_PACKAGE.pkg = GadflyPackage()
  else
    error("Unknown plotter $modname.  Choose from: $AVAILABLE_PACKAGES")
  end

  # update the symbol
  CURRENT_PACKAGE.sym = modname

  # return the package
  CURRENT_PACKAGE.pkg
end
