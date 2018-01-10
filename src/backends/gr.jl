
# https://github.com/jheinen/GR.jl

# significant contributions by @jheinen

@require Revise begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "gr.jl"))
end

const _gr_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :layout,
    :title, :window_title,
    :guide, :lims, :ticks, :scale, :flip,
    :titlefontfamily, :titlefontsize, :titlefonthalign, :titlefontvalign,
    :titlefontrotation, :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfonthalign, :legendfontvalign,
    :legendfontrotation, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfonthalign, :tickfontvalign,
    :tickfontrotation, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefonthalign, :guidefontvalign,
    :guidefontrotation, :guidefontcolor,
    :grid, :gridalpha, :gridstyle, :gridlinewidth,
    :legend, :legendtitle, :colorbar,
    :fill_z, :line_z, :marker_z, :levels,
    :ribbon, :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :aspect_ratio,
    :normalize, :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :camera,
])
const _gr_seriestype = [
    :path, :scatter,
    :heatmap, :pie, :image,
    :contour, :path3d, :scatter3d, :surface, :wireframe,
    :shape
]
const _gr_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _gr_marker = _allMarkers
const _gr_scale = [:identity, :log10]
is_marker_supported(::GRBackend, shape::Shape) = true

function add_backend_string(::GRBackend)
    """
    Pkg.add("GR")
    Pkg.build("GR")
    """
end

function _initialize_backend(::GRBackend; kw...)
    @eval begin
        import GR
        export GR
    end
end

# --------------------------------------------------------------------------------------

const gr_linetype = KW(
    :auto => 1,
    :solid => 1,
    :dash => 2,
    :dot => 3,
    :dashdot => 4,
    :dashdotdot => -1
)

const gr_markertype = KW(
    :auto => 1,
    :none => -1,
    :circle => -1,
    :rect => -7,
    :diamond => -13,
    :utriangle => -3,
    :dtriangle => -5,
    :ltriangle => -18,
    :rtriangle => -17,
    :pentagon => -21,
    :hexagon => -22,
    :heptagon => -23,
    :octagon => -24,
    :cross => 2,
    :xcross => 5,
    :+ => 2,
    :x => 5,
    :star4 => -25,
    :star5 => -26,
    :star6 => -27,
    :star7 => -28,
    :star8 => -29,
    :vline => -30,
    :hline => -31
)

const gr_halign = KW(
    :left => 1,
    :hcenter => 2,
    :right => 3
)

const gr_valign = KW(
    :top => 1,
    :vcenter => 3,
    :bottom => 5
)

const gr_font_family = Dict(
    "times" => 1,
    "helvetica" => 5,
    "courier" => 9,
    "bookman" => 14,
    "newcenturyschlbk" => 18,
    "avantgarde" => 22,
    "palatino" => 26
)

# --------------------------------------------------------------------------------------

function gr_getcolorind(c)
    GR.settransparency(float(alpha(c)))
    convert(Int, GR.inqcolorfromrgb(red(c), green(c), blue(c)))
end

gr_set_linecolor(c)   = GR.setlinecolorind(gr_getcolorind(_cycle(c,1)))
gr_set_fillcolor(c)   = GR.setfillcolorind(gr_getcolorind(_cycle(c,1)))
gr_set_markercolor(c) = GR.setmarkercolorind(gr_getcolorind(_cycle(c,1)))
gr_set_textcolor(c)   = GR.settextcolorind(gr_getcolorind(_cycle(c,1)))

# --------------------------------------------------------------------------------------


# draw line segments, splitting x/y into contiguous/finite segments
# note: this can be used for shapes by passing func `GR.fillarea`
function gr_polyline(x, y, func = GR.polyline; arrowside=:none)
    iend = 0
    n = length(x)
    while iend < n-1
        # set istart to the first index that is finite
        istart = -1
        for j = iend+1:n
            if isfinite(x[j]) && isfinite(y[j])
                istart = j
                break
            end
        end

        if istart > 0
            # iend is the last finite index
            iend = -1
            for j = istart+1:n
                if isfinite(x[j]) && isfinite(y[j])
                    iend = j
                else
                    break
                end
            end
        end

        # if we found a start and end, draw the line segment, otherwise we're done
        if istart > 0 && iend > 0
            func(x[istart:iend], y[istart:iend])
            if arrowside in (:head,:both)
                GR.drawarrow(x[iend-1], y[iend-1], x[iend], y[iend])
            end
            if arrowside in (:tail,:both)
                GR.drawarrow(x[istart+1], y[istart+1], x[istart], y[istart])
            end
        else
            break
        end
    end
end

gr_inqtext(x, y, s::Symbol) = gr_inqtext(x, y, string(s))

