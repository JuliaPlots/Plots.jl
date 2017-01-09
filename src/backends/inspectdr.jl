
# https://github.com/ma-laforge/InspectDR.jl

#=TODO:
Not supported by InspectDR:
    :foreground_color_title (font), title_location
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :polar,


Add in functionality to Plots.jl:
    :annotations, :aspect_ratio,
=#

# ---------------------------------------------------------------------------
#TODO: remove features
const _inspectdr_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :markerstrokestyle, #Causes warning not to have it... what is this?
    :fillcolor, :fillalpha, #:fillrange,
#    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :scale, #:ticks, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, #:colorbar,
#    :marker_z,
#    :line_z,
#    :levels,
 #   :ribbon, :quiver, :arrow,
#    :orientation,
    :overwrite_figure,
#    :polar,
#    :normalize, :weights,
#    :contours, :aspect_ratio,
    :match_dimensions,
#    :clims,
#    :inset_subplots,
    :dpi,
#    :colorbar_title,
  ])
const _inspectdr_style = [:auto, :solid, :dash, :dot, :dashdot]
const _inspectdr_seriestype = [
        :path, :scatter #, :steppre, :steppost, :shape,
    ]
#see: _allMarkers, _shape_keys
const _inspectdr_marker = Symbol[
    :none,
    :auto,
    :circle,
    :rect,
  :diamond,
#  :hexagon,
  :cross,
  :xcross,
  :utriangle,
  :dtriangle,
  :rtriangle,
  :ltriangle,
#  :pentagon,
#  :heptagon,
#  :octagon,
#  :star4,
#    :star5,
#  :star6,
#  :star7,
  :star8,
#  :vline,
#  :hline,
  :+,
  :x,
]

const _inspectdr_scale = [:identity, :ln, :log2, :log10] #Does not really support ln, (plot using log10 instead).

#Do we avoid Map to avoid possible pre-comile issues?
function _inspectdr_mapglyph(s::Symbol)
    s == :rect && return :square
    s == :utriangle && return :uarrow
    s == :dtriangle && return :darrow
    s == :ltriangle && return :larrow
    s == :rtriangle && return :rarrow
    s == :xcross && return :diagcross
    s == :star8 && return :*

#= Actually supported:
    :square, :diamond,
    :uarrow, :darrow, :larrow, :rarrow, #usually triangles
    :cross, :+, :diagcross, :x,
    :circle, :o, :star, :*,
=#

    return s
end

# py_marker(markers::AVec) = map(py_marker, markers)
function _inspectdr_mapglyph(markers::AVec)
    warn("Vectors of markers are currently unsupported in InspectDR.")
    _inspectdr_mapglyph(markers[1])
end

_inspectdr_mapglyphsize(v::Real) = v
function _inspectdr_mapglyphsize(v::Vector)
    warn("Vectors of marker sizes are currently unsupported in InspectDR.")
    _inspectdr_mapglyphsize(v[1])
end

_inspectdr_mapcolor(v::Colorant) = v
function _inspectdr_mapcolor(g::PlotUtils.ColorGradient)
    warn("Vectors of colors are currently unsupported in InspectDR.")
    #Pick middle color:
    _inspectdr_mapcolor(g.colors[div(1+end,2)])
end

#Hack: suggested point size does not seem adequate relative to plot size, for some reason.
_inspectdr_mapptsize(v) = 1.5*v

# ---------------------------------------------------------------------------
#InspectDR-dependent structures and method signatures.
#(To be evalutated only once ready to load module)
const _inspectdr_depcode = quote

import InspectDR
export InspectDR

type InspectDRPlotEnv
    #Stores reference to active plot GUI:
    cur_gui::Nullable{InspectDR.GtkPlot}
end
InspectDRPlotEnv() = InspectDRPlotEnv(nothing)
const _inspectdr_plotenv = InspectDRPlotEnv()
end #_inspectdr_depcode
# ---------------------------------------------------------------------------

function _inspectdr_getscale(s::Symbol)
#TODO: Support :ln, :asinh, :sqrt
    if :log2 == s
        return InspectDR.AxisScale(:log2)
    elseif :log10 == s
        return InspectDR.AxisScale(:log10)
    elseif :ln == s
        return InspectDR.AxisScale(:log10) #At least it will be a log-plot
    else #identity
        return InspectDR.AxisScale(:lin)
    end
