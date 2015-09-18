
# https://github.com/JuliaGraphics/Immerse.jl

immutable ImmersePackage <: PlottingPackage end

export immerse!
immerse!() = plotter!(:immerse)


supportedArgs(::ImmersePackage) = supportedArgs(GadflyPackage())
supportedAxes(::ImmersePackage) = supportedAxes(GadflyPackage())
supportedTypes(::ImmersePackage) = supportedTypes(GadflyPackage())
supportedStyles(::ImmersePackage) = supportedStyles(GadflyPackage())
supportedMarkers(::ImmersePackage) = supportedMarkers(GadflyPackage())


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

  # # display a new Figure object to force a redraw
  # display(Immerse.Figure(fig.canvas, gplt))

  Immerse.figure(fig.figno; displayfig = false)
  display(gplt)
end

# -------------------------------

getGadflyContext(::ImmersePackage, plt::Plot) = plt.o[2]
getGadflyContext(::ImmersePackage, subplt::Subplot) = buildGadflySubplotContext(subplt)

function savepng(::ImmersePackage, plt::PlottingObject, fn::AbstractString;
                                    w = 6 * Immerse.inch,
                                    h = 4 * Immerse.inch)
  gctx = getGadflyContext(plt.plotter, plt)
  Gadfly.draw(Gadfly.PNG(fn, w, h), gctx)
  nothing
end


# -------------------------------


function buildSubplotObject!(::ImmersePackage, subplt::Subplot)

  # create the Gtk window with vertical box vsep
  d = subplt.initargs[1]
  w,h = d[:size]
  vsep = Gtk.GtkBoxLeaf(:v)
  win = Gtk.GtkWindowLeaf(vsep, d[:windowtitle], w, h)

  # add the plot boxes
  i = 0
  rows = []
  figindices = []
  for rowcnt in subplt.layout.rowcounts

    # create a new row and add it to the main Box vsep
    row = Gtk.GtkBoxLeaf(:h)
    push!(vsep, row)

    # now add the plot components to the row
    for plt in subplt.plts[(1:rowcnt) + i]

      # get the components... box is the main plot GtkBox, and canvas is the GtkCanvas where it's plotted
      box, toolbar, canvas = Immerse.createPlotGuiComponents()

      # add the plot's box to the row
      push!(row, box)

      # create the figure and store the index returned for destruction later
      figidx = Immerse.figure(canvas)
      push!(figindices, figidx)

      fig = Immerse.figure(figidx)
      plt.o = (fig, plt.o[2])
    end

    i += rowcnt
  end

  # destructor... clean up plots
  Gtk.on_signal_destroy((x...) -> [Immerse.dropfig(_display,i) for i in figindices], win)

  subplt.o = win
end


# # create the underlying object
# function buildSubplotObject!(::ImmersePackage, subplt::Subplot)
#   subplt.o = (nothing, nothing)
# end


function Base.display(::ImmersePackage, subplt::Subplot)

  # display the plots by creating a fresh Immerse.Figure object from the GtkCanvas and Gadfly.Plot
  for plt in subplt.plts
    fig, gplt = plt.o
    Immerse.figure(fig.figno; displayfig = false)
    display(gplt)
    # display(Immerse.Figure(fig.canvas, gplt))
  end

  # o is the window... show it
  showall(subplt.o)
end