function gr_inqtext(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.inqtextext(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || contains(s, "10^{")
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

gr_text(x, y, s::Symbol) = gr_text(x, y, string(s))

function gr_text(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.mathtex(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || contains(s, "10^{")
        GR.textext(x, y, s)
    else
        GR.text(x, y, s)
    end
end

function gr_polaraxes(rmin::Real, rmax::Real, sp::Subplot)
    GR.savestate()
    xaxis = sp[:xaxis]
    yaxis = sp[:yaxis]

    α = 0:45:315
    a = α .+ 90
    sinf = sind.(a)
    cosf = cosd.(a)
    rtick_values, rtick_labels = get_ticks(yaxis)
    if yaxis[:formatter] == :scientific && yaxis[:ticks] == :auto
        rtick_labels = convert_sci_unicode(rtick_labels)
    end

    #draw angular grid
    if xaxis[:grid]
        gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
        GR.settransparency(xaxis[:gridalpha])
        for i in 1:length(α)
            GR.polyline([sinf[i], 0], [cosf[i], 0])
        end
    end

    #draw radial grid
    if yaxis[:grid]
        gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
        GR.settransparency(yaxis[:gridalpha])
        for i in 1:length(rtick_values)
            r = (rtick_values[i] - rmin) / (rmax - rmin)
            if r <= 1.0 && r >= 0.0
                GR.drawarc(-r, r, -r, r, 0, 359)
            end
        end
        GR.drawarc(-1, 1, -1, 1, 0, 359)
    end

    #prepare to draw ticks
    GR.settransparency(1)
    GR.setlinecolorind(90)
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)

    #draw angular ticks
    if xaxis[:showaxis]
        GR.drawarc(-1, 1, -1, 1, 0, 359)
        for i in 1:length(α)
            x, y = GR.wctondc(1.1 * sinf[i], 1.1 * cosf[i])
            GR.textext(x, y, string((360-α[i])%360, "^o"))
        end
    end

    #draw radial ticks
    if yaxis[:showaxis]
        for i in 1:length(rtick_values)
            r = (rtick_values[i] - rmin) / (rmax - rmin)
            if r <= 1.0 && r >= 0.0
                x, y = GR.wctondc(0.05, r)
                gr_text(x, y, _cycle(rtick_labels, i))
            end
        end
    end
    GR.restorestate()
end


# using the axis extrema and limit overrides, return the min/max value for this axis
gr_x_axislims(sp::Subplot) = axis_limits(sp[:xaxis])
gr_y_axislims(sp::Subplot) = axis_limits(sp[:yaxis])
gr_z_axislims(sp::Subplot) = axis_limits(sp[:zaxis])
gr_xy_axislims(sp::Subplot) = gr_x_axislims(sp)..., gr_y_axislims(sp)...

function gr_lims(axis::Axis, adjust::Bool, expand = nothing)
    if expand != nothing
        expand_extrema!(axis, expand)
    end
    lims = axis_limits(axis)
    if adjust
        GR.adjustrange(lims...)
    else
        lims
    end
end


function gr_fill_viewport(vp::AVec{Float64}, c)
    GR.savestate()
    GR.selntran(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_set_fillcolor(c)
    GR.fillrect(vp...)
    GR.selntran(1)
    GR.restorestate()
end


normalize_zvals(args...) = nothing
function normalize_zvals(zv::AVec, clims::NTuple{2, <:Real})
    vmin, vmax = ignorenan_extrema(zv)
    isfinite(clims[1]) && (vmin = clims[1])
    isfinite(clims[2]) && (vmax = clims[2])
    if vmin == vmax
        zeros(length(zv))
    else
        clamp.((zv - vmin) ./ (vmax - vmin), 0, 1)
    end
end

gr_alpha(α::Void) = 1
gr_alpha(α::Real) = α

# ---------------------------------------------------------

# draw ONE Shape
function gr_draw_marker(xi, yi, msize, shape::Shape)
    sx, sy = coords(shape)
    # convert to ndc coords (percentages of window)
    GR.selntran(0)
    w, h = gr_plot_size
    f = msize / (w + h)
    xi, yi = GR.wctondc(xi, yi)
    GR.fillarea(xi .+ sx .* f,
                yi .+ sy .* f)
    GR.selntran(1)
end

# draw ONE symbol marker
function gr_draw_marker(xi, yi, msize::Number, shape::Symbol)
    GR.setmarkertype(gr_markertype[shape])
    w, h = gr_plot_size
    GR.setmarkersize(0.3msize / ((w + h) * 0.001))
    GR.polymarker([xi], [yi])
end


# draw the markers, one at a time
function gr_draw_markers(series::Series, x, y, msize, mz)
    shapes = series[:markershape]
    if shapes != :none
        for i=1:length(x)
            msi = _cycle(msize, i)
            shape = _cycle(shapes, i)
            cfunc = isa(shape, Shape) ? gr_set_fillcolor : gr_set_markercolor
            cfuncind = isa(shape, Shape) ? GR.setfillcolorind : GR.setmarkercolorind

            # draw a filled in shape, slightly bigger, to estimate a stroke
            if series[:markerstrokewidth] > 0
                cfunc(_cycle(series[:markerstrokecolor], i)) #, series[:markerstrokealpha])
                gr_draw_marker(x[i], y[i], msi + series[:markerstrokewidth], shape)
            end

            # draw the shape
            if mz == nothing
                cfunc(_cycle(series[:markercolor], i)) #, series[:markeralpha])
            else
                # pick a color from the pre-loaded gradient
                ci = round(Int, 1000 + _cycle(mz, i) * 255)
                cfuncind(ci)
                GR.settransparency(_gr_gradient_alpha[ci-999])
            end
            # don't draw filled area if marker shape is 1D
            if !(shape in (:hline, :vline, :+, :x))
                gr_draw_marker(x[i], y[i], msi, shape)
            end
        end
    end
end

function gr_draw_markers(series::Series, x, y, clims)
    isempty(x) && return
    mz = normalize_zvals(series[:marker_z], clims)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_draw_markers(series, x, y, series[:markersize], mz)
end

# ---------------------------------------------------------

function gr_set_line(lw, style, c) #, a)
    GR.setlinetype(gr_linetype[style])
    w, h = gr_plot_size
    GR.setlinewidth(max(0, lw / ((w + h) * 0.001)))
    gr_set_linecolor(c) #, a)
end



function gr_set_fill(c) #, a)
    gr_set_fillcolor(c) #, a)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
end

# this stores the conversion from a font pointsize to "percentage of window height" (which is what GR uses)
const _gr_point_mult = 0.0018 * ones(1)

# set the font attributes... assumes _gr_point_mult has been populated already
function gr_set_font(f::Font; halign = f.halign, valign = f.valign,
                              color = f.color, rotation = f.rotation)
    family = lowercase(f.family)
    GR.setcharheight(_gr_point_mult[1] * f.pointsize)
    GR.setcharup(sind(-rotation), cosd(-rotation))
    if haskey(gr_font_family, family)
        GR.settextfontprec(100 + gr_font_family[family], GR.TEXT_PRECISION_STRING)
    end
    gr_set_textcolor(color)
    GR.settextalign(gr_halign[halign], gr_valign[valign])
end

function gr_nans_to_infs!(z)
    for (i,zi) in enumerate(z)
        if zi == NaN
            z[i] = Inf
        end
    end
end

# --------------------------------------------------------------------------------------
# viewport plot area

# this stays constant for a given subplot while displaying that subplot.
# values are [xmin, xmax, ymin, ymax].  they range [0,1].
const viewport_plotarea = zeros(4)

# the size of the current plot in pixels
const gr_plot_size = [600.0, 400.0]

function gr_viewport_from_bbox(sp::Subplot{GRBackend}, bb::BoundingBox, w, h, viewport_canvas)
    viewport = zeros(4)
    viewport[1] = viewport_canvas[2] * (left(bb) / w)
    viewport[2] = viewport_canvas[2] * (right(bb) / w)
    viewport[3] = viewport_canvas[4] * (1.0 - bottom(bb) / h)
    viewport[4] = viewport_canvas[4] * (1.0 - top(bb) / h)
    if is3d(sp)
        vp = viewport[:]
        extent = min(vp[2] - vp[1], vp[4] - vp[3])
        viewport[1] = 0.5 * (vp[1] + vp[2] - extent)
        viewport[2] = 0.5 * (vp[1] + vp[2] + extent)
        viewport[3] = 0.5 * (vp[3] + vp[4] - extent)
        viewport[4] = 0.5 * (vp[3] + vp[4] + extent)
    end
    if hascolorbar(sp)
        viewport[2] -= 0.1
    end
    viewport
end

# change so we're focused on the viewport area
function gr_set_viewport_cmap(sp::Subplot)
    GR.setviewport(
        viewport_plotarea[2] + (is3d(sp) ? 0.07 : 0.02),
        viewport_plotarea[2] + (is3d(sp) ? 0.10 : 0.05),
        viewport_plotarea[3],
        viewport_plotarea[4]
    )
end

# reset the viewport to the plot area
function gr_set_viewport_plotarea()
    GR.setviewport(
        viewport_plotarea[1],
        viewport_plotarea[2],
        viewport_plotarea[3],
        viewport_plotarea[4]
    )
end

function gr_set_viewport_polar()
    xmin, xmax, ymin, ymax = viewport_plotarea
    ymax -= 0.05 * (xmax - xmin)
    xcenter = 0.5 * (xmin + xmax)
    ycenter = 0.5 * (ymin + ymax)
    r = 0.5 * NaNMath.min(xmax - xmin, ymax - ymin)
    GR.setviewport(xcenter -r, xcenter + r, ycenter - r, ycenter + r)
    GR.setwindow(-1, 1, -1, 1)
    r
end

# add the colorbar
function gr_colorbar(sp::Subplot, clims)
    xmin, xmax = gr_xy_axislims(sp)[1:2]
    gr_set_viewport_cmap(sp)
    l = zeros(Int32, 1, 256)
    l[1,:] = Int[round(Int, _i) for _i in linspace(1000, 1255, 256)]
    GR.setscale(0)
    GR.setwindow(xmin, xmax, clims[1], clims[2])
    GR.cellarray(xmin, xmax, clims[2], clims[1], 1, length(l), l)
    ztick = 0.5 * GR.tick(clims[1], clims[2])
    GR.axes(0, ztick, xmax, clims[1], 0, 1, 0.005)
    gr_set_viewport_plotarea()
end

gr_view_xcenter() = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
gr_view_ycenter() = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])

function gr_legend_pos(s::Symbol,w,h)
    str = string(s)
    if str == "best"
        str = "topright"
    end
    if contains(str,"right")
        xpos = viewport_plotarea[2] - 0.05 - w
    elseif contains(str,"left")
        xpos = viewport_plotarea[1] + 0.11
    else
        xpos = (viewport_plotarea[2]-viewport_plotarea[1])/2 - w/2 +.04
    end
    if contains(str,"top")
        ypos = viewport_plotarea[4] - 0.06
    elseif contains(str,"bottom")
        ypos = viewport_plotarea[3] + h + 0.06
    else
        ypos = (viewport_plotarea[4]-viewport_plotarea[3])/2 + h/2
    end
    (xpos,ypos)
end

function gr_legend_pos(v::Tuple{S,T},w,h) where {S<:Real, T<:Real}
    xpos = v[1] * (viewport_plotarea[2] - viewport_plotarea[1]) + viewport_plotarea[1]
    ypos = v[2] * (viewport_plotarea[4] - viewport_plotarea[3]) + viewport_plotarea[3]
    (xpos,ypos)
end

# --------------------------------------------------------------------------------------

const _gr_gradient_alpha = ones(256)

function gr_set_gradient(c)
    grad = isa(c, ColorGradient) ? c : cgrad()
    for (i,z) in enumerate(linspace(0, 1, 256))
        c = grad[z]
        GR.setcolorrep(999+i, red(c), green(c), blue(c))
        _gr_gradient_alpha[i] = alpha(c)
    end
    grad
end

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot, fmt="")
    GR.clearws()

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0,1,0,1]
    w, h = plt[:size]
    if !haskey(ENV, "PLOTS_TEST")
        dpi_factor = plt[:dpi] / DPI
        if fmt == "png"
            dpi_factor *= 6
        end
    else
        dpi_factor = 1
    end
    gr_plot_size[:] = [w, h]
    if w > h
        ratio = float(h) / w
        msize = display_width_ratio * w * dpi_factor
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        viewport_canvas[3] *= ratio
        viewport_canvas[4] *= ratio
    else
        ratio = float(w) / h
        msize = display_height_ratio * h * dpi_factor
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        viewport_canvas[1] *= ratio
        viewport_canvas[2] *= ratio
    end

    # fill in the viewport_canvas background
    gr_fill_viewport(viewport_canvas, plt[:background_color_outside])

    # update point mult
    px_per_pt = px / pt
    _gr_point_mult[1] = 1.5 * px_per_pt / max(h,w)

    # subplots:
    for sp in plt.subplots
        gr_display(sp, w*px, h*px, viewport_canvas)
    end

    GR.updatews()
