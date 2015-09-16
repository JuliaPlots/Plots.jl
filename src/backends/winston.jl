
# https://github.com/nolta/Winston.jl

# credit goes to https://github.com/jverzani for the first draft of this backend implementation

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
supportedStyles(::WinstonPackage) = vcat(:auto, keys(winston_linestyle))
supportedMarkers(::WinstonPackage) = vcat(:auto, collect(keys(winston_marker)))
subplotSupported(::WinstonPackage) = false

# ---------------------------------------------------------------------------

function plot(pkg::WinstonPackage; kw...)
  d = Dict(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  o = Winston.FramedPlot()

  # add the title, axis labels, and theme
  Winston.setattr(o, "xlabel", d[:xlabel])
  Winston.setattr(o, "ylabel", d[:ylabel])
  Winston.setattr(o, "title",  d[:title])

  # TODO: add the legend?

  Plot(o, pkg, 0, d, Dict[])
end

copy_remove(d::Dict, s::Symbol) = delete!(copy(d), s)

function addRegressionLineWinston(d::Dict)
  xs, ys = regressionXY(d[:x], d[:y])
  Winston.add(plt.o, Winston.Curve(xs, ys, kind="dotted"))
end

function plot!(::WinstonPackage, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package

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
      Winston.add(plt.o, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))

  elseif d[:linetype] == :line
      Winston.add(plt.o, Winston.Curve(d[:x], d[:y]; e...))

  # elseif d[:linetype] == :step
  #     fn = Winston.XXX

  # elseif d[:linetype] == :stepinverted
  #     fn = Winston.XXX

  elseif d[:linetype] == :sticks
      Winston.add(plt.o, Winston.Stems(d[:x], d[:y]; e...))

  # elseif d[:linetype] == :dots
  #     fn = Winston.XXX

  # elseif d[:linetype] == :heatmap
  #     fn = Winston.XXX

  # elseif d[:linetype] == :hexbin
  #     fn = Winston.XXX

  elseif d[:linetype] == :hist
      hst = hist(d[:y], d[:nbins])
      Winston.add(plt.o, Winston.Histogram(hst...; copy_remove(e, :nbins)...))

  # elseif d[:linetype] == :bar
  #     # fn = Winston.XXX

  end


  # marker
  if d[:marker] != :none
    Winston.add(plt.o, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))
  end


  # optionally add a regression line
  d[:reg] && d[:linetype] != :hist && addRegressionLineWinston(d)

  push!(plt.seriesargs, d)
  plt
end


function Base.display(::WinstonPackage, plt::Plot)
  Winston.display(plt.o)
end

# -------------------------------

function savepng(::WinstonPackage, plt::PlottingObject, fn::String; kw...)
  f = open(fn, "w")
  writemime(f, "image/png", plt.o)
  close(f)
end


# -------------------------------

function buildSubplotObject!(::WinstonPackage, subplt::Subplot)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end


function Base.display(::WinstonPackage, subplt::Subplot)
  # TODO: display/show the Subplot object
end