end

# ---------------------------------------------------------------------------

function _initialize_backend(::InspectDRBackend; kw...)
    eval(_inspectdr_depcode)
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{InspectDRBackend})
    mplot = plt.o

    #:overwrite_figure: want to reuse current figure
    if plt[:overwrite_figure] && isa(mplot, InspectDR.Multiplot)
        mplot.subplots = [] #Reset
        if !isnull(_inspectdr_plotenv.cur_gui) #Create new one:
            gplot = get(_inspectdr_plotenv.cur_gui)
            gplot.src = mplot
        end
    else #want new one:
        mplot = InspectDR.Multiplot()
        if !isnull(_inspectdr_plotenv.cur_gui) #Create new one:
            _inspectdr_plotenv.cur_gui = display(InspectDR.GtkDisplay(), mplot)
        end
    end

    #break link with old subplots
    for sp in plt.subplots
        sp.o = nothing
    end
    plt.o = mplot
    return mplot
end

# ---------------------------------------------------------------------------

# # this is called early in the pipeline, use it to make the plot current or something
# function _prepare_plot_object(plt::Plot{InspectDRBackend})
# end

# ---------------------------------------------------------------------------

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{InspectDRBackend}, sp::Subplot{InspectDRBackend})
    plot = sp.o

    #Don't do anything without a "subplot" object:  Will process later.
    if nothing == plot; return; end
    plot.data = []
    
    return plot
end

# ---------------------------------------------------------------------------

# Add one series to the underlying backend object.
# Called once per series
# NOTE: Seems to be called when user calls plot()... even if backend
#       plot, sp.o has not yet been constructed...
function _series_added(plt::Plot{InspectDRBackend}, series::Series)
    st = series[:seriestype]
    sp = series[:subplot]
    plot = sp.o

    #Don't do anything without a "subplot" object:  Will process later.
    if nothing == plot; return; end

    _vectorize(v) = isa(v, Vector)? v: collect(v) #InspectDR only supports vectors
    x = _vectorize(series[:x]); y = _vectorize(series[:y])

    # doesn't handle mismatched x/y - wrap data (pyplot behaviour):
    nx = length(x); ny = length(y)
    if nx < ny
        series[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
    elseif ny > nx
        series[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
    end

#= TODO: Eventually support
    series[:fillcolor] #I think this is fill under line
    zorder = series[:series_plotindex]
=#

    #TODO: scale width & sizes
   if st in (:path, :scatter) #, :steppre, :steppost)
        #NOTE: In Plots.jl, :scatter plots have 0-linewidths (I think).
        linewidth = series[:linewidth]
        #More efficient & allows some support for markerstrokewidth:
        _style = (0==linewidth? :none: series[:linestyle])
        wfrm = InspectDR.add(plot, x, y, id=series[:label])
        wfrm.line = InspectDR.line(
            style = _style,
            width = series[:linewidth],
            color = series[:linecolor],
        )
        #InspectDR does not control markerstrokewidth independently.
        if :none == _style
            #Use this property only if no line is displayed:
            wfrm.line.width = series[:markerstrokewidth]
        end
        wfrm.glyph = InspectDR.glyph(
            shape = _inspectdr_mapglyph(series[:markershape]),
            size = _inspectdr_mapglyphsize(series[:markersize]),
            color = _inspectdr_mapcolor(series[:markerstrokecolor]),
            fillcolor = _inspectdr_mapcolor(series[:markercolor]),
        )
    end
    return
end

# ---------------------------------------------------------------------------

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{InspectDRBackend}, series::Series)
    #Nothing to do
end

# ---------------------------------------------------------------------------

function _inspectdr_setupsubplot(sp::Subplot{InspectDRBackend})
    const gridon = InspectDR.grid(vmajor=true, hmajor=true)
    const gridoff = InspectDR.grid()
    const plot = sp.o

    xaxis = sp[:xaxis]; yaxis = sp[:yaxis]
        xscale = _inspectdr_getscale(xaxis[:scale])
        yscale = _inspectdr_getscale(yaxis[:scale])
        plot.axes = InspectDR.AxesRect(xscale, yscale)
        xmin, xmax  = axis_limits(xaxis)
        ymin, ymax  = axis_limits(yaxis)
        #TODO: not sure which extents we should be modifying.
        plot.ext = InspectDR.PExtents2D() #reset
        plot.ext_full = InspectDR.PExtents2D(xmin, xmax, ymin, ymax)
    a = plot.annotation
        a.title = sp[:title]
        a.xlabel = xaxis[:guide]; a.ylabel = yaxis[:guide]

    l = plot.layout
        l.fnttitle.name = sp[:titlefont].family
        l.fnttitle._size = _inspectdr_mapptsize(sp[:titlefont].pointsize)
        #Cannot independently control fonts of axes with InspectDR:
        l.fntaxlabel.name = xaxis[:guidefont].family
        l.fntaxlabel._size = _inspectdr_mapptsize(xaxis[:guidefont].pointsize)
        l.fntticklabel.name = xaxis[:tickfont].family
        l.fntticklabel._size = _inspectdr_mapptsize(xaxis[:tickfont].pointsize)
        #No independent control of grid???
        l.grid = sp[:grid]? gridon: gridoff
    leg = l.legend
        leg.enabled = (sp[:legend] != :none)
        #leg.width = 150 #TODO: compute???
        leg.font.name = sp[:legendfont].family
        leg.font._size = _inspectdr_mapptsize(sp[:legendfont].pointsize)
end

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{InspectDRBackend})
    mplot = plt.o
    resize!(mplot.subplots, length(plt.subplots))
    nsubplots = length(plt.subplots)
    for (i, sp) in enumerate(plt.subplots)
        if !isassigned(mplot.subplots, i)
            mplot.subplots[i] = InspectDR.Plot2D()
        end
        sp.o = mplot.subplots[i]
        _initialize_subplot(plt, sp)
        _inspectdr_setupsubplot(sp)
    end

    #Do not yet support absolute plot positionning.
    #Just try to make things look more-or less ok:
    if nsubplots <= 4
        mplot.ncolumns = 2
    elseif nsubplots <= 6
        mplot.ncolumns = 3
    elseif nsubplots <= 12
        mplot.ncolumns = 4
    else
        mplot.ncolumns = 5
    end

    for series in plt.series_list
        _series_added(plt, series)
    end
