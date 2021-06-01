
# https://github.com/ma-laforge/InspectDR.jl

#=TODO:
    Tweak scale factor for width & other sizes

Not supported by InspectDR:
    :foreground_color_grid
    :foreground_color_border
    :polar,

Add in functionality to Plots.jl:
    :aspect_ratio,
=#

# ---------------------------------------------------------------------------

is_marker_supported(::InspectDRBackend, shape::Shape) = true

#Do we avoid Map to avoid possible pre-comile issues?
function _inspectdr_mapglyph(s::Symbol)
    s == :rect && return :square
    return s
end

function _inspectdr_mapglyph(s::Shape)
    x, y = coords(s)
    return InspectDR.GlyphPolyline(x, y)
end

# py_marker(markers::AVec) = map(py_marker, markers)
function _inspectdr_mapglyph(markers::AVec)
    @warn("Vectors of markers are currently unsupported in InspectDR.")
    _inspectdr_mapglyph(markers[1])
end

_inspectdr_mapglyphsize(v::Real) = v
function _inspectdr_mapglyphsize(v::Vector)
    @warn("Vectors of marker sizes are currently unsupported in InspectDR.")
    _inspectdr_mapglyphsize(v[1])
end

_inspectdr_mapcolor(v::Colorant) = v
function _inspectdr_mapcolor(g::PlotUtils.ColorGradient)
    @warn("Color gradients are currently unsupported in InspectDR.")
    #Pick middle color:
    _inspectdr_mapcolor(g.colors[div(1+end,2)])
end
function _inspectdr_mapcolor(v::AVec)
    @warn("Vectors of colors are currently unsupported in InspectDR.")
    #Pick middle color:
    _inspectdr_mapcolor(v[div(1+end,2)])
end

#Hack: suggested point size does not seem adequate relative to plot size, for some reason.
_inspectdr_mapptsize(v) = 1.5*v

function _inspectdr_add_annotations(plot, x, y, val)
    #What kind of annotation is this?
end

#plot::InspectDR.Plot2D
function _inspectdr_add_annotations(plot, x, y, val::PlotText)
    vmap = Dict{Symbol, Symbol}(:top=>:t, :bottom=>:b) #:vcenter
    hmap = Dict{Symbol, Symbol}(:left=>:l, :right=>:r) #:hcenter
    align = Symbol(get(vmap, val.font.valign, :c), get(hmap, val.font.halign, :c))
    fnt = InspectDR.Font(val.font.family, val.font.pointsize,
        color =_inspectdr_mapcolor(val.font.color)
    )
    ann = InspectDR.atext(val.str, x=x, y=y,
        font=fnt, angle=val.font.rotation, align=align
    )
    InspectDR.add(plot, ann)
    return
end

# ---------------------------------------------------------------------------

function _inspectdr_getaxisticks(ticks, gridlines, xfrm)
    TickCustom = InspectDR.TickCustom
    _xfrm(coord) = InspectDR.axis2aloc(Float64(coord), xfrm.spec) #Ensure Float64 - in case

    ttype = ticksType(ticks)
    if ticks == :native
        #keep current
    elseif ttype == :ticks_and_labels
        pos = ticks[1]; labels = ticks[2]; nticks = length(ticks[1])
        newticks = TickCustom[TickCustom(_xfrm(pos[i]), labels[i]) for i in 1:nticks]
        gridlines = InspectDR.GridLinesCustom(gridlines)
        gridlines.major = newticks
        gridlines.minor = []
        gridlines.displayminor = false
    elseif ttype == :ticks
        nticks = length(ticks)
        gridlines.major = Float64[_xfrm(t) for t in ticks]
        gridlines.minor = []
        gridlines.displayminor = false
    elseif isnothing(ticks)
        gridlines.major = []
        gridlines.minor = []
    else #Assume ticks == :native
        #keep current
    end

    return gridlines #keep current
end

function _inspectdr_setticks(sp::Subplot, plot, strip, xaxis, yaxis)
    InputXfrm1D = InspectDR.InputXfrm1D
    _get_ticks(axis) = :native == axis[:ticks] ? (:native) : get_ticks(sp, axis)
    wantnative(ticks) = (:native == ticks)

    xticks = _get_ticks(xaxis)
    yticks = _get_ticks(yaxis)

    if wantnative(xticks) && wantnative(yticks)
        #Don't "eval" tick values
        return
    end

    #TODO: Allow InspectDR to independently "eval" x or y ticks
    ext = InspectDR.getextents_aloc(plot, 1)
    grid = InspectDR._eval(strip.grid, plot.xscale, strip.yscale, ext)
    grid.xlines = _inspectdr_getaxisticks(xticks, grid.xlines, InputXfrm1D(plot.xscale))
    grid.ylines = _inspectdr_getaxisticks(yticks, grid.ylines, InputXfrm1D(strip.yscale))
    strip.grid = grid
