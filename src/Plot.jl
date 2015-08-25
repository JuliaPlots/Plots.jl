module Plot

using Requires

# these are the plotting packages you can load.  we use lazymod so that we
# don't "import" the module until we want it
@lazymod Qwt
@lazymod Gadfly

# ---------------------------------------------------------

abstract PlottingPackage

immutable QwtPackage <: PlottingPackage end
immutable GadflyPackage <: PlottingPackage end

const AVAILABLE_PACKAGES = [:Qwt, :Gadfly]
const INITIALIZED_PACKAGES = Set{Symbol}()

type CurrentPackage
  pkg::Nullable{PlottingPackage}
end

const CURRENT_PACKAGE = CurrentPackage(Nullable{PlottingPackage}())
function currentPackage()
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
function plotter(modname)
  if modname == :Qwt
    if !(modname in INITIALIZED_PACKAGES)
      qwt()
      push!(INITIALIZED_PACKAGES, modname)
    end
    global Qwt = Main.Qwt
    CURRENT_PACKAGE.pkg = Nullable(QwtPackage())
    return
  elseif modname == :Gadfly
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

# ---------------------------------------------------------

const IMG_DIR = "$(ENV["HOME"])/.julia/v0.4/Plot/img/"


# ---------------------------------------------------------

# Qwt

plot(::QwtPackage, args...; kwargs...) = Qwt.plot(args...; kwargs...)
savepng(::QwtPackage, plt, fn::String, args...) = Qwt.savepng(plt, fn)

# ---------------------------------------------------------

# Gadfly

plot(::GadflyPackage, y; kwargs...) = Gadfly.plot(; x = 1:length(y), y = y, kwargs...)
plot(::GadflyPackage, x, y; kwargs...) = Gadfly.plot(; x = x, y = y, kwargs...)
plot(::GadflyPackage, args...; kwargs...) = Gadfly.plot(args...; kwargs...)
savepng(::GadflyPackage, plt, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt)


# ---------------------------------------------------------


export
  plotter,
  plot,
  savepng

doc"""
The main plot command.  You must call `plotter(:ModuleName)` to set the current plotting environment first.
Commands are converted into the relevant plotting commands for that package:
  plotter(:Gadfly)
  plot(1:10)    # this calls `y = 1:10; Gadfly.plot(x=1:length(y), y=y)`
  plotter(:Qwt)
  plot(1:10)    # this calls `Qwt.plot(1:10)`
"""
plot(args...; kwargs...) = plot(currentPackage(), args...; kwargs...)
savepng(args...; kwargs...) = savepng(currentPackage(), args...; kwargs...)



# ---------------------------------------------------------

end # module
