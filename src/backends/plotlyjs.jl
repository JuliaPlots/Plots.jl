
# https://github.com/spencerlyon2/PlotlyJS.jl

supportedArgs(::PlotlyJSBackend) = [
    :annotation,
    # :axis,
    :background_color,
    :color_palette,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :seriescolor, :seriesalpha,
    :linecolor,
    :linestyle,
    :seriestype,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokestyle,
    :n,
    :bins,
    :nc,
    :nr,
    # :pos,
    # :smooth,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :marker_z,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :levels,
    :xerror,
    :yerror,
    :ribbon,
    :quiver,
    :orientation,
    :polar,
  ]
supportedAxes(::PlotlyJSBackend) = [:auto, :left]
supportedTypes(::PlotlyJSBackend) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :hist2d, :hist, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap] #,, :sticks, :hexbin, :hline, :vline]
supportedStyles(::PlotlyJSBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PlotlyJSBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline] #vcat(_allMarkers, Shape)
supportedScales(::PlotlyJSBackend) = [:identity, :log10] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PlotlyJSBackend) = true
stringsSupported(::PlotlyJSBackend) = true

# --------------------------------------------------------------------------------------

function _initialize_backend(::PlotlyJSBackend; kw...)
    @eval begin
        import PlotlyJS
        export PlotlyJS
    end

    for (mime, fmt) in PlotlyJS._mimeformats
        # mime == "image/png" && continue  # don't use plotlyjs's writemime for png
        @eval Base.writemime(io::IO, m::MIME{symbol($mime)}, p::Plot{PlotlyJSBackend}) = writemime(io, m, p.o)
    end

    # override IJulia inline display
    if isijulia()
        IJulia.display_dict(plt::AbstractPlot{PlotlyJSBackend}) = IJulia.display_dict(plt.o)
    end
end

# ---------------------------------------------------------------------------

# function _create_plot(pkg::PlotlyJSBackend, d::KW)
#     # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
#     # TODO: initialize the plot... title, xlabel, bgcolor, etc
#     # o = PlotlyJS.Plot(PlotlyJS.GenericTrace[], PlotlyJS.Layout(),
#     #                   Base.Random.uuid4(), PlotlyJS.ElectronDisplay())
#     # T = isijulia() ? PlotlyJS.JupyterPlot : PlotlyJS.ElectronPlot
#     # o = T(PlotlyJS.Plot())
#     o = PlotlyJS.plot()
#
#     Plot(o, pkg, 0, d, KW[])
# end

function _create_backend_figure(plt::Plot{PlotlyJSBackend})
    PlotlyJS.plot()
end


function _add_series(plt::Plot{PlotlyJSBackend}, series::Series)
    d = series.d
    syncplot = plt.o

    # add to the data array
    pdict = plotly_series(d, plt.plotargs)
    typ = pop!(pdict, :type)
    gt = PlotlyJS.GenericTrace(typ; pdict...)
    PlotlyJS.addtraces!(syncplot, gt)

    # push!(plt.seriesargs, d)
    # plt
end


# ---------------------------------------------------------------------------


function _add_annotations{X,Y,V}(plt::Plot{PlotlyJSBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
    # set or add to the annotation_list
    if !haskey(plt.plotargs, :annotation_list)
        plt.plotargs[:annotation_list] = Any[]
    end
    append!(plt.plotargs[:annotation_list], anns)
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PlotlyJSBackend})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyJSBackend}, d::KW)
    pdict = plotly_layout(plt.plotargs, plt.seriesargs)
    syncplot = plt.o
    w,h = d[:size]
    PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
end


function _update_plot_pos_size(plt::AbstractPlot{PlotlyJSBackend}, d::KW)
end

# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{PlotlyJSBackend}, i::Int)
#   d = plt.seriesargs[i]
#   d[:x], d[:y]
# end

function setxy!{X,Y}(plt::Plot{PlotlyJSBackend}, xy::Tuple{X,Y}, i::Integer)
  d = plt.seriesargs[i]
  ispolar = get(plt.plotargs, :polar, false)
  xsym = ispolar ? :t : :x
  ysym = ispolar ? :r : :y
  d[xsym], d[ysym] = xy
  # TODO: this is likely ineffecient... we should make a call that ONLY changes the plot data
  PlotlyJS.restyle!(plt.o, i, KW(xsym=>(d[xsym],), ysym=>(d[ysym],)))
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PlotlyJSBackend}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PlotlyJSBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PlotlyJSBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

# function Base.writemime(io::IO, m::MIME"text/html", plt::AbstractPlot{PlotlyJSBackend})
#     Base.writemime(io, m, plt.o)
# end

# function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{PlotlyJSBackend})
#     println("here!")
#     writemime_png_from_html(io, plt)
# end

function Base.display(::PlotsDisplay, plt::Plot{PlotlyJSBackend})
    display(plt.o)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyJSBackend})
    error()
end