end

# ---------------------------------------------------------------------------

function _inspectdr_getscale(s::Symbol, yaxis::Bool)
#TODO: Support :asinh, :sqrt
    kwargs = yaxis ? (:tgtmajor=>8, :tgtminor=>2) : () #More grid lines on y-axis
    if :log2 == s
        return InspectDR.AxisScale(:log2; kwargs...)
    elseif :log10 == s
        return InspectDR.AxisScale(:log10; kwargs...)
    elseif :ln == s
        return InspectDR.AxisScale(:ln; kwargs...)
    else #identity
        return InspectDR.AxisScale(:lin; kwargs...)
    end
end

# ---------------------------------------------------------------------------

#Glyph used when plotting "Shape"s:
INSPECTDR_GLYPH_SHAPE = InspectDR.GlyphPolyline(
    2*InspectDR.GLYPH_SQUARE.x, InspectDR.GLYPH_SQUARE.y
)

mutable struct InspecDRPlotRef
    mplot::Union{Nothing, InspectDR.Multiplot}
    gui::Union{Nothing, InspectDR.GtkPlot}
end

_inspectdr_getmplot(::Any) = nothing
_inspectdr_getmplot(r::InspecDRPlotRef) = r.mplot

_inspectdr_getgui(::Any) = nothing
_inspectdr_getgui(gplot::InspectDR.GtkPlot) = (gplot.destroyed ? nothing : gplot)
_inspectdr_getgui(r::InspecDRPlotRef) = _inspectdr_getgui(r.gui)
push!(_initialized_backends, :inspectdr)

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    gplot = _inspectdr_getgui(plt.o)

    #:overwrite_figure: want to reuse current figure
    if plt[:overwrite_figure] && mplot !== nothing
        mplot.subplots = [] #Reset
        if gplot !== nothing #Ensure still references current plot
            gplot.src = mplot
        end
    else #want new one:
        mplot = InspectDR.Multiplot()
        gplot = nothing #Will be created later
    end

    #break link with old subplots
    for sp in plt.subplots
        sp.o = nothing
    end

    return InspecDRPlotRef(mplot, gplot)
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
    plot.userannot = [] #Clear old markers/text annotation/polyline "annotation"
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
    clims = get_clims(sp, series)

    #Don't do anything without a "subplot" object:  Will process later.
    if nothing == plot; return; end

    _vectorize(v) = isa(v, Vector) ? v : collect(v) #InspectDR only supports vectors
    x, y = if st == :straightline
        straightline_data(series)
    else
        _vectorize(series[:x]), _vectorize(series[:y])
    end

    #No support for polar grid... but can still perform polar transformation:
    if ispolar(sp)
        Θ = x; r = y
        x = r.*cos.(Θ); y = r.*sin.(Θ)
    end

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

For st in :shape:
    zorder = series[:series_plotindex],
