
# https://github.com/JuliaGraphics/Immerse.jl

immutable ImmersePackage <: PlottingPackage end

immerse!() = plotter!(:immerse)



# create a blank Gadfly.Plot object
function plot(pkg::ImmersePackage; kw...)
  d = Dict(kw)

  # create the underlying Gadfly.Plot object
  gplt = createGadflyPlotObject(d)

  # create the figure.  Immerse just returns the index of the Figure in the GadflyDisplay... call Figure(figidx) to get the object
  w,h = d[:size]
  figidx = Immerse.figure(; name = d[:windowtitle], width = w, height = h)
  fig = Immerse.Figure(figidx)

  # save both the Immerse.Figure and the Gadfly.Plot
  Plot((fig,gplt), pkg, 0, d, Dict[])
end


# plot one data series
function plot!(::ImmersePackage, plt::Plot; kw...)
  d = Dict(kw)
  addGadflySeries!(plt.o[2], d)
  push!(plt.seriesargs, d)
  plt
end

function Base.display(::ImmersePackage, plt::Plot)
  display(plt.o[2])
end

# -------------------------------

function savepng(::ImmersePackage, plt::PlottingObject, fn::String;
                                    w = 6 * Immerse.inch,
                                    h = 4 * Immerse.inch)
  Immerse.draw(Immerse.PNG(fn, w, h), plt.o)
end


# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::ImmersePackage, subplt::Subplot)
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Gadfly.hstack([plt.o[2] for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  gctx = Gadfly.vstack(rows...)

  figidx = Immerse.figure()
  fig = Immerse.Figure(figidx)
  (fig, gctx)
end


function Base.display(::ImmersePackage, subplt::Subplot)
  display(subplt.o[2])
end
