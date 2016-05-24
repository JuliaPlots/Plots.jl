
# https://github.com/JuliaGraphics/Immerse.jl

supportedArgs(::ImmerseBackend) = supportedArgs(GadflyBackend())
supportedAxes(::ImmerseBackend) = supportedAxes(GadflyBackend())
supportedTypes(::ImmerseBackend) = supportedTypes(GadflyBackend())
supportedStyles(::ImmerseBackend) = supportedStyles(GadflyBackend())
supportedMarkers(::ImmerseBackend) = supportedMarkers(GadflyBackend())
supportedScales(::ImmerseBackend) = supportedScales(GadflyBackend())
subplotSupported(::ImmerseBackend) = true

# --------------------------------------------------------------------------------------

function _initialize_backend(::ImmerseBackend; kw...)
  @eval begin
    import Immerse, Gadfly, Compose, Gtk
    export Immerse, Gadfly, Compose, Gtk
    include(joinpath(Pkg.dir("Plots"), "src", "backends", "gadfly_shapes.jl"))
  end
end

function createImmerseFigure(d::KW)
  w,h = d[:size]
  figidx = Immerse.figure(; name = d[:window_title], width = w, height = h)
  Immerse.Figure(figidx)
end

# ----------------------------------------------------------------


# create a blank Gadfly.Plot object
# function _create_plot(pkg::ImmerseBackend, d::KW)
#   # create the underlying Gadfly.Plot object
#   gplt = createGadflyPlotObject(d)
#
#   # save both the Immerse.Figure and the Gadfly.Plot
#   Plot((nothing,gplt), pkg, 0, d, KW[])
# end
function _create_backend_figure(plt::Plot{ImmerseBackend})
    (nothing, createGadflyPlotObject(plt.attr))
end


# # plot one data series
# function _series_added(::ImmerseBackend, plt::Plot, d::KW)
#   addGadflySeries!(plt, d)
#   push!(plt.seriesargs, d)
#   plt
# end

function _series_added(plt::Plot{ImmerseBackend}, series::Series)
    addGadflySeries!(plt, series.d)
end


function _update_plot(plt::Plot{ImmerseBackend}, d::KW)
  updateGadflyGuides(plt, d)
  updateGadflyPlotTheme(plt, d)
end



# ----------------------------------------------------------------

function _add_annotations{X,Y,V}(plt::Plot{ImmerseBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    push!(getGadflyContext(plt).guides, createGadflyAnnotationObject(ann...))
  end
end

# ----------------------------------------------------------------

# accessors for x/y data

function getxy(plt::Plot{ImmerseBackend}, i::Integer)
  mapping = getGadflyMappings(plt, i)[1]
  mapping[:x], mapping[:y]
end

function setxy!{X,Y}(plt::Plot{ImmerseBackend}, xy::Tuple{X,Y}, i::Integer)
  for mapping in getGadflyMappings(plt, i)
    mapping[:x], mapping[:y] = xy
  end
  plt
end


# ----------------------------------------------------------------


# function _create_subplot(subplt::Subplot{ImmerseBackend}, isbefore::Bool)
#   return false
#   # isbefore && return false
# end
#
# function showSubplotObject(subplt::Subplot{ImmerseBackend})
#   # create the Gtk window with vertical box vsep
#   d = getattr(subplt,1)
#   w,h = d[:size]
#   vsep = Gtk.GtkBoxLeaf(:v)
#   win = Gtk.GtkWindowLeaf(vsep, d[:window_title], w, h)
#
#   figindices = []
#   row = Gtk.GtkBoxLeaf(:h)
#   push!(vsep, row)
#   for (i,(r,c)) in enumerate(subplt.layout)
#     plt = subplt.plts[i]
#
#     # get the components... box is the main plot GtkBox, and canvas is the GtkCanvas where it's plotted
#     box, toolbar, canvas = Immerse.createPlotGuiComponents()
#
#     # add the plot's box to the row
#     push!(row, box)
#
#     # create the figure and store the index returned for destruction later
#     figidx = Immerse.figure(canvas)
#     push!(figindices, figidx)
#
#     fig = Immerse.figure(figidx)
#     plt.o = (fig, plt.o[2])
#
#     # add the row
#     if c == ncols(subplt.layout, r)
#       row = Gtk.GtkBoxLeaf(:h)
#       push!(vsep, row)
#     end
#
#   end
#
#   # destructor... clean up plots
#   Gtk.on_signal_destroy((x...) -> ([Immerse.dropfig(Immerse._display,i) for i in figindices]; subplt.o = nothing), win)
#
#   subplt.o = win
#   true
# end


function _remove_axis(plt::Plot{ImmerseBackend}, isx::Bool)
  gplt = getGadflyContext(plt)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
  addOrReplace(gplt.guides, isx ? Gadfly.Guide.xlabel : Gadfly.Guide.ylabel, "")
end

function _expand_limits(lims, plt::Plot{ImmerseBackend}, isx::Bool)
  for l in getGadflyContext(plt).layers
    _expand_limits(lims, l.mapping[isx ? :x : :y])
  end
end


# ----------------------------------------------------------------

getGadflyContext(plt::Plot{ImmerseBackend}) = plt.o[2]
# getGadflyContext(subplt::Subplot{ImmerseBackend}) = buildGadflySubplotContext(subplt)


function Base.display(::PlotsDisplay, plt::Plot{ImmerseBackend})

  fig, gplt = plt.o
  if fig == nothing
    fig = createImmerseFigure(plt.attr)
    Gtk.on_signal_destroy((x...) -> (Immerse.dropfig(Immerse._display, fig.figno); plt.o = (nothing,gplt)), fig.canvas)
    plt.o = (fig, gplt)
  end

  Immerse.figure(fig.figno; displayfig = false)
  display(gplt)
end


# function Base.display(::PlotsDisplay, subplt::Subplot{ImmerseBackend})
#
#   # if we haven't created the window yet, do it
#   if subplt.o == nothing
#     showSubplotObject(subplt)
#   end
#
#   # display the plots by creating a fresh Immerse.Figure object from the GtkCanvas and Gadfly.Plot
#   for plt in subplt.plts
#     fig, gplt = plt.o
#     Immerse.figure(fig.figno; displayfig = false)
#     display(gplt)
#   end
#
#   # o is the window... show it
#   showall(subplt.o)
# end
