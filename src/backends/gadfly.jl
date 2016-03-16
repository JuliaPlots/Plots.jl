
# https://github.com/dcjones/Gadfly.jl


function _initialize_backend(::GadflyBackend; kw...)
    @eval begin
        import Gadfly, Compose
        export Gadfly, Compose
        include(joinpath(Pkg.dir("Plots"), "src", "backends", "gadfly_shapes.jl"))
    end
end

# ---------------------------------------------------------------------------

# immutable MissingVec <: AbstractVector{Float64} end
# Base.size(v::MissingVec) = (1,)
# Base.getindex(v::MissingVec, i::Integer) = 0.0

function createGadflyPlotObject(d::Dict)
    gplt = Gadfly.Plot()
    gplt.mapping = Dict()
    gplt.data_source = Gadfly.DataFrames.DataFrame()
    # gplt.layers = gplt.layers[1:0]
    gplt.layers = [Gadfly.layer(Gadfly.Geom.point(tag=:remove), x=zeros(1), y=zeros(1));] # x=MissingVec(), y=MissingVec());]
    gplt.guides = Gadfly.GuideElement[Gadfly.Guide.xlabel(d[:xlabel]),
                                   Gadfly.Guide.ylabel(d[:ylabel]),
                                   Gadfly.Guide.title(d[:title])]
    gplt
end

# ---------------------------------------------------------------------------


function getLineGeom(d::Dict)
    lt = d[:linetype]
    xbins, ybins = maketuple(d[:nbins])
    if lt == :hexb
        Gadfly.Geom.hexbin(xbincount = xbins, ybincount = ybins)
    elseif lt == :hist2d
        Gadfly.Geom.histogram2d(xbincount = xbins, ybincount = ybins)
    elseif lt == :hist
        Gadfly.Geom.histogram(bincount = xbins)
    elseif lt == :path
        Gadfly.Geom.path
    elseif lt in (:bar, :sticks)
        Gadfly.Geom.bar
    elseif lt == :steppost
        Gadfly.Geom.step
    elseif lt == :steppre
        Gadfly.Geom.step(direction = :vh)
    elseif lt == :hline
        Gadfly.Geom.hline
    elseif lt == :vline
        Gadfly.Geom.vline
    elseif lt == :contour
        Gadfly.Geom.contour(levels = d[:levels])
    # elseif lt == :shape
    #     Gadfly.Geom.polygon(fill = true, preserve_order = true)
    else
        nothing
    end
end

function get_extra_theme_args(d::Dict, k::Symbol)
    # gracefully handles old Gadfly versions
    extra_theme_args = Dict()
    try
        extra_theme_args[:line_style] = Gadfly.get_stroke_vector(d[k])
    catch err
        if string(err) == "UndefVarError(:get_stroke_vector)"
            Base.warn_once("Gadfly.get_stroke_vector failed... do you have an old version of Gadfly?")
        else
            rethrow()
        end
    end
    extra_theme_args
end

function getGadflyLineTheme(d::Dict)
    lc = convertColor(getColor(d[:linecolor]), d[:linealpha])
    fc = convertColor(getColor(d[:fillcolor]), d[:fillalpha])

    Gadfly.Theme(;
        default_color = lc,
        line_width = (d[:linetype] == :sticks ? 1 : d[:linewidth]) * Gadfly.px,
        # line_style = Gadfly.get_stroke_vector(d[:linestyle]),
        lowlight_color = x->RGB(fc),  # fill/ribbon
        lowlight_opacity = alpha(fc), # fill/ribbon
        bar_highlight = RGB(lc),      # bars
        get_extra_theme_args(d, :linestyle)...
    )
end

