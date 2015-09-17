
# https://github.com/nolta/Winston.jl

# credit goes to https://github.com/jverzani for contributing to the first draft of this backend implementation

immutable WinstonPackage <: PlottingPackage end

export winston!
winston!() = plotter!(:winston)

# ---------------------------------------------------------------------------


## dictionaries for conversion of Plots.jl names to Winston ones.
const winston_linestyle =  Dict(:solid=>"solid",
                                :dash=>"dash",
                                :dot=>"dotted",
                                :dashdot=>"dotdashed"
                               )

const winston_marker = Dict(:none=>".",
                            :rect => "square",
                            :ellipse=>"circle",
                            :diamond=>"diamond",
                            :utriangle=>"triangle",
                            :dtriangle=>"down-triangle",
                            :cross => "plus",
                            :xcross => "cross",
                            :star1 => "asterisk"
                           )


supportedArgs(::WinstonPackage) = setdiff(ARGS, [:heatmap_c, :fillto, :pos, :markercolor, :background_color])
supportedAxes(::WinstonPackage) = [:auto, :left]
supportedTypes(::WinstonPackage) = [:none, :line, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonPackage) = intersect(ALL_STYLES, collect(keys(winston_linestyle))) # [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::WinstonPackage) = intersect(ALL_MARKERS, collect(keys(winston_marker))) # [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1]
subplotSupported(::WinstonPackage) = false

# ---------------------------------------------------------------------------


# function createWinstonFigure(d::Dict)
#   # println("Creating immerse figure: ", d)
#   w,h = d[:size]
#   figidx = Winston.figure(; name = d[:windowtitle], width = w, height = h)
#   Winston.Figure(figidx)
# end



function plot(pkg::WinstonPackage; kw...)
  d = Dict(kw)

  # bgcolor

  # create a new window
  # the call to figure does a few things here:
  #   get a new unique id
  #   create a new GtkWindow (or Tk?)

  # w,h = d[:size]
  # canvas = Gtk.GtkCanvasLeaf()
  # window = Gtk.GtkWindowLeaf(canvas, d[:windowtitle], w, h)

  # figidx = Winston.figure(; name = d[:windowtitle], width = w, height = h)

  # # skip the current fig stuff... just grab the fig directly
  # fig = Winston._display.figs[figidx]

  # overwrite the placeholder FramedPlot with our own
  # fig.plot = Winston.FramedPlot(title = d[:title], xlabel = d[:xlabel], ylabel = d[:ylabel])
  wplt = Winston.FramedPlot(title = d[:title], xlabel = d[:xlabel], ylabel = d[:ylabel])

  # # using the figure index returned from Winston.figure, make this plot current and get the 
  # # Figure object (fields: window::GtkWindow and plot::FramedPlot)
  # Winston.switchfig(Winston._display, figidx)
  # fig = Winston.curfig(Winston._display)
  # Winston._pwinston = fig.plot



  # Winston.setattr(fig.plot, "xlabel", d[:xlabel])
  # Winston.setattr(fig.plot, "ylabel", d[:ylabel])
  # Winston.setattr(fig.plot, "title",  d[:title])
  
  Plot(wplt, pkg, 0, d, Dict[])
  # Plot((window, canvas, wplt), pkg, 0, d, Dict[])
  # Plot((fig, figidx), pkg, 0, d, Dict[])
end

copy_remove(d::Dict, s::Symbol) = delete!(copy(d), s)

function addRegressionLineWinston(d::Dict, wplt)
  xs, ys = regressionXY(d[:x], d[:y])
  Winston.add(wplt, Winston.Curve(xs, ys, kind="dotted"))
end

function getWinstonItems(plt::Plot)
  if isa(plt.o, Winston.FramedPlot)
    wplt = plt.o
    window, canvas = nothing, nothing
  else
    window, canvas, wplt = plt.o
  end
  window, canvas, wplt
end

