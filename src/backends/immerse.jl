
# https://github.com/JuliaGraphics/Immerse.jl


function createImmerseFigure(d::Dict)
  w,h = d[:size]
  figidx = Immerse.figure(; name = d[:windowtitle], width = w, height = h)
  Immerse.Figure(figidx)
end

# ----------------------------------------------------------------


# create a blank Gadfly.Plot object
function _create_plot(pkg::ImmersePackage; kw...)
  d = Dict(kw)

  # create the underlying Gadfly.Plot object
  gplt = createGadflyPlotObject(d)

  # save both the Immerse.Figure and the Gadfly.Plot
  Plot((nothing,gplt), pkg, 0, d, Dict[])
end


# plot one data series
function _add_series(::ImmersePackage, plt::Plot; kw...)
  d = Dict(kw)
  addGadflySeries!(plt, d)
  push!(plt.seriesargs, d)
  plt
end


function _update_plot(plt::Plot{ImmersePackage}, d::Dict)
  updateGadflyGuides(plt, d)
  updateGadflyPlotTheme(plt, d)
end



# ----------------------------------------------------------------

function _add_annotations{X,Y,V}(plt::Plot{ImmersePackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    push!(getGadflyContext(plt).guides, createGadflyAnnotationObject(ann...))
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{ImmersePackage}, i::Integer)
  mapping = getGadflyMappings(plt, i)[1]
  mapping[:x], mapping[:y]
end

function Base.setindex!(plt::Plot{ImmersePackage}, xy::Tuple, i::Integer)
  for mapping in getGadflyMappings(plt, i)
    mapping[:x], mapping[:y] = xy
  end
  plt
end


# ----------------------------------------------------------------


function _create_subplot(subplt::Subplot{ImmersePackage}, isbefore::Bool)
  return false
  # isbefore && return false
end

function showSubplotObject(subplt::Subplot{ImmersePackage})
  # create the Gtk window with vertical box vsep
  d = getplotargs(subplt,1)
  w,h = d[:size]
  vsep = Gtk.GtkBoxLeaf(:v)
  win = Gtk.GtkWindowLeaf(vsep, d[:windowtitle], w, h)

  figindices = []
  row = Gtk.GtkBoxLeaf(:h)
  push!(vsep, row)
  for (i,(r,c)) in enumerate(subplt.layout)
    plt = subplt.plts[i]

    # get the components... box is the main plot GtkBox, and canvas is the GtkCanvas where it's plotted
    box, toolbar, canvas = Immerse.createPlotGuiComponents()

    # add the plot's box to the row
    push!(row, box)

    # create the figure and store the index returned for destruction later
    figidx = Immerse.figure(canvas)
    push!(figindices, figidx)

    fig = Immerse.figure(figidx)
    plt.o = (fig, plt.o[2])

    # add the row
    if c == ncols(subplt.layout, r)
      row = Gtk.GtkBoxLeaf(:h)
      push!(vsep, row)
    end

  end

  # destructor... clean up plots
  Gtk.on_signal_destroy((x...) -> ([Immerse.dropfig(Immerse._display,i) for i in figindices]; subplt.o = nothing), win)

  subplt.o = win
  true
end


function _remove_axis(plt::Plot{ImmersePackage}, isx::Bool)
  gplt = getGadflyContext(plt)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xlabel : Gadfly.Guide.ylabel, "")
end

function _expand_limits(lims, plt::Plot{ImmersePackage}, isx::Bool)
  for l in getGadflyContext(plt).layers
    _expand_limits(lims, l.mapping[isx ? :x : :y])
  end
end


# ----------------------------------------------------------------

getGadflyContext(plt::Plot{ImmersePackage}) = plt.o[2]
getGadflyContext(subplt::Subplot{ImmersePackage}) = buildGadflySubplotContext(subplt)


function Base.display(::PlotsDisplay, plt::Plot{ImmersePackage})

  fig, gplt = plt.o
  if fig == nothing
    fig = createImmerseFigure(plt.plotargs)
    Gtk.on_signal_destroy((x...) -> (Immerse.dropfig(Immerse._display, fig.figno); plt.o = (nothing,gplt)), fig.canvas)
    plt.o = (fig, gplt)
  end

  Immerse.figure(fig.figno; displayfig = false)
  display(gplt)
end


function Base.display(::PlotsDisplay, subplt::Subplot{ImmersePackage})

  # if we haven't created the window yet, do it
  if subplt.o == nothing
    showSubplotObject(subplt)
  end

  # display the plots by creating a fresh Immerse.Figure object from the GtkCanvas and Gadfly.Plot
  for plt in subplt.plts
    fig, gplt = plt.o
    Immerse.figure(fig.figno; displayfig = false)
    display(gplt)
  end

  # o is the window... show it
  showall(subplt.o)
end
