
# https://github.com/JuliaGraphics/Immerse.jl

immutable ImmersePackage <: PlottingPackage end

export immerse
immerse() = backend(:immerse)


supportedArgs(::ImmersePackage) = supportedArgs(GadflyPackage())
supportedAxes(::ImmersePackage) = supportedAxes(GadflyPackage())
supportedTypes(::ImmersePackage) = supportedTypes(GadflyPackage())
supportedStyles(::ImmersePackage) = supportedStyles(GadflyPackage())
supportedMarkers(::ImmersePackage) = supportedMarkers(GadflyPackage())
supportedScales(::ImmersePackage) = supportedScales(GadflyPackage())


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
  addGadflySeries!(gplt, d, plt.initargs)
  push!(plt.seriesargs, d)
  plt
end


function updatePlotItems(plt::Plot{ImmersePackage}, d::Dict)
  updateGadflyGuides(plt.o[2], d)
end



# ----------------------------------------------------------------

function addAnnotations{X,Y,V}(plt::Plot{ImmersePackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    push!(plt.o[2].guides, createGadflyAnnotationObject(ann...))
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{ImmersePackage}, i::Int)
  data = plt.o[2].layers[end-i+1].mapping
  data[:x], data[:y]
end

function Base.setindex!(plt::Plot{ImmersePackage}, xy::Tuple, i::Integer)
  data = plt.o[2].layers[end-i+1].mapping
  data[:x], data[:y] = xy
  plt
end



# ----------------------------------------------------------------


function buildSubplotObject!(subplt::Subplot{ImmersePackage})

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
  Gtk.on_signal_destroy((x...) -> [Immerse.dropfig(Immerse._display,i) for i in figindices], win)

  subplt.o = win
end

# ----------------------------------------------------------------

getGadflyContext(plt::Plot{ImmersePackage}) = plt.o[2]
getGadflyContext(subplt::Subplot{ImmersePackage}) = buildGadflySubplotContext(subplt)

function Base.writemime(io::IO, ::MIME"image/png", plt::Plot{ImmersePackage})
  gplt = getGadflyContext(plt.backend, plt)
  setGadflyDisplaySize(plt.initargs[:size]...)
  Gadfly.draw(Gadfly.PNG(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end


function Base.display(::PlotsDisplay, plt::Plot{ImmersePackage})

  fig, gplt = plt.o
  if fig == nothing
    fig = createImmerseFigure(plt.initargs)
    plt.o = (fig, gplt)
  end

  Immerse.figure(fig.figno; displayfig = false)
  display(gplt)
end


function Base.writemime(io::IO, ::MIME"image/png", plt::Subplot{ImmersePackage})
  gplt = getGadflyContext(plt)
  setGadflyDisplaySize(plt.initargs[1][:size]...)
  Gadfly.draw(Gadfly.PNG(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end

function Base.display(::PlotsDisplay, subplt::Subplot{ImmersePackage})

  # display the plots by creating a fresh Immerse.Figure object from the GtkCanvas and Gadfly.Plot
  for plt in subplt.plts
    fig, gplt = plt.o
    Immerse.figure(fig.figno; displayfig = false)
    display(gplt)
  end

  # o is the window... show it
  showall(subplt.o)
end