end


function gr_set_xticks_font(sp)
    flip = sp[:yaxis][:flip]
    mirror = sp[:xaxis][:mirror]
    gr_set_font(tickfont(sp[:xaxis]),
                halign = (:left, :hcenter, :right)[sign(sp[:xaxis][:rotation]) + 2],
                valign = (mirror ? :bottom : :top),
                rotation = sp[:xaxis][:rotation])
    return flip, mirror
end


function gr_set_yticks_font(sp)
    flip = sp[:xaxis][:flip]
    mirror = sp[:yaxis][:mirror]
    gr_set_font(tickfont(sp[:yaxis]),
                halign = (mirror ? :left : :right),
                valign = (:top, :vcenter, :bottom)[sign(sp[:yaxis][:rotation]) + 2],
                rotation = sp[:yaxis][:rotation])
    return flip, mirror
end

function gr_get_ticks_size(ticks, i)
    GR.savestate()
    GR.selntran(0)
    l = 0.0
    for (cv, dv) in zip(ticks...)
        tb = gr_inqtext(0, 0, string(dv))[i]
        tb_min, tb_max = extrema(tb)
        l = max(l, tb_max - tb_min)
    end
    GR.restorestate()
    return l
end

function _update_min_padding!(sp::Subplot{GRBackend})
    if !haskey(ENV, "GKSwstype")
        if isijulia() || (isdefined(Main, :Juno) && Juno.isactive())
            ENV["GKSwstype"] = "svg"
        end
    end
    # Add margin given by the user
    leftpad   = 2mm  + sp[:left_margin]
    toppad    = 2mm  + sp[:top_margin]
    rightpad  = 4mm  + sp[:right_margin]
    bottompad = 2mm  + sp[:bottom_margin]
    # Add margin for title
    if sp[:title] != ""
        toppad += 5mm
    end
    # Add margin for x and y ticks
    xticks, yticks = axis_drawing_info(sp)[1:2]
    if !(xticks in (nothing, false))
        flip, mirror = gr_set_xticks_font(sp)
        l = gr_get_ticks_size(xticks, 2)
        if mirror
            toppad += 1mm + gr_plot_size[2] * l * px
        else
            bottompad += 1mm + gr_plot_size[2] * l * px
        end
    end
    if !(yticks in (nothing, false))
        flip, mirror = gr_set_yticks_font(sp)
        l = gr_get_ticks_size(yticks, 1)
        if mirror
            rightpad += 1mm + gr_plot_size[1] * l * px
        else
            leftpad += 1mm + gr_plot_size[1] * l * px
        end
    end
    # Add margin for x label
    if sp[:xaxis][:guide] != ""
        bottompad += 4mm
    end
    # Add margin for y label
    if sp[:yaxis][:guide] != ""
        leftpad += 4mm
    end
    sp.minpad = (leftpad, toppad, rightpad, bottompad)
