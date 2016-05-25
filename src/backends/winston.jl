
# https://github.com/nolta/Winston.jl

# credit goes to https://github.com/jverzani for contributing to the first draft of this backend implementation

supportedArgs(::WinstonBackend) = [
    :annotations,
    # :args,
    # :axis,
    # :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    # :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    # :layout,
    :legend,
    :seriescolor, :seriesalpha,
    :linestyle,
    :seriestype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    :bins,
    # :nc,
    # :nr,
    # :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :window_title,
    :x,
    :xguide,
    :xlims,
    # :xticks,
    :y,
    :yguide,
    :ylims,
    # :yrightlabel,
    # :yticks,
    :xscale,
    :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedAxes(::WinstonBackend) = [:auto, :left]
supportedTypes(::WinstonBackend) = [:none, :line, :path, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::WinstonBackend) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5]
supportedScales(::WinstonBackend) = [:identity, :log10]
subplotSupported(::WinstonBackend) = false


# --------------------------------------------------------------------------------------


function _initialize_backend(::WinstonBackend; kw...)
  @eval begin
    # ENV["WINSTON_OUTPUT"] = "gtk"
    warn("Winston is no longer supported... many features will likely be broken.")
    import Winston, Gtk
    export Winston, Gtk
  end
end

# ---------------------------------------------------------------------------


## dictionaries for conversion of Plots.jl names to Winston ones.
@compat const winston_linestyle =  KW(:solid=>"solid",
                                :dash=>"dash",
                                :dot=>"dotted",
                                :dashdot=>"dotdashed"
                               )

@compat const winston_marker = KW(:none=>".",
                            :rect => "square",
                            :ellipse=>"circle",
                            :diamond=>"diamond",
                            :utriangle=>"triangle",
                            :dtriangle=>"down-triangle",
                            :cross => "plus",
                            :xcross => "cross",
                            :star5 => "asterisk"
                           )

function _before_update(plt::Plot{WinstonBackend})
  Winston.ghf(plt.o)
end

# ---------------------------------------------------------------------------

function _create_backend_figure(plt::Plot{WinstonBackend})
    Winston.FramedPlot(
        title = plt.attr[:title],
        xlabel = plt.attr[:xguide],
        ylabel = plt.attr[:yguide]
    )
end

copy_remove(d::KW, s::Symbol) = delete!(copy(d), s)

function addRegressionLineWinston(d::KW, wplt)
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

function _series_added(plt::Plot{WinstonBackend}, series::Series)
    d = series.d
  window, canvas, wplt = getWinstonItems(plt)

  # until we call it normally, do the hack
  if d[:seriestype] == :bar
    d = barHack(;d...)
  end


  e = KW()
  e[:color] = getColor(d[:linecolor])
  e[:linewidth] = d[:linewidth]
  e[:kind] = winston_linestyle[d[:linestyle]]
  e[:symbolkind] = winston_marker[d[:markershape]]
  # markercolor     # same choices as `color`, or :match will set the color to be the same as `color`
  e[:symbolsize] = d[:markersize] / 5

  # pos             # (Int,Int), move the enclosing window to this position
  # screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)



  ## lintype :path, :step, :stepinverted, :sticks, :dots, :none, :hist2d, :hexbin, :hist, :bar
  if d[:seriestype] == :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)..., color=getColor(d[:markercolor])))

  elseif d[:seriestype] == :path
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

  elseif d[:seriestype] == :scatter
    if d[:markershape] == :none
      d[:markershape] = :ellipse
    end

  # elseif d[:seriestype] == :step
  #     fn = Winston.XXX

  # elseif d[:seriestype] == :stepinverted
  #     fn = Winston.XXX

  elseif d[:seriestype] == :sticks
      Winston.add(wplt, Winston.Stems(d[:x], d[:y]; e...))

  # elseif d[:seriestype] == :dots
  #     fn = Winston.XXX

  # elseif d[:seriestype] == :hist2d
  #     fn = Winston.XXX

  # elseif d[:seriestype] == :hexbin
  #     fn = Winston.XXX

  elseif d[:seriestype] == :hist
      hst = hist(d[:y], d[:bins])
      Winston.add(wplt, Winston.Histogram(hst...; copy_remove(e, :bins)...))

  # elseif d[:seriestype] == :bar
  #     # fn = Winston.XXX

  else
    error("seriestype $(d[:seriestype]) not supported by Winston.")

  end


  # markershape
  if d[:markershape] != :none
    Winston.add(wplt, Winston.Points(d[:x], d[:y]; copy_remove(e, :kind)..., color=getColor(d[:markercolor])))
  end


  # optionally add a regression line
  d[:smooth] && d[:seriestype] != :hist && addRegressionLineWinston(d, wplt)

  # push!(plt.seriesargs, d)
  # plt
end


# ----------------------------------------------------------------

@compat const _winstonNames = KW(
    :xlims => :xrange,
    :ylims => :yrange,
    :xscale => :xlog,
    :yscale => :ylog,
  )

function _update_plot_object(plt::Plot{WinstonBackend}, d::KW)
  window, canvas, wplt = getWinstonItems(plt)
  for k in (:xguide, :yguide, :title, :xlims, :ylims)
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

function createWinstonAnnotationObject(plt::Plot{WinstonBackend}, x, y, val::@compat(AbstractString))
  Winston.text(x, y, val)
end

function _add_annotations{X,Y,V}(plt::Plot{WinstonBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    createWinstonAnnotationObject(plt, ann...)
  end
end


# ----------------------------------------------------------------

# function _create_subplot(subplt::Subplot{WinstonBackend}, isbefore::Bool)
#   # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
# end

# ----------------------------------------------------------------

function addWinstonLegend(plt::Plot, wplt)
  if plt.attr[:legend] != :none
    Winston.legend(wplt, [sd[:label] for sd in plt.seriesargs])
  end
end

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{WinstonBackend})
  window, canvas, wplt = getWinstonItems(plt)
  addWinstonLegend(plt, wplt)
  writemime(io, "image/png", wplt)
end


function Base.display(::PlotsDisplay, plt::Plot{WinstonBackend})

  window, canvas, wplt = getWinstonItems(plt)

  if window == nothing
    if Winston.output_surface != :gtk
      error("Gtk is the only supported display for Winston in Plots.  Set `output_surface = gtk` in src/Winston.ini")
    end
    # initialize window
    w,h = plt.attr[:size]
    canvas = Gtk.GtkCanvasLeaf()
    window = Gtk.GtkWindowLeaf(canvas, plt.attr[:window_title], w, h)
    plt.o = (window, canvas, wplt)
  end

  addWinstonLegend(plt, wplt)

  Winston.display(canvas, wplt)
  Gtk.showall(window)
end


# function Base.display(::PlotsDisplay, subplt::Subplot{WinstonBackend})
#   # TODO: display/show the Subplot object
# end
