
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


function buildSubplotObject!(::ImmersePackage, subplt::Subplot)

  # box, tb, c = createPlotGuiComponents()
  vsep = Gtk.ShortNames.@Box(:v)

  # now we create the GUI
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts

    # create a new row and add it to the main Box vsep
    row = Gtk.ShortNames.@Box(:h)
    push!(vsep, row)

    # now add the plot components to the row
    for plt in subplt.plts[(1:rowcnt) + i]

      # get the components... box is the main plot GtkBox, and canvas is the GtkCanvas where it's plotted
      box, toolbar, canvas = Immerse.createPlotGuiComponents()

      # create and save the Figure
      plt.o = (figure(canvas), plt.o[2])

      # add the plot's box to the row
      push!(row, box)
    end
    # push!(rows, Gadfly.hstack([getGadflyContext(plt.plotter, plt) for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end

  d = subplt.initargs
  w,h = d[:size]
  win = Gtk.ShortNames.@GtkWindow(vsep, d[:windowtitle], w, h)
  guidata[win, :toolbar] = tb
  if closecb !== nothing
      Gtk.ShortNames.on_signal_destroy(closecb, win)
  end
  showall(win)

  subplt.o = win
end


# # create the underlying object
# function buildSubplotObject!(::ImmersePackage, subplt::Subplot)
#   subplt.o = (nothing, nothing)
# end


function Base.display(::ImmersePackage, subplt::Subplot)

  # fig, gctx = subplt.o
  # if fig == nothing
  #   fig = createImmerseFigure(subplt.initargs)
  #   subplt.o = (fig, gctx)
  # end

  # newfig = Immerse.Figure(fig.canvas)
  # newfig.cc = buildGadflySubplotContext(subplt)
  # display(newfig)

  # o is the window... show it
  showall(subplt.o)
end