# add a line as a new layer
function addGadflyLine!(plt::Plot, numlayers::Int, d::Dict, geoms...)
    gplt = getGadflyContext(plt)
    gfargs = vcat(geoms..., getGadflyLineTheme(d))
    kwargs = Dict()
    lt = d[:linetype]

    # add a fill?
    if d[:fillrange] != nothing && lt != :contour
        fillmin, fillmax = map(makevec, maketuple(d[:fillrange]))
        nmin, nmax = length(fillmin), length(fillmax)
        kwargs[:ymin] = Float64[min(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]
        kwargs[:ymax] = Float64[max(y, fillmin[mod1(i, nmin)], fillmax[mod1(i, nmax)]) for (i,y) in enumerate(d[:y])]
        push!(gfargs, Gadfly.Geom.ribbon)
    end

    if lt in (:hline, :vline)
        kwargs[lt == :hline ? :yintercept : :xintercept] = d[:y]

    else
        if lt == :sticks
            w = 0.01 * mean(diff(d[:x]))
            kwargs[:xmin] = d[:x] - w
            kwargs[:xmax] = d[:x] + w
        elseif lt == :contour
            kwargs[:z] = d[:z].surf
            addGadflyContColorScale(plt, d[:linecolor])
        end

        kwargs[:x] = d[lt == :hist ? :y : :x]
        kwargs[:y] = d[:y]

    end

    # # add the layer
    Gadfly.layer(gfargs...; order=numlayers, kwargs...)
end


# ---------------------------------------------------------------------------

# extract the underlying ShapeGeometry object(s)
getMarkerGeom(shape::Shape) = gadflyshape(shape)
getMarkerGeom(shape::Symbol) = gadflyshape(_shapes[shape])
getMarkerGeom(shapes::AVec) = map(getMarkerGeom, shapes)
function getMarkerGeom(d::Dict)
    if d[:linetype] == :shape
        Gadfly.Geom.polygon(fill = true, preserve_order = true)
    else
        getMarkerGeom(d[:markershape])
    end
end

function getGadflyMarkerTheme(d::Dict, plotargs::Dict)
    c = getColor(d[:markercolor])
    α = d[:markeralpha]
    if α != nothing
        c = RGBA(RGB(c), α)
    end

    ms = d[:markersize]
    ms = if typeof(ms) <: AVec
        warn("Gadfly doesn't support variable marker sizes... using the average: $(mean(ms))")
        mean(ms) * Gadfly.px
    else
        ms * Gadfly.px
    end

    Gadfly.Theme(;
        default_color = c,
        default_point_size = ms,
        discrete_highlight_color = c -> RGB(getColor(d[:markerstrokecolor])),
        highlight_width = d[:markerstrokewidth] * Gadfly.px,
        line_width = d[:markerstrokewidth] * Gadfly.px,
        # get_extra_theme_args(d, :markerstrokestyle)...
    )
end

function addGadflyContColorScale(plt::Plot{GadflyBackend}, c)
    plt.plotargs[:colorbar] == :none && return
    if !isa(c, ColorGradient)
        c = colorscheme(:bluesreds)
    end
    push!(getGadflyContext(plt).scales, Gadfly.Scale.ContinuousColorScale(p -> RGB(getColorZ(c, p))))
end

function addGadflyMarker!(plt::Plot, numlayers::Int, d::Dict, plotargs::Dict, geoms...)
    gfargs = vcat(geoms..., getGadflyMarkerTheme(d, plotargs), getMarkerGeom(d))
    kwargs = Dict()

    # handle continuous color scales for the markers
    zcolor = d[:zcolor]
    if zcolor != nothing && typeof(zcolor) <: AVec
        kwargs[:color] = zcolor
        addGadflyContColorScale(plt, d[:markercolor])
    end

    Gadfly.layer(gfargs...; x = d[:x], y = d[:y], order=numlayers, kwargs...)
end


# ---------------------------------------------------------------------------

function addToGadflyLegend(plt::Plot, d::Dict)
    if plt.plotargs[:legend] != :none && d[:label] != ""
        gplt = getGadflyContext(plt)

        # add the legend if needed
        if all(g -> !isa(g, Gadfly.Guide.ManualColorKey), gplt.guides)
            unshift!(gplt.guides, Gadfly.Guide.manual_color_key("", @compat(AbstractString)[], Color[]))
        end

        # now add the series to the legend
        for guide in gplt.guides
            if isa(guide, Gadfly.Guide.ManualColorKey)
                # TODO: there's a BUG in gadfly if you pass in the same color more than once,
                # since gadfly will call unique(colors), but doesn't also merge the rows that match
                # Should ensure from this side that colors which are the same are merged together

                c = getColor(d[d[:markershape] == :none ? :linecolor : :markercolor])
                foundit = false

                # extend the label if we found this color
                for i in 1:length(guide.colors)
                    if RGB(c) == guide.colors[i]
                        guide.labels[i] *= ", " * d[:label]
                        foundit = true
                    end
                end

                # didn't find the color, so add a new entry into the legend
                if !foundit
                    push!(guide.labels, d[:label])
                    push!(guide.colors, c)
                end
            end
        end
    end
end

getGadflySmoothing(smooth::Bool) = smooth ? [Gadfly.Geom.smooth(method=:lm)] : Any[]
getGadflySmoothing(smooth::Real) = [Gadfly.Geom.smooth(method=:loess, smoothing=float(smooth))]


function addGadflySeries!(plt::Plot, d::Dict)
    layers = Gadfly.Layer[]
    gplt = getGadflyContext(plt)

    # add a regression line?
    # TODO: make more flexible
    smooth = getGadflySmoothing(d[:smooth])

    # lines
    geom = getLineGeom(d)
    if geom != nothing
        prepend!(layers, addGadflyLine!(plt, length(gplt.layers), d, geom, smooth...))
        smooth = Any[] # don't add a regression for markers too
    end

    # special handling for ohlc and scatter
    lt = d[:linetype]
    if lt == :ohlc
        error("Haven't re-implemented after refactoring")
    elseif lt in (:hist2d, :hexbin) && (isa(d[:linecolor], ColorGradient) || isa(d[:linecolor], ColorFunction))
        push!(gplt.scales, Gadfly.Scale.ContinuousColorScale(p -> RGB(getColorZ(d[:linecolor], p))))
    elseif lt == :scatter && d[:markershape] == :none
        d[:markershape] = :ellipse
    end

    # markers
    if d[:markershape] != :none || lt == :shape
        prepend!(layers, addGadflyMarker!(plt, length(gplt.layers), d, plt.plotargs, smooth...))
    end

    lt in (:hist2d, :hexbin, :contour) || addToGadflyLegend(plt, d)

    # now save the layers that apply to this series
    d[:gadflylayers] = layers
    prepend!(gplt.layers, layers)
end


# ---------------------------------------------------------------------------

# NOTE: I'm leaving this here and commented out just in case I want to implement again... it was hacky code to create multi-colored line segments

#   # colorgroup
#   z = d[:z]

#   # handle line segments of different colors
#   cscheme = d[:linecolor]
#   if isa(cscheme, ColorVector)
#     # create a color scale, and set the color group to the index of the color
#     push!(gplt.scales, Gadfly.Scale.color_discrete_manual(cscheme.v...))

#     # this is super weird, but... oh well... for some reason this creates n separate line segments...
#     # create a list of vertices that go: [x1,x2,x2,x3,x3, ... ,xi,xi, ... xn,xn] (same for y)
#     # then the vector passed to the "color" keyword should be a vector: [1,1,2,2,3,3,4,4, ..., i,i, ... , n,n]
#     csindices = Int[mod1(i,length(cscheme.v)) for i in 1:length(d[:y])]
#     cs = collect(repmat(csindices', 2, 1))[1:end-1]
#     grp = collect(repmat((1:length(d[:y]))', 2, 1))[1:end-1]
#     d[:x], d[:y] = map(createSegments, (d[:x], d[:y]))
#     colorgroup = [(:linecolor, cs), (:group, grp)]


# ---------------------------------------------------------------------------


function addGadflyTicksGuide(gplt, ticks, isx::Bool)
    ticks == :auto && return

    # remove the ticks?
    if ticks in (:none, false, nothing)
        return addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
    end

    ttype = ticksType(ticks)

    # just the values... put ticks here, but use standard labels
    if ttype == :ticks
        gtype = isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks
        replaceType(gplt.guides, gtype(ticks = collect(ticks)))

    # set the ticks and the labels
    elseif ttype == :ticks_and_labels
        gtype = isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks
        replaceType(gplt.guides, gtype(ticks = collect(ticks[1])))

        # TODO add xtick_label function (given tick, return label??)
        # Scale.x_discrete(; labels=nothing, levels=nothing, order=nothing)
        filterGadflyScale(gplt, isx)
        gfunc = isx ? Gadfly.Scale.x_discrete : Gadfly.Scale.y_discrete
        labelmap = Dict(zip(ticks...))
        labelfunc = val -> labelmap[val]
        push!(gplt.scales, gfunc(levels = collect(ticks[1]), labels = labelfunc))

    else
        error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
    end
end

continuousAndSameAxis(scale, isx::Bool) = isa(scale, Gadfly.Scale.ContinuousScale) && scale.vars[1] == (isx ? :x : :y)
filterGadflyScale(gplt, isx::Bool) = filter!(scale -> !continuousAndSameAxis(scale, isx), gplt.scales)


function getGadflyScaleFunction(d::Dict, isx::Bool)
    scalekey = isx ? :xscale : :yscale
    hasScaleKey = haskey(d, scalekey)
    if hasScaleKey
        scale = d[scalekey]
        scale == :ln && return isx ? Gadfly.Scale.x_log : Gadfly.Scale.y_log, hasScaleKey
        scale == :log2 && return isx ? Gadfly.Scale.x_log2 : Gadfly.Scale.y_log2, hasScaleKey
        scale == :log10 && return isx ? Gadfly.Scale.x_log10 : Gadfly.Scale.y_log10, hasScaleKey
        scale == :asinh && return isx ? Gadfly.Scale.x_asinh : Gadfly.Scale.y_asinh, hasScaleKey
        scale == :sqrt && return isx ? Gadfly.Scale.x_sqrt : Gadfly.Scale.y_sqrt, hasScaleKey
    end
    isx ? Gadfly.Scale.x_continuous : Gadfly.Scale.y_continuous, hasScaleKey
end


function addGadflyLimitsScale(gplt, d::Dict, isx::Bool)
    gfunc, hasScaleKey = getGadflyScaleFunction(d, isx)

    # do we want to add min/max limits for the axis?
    limsym = isx ? :xlims : :ylims
    limargs = Any[]

    # map :auto to nothing, otherwise add to limargs
    lims = get(d, limsym, :auto)
    if lims == :auto
        lims = nothing
    else
        if limsType(lims) == :limits
            push!(limargs, (:minvalue, min(lims...)))
            push!(limargs, (:maxvalue, max(lims...)))
        else
            error("Invalid input for $(isx ? "xlims" : "ylims"): ", lims)
        end
    end

    # replace any current scales with this one
    if hasScaleKey || !isempty(limargs)
        filterGadflyScale(gplt, isx)
        push!(gplt.scales, gfunc(; limargs...))
    end

    lims
end

function updateGadflyAxisFlips(gplt, d::Dict, xlims, ylims)
    if isa(gplt.coord, Gadfly.Coord.Cartesian)
        gplt.coord = Gadfly.Coord.cartesian(
            gplt.coord.xvars,
            gplt.coord.yvars;
            xmin = xlims == nothing ? gplt.coord.xmin : minimum(xlims),
            xmax = xlims == nothing ? gplt.coord.xmax : maximum(xlims),
            ymin = ylims == nothing ? gplt.coord.ymin : minimum(ylims),
            ymax = ylims == nothing ? gplt.coord.ymax : maximum(ylims),
            xflip = get(d, :xflip, gplt.coord.xflip),
            yflip = get(d, :yflip, gplt.coord.yflip),
            fixed = gplt.coord.fixed,
            aspect_ratio = gplt.coord.aspect_ratio,
            raster = gplt.coord.raster
        )
    else
        gplt.coord = Gadfly.Coord.Cartesian(
            xflip = get(d, :xflip, false),
            yflip = get(d, :yflip, false)
        )
    end
end


function findGuideAndSet(gplt, t::DataType, args...; kw...) #s::@compat(AbstractString))
    for (i,guide) in enumerate(gplt.guides)
        if isa(guide, t)
            gplt.guides[i] = t(args...; kw...)
        end
    end
end

function updateGadflyGuides(plt::Plot, d::Dict)
    gplt = getGadflyContext(plt)
    haskey(d, :title) && findGuideAndSet(gplt, Gadfly.Guide.title, string(d[:title]))
    haskey(d, :xlabel) && findGuideAndSet(gplt, Gadfly.Guide.xlabel, string(d[:xlabel]))
    haskey(d, :ylabel) && findGuideAndSet(gplt, Gadfly.Guide.ylabel, string(d[:ylabel]))

    xlims = addGadflyLimitsScale(gplt, d, true)
    ylims = addGadflyLimitsScale(gplt, d, false)

    ticks = get(d, :xticks, :auto)
    if ticks == :none
        _remove_axis(plt, true)
    else
        addGadflyTicksGuide(gplt, ticks, true)
    end
    ticks = get(d, :yticks, :auto)
    if ticks == :none
        _remove_axis(plt, false)
    else
        addGadflyTicksGuide(gplt, ticks, false)
    end

    updateGadflyAxisFlips(gplt, d, xlims, ylims)
end

function updateGadflyPlotTheme(plt::Plot, d::Dict)
    kwargs = Dict()

    # # hide the legend?
    leg = d[d[:legend] == :none ? :colorbar : :legend]
    if leg != :best
        kwargs[:key_position] = leg == :inside ? :right : leg
    end

    if !get(d, :grid, true)
        kwargs[:grid_color] = getColor(d[:background_color])
    end

    # fonts
    tfont, gfont, lfont = d[:tickfont], d[:guidefont], d[:legendfont]

    fg = getColor(d[:foreground_color])
    getGadflyContext(plt).theme = Gadfly.Theme(;
        background_color = getColor(d[:background_color]),
        minor_label_color = fg,
        minor_label_font = tfont.family,
        minor_label_font_size = tfont.pointsize * Gadfly.pt,
        major_label_color = fg,
        major_label_font = gfont.family,
        major_label_font_size = gfont.pointsize * Gadfly.pt,
        key_title_color = fg,
        key_title_font = gfont.family,
        key_title_font_size = gfont.pointsize * Gadfly.pt,
        key_label_color = fg,
        key_label_font = lfont.family,
        key_label_font_size = lfont.pointsize * Gadfly.pt,
        plot_padding = 1 * Gadfly.mm,
        kwargs...
    )
end

# ----------------------------------------------------------------


function createGadflyAnnotationObject(x, y, val::@compat(AbstractString))
    Gadfly.Guide.annotation(Compose.compose(
                              Compose.context(),
                              Compose.text(x, y, val)
                            ))
end

function createGadflyAnnotationObject(x, y, txt::PlotText)
    halign = (txt.font.halign == :hcenter ? Compose.hcenter : (txt.font.halign == :left ? Compose.hleft : Compose.hright))
    valign = (txt.font.valign == :vcenter ? Compose.vcenter : (txt.font.valign == :top ? Compose.vtop : Compose.vbottom))
    rotations = (txt.font.rotation == 0.0 ? [] : [Compose.Rotation(txt.font.rotation, Compose.Point(Compose.x_measure(x), Compose.y_measure(y)))])
    Gadfly.Guide.annotation(Compose.compose(
                              Compose.context(),
                              Compose.text(x, y, txt.str, halign, valign, rotations...),
                              Compose.font(string(txt.font.family)),
                              Compose.fontsize(txt.font.pointsize * Gadfly.pt),
                              Compose.stroke(txt.font.color),
                              Compose.fill(txt.font.color)
                            ))
end

function _add_annotations{X,Y,V}(plt::Plot{GadflyBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
    for ann in anns
        push!(plt.o.guides, createGadflyAnnotationObject(ann...))
    end
end


# ---------------------------------------------------------------------------

# create a blank Gadfly.Plot object
function _create_plot(pkg::GadflyBackend; kw...)
    d = Dict(kw)
    gplt = createGadflyPlotObject(d)
    Plot(gplt, pkg, 0, d, Dict[])
end


# plot one data series
function _add_series(::GadflyBackend, plt::Plot; kw...)
    # first clear out the temporary layer
    gplt = getGadflyContext(plt)
    if gplt.layers[1].geom.tag == :remove
        gplt.layers = gplt.layers[2:end]
    end

    d = Dict(kw)
    addGadflySeries!(plt, d)
    push!(plt.seriesargs, d)
    plt
end



function _update_plot(plt::Plot{GadflyBackend}, d::Dict)
    updateGadflyGuides(plt, d)
    updateGadflyPlotTheme(plt, d)
end


# ----------------------------------------------------------------

# accessors for x/y data

# TODO: need to save all the layer indices which apply to this series
function getGadflyMappings(plt::Plot, i::Integer)
    @assert i > 0 && i <= plt.n
    mappings = [l.mapping for l in plt.seriesargs[i][:gadflylayers]]
end

function Base.getindex(plt::Plot{GadflyBackend}, i::Integer)
    mapping = getGadflyMappings(plt, i)[1]
    mapping[:x], mapping[:y]
end

function Base.setindex!(plt::Plot{GadflyBackend}, xy::Tuple, i::Integer)
    for mapping in getGadflyMappings(plt, i)
        mapping[:x], mapping[:y] = xy
    end
    plt
end

# ----------------------------------------------------------------


# create the underlying object (each backend will do this differently)
function _create_subplot(subplt::Subplot{GadflyBackend}, isbefore::Bool)
    isbefore && return false # wait until after plotting to create the subplots
    subplt.o = nothing
    true
end


function _remove_axis(plt::Plot{GadflyBackend}, isx::Bool)
    gplt = getGadflyContext(plt)
    addOrReplace(gplt.guides, isx ? Gadfly.Guide.xticks : Gadfly.Guide.yticks; label=false)
    addOrReplace(gplt.guides, isx ? Gadfly.Guide.xlabel : Gadfly.Guide.ylabel, "")
end

function _expand_limits(lims, plt::Plot{GadflyBackend}, isx::Bool)
    for l in getGadflyContext(plt).layers
        _expand_limits(lims, l.mapping[isx ? :x : :y])
    end
end


# ----------------------------------------------------------------


getGadflyContext(plt::Plot{GadflyBackend}) = plt.o
getGadflyContext(subplt::Subplot{GadflyBackend}) = buildGadflySubplotContext(subplt)

# create my Compose.Context grid by hstacking and vstacking the Gadfly.Plot objects
function buildGadflySubplotContext(subplt::Subplot)
    rows = Any[]
    row = Any[]
    for (i,(r,c)) in enumerate(subplt.layout)

        # add the Plot object to the row
        push!(row, getGadflyContext(subplt.plts[i]))

        # add the row
        if c == ncols(subplt.layout, r)
            push!(rows, Gadfly.hstack(row...))
            row = Any[]
        end
    end

    # stack the rows
    Gadfly.vstack(rows...)
end

setGadflyDisplaySize(w,h) = Compose.set_default_graphic_size(w * Compose.px, h * Compose.px)
setGadflyDisplaySize(plt::Plot) = setGadflyDisplaySize(plt.plotargs[:size]...)
setGadflyDisplaySize(subplt::Subplot) = setGadflyDisplaySize(getplotargs(subplt, 1)[:size]...)
# -------------------------------------------------------------------------


function dowritemime{P<:Union{GadflyBackend,ImmerseBackend}}(io::IO, func, plt::AbstractPlot{P})
    gplt = getGadflyContext(plt)
    setGadflyDisplaySize(plt)
    Gadfly.draw(func(io, Compose.default_graphic_width, Compose.default_graphic_height), gplt)
end

getGadflyWriteFunc(::MIME"image/png") = Gadfly.PNG
getGadflyWriteFunc(::MIME"image/svg+xml") = Gadfly.SVG
# getGadflyWriteFunc(::MIME"text/html") = Gadfly.SVGJS
getGadflyWriteFunc(::MIME"application/pdf") = Gadfly.PDF
getGadflyWriteFunc(::MIME"application/postscript") = Gadfly.PS
getGadflyWriteFunc(::MIME"application/x-tex") = Gadfly.PGF
getGadflyWriteFunc(m::MIME) = error("Unsupported in Gadfly/Immerse: ", m)

for mime in (MIME"image/png", MIME"image/svg+xml", MIME"application/pdf", MIME"application/postscript", MIME"application/x-tex")
    @eval function Base.writemime{P<:Union{GadflyBackend,ImmerseBackend}}(io::IO, ::$mime, plt::AbstractPlot{P})
        func = getGadflyWriteFunc($mime())
        dowritemime(io, func, plt)
    end
end



function Base.display(::PlotsDisplay, plt::Plot{GadflyBackend})
    setGadflyDisplaySize(plt.plotargs[:size]...)
    display(plt.o)
end


function Base.display(::PlotsDisplay, subplt::Subplot{GadflyBackend})
    setGadflyDisplaySize(getplotargs(subplt,1)[:size]...)
    ctx = buildGadflySubplotContext(subplt)

    # taken from Gadfly since I couldn't figure out how to do it directly

    filename = string(Gadfly.tempname(), ".html")
    output = open(filename, "w")

    plot_output = IOBuffer()
    Gadfly.draw(Gadfly.SVGJS(plot_output, Compose.default_graphic_width,
             Compose.default_graphic_height, false), ctx)
    plotsvg = takebuf_string(plot_output)

    write(output,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Gadfly Plot</title>
          <meta charset="utf-8">
        </head>
          <body>
          <script charset="utf-8">
              $(readall(Compose.snapsvgjs))
          </script>
          <script charset="utf-8">
              $(readall(Gadfly.gadflyjs))
          </script>
          $(plotsvg)
        </body>
      </html>
      """)
    close(output)
    Gadfly.open_file(filename)
end
