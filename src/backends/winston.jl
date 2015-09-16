
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
                                :dashdot=>"dotdashed",
                                :dashdotdot=>"dotdashed")

const winston_marker = Dict(:none=>".",
                            :ellipse=>"circle",
                            :rect => "square",
                            :diamond=>"diamond",
                            :utriangle=>"triangle",
                            :dtriangle=>"down-triangle",
                            :cross => "cross",
                            :xcross => "cross",
                            :star1 => "asterisk",
                            :star2 => "filled circle",
                            :hexagon => "asterisk"
                            )


supportedArgs(::WinstonPackage) = ARGS
supportedAxes(::WinstonPackage) = [:auto, :left]
supportedTypes(::WinstonPackage) = [:none, :line, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonPackage) = unshift!(collect(keys(winston_linestyle)), :auto)  # vcat(:auto, keys(winston_linestyle))
supportedMarkers(::WinstonPackage) = unshift!(collect(keys(winston_marker)), :auto) # vcat(:auto, collect(keys(winston_marker)))
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
  w,h = d[:size]
  figidx = Winston.figure(; name = d[:windowtitle], width = w, height = h)

  # skip the current fig stuff... just grab the fig directly
  fig = Winston._display.figs[figidx]

  # overwrite the placeholder FramedPlot with our own
  fig.plot = Winston.FramedPlot(title = d[:title], xlabel = d[:xlabel], ylabel = d[:ylabel])

  # # using the figure index returned from Winston.figure, make this plot current and get the 
  # # Figure object (fields: window::GtkWindow and plot::FramedPlot)
  # Winston.switchfig(Winston._display, figidx)
  # fig = Winston.curfig(Winston._display)
  # Winston._pwinston = fig.plot



  # Winston.setattr(fig.plot, "xlabel", d[:xlabel])
  # Winston.setattr(fig.plot, "ylabel", d[:ylabel])
  # Winston.setattr(fig.plot, "title",  d[:title])
  
  Plot((fig, figidx), pkg, 0, d, Dict[])
end

copy_remove(d::Dict, s::Symbol) = delete!(copy(d), s)

function addRegressionLineWinston(d::Dict)
  xs, ys = regressionXY(d[:x], d[:y])
  Winston.add(plt.o.plot, Winston.Curve(xs, ys, kind="dotted"))
end

function plot!(::WinstonPackage, plt::Plot; kw...)
  d = Dict(kw)
  
  # make this figure current
  fig, figidx = plt.o
  Winston.switchfig(Winston._display, figidx)

  # until we call it normally, do the hack
  if d[:linetype] == :bar
    d = barHack(;d...)
  end


  e = Dict()
  e[:color] = d[:color]
  # label           # string or symbol, applies to that line, may go in a legend
  e[:linewidth] = d[:width]
  e[:kind] = winston_linestyle[d[:linestyle]]
  e[:symbolkind] = winston_marker[d[:marker]]
  # markercolor     # same choices as `color`, or :match will set the color to be the same as `color`
  e[:symbolsize] = d[:markersize] / 3
  # fillto          # fillto value for area plots

  # size            # (Int,Int), resize the enclosing window
  # pos             # (Int,Int), move the enclosing window to this position
  # windowtitle     # string or symbol, set the title of the enclosing windowtitle
  # screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)



  ## lintype :line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar
  if d[:linetype] == :none
      Winston.add(fig.plot, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))

  elseif d[:linetype] == :line
      Winston.add(fig.plot, Winston.Curve(d[:x], d[:y]; e...))

  elseif d[:linetype] == :scatter
    if d[:marker] == :none
      d[:marker] = :ellipse
    end

  # elseif d[:linetype] == :step
  #     fn = Winston.XXX

  # elseif d[:linetype] == :stepinverted
  #     fn = Winston.XXX

  elseif d[:linetype] == :sticks
      Winston.add(fig.plot, Winston.Stems(d[:x], d[:y]; e...))

  # elseif d[:linetype] == :dots
  #     fn = Winston.XXX

  # elseif d[:linetype] == :heatmap
  #     fn = Winston.XXX

  # elseif d[:linetype] == :hexbin
  #     fn = Winston.XXX

  elseif d[:linetype] == :hist
      hst = hist(d[:y], d[:nbins])
      Winston.add(fig.plot, Winston.Histogram(hst...; copy_remove(e, :nbins)...))

  # elseif d[:linetype] == :bar
  #     # fn = Winston.XXX

  else
    error("linetype $(d[:linetype]) not supported by Winston.")

  end


  # marker
  if d[:marker] != :none
    Winston.add(fig.plot, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))
  end


  # optionally add a regression line
  d[:reg] && d[:linetype] != :hist && addRegressionLineWinston(d)

  push!(plt.seriesargs, d)
  println("DONE HERE ", figidx)
  plt
end


function Base.display(::WinstonPackage, plt::Plot)
  # recreate the legend
  fig, figidx = plt.o
  println("before legend")
  Winston.legend(fig.plot, [sd[:label] for sd in plt.seriesargs])
  println("after legend")

  # display the Figure
  display(fig)

  # display(plt.o.window)

  # # show it
  # Winston.display(plt.o.plot)
end

# -------------------------------

function savepng(::WinstonPackage, plt::PlottingObject, fn::String; kw...)
  f = open(fn, "w")
  writemime(f, "image/png", plt.o.plot)
  close(f)
end


# -------------------------------

function buildSubplotObject!(::WinstonPackage, subplt::Subplot)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end


function Base.display(::WinstonPackage, subplt::Subplot)
  # TODO: display/show the Subplot object
end
