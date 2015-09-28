
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


supportedArgs(::WinstonPackage) = setdiff(_allArgs, [:heatmap_c, :fillto, :pos, :markercolor, :background_color, :xlims, :ylims, :xticks, :yticks])
supportedAxes(::WinstonPackage) = [:auto, :left]
supportedTypes(::WinstonPackage) = [:none, :line, :path, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonPackage) = intersect(_allStyles, collect(keys(winston_linestyle)))
supportedMarkers(::WinstonPackage) = intersect(_allMarkers, collect(keys(winston_marker)))
subplotSupported(::WinstonPackage) = false


function preparePlotUpdate(plt::Plot{WinstonPackage})
  Winston.ghf(plt.o)
end

# ---------------------------------------------------------------------------


# function createWinstonFigure(d::Dict)
#   # println("Creating immerse figure: ", d)
#   w,h = d[:size]
#   figidx = Winston.figure(; name = d[:windowtitle], width = w, height = h)
#   Winston.Figure(figidx)
# end



function plot(pkg::WinstonPackage; kw...)
  d = Dict(kw)
  wplt = Winston.FramedPlot(title = d[:title], xlabel = d[:xlabel], ylabel = d[:ylabel])
  
  Plot(wplt, pkg, 0, d, Dict[])
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



  ## lintype :path, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar
  if d[:linetype] == :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)...))

  elseif d[:linetype] == :path
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


function updatePlotItems(plt::Plot{WinstonPackage}, d::Dict)
  window, canvas, wplt = getWinstonItems(plt)
  for k in (:xlabel, :ylabel, :title)
    if haskey(d, k)
      Winston.setattr(wplt, string(k), d[k])
    end
  end
end



# -------------------------------

function createWinstonAnnotationObject(plt::Plot{WinstonPackage}, x, y, val::AbstractString)
  Winston.text(x, y, val)
end

function addAnnotations{X,Y,V}(plt::Plot{WinstonPackage}, anns::AVec{Tuple{X,Y,V}})
  for ann in anns
    createWinstonAnnotationObject(plt, ann...)
  end
end


# -------------------------------

function buildSubplotObject!(subplt::Subplot{WinstonPackage})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

# ----------------------------------------------------------------

function addWinstonLegend(plt::Plot, wplt)
  if plt.initargs[:legend]
    Winston.legend(wplt, [sd[:label] for sd in plt.seriesargs])
  end
end

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{WinstonPackage})
  window, canvas, wplt = getWinstonItems(plt)
  addWinstonLegend(plt, wplt)
  writemime(io, "image/png", wplt)
end


function Base.display(::PlotsDisplay, plt::Plot{WinstonPackage})

  window, canvas, wplt = getWinstonItems(plt)

  if window == nothing
    # initialize window
    w,h = plt.initargs[:size]
    canvas = Gtk.GtkCanvasLeaf()
    window = Gtk.GtkWindowLeaf(canvas, plt.initargs[:windowtitle], w, h)
    plt.o = (window, canvas, wplt)
  end

  addWinstonLegend(plt, wplt)

  Winston.display(canvas, wplt)
  Gtk.showall(window)
end


function Base.display(::PlotsDisplay, subplt::Subplot{WinstonPackage})
  # TODO: display/show the Subplot object
end
