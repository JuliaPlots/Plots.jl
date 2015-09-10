

plot(pkg::PlottingPackage; kw...) = error("plot($pkg; kw...) is not implemented")
plot!(pkg::PlottingPackage, plt::Plot; kw...) = error("plot!($pkg, plt; kw...) is not implemented")
Base.display(pkg::PlottingPackage, plt::Plot) = error("display($pkg, plt) is not implemented")

# ---------------------------------------------------------


const AVAILABLE_PACKAGES = [:qwt, :gadfly]
const INITIALIZED_PACKAGES = Set{Symbol}()

type CurrentPackage
  # pkg::Nullable{PlottingPackage}
  sym::Symbol
  pkg::PlottingPackage
end
# const CURRENT_PACKAGE = CurrentPackage(Nullable{PlottingPackage}())
const CURRENT_PACKAGE = CurrentPackage(:qwt, QwtPackage())


doc"""
Returns the current plotting package name.  Initializes package on first use.
"""
function plotter()
  # if isnull(CURRENT_PACKAGE.pkg)
  #   error("Must choose a plotter.  Example: `plotter!(:qwt)`")
  # end
  currentPackageSymbol = CURRENT_PACKAGE.sym
  if !(currentPackageSymbol in INITIALIZED_PACKAGES)

    # initialize
    if currentPackageSymbol == :qwt
      @eval import Qwt
    elseif currentPackageSymbol == :gadfly
      @eval import Gadfly
    else
      error("Unknown plotter $currentPackageSymbol.  Choose from: $AVAILABLE_PACKAGES")
    end
    push!(INITIALIZED_PACKAGES, currentPackageSymbol)
    # plotter!(CURRENT_PACKAGE.sym)

  end
  # get(CURRENT_PACKAGE.pkg)
  println("Current package: $CURRENT_PACKAGE")
  CURRENT_PACKAGE.pkg
end

doc"""
Set the plot backend.  Choose from:  :qwt, :gadfly
"""
function plotter!(modname)
  
  if modname == :qwt
    # if !(modname in INITIALIZED_PACKAGES)
    #   # qwt()
    #   @eval import Qwt
    #   push!(INITIALIZED_PACKAGES, modname)
    # end
    # global Qwt = Main.Qwt
    # CURRENT_PACKAGE.sym = modname
    # CURRENT_PACKAGE.pkg = Nullable(QwtPackage())
    CURRENT_PACKAGE.pkg = QwtPackage()
    # return

  elseif modname == :gadfly
    # if !(modname in INITIALIZED_PACKAGES)
    #   # gadfly()
    #   @eval import Gadfly
    #   push!(INITIALIZED_PACKAGES, modname)
    # end
    # global Gadfly = Main.Gadfly
    # CURRENT_PACKAGE.sym = modname
    # CURRENT_PACKAGE.pkg = Nullable(GadflyPackage())
    CURRENT_PACKAGE.pkg = GadflyPackage()
    # return
  
  else
    error("Unknown plotter $modname.  Choose from: $AVAILABLE_PACKAGES")
  end

  CURRENT_PACKAGE.sym = modname
  CURRENT_PACKAGE.pkg
end