=#

    if st in (:shape,)
        x, y = shape_data(series)
        nmax = 0
        for (i,rng) in enumerate(iter_segments(x, y))
            nmax = i
            if length(rng) > 1
                linewidth = series[:linewidth]
                c = plot_color(get_linecolor(series), get_linealpha(series))
                linecolor = _inspectdr_mapcolor(_cycle(c, i))
                c = plot_color(get_fillcolor(series), get_fillalpha(series))
                fillcolor = _inspectdr_mapcolor(_cycle(c, i))
                line = InspectDR.line(
                    style=:solid, width=linewidth, color=linecolor
                )
                apline = InspectDR.PolylineAnnotation(
                    x[rng], y[rng], line=line, fillcolor=fillcolor
                )
                InspectDR.add(plot, apline)
            end
        end

        i = (nmax >= 2 ? div(nmax, 2) : nmax) #Must pick one set of colors for legend
        if i > 1 #Add dummy waveform for legend entry:
            linewidth = series[:linewidth]
            c = plot_color(get_linecolor(series), get_linealpha(series))
            linecolor = _inspectdr_mapcolor(_cycle(c, i))
            c = plot_color(get_fillcolor(series), get_fillalpha(series))
            fillcolor = _inspectdr_mapcolor(_cycle(c, i))
            wfrm = InspectDR.add(plot, Float64[], Float64[], id=series[:label])
            wfrm.line = InspectDR.line(
                style=:none, width=linewidth, #linewidth affects glyph
            )
            wfrm.glyph = InspectDR.glyph(
                shape = INSPECTDR_GLYPH_SHAPE, size = 8,
                color = linecolor, fillcolor = fillcolor
            )
        end
   elseif st in (:path, :scatter, :straightline) #, :steppre, :stepmid, :steppost)
        #NOTE: In Plots.jl, :scatter plots have 0-linewidths (I think).
        linewidth = series[:linewidth]
        #More efficient & allows some support for markerstrokewidth:
        _style = (0==linewidth ? :none : series[:linestyle])
        wfrm = InspectDR.add(plot, x, y, id=series[:label])
        wfrm.line = InspectDR.line(
            style = _style,
            width = series[:linewidth],
            color = plot_color(get_linecolor(series), get_linealpha(series)),
        )
        #InspectDR does not control markerstrokewidth independently.
        if :none == _style
            #Use this property only if no line is displayed:
            wfrm.line.width = series[:markerstrokewidth]
        end
        wfrm.glyph = InspectDR.glyph(
            shape = _inspectdr_mapglyph(series[:markershape]),
            size = _inspectdr_mapglyphsize(series[:markersize]),
            color = _inspectdr_mapcolor(plot_color(get_markerstrokecolor(series), get_markerstrokealpha(series))),
            fillcolor = _inspectdr_mapcolor(plot_color(get_markercolor(series, clims), get_markeralpha(series))),
        )
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi,yi,str,fnt) in EachAnn(anns, x, y)
        _inspectdr_add_annotations(plot, xi, yi, PlotText(str, fnt))
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
    plot = sp.o
    strip = plot.strips[1] #Only 1 strip supported with Plots.jl

    xaxis = sp[:xaxis]; yaxis = sp[:yaxis]
    xgrid_show = xaxis[:grid]
    ygrid_show = yaxis[:grid]

    strip.grid = InspectDR.GridRect(
        vmajor=xgrid_show, # vminor=xgrid_show,
        hmajor=ygrid_show, # hminor=ygrid_show,
    )

        plot.xscale = _inspectdr_getscale(xaxis[:scale], false)
        strip.yscale = _inspectdr_getscale(yaxis[:scale], true)
        xmin, xmax  = axis_limits(sp, :x)
        ymin, ymax  = axis_limits(sp, :y)
        if ispolar(sp)
            #Plots.jl appears to give (xmin,xmax) ≜ (Θmin,Θmax) & (ymin,ymax) ≜ (rmin,rmax)
            rmax = NaNMath.max(abs(ymin), abs(ymax))
            xmin, xmax = -rmax, rmax
            ymin, ymax = -rmax, rmax
        end
        plot.xext_full = InspectDR.PExtents1D(xmin, xmax)
        strip.yext_full = InspectDR.PExtents1D(ymin, ymax)
        #Set current extents = full extents (needed for _eval(strip.grid,...))
        plot.xext = plot.xext_full
        strip.yext = strip.yext_full
        _inspectdr_setticks(sp, plot, strip, xaxis, yaxis)

    a = plot.annotation
        a.title = sp[:title]
        a.xlabel = xaxis[:guide]; a.ylabels = [yaxis[:guide]]

    #Modify base layout of new object:
    l = plot.layout.defaults = deepcopy(InspectDR.defaults.plotlayout)
        #IMPORTANT: Must deepcopy to ensure we don't change layouts of other plots.
        #Works because plot uses defaults (not user-overwritten `layout.values`)
        l.frame_canvas.fillcolor = _inspectdr_mapcolor(sp[:background_color_subplot])
        l.frame_data.fillcolor = _inspectdr_mapcolor(sp[:background_color_inside])
        l.frame_data.line.color = _inspectdr_mapcolor(xaxis[:foreground_color_axis])
        l.font_title = InspectDR.Font(sp[:titlefontfamily],
            _inspectdr_mapptsize(sp[:titlefontsize]),
            color = _inspectdr_mapcolor(sp[:titlefontcolor])
        )
        #Cannot independently control fonts of axes with InspectDR:
        l.font_axislabel = InspectDR.Font(xaxis[:guidefontfamily],
            _inspectdr_mapptsize(xaxis[:guidefontsize]),
            color = _inspectdr_mapcolor(xaxis[:guidefontcolor])
        )
        l.font_ticklabel = InspectDR.Font(xaxis[:tickfontfamily],
            _inspectdr_mapptsize(xaxis[:tickfontsize]),
            color = _inspectdr_mapcolor(xaxis[:tickfontcolor])
        )
        l.enable_legend = (sp[:legend_position] != :none)
        #l.halloc_legend = 150 #TODO: compute???
        l.font_legend = InspectDR.Font(sp[:legend_font_family],
            _inspectdr_mapptsize(sp[:legend_font_pointsize]),
            color = _inspectdr_mapcolor(sp[:legend_font_color])
        )
        l.frame_legend.fillcolor = _inspectdr_mapcolor(sp[:legend_background_color])
        #_round!() ensures values use integer spacings (looks better on screen):
        InspectDR._round!(InspectDR.autofit2font!(l, legend_width=10.0)) #10 "em"s wide
    return