end

function gr_display(sp::Subplot{GRBackend}, w, h, viewport_canvas)
    _update_min_padding!(sp)

    # the viewports for this subplot
    viewport_subplot = gr_viewport_from_bbox(sp, bbox(sp), w, h, viewport_canvas)
    viewport_plotarea[:] = gr_viewport_from_bbox(sp, plotarea(sp), w, h, viewport_canvas)
    # get data limits
    data_lims = gr_xy_axislims(sp)
    xy_lims = data_lims

    ratio = sp[:aspect_ratio]
    if ratio != :none
        if ratio == :equal
            ratio = 1
        end
        viewport_ratio = (viewport_plotarea[2] - viewport_plotarea[1]) / (viewport_plotarea[4] - viewport_plotarea[3])
        window_ratio = (data_lims[2] - data_lims[1]) / (data_lims[4] - data_lims[3]) / ratio
        if window_ratio < viewport_ratio
            viewport_center = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
            viewport_size = (viewport_plotarea[2] - viewport_plotarea[1]) * window_ratio / viewport_ratio
            viewport_plotarea[1] = viewport_center - 0.5 * viewport_size
            viewport_plotarea[2] = viewport_center + 0.5 * viewport_size
        elseif window_ratio > viewport_ratio
            viewport_center = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])
            viewport_size = (viewport_plotarea[4] - viewport_plotarea[3]) * viewport_ratio / window_ratio
            viewport_plotarea[3] = viewport_center - 0.5 * viewport_size
            viewport_plotarea[4] = viewport_center + 0.5 * viewport_size
        end
    end

    # fill in the plot area background
    bg = plot_color(sp[:background_color_inside])
    gr_fill_viewport(viewport_plotarea, bg)

    # reduced from before... set some flags based on the series in this subplot
    # TODO: can these be generic flags?
    outside_ticks = false
    cmap = hascolorbar(sp)
    draw_axes = sp[:framestyle] != :none
    # axes_2d = true
    for series in series_list(sp)
        st = series[:seriestype]
        if st == :pie
            draw_axes = false
        end
        if st == :heatmap
            outside_ticks = true
            x, y = heatmap_edges(series[:x], sp[:xaxis][:scale]), heatmap_edges(series[:y], sp[:yaxis][:scale])
            xy_lims = x[1], x[end], y[1], y[end]
            expand_extrema!(sp[:xaxis], x)
            expand_extrema!(sp[:yaxis], y)
            data_lims = gr_xy_axislims(sp)
        end
    end

    # set our plot area view
    gr_set_viewport_plotarea()

    # these are the Axis objects, which hold scale, lims, etc
    xaxis = sp[:xaxis]
    yaxis = sp[:yaxis]
    zaxis = sp[:zaxis]

    # set the scale flags and window
    xmin, xmax, ymin, ymax = data_lims
    scaleop = 0
    xtick, ytick = 1, 1
    if xmax > xmin && ymax > ymin
        # NOTE: for log axes, the major_x and major_y - if non-zero (omit labels) - control the minor grid lines (1 = draw 9 minor grid lines, 2 = no minor grid lines)
        # NOTE: for log axes, the x_tick and y_tick - if non-zero (omit axes) - only affect the output appearance (1 = nomal, 2 = scientiic notation)
        xaxis[:scale] == :log10 && (scaleop |= GR.OPTION_X_LOG)
        yaxis[:scale] == :log10 && (scaleop |= GR.OPTION_Y_LOG)
        xaxis[:flip]            && (scaleop |= GR.OPTION_FLIP_X)
        yaxis[:flip]            && (scaleop |= GR.OPTION_FLIP_Y)
        if scaleop & GR.OPTION_X_LOG == 0
            majorx = 1 #5
            xtick = GR.tick(xmin, xmax) / majorx
        else
            # log axis
            xtick = 2  # scientific notation
            majorx = 2 # no minor grid lines
        end
        if scaleop & GR.OPTION_Y_LOG == 0
            majory = 1 #5
            ytick = GR.tick(ymin, ymax) / majory
        else
            # log axis
            ytick = 2  # scientific notation
            majory = 2 # no minor grid lines
        end

        # NOTE: setwindow sets the "data coordinate" limits of the current "viewport"
        GR.setwindow(xmin, xmax, ymin, ymax)
        GR.setscale(scaleop)
    end

    # draw the axes
    gr_set_font(tickfont(xaxis))
    GR.setlinewidth(1)

    if is3d(sp)
        zmin, zmax = gr_lims(zaxis, true)
        clims = sp[:clims]
        if is_2tuple(clims)
            isfinite(clims[1]) && (zmin = clims[1])
            isfinite(clims[2]) && (zmax = clims[2])
        end
        GR.setspace(zmin, zmax, round.(Int, sp[:camera])...)
        xtick = GR.tick(xmin, xmax) / 2
        ytick = GR.tick(ymin, ymax) / 2
        ztick = GR.tick(zmin, zmax) / 2
        ticksize = 0.01 * (viewport_plotarea[2] - viewport_plotarea[1])

        if xaxis[:grid]
            gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
            GR.settransparency(xaxis[:gridalpha])
            GR.grid3d(xtick, 0, 0, xmin, ymax, zmin, 2, 0, 0)
        end
        if yaxis[:grid]
            gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
            GR.settransparency(yaxis[:gridalpha])
            GR.grid3d(0, ytick, 0, xmin, ymax, zmin, 0, 2, 0)
        end
        if zaxis[:grid]
            gr_set_line(zaxis[:gridlinewidth], zaxis[:gridstyle], zaxis[:foreground_color_grid])
            GR.settransparency(zaxis[:gridalpha])
            GR.grid3d(0, 0, ztick, xmin, ymax, zmin, 0, 0, 2)
        end
        gr_set_line(1, :solid, xaxis[:foreground_color_axis])
        GR.settransparency(1)
        GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
        GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)

    elseif ispolar(sp)
        r = gr_set_viewport_polar()
        #rmin, rmax = GR.adjustrange(ignorenan_minimum(r), ignorenan_maximum(r))
        rmin, rmax = axis_limits(sp[:yaxis])
        gr_polaraxes(rmin, rmax, sp)

    elseif draw_axes
        if xmax > xmin && ymax > ymin
            GR.setwindow(xmin, xmax, ymin, ymax)
        end

        xticks, yticks, xspine_segs, yspine_segs, xtick_segs, ytick_segs, xgrid_segs, ygrid_segs, xborder_segs, yborder_segs = axis_drawing_info(sp)
        # @show xticks yticks #spine_segs grid_segs

        # draw the grid lines
        if xaxis[:grid]
            # gr_set_linecolor(sp[:foreground_color_grid])
            # GR.grid(xtick, ytick, 0, 0, majorx, majory)
            gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
            GR.settransparency(xaxis[:gridalpha])
            gr_polyline(coords(xgrid_segs)...)
        end
        if yaxis[:grid]
            gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
            GR.settransparency(yaxis[:gridalpha])
            gr_polyline(coords(ygrid_segs)...)
        end
        GR.settransparency(1.0)

        # axis lines
        if xaxis[:showaxis]
            gr_set_line(1, :solid, xaxis[:foreground_color_axis])
            GR.setclip(0)
            gr_polyline(coords(xspine_segs)...)
        end
        if yaxis[:showaxis]
            gr_set_line(1, :solid, yaxis[:foreground_color_axis])
            GR.setclip(0)
            gr_polyline(coords(yspine_segs)...)
        end
        GR.setclip(1)

        # axis ticks
        if xaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, xaxis[:foreground_color_grid])
                GR.settransparency(xaxis[:gridalpha])
            else
                gr_set_line(1, :solid, xaxis[:foreground_color_axis])
            end
            GR.setclip(0)
            gr_polyline(coords(xtick_segs)...)
        end
        if  yaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, yaxis[:foreground_color_grid])
                GR.settransparency(yaxis[:gridalpha])
            else
                gr_set_line(1, :solid, yaxis[:foreground_color_axis])
            end
            GR.setclip(0)
            gr_polyline(coords(ytick_segs)...)
        end
        GR.setclip(1)

        # tick marks
        if !(xticks in (:none, nothing, false)) && xaxis[:showaxis]
            # x labels
            flip, mirror = gr_set_xticks_font(sp)
            for (cv, dv) in zip(xticks...)
                # use xor ($) to get the right y coords
                xi, yi = GR.wctondc(cv, sp[:framestyle] == :origin ? 0 : xor(flip, mirror) ? ymax : ymin)
                # @show cv dv ymin xi yi flip mirror (flip $ mirror)
                # ensure correct dispatch in gr_text for automatic log ticks
                if xaxis[:formatter] == :scientific && xaxis[:ticks] == :auto
                    dv = convert_sci_unicode(dv)
                end
                gr_text(xi, yi + (mirror ? 1 : -1) * 5e-3 * (xaxis[:tick_direction] == :out ? 1.5 : 1.0), string(dv))
            end
        end

        if !(yticks in (:none, nothing, false)) && yaxis[:showaxis]
            # y labels
            flip, mirror = gr_set_yticks_font(sp)
            for (cv, dv) in zip(yticks...)
                # use xor ($) to get the right y coords
                xi, yi = GR.wctondc(sp[:framestyle] == :origin ? 0 : xor(flip, mirror) ? xmax : xmin, cv)
                # @show cv dv xmin xi yi
                # ensure correct dispatch in gr_text for automatic log ticks
                if yaxis[:formatter] == :scientific && yaxis[:ticks] == :auto
                    dv = convert_sci_unicode(dv)
                end
                gr_text(xi + (mirror ? 1 : -1) * 1e-2 * (yaxis[:tick_direction] == :out ? 1.5 : 1.0), yi, string(dv))
            end
        end

        # border
        intensity = sp[:framestyle] == :semi ? 0.5 : 1.0
        if sp[:framestyle] in (:box, :semi)
            gr_set_line(intensity, :solid, xaxis[:foreground_color_border])
            GR.settransparency(intensity)
            gr_polyline(coords(xborder_segs)...)
            gr_set_line(intensity, :solid, yaxis[:foreground_color_border])
            GR.settransparency(intensity)
            gr_polyline(coords(yborder_segs)...)
        end
    end
    # end

    # add the guides
    GR.savestate()
    if sp[:title] != ""
        gr_set_font(titlefont(sp))
        loc = sp[:title_location]
        if loc == :left
            xpos = viewport_plotarea[1]
            halign = GR.TEXT_HALIGN_LEFT
        elseif loc == :right
            xpos = viewport_plotarea[2]
            halign = GR.TEXT_HALIGN_RIGHT
        else
            xpos = gr_view_xcenter()
            halign = GR.TEXT_HALIGN_CENTER
        end
        GR.settextalign(halign, GR.TEXT_VALIGN_TOP)
        gr_text(xpos, viewport_subplot[4], sp[:title])
    end

    if xaxis[:guide] != ""
        gr_set_font(guidefont(xaxis))
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
        gr_text(gr_view_xcenter(), viewport_subplot[3], xaxis[:guide])
    end

    if yaxis[:guide] != ""
        gr_set_font(guidefont(yaxis))
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        GR.setcharup(-1, 0)
        gr_text(viewport_subplot[1], gr_view_ycenter(), yaxis[:guide])
    end
    GR.restorestate()

    gr_set_font(tickfont(xaxis))

    # this needs to be here to point the colormap to the right indices
    GR.setcolormap(1000 + GR.COLORMAP_COOLWARM)

    # calculate the colorbar limits once for a subplot
    clims = get_clims(sp)

    for (idx, series) in enumerate(series_list(sp))
        st = series[:seriestype]

        # update the current stored gradient
        if st in (:contour, :surface, :wireframe, :heatmap)
            gr_set_gradient(series[:fillcolor]) #, series[:fillalpha])
        elseif series[:marker_z] != nothing
            series[:markercolor] = gr_set_gradient(series[:markercolor])
        elseif series[:line_z] !=  nothing
            series[:linecolor] = gr_set_gradient(series[:linecolor])
        elseif series[:fill_z] != nothing
            series[:fillcolor] = gr_set_gradient(series[:fillcolor])
        end

        GR.savestate()


        # update the bounding window
        if ispolar(sp)
            gr_set_viewport_polar()
        else
            xmin, xmax, ymin, ymax = data_lims
            if xmax > xmin && ymax > ymin
                GR.setwindow(xmin, xmax, ymin, ymax)
            end
        end

        x, y, z = series[:x], series[:y], series[:z]
        frng = series[:fillrange]

        # add custom frame shapes to markershape?
        series_annotations_shapes!(series)
        # -------------------------------------------------------

        # recompute data
        if typeof(z) <: Surface
            z = vec(transpose_z(series, z.surf, false))
        elseif ispolar(sp)
            if frng != nothing
                _, frng = convert_to_polar(x, frng, (rmin, rmax))
            end
            x, y = convert_to_polar(x, y, (rmin, rmax))
        end

        if st in (:path, :scatter)
            if length(x) > 1
                lz = series[:line_z]
                segments_iterator = if lz != nothing && length(lz) > 1
                    [i:(i + 1) for i in 1:(length(x) - 1)]
                else
                    iter_segments(x, y)
                end
                # do area fill
                if frng != nothing
                    GR.setfillintstyle(GR.INTSTYLE_SOLID)
                    fr_from, fr_to = (is_2tuple(frng) ? frng : (y, frng))
                    for (i, rng) in enumerate(segments_iterator)
                        gr_set_fillcolor(get_fillcolor(sp, series, i))
                        fx = _cycle(x, vcat(rng, reverse(rng)))
                        fy = vcat(_cycle(fr_from,rng), _cycle(fr_to,reverse(rng)))
                        series[:fillalpha] != nothing && GR.settransparency(series[:fillalpha])
                        GR.fillarea(fx, fy)
                    end
                end

                # draw the line(s)
                if st == :path
                    for (i, rng) in enumerate(segments_iterator)
                        gr_set_line(series[:linewidth], series[:linestyle], get_linecolor(sp, series, i)) #, series[:linealpha])
                        arrowside = isa(series[:arrow], Arrow) ? series[:arrow].side : :none
                        gr_polyline(x[rng], y[rng]; arrowside = arrowside)
                    end
                end
            end

            if series[:markershape] != :none
                if series[:marker_z] != nothing
                    zmin, zmax = extrema(series[:marker_z])
                    GR.setspace(zmin, zmax, 0, 90)
                end
                gr_draw_markers(series, x, y, clims)
            end

        elseif st == :contour
            zmin, zmax = clims
            GR.setspace(zmin, zmax, 0, 90)
            if typeof(series[:levels]) <: Array
                h = series[:levels]
            else
                h = linspace(zmin, zmax, series[:levels])
            end
            if series[:fillrange] != nothing
                GR.surface(x, y, z, GR.OPTION_CELL_ARRAY)
            else
                GR.setlinetype(gr_linetype[series[:linestyle]])
                GR.setlinewidth(max(0, series[:linewidth] / (sum(gr_plot_size) * 0.001)))
                GR.contour(x, y, h, z, 1000)
            end

            # create the colorbar of contour levels
            if cmap
                gr_set_line(1, :solid, yaxis[:foreground_color_axis])
                gr_set_viewport_cmap(sp)
                l = round.(Int32, 1000 + (h - ignorenan_minimum(h)) / (ignorenan_maximum(h) - ignorenan_minimum(h)) * 255)
                GR.setwindow(xmin, xmax, zmin, zmax)
                GR.cellarray(xmin, xmax, zmax, zmin, 1, length(l), l)
                ztick = 0.5 * GR.tick(zmin, zmax)
                GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)
                gr_set_viewport_plotarea()
            end

        elseif st in [:surface, :wireframe]
            if st == :surface
                if length(x) == length(y) == length(z)
                    GR.trisurface(x, y, z)
                else
                    GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
                end
            else
                GR.setfillcolorind(0)
                GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
            end

        elseif st == :heatmap
            xmin, xmax, ymin, ymax = xy_lims
            zmin, zmax = clims
            GR.setspace(zmin, zmax, 0, 90)
            grad = isa(series[:fillcolor], ColorGradient) ? series[:fillcolor] : cgrad()
            colors = [plot_color(grad[clamp((zi-zmin) / (zmax-zmin), 0, 1)], series[:fillalpha]) for zi=z]
            rgba = map(c -> UInt32( round(Int, alpha(c) * 255) << 24 +
                                    round(Int,  blue(c) * 255) << 16 +
                                    round(Int, green(c) * 255) << 8  +
                                    round(Int,   red(c) * 255) ), colors)
            w, h = length(x), length(y)
            GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)

        elseif st in (:path3d, :scatter3d)
            # draw path
            if st == :path3d
                if length(x) > 1
                    lz = series[:line_z]
                    segments_iterator = if lz != nothing && length(lz) > 1
                        [i:(i + 1) for i in 1:(length(x) - 1)]
                    else
                        iter_segments(x, y, z)
                    end
                    for (i, rng) in enumerate(segments_iterator)
                        gr_set_line(series[:linewidth], series[:linestyle], get_linecolor(sp, series, i)) #, series[:linealpha])
                        GR.polyline3d(x[rng], y[rng], z[rng])
                    end
                end
            end

            # draw markers
            if st == :scatter3d || series[:markershape] != :none
                x2, y2 = unzip(map(GR.wc3towc, x, y, z))
                gr_draw_markers(series, x2, y2, clims)
            end

        # TODO: replace with pie recipe
        elseif st == :pie
            GR.selntran(0)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            xmin, xmax, ymin, ymax = viewport_plotarea
            ymax -= 0.1 * (xmax - xmin)
            xcenter = 0.5 * (xmin + xmax)
            ycenter = 0.5 * (ymin + ymax)
            if xmax - xmin > ymax - ymin
                r = 0.5 * (ymax - ymin)
                xmin, xmax = xcenter - r, xcenter + r
            else
                r = 0.5 * (xmax - xmin)
                ymin, ymax = ycenter - r, ycenter + r
            end
            labels = pie_labels(sp, series)
            slices = series[:y]
            numslices = length(slices)
            total = sum(slices)
            a1 = 0
            x = zeros(3)
            y = zeros(3)
            for i in 1:numslices
                a2 = round(Int, a1 + (slices[i] / total) * 360.0)
                GR.setfillcolorind(980 + (i-1) % 20)
                GR.fillarc(xmin, xmax, ymin, ymax, a1, a2)
                α = 0.5 * (a1 + a2)
                cosf = r * cos(α * pi / 180)
                sinf = r * sin(α * pi / 180)
                x[1] = xcenter + cosf
                y[1] = ycenter + sinf
                x[2] = x[1] + 0.1 * cosf
                y[2] = y[1] + 0.1 * sinf
                y[3] = y[2]
                if 90 <= α < 270
                    x[3] = x[2] - 0.05
                    GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
                    gr_text(x[3] - 0.01, y[3], string(labels[i]))
                else
                    x[3] = x[2] + 0.05
                    GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                    gr_text(x[3] + 0.01, y[3], string(labels[i]))
                end
                gr_polyline(x, y)
                a1 = a2
            end
            GR.selntran(1)

        elseif st == :shape
            for (i,rng) in enumerate(iter_segments(x, y))
                if length(rng) > 1
                    # connect to the beginning
                    rng = vcat(rng, rng[1])

                    # get the segments
                    xseg, yseg = x[rng], y[rng]

                    # draw the interior
                    gr_set_fill(get_fillcolor(sp, series, i))
                    GR.fillarea(xseg, yseg)

                    # draw the shapes
                    gr_set_line(series[:linewidth], :solid, get_linecolor(sp, series, i))
                    GR.polyline(xseg, yseg)
                end
            end


        elseif st == :image
            z = transpose_z(series, series[:z].surf, true)'
            w, h = size(z)
            if eltype(z) <: Colors.AbstractGray
                grey = round(UInt8, float(z) * 255)
                rgba = map(c -> UInt32( 0xff000000 + Int(c)<<16 + Int(c)<<8 + Int(c) ), grey)
            else
                rgba = map(c -> UInt32( round(Int, alpha(c) * 255) << 24 +
                                        round(Int,  blue(c) * 255) << 16 +
                                        round(Int, green(c) * 255) << 8  +
                                        round(Int,   red(c) * 255) ), z)
            end
            GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)
        end

        # this is all we need to add the series_annotations text
        anns = series[:series_annotations]
        for (xi,yi,str,fnt) in EachAnn(anns, x, y)
            gr_set_font(fnt)
            gr_text(GR.wctondc(xi, yi)..., str)
        end

        # draw the colorbar
        if cmap && st != :contour # special colorbar with steps is drawn for contours
            gr_set_line(1, :solid, yaxis[:foreground_color_axis])
            GR.settransparency(1)
            gr_colorbar(sp, clims)
        end

        GR.restorestate()
    end


    # add the legend
    if sp[:legend] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        gr_set_font(legendfont(sp))
        w = 0
        i = 0
        n = 0
        if sp[:legendtitle] != nothing
            tbx, tby = gr_inqtext(0, 0, string(sp[:legendtitle]))
            w = tbx[3] - tbx[1]
            n += 1
        end
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            n += 1
            if typeof(series[:label]) <: Array
                i += 1
                lab = series[:label][i]
            else
                lab = series[:label]
            end
            tbx, tby = gr_inqtext(0, 0, string(lab))
            w = max(w, tbx[3] - tbx[1])
        end
        if w > 0
            dy = _gr_point_mult[1] * sp[:legendfontsize] * 1.75
            h = dy*n
            (xpos,ypos) = gr_legend_pos(sp[:legend],w,h)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            gr_set_fillcolor(sp[:background_color_legend])
            GR.fillrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            gr_set_line(1, :solid, sp[:foreground_color_legend])
            GR.drawrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            i = 0
            if sp[:legendtitle] != nothing
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
                gr_set_textcolor(sp[:legendfontcolor])
                GR.settransparency(1)
                gr_text(xpos - 0.03 + 0.5*w, ypos, string(sp[:legendtitle]))
                ypos -= dy
            end
            for series in series_list(sp)
                should_add_to_legend(series) || continue
                st = series[:seriestype]
                gr_set_line(series[:linewidth], series[:linestyle], get_linecolor(sp, series)) #, series[:linealpha])

                if (st == :shape || series[:fillrange] != nothing) && series[:ribbon] == nothing
                    gr_set_fill(get_fillcolor(sp, series)) #, series[:fillalpha])
                    l, r = xpos-0.07, xpos-0.01
                    b, t = ypos-0.4dy, ypos+0.4dy
                    x = [l, r, r, l, l]
                    y = [b, b, t, t, b]
                    GR.settransparency(gr_alpha(series[:fillalpha]))
                    gr_polyline(x, y, GR.fillarea)
                    GR.settransparency(gr_alpha(series[:linealpha]))
                    st == :shape && gr_polyline(x, y)
                end

                if st == :path
                    GR.settransparency(gr_alpha(series[:linealpha]))
                    if series[:fillrange] == nothing || series[:ribbon] != nothing
                        GR.polyline([xpos - 0.07, xpos - 0.01], [ypos, ypos])
                    else
                        GR.polyline([xpos - 0.07, xpos - 0.01], [ypos+0.4dy, ypos+0.4dy])
                    end
                end

                if series[:markershape] != :none
                    gr_draw_markers(series, xpos - .035, ypos, 6, nothing)
                end

                if typeof(series[:label]) <: Array
                    i += 1
                    lab = series[:label][i]
                else
                    lab = series[:label]
                end
                GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                gr_set_textcolor(sp[:legendfontcolor])
                gr_text(xpos, ypos, string(lab))
                ypos -= dy
            end
        end
        GR.selntran(1)
        GR.restorestate()
    end

    # add annotations
    GR.savestate()
    # update the bounding window
    if ispolar(sp)
        gr_set_viewport_polar()
    else
        xmin, xmax, ymin, ymax = data_lims
        if xmax > xmin && ymax > ymin
            GR.setwindow(xmin, xmax, ymin, ymax)
        end
    end
    for ann in sp[:annotations]
        x, y, val = ann
        x, y = if is3d(sp)
            # GR.wc3towc(x, y, z)
        else
            GR.wctondc(x, y)
        end
        gr_set_font(val.font)
        gr_text(x, y, val.str)
    end
    GR.restorestate()
