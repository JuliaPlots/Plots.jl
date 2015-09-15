
# https://github.com/JuliaGraphics/Immerse.jl

immutable ImmersePackage <: PlottingPackage end

immerse!() = plotter!(:immerse)


function createImmerseFigure(d::Dict)
  # println("Creating immerse figure: ", d)
  w,h = d[:size]
  figidx = Immerse.figure(; name = d[:windowtitle], width = w, height = h)
  Immerse.Figure(figidx)
end


# create a blank Gadfly.Plot object
function plot(pkg::ImmersePackage; kw...)
  d = Dict(kw)

  # create the underlying Gadfly.Plot object
  gplt = createGadflyPlotObject(d)

  # save both the Immerse.Figure and the Gadfly.Plot
  Plot((nothing,gplt), pkg, 0, d, Dict[])
end


# plot one data series
function plot!(::ImmersePackage, plt::Plot; kw...)
  d = Dict(kw)
  gplt = plt.o[2]
  addGadflySeries!(gplt, d)
  push!(plt.seriesargs, d)
  plt
end

function Base.display(::ImmersePackage, plt::Plot)

  fig, gplt = plt.o
  if fig == nothing
    fig = createImmerseFigure(plt.initargs)
    plt.o = (fig, gplt)
  end

  # display a new Figure object to force a redraw
  display(Immerse.Figure(fig.canvas, gplt))
end

# -------------------------------

getGadflyContext(::ImmersePackage, plt::Plot) = plt.o[2]
getGadflyContext(::ImmersePackage, subplt::Subplot) = buildGadflySubplotContext(subplt)

function savepng(::ImmersePackage, plt::PlottingObject, fn::String;
                                    w = 6 * Immerse.inch,
                                    h = 4 * Immerse.inch)
  gctx = getGadflyContext(plt.plotter, plt)
  Gadfly.draw(Gadfly.PNG(fn, w, h), gctx)
  nothing
end


# -------------------------------


# function buildSubplotObject!(::ImmersePackage, subplt::Subplot)
# end


# create the underlying object
function buildSubplotObject!(::ImmersePackage, subplt::Subplot)
  subplt.o = (nothing, nothing)
end


function Base.display(::ImmersePackage, subplt::Subplot)

  fig, gctx = subplt.o
  if fig == nothing
    fig = createImmerseFigure(subplt.initargs)
    subplt.o = (fig, gctx)
  end

  newfig = Immerse.Figure(fig.canvas)
  newfig.cc = buildGadflySubplotContext(subplt)
  display(newfig)
end
