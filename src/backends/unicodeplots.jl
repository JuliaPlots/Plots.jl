
# https://github.com/Evizero/UnicodePlots.jl

supported_args(::UnicodePlotsBackend) = [
    # :annotations,
    # :args,
    # :axis,
    # :background_color,
    # :linecolor,
    # :fill,
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
    # :linewidth,
    :markershape,
    # :markercolor,
    # :markersize,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    :bins,
    # :nc,
    # :nr,
    # :pos,
    # :reg,
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
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supported_types(::UnicodePlotsBackend) = [
    :path, :steppre, :steppost, :scatter,
    :histogram2d, :hline, :vline
]
supported_styles(::UnicodePlotsBackend) = [:auto, :solid]
supported_markers(::UnicodePlotsBackend) = [:none, :auto, :ellipse]
supported_scales(::UnicodePlotsBackend) = [:identity]
is_subplot_supported(::UnicodePlotsBackend) = true


# don't warn on unsupported... there's just too many warnings!!
warnOnUnsupported_args(pkg::UnicodePlotsBackend, d::KW) = nothing

# --------------------------------------------------------------------------------------

function _initialize_backend(::UnicodePlotsBackend; kw...)
  @eval begin
    import UnicodePlots
    export UnicodePlots
  end
end

# -------------------------------

# convert_size_from_pixels(sz) =

# do all the magic here... build it all at once, since we need to know about all the series at the very beginning
function rebuildUnicodePlot!(plt::Plot)
    plt.o = []
    for sp in plt.subplots
        xaxis = sp[:xaxis]
        yaxis = sp[:yaxis]
        xlim =  axis_limits(xaxis)
        ylim =  axis_limits(yaxis)

        # make vectors
        xlim = [xlim[1], xlim[2]]
        ylim = [ylim[1], ylim[2]]

        # we set x/y to have a single point, since we need to create the plot with some data.
        # since this point is at the bottom left corner of the plot, it shouldn't actually be shown
        x = Float64[xlim[1]]
        y = Float64[ylim[1]]

        # create a plot window with xlim/ylim set, but the X/Y vectors are outside the bounds
        width, height = plt[:size]
        o = UnicodePlots.Plot(x, y;
            width = width,
            height = height,
            title = sp[:title],
            xlim = xlim,
            ylim = ylim
        )

        # set the axis labels
        UnicodePlots.xlabel!(o, xaxis[:guide])
        UnicodePlots.ylabel!(o, yaxis[:guide])

        # now use the ! functions to add to the plot
        for series in series_list(sp)
            addUnicodeSeries!(o, series.d, sp[:legend] != :none, xlim, ylim)
        end

        # save the object
        push!(plt.o, o)
    end
end

# # do all the magic here... build it all at once, since we need to know about all the series at the very beginning
# function rebuildUnicodePlot!(plt::Plot)
#
#   # figure out the plotting area xlim = [xmin, xmax] and ylim = [ymin, ymax]
#   sargs = plt.seriesargs
#   iargs = plt.attr
#
#   # get the x/y limits
#   if get(iargs, :xlims, :auto) == :auto
#     xlim = [Inf, -Inf]
#     for d in sargs
#       _expand_limits(xlim, d[:x])
#     end
#   else
#     xmin, xmax = iargs[:xlims]
#     xlim = [xmin, xmax]
#   end
#
#   if get(iargs, :ylims, :auto) == :auto
#     ylim = [Inf, -Inf]
#     for d in sargs
#       _expand_limits(ylim, d[:y])
#     end
#   else
#     ymin, ymax = iargs[:ylims]
#     ylim = [ymin, ymax]
#   end
#
#   # we set x/y to have a single point, since we need to create the plot with some data.
#   # since this point is at the bottom left corner of the plot, it shouldn't actually be shown
#   x = Float64[xlim[1]]
#   y = Float64[ylim[1]]
#
#   # create a plot window with xlim/ylim set, but the X/Y vectors are outside the bounds
#   width, height = iargs[:size]
#   o = UnicodePlots.Plot(x, y; width = width,
#                                 height = height,
#                                 title = iargs[:title],
#                                 # labels = iargs[:legend],
#                                 xlim = xlim,
#                                 ylim = ylim)
#
#   # set the axis labels
#   UnicodePlots.xlabel!(o, iargs[:xguide])
#   UnicodePlots.ylabel!(o, iargs[:yguide])
#
#   # now use the ! functions to add to the plot
#   for d in sargs
#     addUnicodeSeries!(o, d, iargs[:legend] != :none, xlim, ylim)
#   end
#
#   # save the object
#   plt.o = o
# end


# add a single series
function addUnicodeSeries!(o, d::KW, addlegend::Bool, xlim, ylim)

    # get the function, or special handling for step/bar/hist
    st = d[:seriestype]

    # handle hline/vline separately
    if st in (:hline,:vline)
        for yi in d[:y]
            if st == :hline
                UnicodePlots.lineplot!(o, xlim, [yi,yi])
            else
                UnicodePlots.lineplot!(o, [yi,yi], ylim)
            end
        end
        return

    # elseif st == :bar
    #     UnicodePlots.barplot!(o, d[:x], d[:y])
    #     return

    # elseif st == :histogram
    #     UnicodePlots.histogram!(o, d[:y], bins = d[:bins])
    #     return

    elseif st == :histogram2d
        UnicodePlots.densityplot!(o, d[:x], d[:y])
        return

    end

  stepstyle = :post
  if st == :path
    func = UnicodePlots.lineplot!
  elseif st == :scatter || d[:markershape] != :none
    func = UnicodePlots.scatterplot!
  elseif st == :steppost
    func = UnicodePlots.stairs!
  elseif st == :steppre
    func = UnicodePlots.stairs!
    stepstyle = :pre
  else
    error("Linestyle $st not supported by UnicodePlots")
  end

  # get the series data and label
  x, y = [collect(float(d[s])) for s in (:x, :y)]
  label = addlegend ? d[:label] : ""

  # if we happen to pass in allowed color symbols, great... otherwise let UnicodePlots decide
  color = d[:linecolor] in UnicodePlots.color_cycle ? d[:linecolor] : :auto

  # add the series
  func(o, x, y; color = color, name = label, style = stepstyle)
end


# function handlePlotColors(::UnicodePlotsBackend, d::KW)
#   # TODO: something special for unicodeplots, since it doesn't take kindly to people messing with its color palette
#   d[:color_palette] = [RGB(0,0,0)]
# end

# -------------------------------


# function _create_plot(pkg::UnicodePlotsBackend, d::KW)
  # plt = Plot(nothing, pkg, 0, d, KW[])

function _create_backend_figure(plt::Plot{UnicodePlotsBackend})
  # do we want to give a new default size?
  # if !haskey(plt.attr, :size) || plt.attr[:size] == default(:size)
  #   plt.attr[:size] = (60,20)
  # end
  w, h = plt[:size]
  plt.attr[:size] = div(w, 10), div(h, 20)
  plt.attr[:color_palette] = [RGB(0,0,0)]
  nothing

  # plt
end

# function _series_added(plt::Plot{UnicodePlotsBackend}, series::Series)
#     d = series.d
#     # TODO don't need these once the "bar" series recipe is done
#   if d[:seriestype] in (:sticks, :bar)
#     d = barHack(; d...)
#   elseif d[:seriestype] == :histogram
#     d = barHack(; histogramHack(; d...)...)
#   end
#   # push!(plt.seriesargs, d)
#   # plt
# end
#
#
# function _update_plot_object(plt::Plot{UnicodePlotsBackend}, d::KW)
#   for k in (:title, :xguide, :yguide, :xlims, :ylims)
#     if haskey(d, k)
#       plt.attr[k] = d[k]
#     end
#   end
# end


# -------------------------------

# since this is such a hack, it's only callable using `png`... should error during normal `writemime`
function png(plt::AbstractPlot{UnicodePlotsBackend}, fn::AbstractString)
  fn = addExtension(fn, "png")

  # make some whitespace and show the plot
  println("\n\n\n\n\n\n")
  gui(plt)

  # @osx_only begin
  @compat @static if is_apple()
    # BEGIN HACK

    # wait while the plot gets drawn
    sleep(0.5)

    # use osx screen capture when my terminal is maximized and cursor starts at the bottom (I know, right?)
    # TODO: compute size of plot to adjust these numbers (or maybe implement something good??)
    run(`screencapture -R50,600,700,420 $fn`)

    # END HACK (phew)
    return
  end

  error("Can only savepng on osx with UnicodePlots (though even then I wouldn't do it)")
end

# -------------------------------

# we don't do very much for subplots... just stack them vertically

# function _create_subplot(subplt::Subplot{UnicodePlotsBackend}, isbefore::Bool)
#   isbefore && return false
#   true
# end


function _display(plt::Plot{UnicodePlotsBackend})
  rebuildUnicodePlot!(plt)
  map(show, plt.o)
  nothing
end



# function Base.display(::PlotsDisplay, subplt::Subplot{UnicodePlotsBackend})
#   for plt in subplt.plts
#     gui(plt)
#   end
# end