end

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end

    mplot.title = plt[:plot_title]
    if "" == mplot.title
        #Don't use window_title... probably not what you want.
        #mplot.title = plt[:window_title]
    end

    mplot.layout[:frame].fillcolor = _inspectdr_mapcolor(plt[:background_color_outside])
        mplot.layout[:frame] = mplot.layout[:frame] #register changes
    resize!(mplot.subplots, length(plt.subplots))
    nsubplots = length(plt.subplots)
    for (i, sp) in enumerate(plt.subplots)
        if !isassigned(mplot.subplots, i)
            mplot.subplots[i] = InspectDR.Plot2D()
        end
        sp.o = mplot.subplots[i]
        plot = sp.o
        _initialize_subplot(plt, sp)
        _inspectdr_setupsubplot(sp)

        # add the annotations
        for ann in sp[:annotations]
            _inspectdr_add_annotations(plot, ann...)
        end
    end

    #Do not yet support absolute plot positionning.
    #Just try to make things look more-or less ok:
    if nsubplots <= 1
        mplot.layout[:ncolumns] = 1
    elseif nsubplots <= 4
        mplot.layout[:ncolumns] = 2
    elseif nsubplots <= 6
        mplot.layout[:ncolumns] = 3
    elseif nsubplots <= 12
        mplot.layout[:ncolumns] = 4
    else
        mplot.layout[:ncolumns] = 5
    end

    for series in plt.series_list
        _series_added(plt, series)
    end
    return
end

# ----------------------------------------------------------------

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{InspectDRBackend})
    plot = sp.o
    if !isa(plot, InspectDR.Plot2D); return sp.minpad; end
    #Computing plotbounds with 0-BoundingBox returns required padding:
    bb = InspectDR.plotbounds(plot.layout.values, InspectDR.BoundingBox(0,0,0,0))
    #NOTE: plotbounds always pads for titles, legends, etc. even if not in use.
    #TODO: possibly zero-out items not in use??

    # add in the user-specified margin to InspectDR padding:
    leftpad   = abs(bb.xmin)*px + sp[:left_margin]
    toppad    = abs(bb.ymin)*px + sp[:top_margin]
    rightpad  = abs(bb.xmax)*px + sp[:right_margin]
    bottompad = abs(bb.ymax)*px + sp[:bottom_margin]
    sp.minpad = (leftpad, toppad, rightpad, bottompad)
end

# ----------------------------------------------------------------

# Override this to update plot items (title, xlabel, etc), and add annotations (plotattributes[:annotations])
function _update_plot_object(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end
    mplot.bblist = InspectDR.BoundingBox[]

    for (i, sp) in enumerate(plt.subplots)
        figw, figh = sp.plt[:size]
        pcts = bbox_to_pcts(sp.bbox, figw*px, figh*px)
        _left, _bottom, _width, _height = pcts
        ymax = 1.0-_bottom
        ymin = ymax - _height
        bb = InspectDR.BoundingBox(_left, _left+_width, ymin, ymax)
        push!(mplot.bblist, bb)
    end

    gplot = _inspectdr_getgui(plt.o)
    if nothing == gplot; return; end

    gplot.src = mplot #Ensure still references current plot
    InspectDR.refresh(gplot)
    return
end

# ----------------------------------------------------------------

_inspectdr_show(io::IO, mime::MIME, ::Nothing, w, h) =
    throw(ErrorException("Cannot show(::IO, ...) plot - not yet generated"))
function _inspectdr_show(io::IO, mime::MIME, mplot, w, h)
    InspectDR._show(io, mime, mplot, Float64(w), Float64(h))
end

function _show(io::IO, mime::MIME{Symbol("image/png")}, plt::Plot{InspectDRBackend})
    dpi = plt[:dpi] # TODO: support
    _inspectdr_show(io, mime, _inspectdr_getmplot(plt.o), plt[:size]...)
end
for (mime, fmt) in (
    "image/svg+xml" => "svg",
    "application/eps" => "eps",
    "image/eps" => "eps",
    # "application/postscript" => "ps", # TODO: support once Cairo supports PSSurface
    "application/pdf" => "pdf",
)
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{InspectDRBackend})
        _inspectdr_show(io, mime, _inspectdr_getmplot(plt.o), plt[:size]...)
    end
end

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end
    gplot = _inspectdr_getgui(plt.o)

    if nothing == gplot
        gplot = display(InspectDR.GtkDisplay(), mplot)
    else
        #redundant... Plots.jl will call _update_plot_object:
        #InspectDR.refresh(gplot)
    end
    plt.o = InspecDRPlotRef(mplot, gplot)
    return gplot
end
