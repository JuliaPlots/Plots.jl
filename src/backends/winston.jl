
# https://github.com/nolta/Winston.jl

# credit goes to https://github.com/jverzani for contributing to the first draft of this backend implementation


# ---------------------------------------------------------------------------


## dictionaries for conversion of Plots.jl names to Winston ones.
@compat const winston_linestyle =  Dict(:solid=>"solid",
                                :dash=>"dash",
                                :dot=>"dotted",
                                :dashdot=>"dotdashed"
                               )

@compat const winston_marker = Dict(:none=>".",
                            :rect => "square",
                            :ellipse=>"circle",
                            :diamond=>"diamond",
                            :utriangle=>"triangle",
                            :dtriangle=>"down-triangle",
                            :cross => "plus",
                            :xcross => "cross",
                            :star5 => "asterisk"
                           )

function _before_add_series(plt::Plot{WinstonPackage})
  Winston.ghf(plt.o)
end

# ---------------------------------------------------------------------------


function _create_plot(pkg::WinstonPackage; kw...)
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

function _add_series(::WinstonPackage, plt::Plot; kw...)
  d = Dict(kw)

  window, canvas, wplt = getWinstonItems(plt)

  # until we call it normally, do the hack
  if d[:linetype] == :bar
    d = barHack(;d...)
  end


  e = Dict()
  e[:color] = getColor(d[:linecolor])
  e[:linewidth] = d[:linewidth]
  e[:kind] = winston_linestyle[d[:linestyle]]
  e[:symbolkind] = winston_marker[d[:markershape]]
  # markercolor     # same choices as `color`, or :match will set the color to be the same as `color`
  e[:symbolsize] = d[:markersize] / 5

  # pos             # (Int,Int), move the enclosing window to this position
  # screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)



  ## lintype :path, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar
  if d[:linetype] == :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)..., color=getColor(d[:markercolor])))

  elseif d[:linetype] == :path
    x, y = d[:x], d[:y]
    Winston.add(wplt, Winston.Curve(x, y; e...))

    fillrange = d[:fillrange]
    if fillrange != nothing
      if isa(fillrange, AbstractVector)
        y2 = fillrange
      else
        y2 = Float64[fillrange for yi in y]
      end
      Winston.add(wplt, Winston.FillBetween(x, y, x, y2, fillcolor=getColor(d[:fillcolor])))
    end

  elseif d[:linetype] == :scatter
    if d[:markershape] == :none
      d[:markershape] = :ellipse
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


  # markershape
  if d[:markershape] != :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)..., color=getColor(d[:markercolor])))
  end


  # optionally add a regression line
  d[:smooth] && d[:linetype] != :hist && addRegressionLineWinston(d, wplt)

  push!(plt.seriesargs, d)
  plt
end


# ----------------------------------------------------------------

@compat const _winstonNames = Dict(
    :xlims => :xrange,
    :ylims => :yrange,
    :xscale => :xlog,
    :yscale => :ylog,
  )

function _update_plot(plt::Plot{WinstonPackage}, d::Dict)
  window, canvas, wplt = getWinstonItems(plt)
  for k in (:xlabel, :ylabel, :title, :xlims, :ylims)
    if haskey(d, k)
      Winston.setattr(wplt, string(get(_winstonNames, k, k)), d[k])
    end
  end

  for k in (:xscale, :yscale)
    if haskey(d, k)
      islogscale = d[k] == :log10
      Winston.setattr(wplt, (k == :xscale ? :xlog : :ylog), islogscale)
    end
  end

end



# ----------------------------------------------------------------

function createWinstonAnnotationObject(plt::Plot{WinstonPackage}, x, y, val::@compat(AbstractString))
  Winston.text(x, y, val)
end

function _add_annotations{X,Y,V}(plt::Plot{WinstonPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    createWinstonAnnotationObject(plt, ann...)
  end
end


# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{WinstonPackage}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

# ----------------------------------------------------------------

function addWinstonLegend(plt::Plot, wplt)
  if plt.plotargs[:legend]
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
    if Winston.output_surface != :gtk
      error("Gtk is the only supported display for Winston in Plots.  Set `output_surface = gtk` in src/Winston.ini")
    end
    # initialize window
    w,h = plt.plotargs[:size]
    canvas = Gtk.GtkCanvasLeaf()
    window = Gtk.GtkWindowLeaf(canvas, plt.plotargs[:windowtitle], w, h)
    plt.o = (window, canvas, wplt)
  end

  addWinstonLegend(plt, wplt)

  Winston.display(canvas, wplt)
  Gtk.showall(window)
end


function Base.display(::PlotsDisplay, subplt::Subplot{WinstonPackage})
  # TODO: display/show the Subplot object
end