function plot!(::WinstonPackage, plt::Plot; kw...)
  d = Dict(kw)
  
  # # make this figure current
  # fig, figidx = plt.o
  # Winston.switchfig(Winston._display, figidx)

  window, canvas, wplt = getWinstonItems(plt)

  # until we call it normally, do the hack
  if d[:linetype] == :bar
    d = barHack(;d...)
  end


  e = Dict()
  e[:color] = d[:color]
  e[:linewidth] = d[:width]
  e[:kind] = winston_linestyle[d[:linestyle]]
  e[:symbolkind] = winston_marker[d[:marker]]
  # markercolor     # same choices as `color`, or :match will set the color to be the same as `color`
  e[:symbolsize] = d[:markersize] / 5
  # fillto          # fillto value for area plots

  # pos             # (Int,Int), move the enclosing window to this position
  # screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)



  ## lintype :line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar
  if d[:linetype] == :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))

  elseif d[:linetype] == :line
    x, y = d[:x], d[:y]
    Winston.add(wplt, Winston.Curve(x, y; e...))

    fillto = d[:fillto]
    if fillto != nothing
      if isa(fillto, AbstractVector)
        y2 = fillto
      else
        y2 = Float64[fillto for yi in y]
      end
      Winston.add(wplt, Winston.FillBetween(x, y, x, y2, fillcolor=d[:color]))
    end

  elseif d[:linetype] == :scatter
    if d[:marker] == :none
      d[:marker] = :ellipse
    end

  # elseif d[:linetype] == :step
  #     fn = Winston.XXX

  # elseif d[:linetype] == :stepinverted
  #     fn = Winston.XXX

  elseif d[:linetype] == :sticks
      Winston.add(wplt, Winston.Stems(d[:x], d[:y]; e...))

  # elseif d[:linetype] == :dots
  #     fn = Winston.XXX

  # elseif d[:linetype] == :heatmap
  #     fn = Winston.XXX

  # elseif d[:linetype] == :hexbin
  #     fn = Winston.XXX

  elseif d[:linetype] == :hist
      hst = hist(d[:y], d[:nbins])
      Winston.add(wplt, Winston.Histogram(hst...; copy_remove(e, :nbins)...))

  # elseif d[:linetype] == :bar
  #     # fn = Winston.XXX

  else
    error("linetype $(d[:linetype]) not supported by Winston.")

  end


  # marker
  if d[:marker] != :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))
  end


  # optionally add a regression line
  d[:reg] && d[:linetype] != :hist && addRegressionLineWinston(d, wplt)

  push!(plt.seriesargs, d)
  plt
end


function addWinstonLegend(plt::Plot, wplt)
  Winston.legend(wplt, [sd[:label] for sd in plt.seriesargs])
end


function Base.display(::WinstonPackage, plt::Plot)
  # recreate the legend
  # fig, figidx = plt.o

  window, canvas, wplt = getWinstonItems(plt)

  if window == nothing
    # initialize window
    w,h = plt.initargs[:size]
    canvas = Gtk.GtkCanvasLeaf()
    window = Gtk.GtkWindowLeaf(canvas, plt.initargs[:windowtitle], w, h)
    # wplt = plt.o
    plt.o = (window, canvas, wplt)
  # else
  #   window, canvas, wplt = plt.o
  end

  addWinstonLegend(plt, wplt)

  Winston.display(canvas, wplt)
  Gtk.showall(window)


  # # display the Figure
  # display(fig)

  # display(plt.o.window)

  # # show it
  # Winston.display(plt.o.plot)
end

# -------------------------------

function savepng(::WinstonPackage, plt::PlottingObject, fn::String; kw...)
  f = open(fn, "w")
  window, canvas, wplt = getWinstonItems(plt)
  addWinstonLegend(plt, wplt)
  writemime(f, "image/png", wplt)
  close(f)
end


# -------------------------------

function buildSubplotObject!(::WinstonPackage, subplt::Subplot)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end


function Base.display(::WinstonPackage, subplt::Subplot)
  # TODO: display/show the Subplot object
end