end

# ----------------------------------------------------------------

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{InspectDRBackend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
    #TODO: Add support for padding.
end

# ----------------------------------------------------------------

# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot_object(plt::Plot{InspectDRBackend})
    const mplot = plt.o
    if nothing == mplot; return; end
    if isnull(_inspectdr_plotenv.cur_gui); return; end
    const gplot = get(_inspectdr_plotenv.cur_gui)

    if gplot.destroyed
        _inspectdr_plotenv.cur_gui = display(InspectDR.GtkDisplay(), mplot)
    else
        gplot.src = mplot
        InspectDR.refresh(gplot)
    end
    return mplot
end

# ----------------------------------------------------------------

const _inspectdr_mimeformats_dpi = Dict(
    "image/png"               => "png"
)
const _inspectdr_mimeformats_nodpi = Dict(
    "image/svg+xml"           => "svg",
    "application/eps"         => "eps",
    "image/eps"               => "eps",
#    "application/postscript"  => "ps", #TODO: support
    "application/pdf"         => "pdf"
)
_inspectdr_show(io::IO, mime::MIME, ::Void) =
    throw(ErrorException("Cannot show(::IO, ...) plot - not yet generated"))
_inspectdr_show(io::IO, mime::MIME, mplot) = show(io, mime, mplot)

for (mime, fmt) in _inspectdr_mimeformats_dpi
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{InspectDRBackend})
        dpi = plt[:dpi]#TODO: support
        _inspectdr_show(io, mime, plt.o)
    end
end
for (mime, fmt) in _inspectdr_mimeformats_nodpi
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{InspectDRBackend})
        _inspectdr_show(io, mime, plt.o)
    end
end

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{InspectDRBackend})
    const mplot = plt.o
    if isnull(_inspectdr_plotenv.cur_gui)
        _inspectdr_plotenv.cur_gui = display(InspectDR.GtkDisplay(), mplot)
    else
        #redundant... Plots.jl will call _update_plot_object:
        #InspectDR.refresh(get(_inspectdr_plotenv.cur_gui))
    end
    return get(_inspectdr_plotenv.cur_gui)
end
