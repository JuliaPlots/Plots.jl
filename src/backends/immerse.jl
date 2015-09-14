
# https://github.com/JuliaGraphics/Immerse.jl

immutable ImmersePackage <: PlottingPackage end

immerse!() = plotter!(:immerse)


function createImmerseFigure(d::Dict)
  # d[:show] || return  # return nothing when we're not showing
  println("Creating immerse figure: ", d)
  w,h = d[:size]
  figidx = Immerse.figure(; name = d[:windowtitle], width = w, height = h)
  Immerse.Figure(figidx)
end


# create a blank Gadfly.Plot object
function plot(pkg::ImmersePackage; kw...)
  d = Dict(kw)

  # create the underlying Gadfly.Plot object
  gplt = createGadflyPlotObject(d)

  # create the figure (or not).  Immerse just returns the index of the Figure in the GadflyDisplay... call Figure(figidx) to get the object
  # fig = d[:show] ? createImmerseFigure(d) : nothing
  fig =  nothing

  # if d[:show]
  #   # w,h = d[:size]
  #   # figidx = Immerse.figure(; name = d[:windowtitle], width = w, height = h)
  #   # fig = Immerse.Figure(figidx)
  #   fig = createImmerseFigure(d)
  # else
  #   fig = nothing
  # end

  # save both the Immerse.Figure and the Gadfly.Plot
  Plot((fig,gplt), pkg, 0, d, Dict[])
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
  println("disp1")
  fig, gplt = plt.o
  if fig == nothing
    fig = createImmerseFigure(plt.initargs)
    plt.o = (fig, gplt)
  end
  newfig = Immerse.Figure(fig.canvas, gplt)
  display(newfig)
end

# -------------------------------

function savepng(::ImmersePackage, plt::PlottingObject, fn::String;
                                    w = 6 * Immerse.inch,
                                    h = 4 * Immerse.inch)
  gctx = plt.o[2]
  Gadfly.draw(Gadfly.PNG(fn, w, h), gctx)
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

  # fig = subplt.initargs[:show] ? createImmerseFigure(subplt.initargs) : nothing
  fig = nothing
  # fig = createImmerseFigure(subplt.initargs)

  subplt.o = (fig, gctx)
end


function Base.display(::ImmersePackage, subplt::Subplot)
  println("disp2")

  fig, gctx = subplt.o
  if fig == nothing
    fig = createImmerseFigure(subplt.initargs)
    subplt.o = (fig, gctx)
  end

  fig.prepped = Gadfly.render_prepare(gctx)
  # Render in the current state
  fig.cc = render_finish(fig.prepped; dynamic=false)
  # Render the figure
  display(fig.canvas, fig)

  # fig.cc = gctx
  # fig.prepped = nothing

  # display(fig)
end