end


# ----------------------------------------------------------------

const _gr_mimeformats = Dict(
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg",
)

const _gr_wstype_default = @static if is_linux()
    "x11"
    # "cairox11"
elseif is_apple()
    "quartz"
else
    "use_default"
end

const _gr_wstype = Ref(get(ENV, "GKSwstype", _gr_wstype_default))
gr_set_output(wstype::String) = (_gr_wstype[] = wstype)

for (mime, fmt) in _gr_mimeformats
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GRBackend})
        GR.emergencyclosegks()
        filepath = tempname() * "." * $fmt
        env = get(ENV, "GKSwstype", "0")
        ENV["GKSwstype"] = $fmt
        ENV["GKS_FILEPATH"] = filepath
        gr_display(plt, $fmt)
        GR.emergencyclosegks()
        write(io, readstring(filepath))
        rm(filepath)
        if env != "0"
            ENV["GKSwstype"] = env
        else
            pop!(ENV,"GKSwstype")
        end
    end
end

function _display(plt::Plot{GRBackend})
    if plt[:display_type] == :inline
        GR.emergencyclosegks()
        filepath = tempname() * ".pdf"
        ENV["GKSwstype"] = "pdf"
        ENV["GKS_FILEPATH"] = filepath
        gr_display(plt)
        GR.emergencyclosegks()
        content = string("\033]1337;File=inline=1;preserveAspectRatio=0:", base64encode(open(read, filepath)), "\a")
        println(content)
        rm(filepath)
    else
        ENV["GKS_DOUBLE_BUF"] = true
        if _gr_wstype[] != "use_default"
            ENV["GKSwstype"] = _gr_wstype[]
        end
        gr_display(plt)
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
