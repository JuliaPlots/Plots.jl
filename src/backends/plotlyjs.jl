
# https://github.com/spencerlyon2/PlotlyJS.jl

supported_args(::PlotlyJSBackend) = [
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
    :window_title,
    :x,
    :xguide,
    :xlims,
    :xticks,
    :y,
    :yguide,
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
supported_types(::PlotlyJSBackend) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :histogram2d, :histogram, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap]
supported_styles(::PlotlyJSBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supported_markers(::PlotlyJSBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline]
supported_scales(::PlotlyJSBackend) = [:identity, :log10]
is_subplot_supported(::PlotlyJSBackend) = true
is_string_supported(::PlotlyJSBackend) = true

# --------------------------------------------------------------------------------------

function _initialize_backend(::PlotlyJSBackend; kw...)
    @eval begin
        import PlotlyJS
        export PlotlyJS
    end

    for (mime, fmt) in PlotlyJS._mimeformats
        # mime == "image/png" && continue  # don't use plotlyjs's writemime for png
        @eval Base.writemime(io::IO, m::MIME{Symbol($mime)}, p::Plot{PlotlyJSBackend}) = writemime(io, m, p.o)
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


function _series_added(plt::Plot{PlotlyJSBackend}, series::Series)
    syncplot = plt.o
    pdict = plotly_series(plt, series)
    typ = pop!(pdict, :type)
    gt = PlotlyJS.GenericTrace(typ; pdict...)
    PlotlyJS.addtraces!(syncplot, gt)
end

function _series_updated(plt::Plot{PlotlyJSBackend}, series::Series)
    xsym, ysym = (ispolar(series) ? (:t,:r) : (:x,:y))
    PlotlyJS.restyle!(
        plt.o,
        findfirst(plt.series_list, series),
        KW(xsym => (series.d[:x],), ysym => (series.d[:y],))
    )
end


# ----------------------------------------------------------------

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot_object(plt::Plot{PlotlyJSBackend})
    pdict = plotly_layout(plt)
    syncplot = plt.o
    w,h = plt[:size]
    # DD(pdict)
    PlotlyJS.relayout!(syncplot, pdict, width = w, height = h)
end


# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{PlotlyJSBackend}, i::Int)
#   d = plt.seriesargs[i]
#   d[:x], d[:y]
# end

# function setxy!{X,Y}(plt::Plot{PlotlyJSBackend}, xy::Tuple{X,Y}, i::Integer)
#   d = plt.seriesargs[i]
#   ispolar = get(plt.attr, :polar, false)
#   xsym = ispolar ? :t : :x
#   ysym = ispolar ? :r : :y
#   d[xsym], d[ysym] = xy
#   # TODO: this is likely ineffecient... we should make a call that ONLY changes the plot data
#   PlotlyJS.restyle!(plt.o, i, KW(xsym=>(d[xsym],), ysym=>(d[ysym],)))
#   plt
# end


# ----------------------------------------------------------------

# function _update_min_padding!(sp::Subplot{PlotlyBackend})
#     sp.minpad = plotly_minpad(sp)
# end

# function plotlyjs_finalize(plt::Plot)
#     plotly_finalize(plt)
#     PlotlyJS.relayout!(plt.o, plotly_layout(plt))
# end

function _writemime(io::IO, ::MIME"image/png", plt::Plot{PlotlyJSBackend})
    tmpfn = tempname() * "png"
    PlotlyJS.savefig(plt.o, tmpfn)
    write(io, read(open(tmpfn)))
end

function _display(plt::Plot{PlotlyJSBackend})
    # plotlyjs_finalize(plt)
    display(plt.o)
end
