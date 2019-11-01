
# https://github.com/jheinen/GR.jl

# significant contributions by @jheinen

import GR
export GR


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
    gr_set_transparency(float(alpha(c)))
    convert(Int, GR.inqcolorfromrgb(red(c), green(c), blue(c)))
end

gr_set_linecolor(c)   = GR.setlinecolorind(gr_getcolorind(_cycle(c,1)))
gr_set_fillcolor(c)   = GR.setfillcolorind(gr_getcolorind(_cycle(c,1)))
gr_set_markercolor(c) = GR.setmarkercolorind(gr_getcolorind(_cycle(c,1)))
gr_set_textcolor(c)   = GR.settextcolorind(gr_getcolorind(_cycle(c,1)))
gr_set_transparency(α::Real) = GR.settransparency(clamp(α, 0, 1))
gr_set_transparency(::Nothing) = GR.settransparency(1)
gr_set_transparency(c, α) = gr_set_transparency(α)
gr_set_transparency(c::Colorant, ::Nothing) = gr_set_transparency(c)
gr_set_transparency(c::Colorant) = GR.settransparency(alpha(c))

const _gr_arrow_map = Dict(
    :simple => 1,
    :hollow => 3,
    :filled => 4,
    :triangle => 5,
    :filledtriangle => 6,
    :closed => 6,
    :open => 5,
)
gr_set_arrowstyle(s::Symbol) = GR.setarrowstyle(get(_gr_arrow_map, s, 1))

# --------------------------------------------------------------------------------------


# draw line segments, splitting x/y into contiguous/finite segments
# note: this can be used for shapes by passing func `GR.fillarea`
function gr_polyline(x, y, func = GR.polyline; arrowside = :none, arrowstyle = :simple)
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
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[iend-1], y[iend-1], x[iend], y[iend])
            end
            if arrowside in (:tail,:both)
                gr_set_arrowstyle(arrowstyle)
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
        GR.inqmathtex(x, y, s[2:end-1])
    elseif findfirst(isequal('\\'), s) !== nothing || occursin("10^{", s)
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

gr_text(x, y, s::Symbol) = gr_text(x, y, string(s))

function gr_text(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.mathtex(x, y, s[2:end-1])
    elseif findfirst(isequal('\\'), s) !== nothing || occursin("10^{", s)
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
    rtick_values, rtick_labels = get_ticks(sp, yaxis)
    if yaxis[:formatter] in (:scientific, :auto) && yaxis[:ticks] in (:auto, :native)
        rtick_labels = convert_sci_unicode.(rtick_labels)
    end

    #draw angular grid
    if xaxis[:grid]
        gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
        gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
        for i in 1:length(α)
            GR.polyline([sinf[i], 0], [cosf[i], 0])
        end
    end

    #draw radial grid
    if yaxis[:grid]
        gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
        gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:gridalpha])
        for i in 1:length(rtick_values)
            r = (rtick_values[i] - rmin) / (rmax - rmin)
            if r <= 1.0 && r >= 0.0
                GR.drawarc(-r, r, -r, r, 0, 359)
            end
        end
        GR.drawarc(-1, 1, -1, 1, 0, 359)
    end

    #prepare to draw ticks
    gr_set_transparency(1)
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
gr_x_axislims(sp::Subplot) = axis_limits(sp, :x)
gr_y_axislims(sp::Subplot) = axis_limits(sp, :y)
gr_z_axislims(sp::Subplot) = axis_limits(sp, :z)
gr_xy_axislims(sp::Subplot) = gr_x_axislims(sp)..., gr_y_axislims(sp)...

function gr_lims(sp::Subplot, axis::Axis, adjust::Bool, expand = nothing)
    if expand !== nothing
        expand_extrema!(axis, expand)
    end
    lims = axis_limits(sp, axis[:letter])
    if adjust
        GR.adjustrange(lims...)
    else
        lims
    end
end


function gr_fill_viewport(vp::AVec{Float64}, c)
    GR.savestate()
    GR.selntran(0)
    GR.setscale(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_set_fillcolor(c)
    GR.fillrect(vp...)
    GR.selntran(1)
    GR.restorestate()
end

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
function gr_draw_markers(series::Series, x, y, clims, msize = series[:markersize])

    isempty(x) && return
    GR.setfillintstyle(GR.INTSTYLE_SOLID)

    shapes = series[:markershape]
    if shapes != :none
        for i=1:length(x)
            msi = _cycle(msize, i)
            shape = _cycle(shapes, i)
            cfunc = isa(shape, Shape) ? gr_set_fillcolor : gr_set_markercolor

            # draw a filled in shape, slightly bigger, to estimate a stroke
            if series[:markerstrokewidth] > 0
                c = get_markerstrokecolor(series, i)
                cfunc(c)
                gr_set_transparency(c, get_markerstrokealpha(series, i))
                gr_draw_marker(x[i], y[i], msi + series[:markerstrokewidth], shape)
            end

            # draw the shape - don't draw filled area if marker shape is 1D
            if !(shape in (:hline, :vline, :+, :x))
                c = get_markercolor(series, clims, i)
                cfunc(c)
                gr_set_transparency(c, get_markeralpha(series, i))
                gr_draw_marker(x[i], y[i], msi, shape)
            end
        end
    end
end

# ---------------------------------------------------------

function gr_set_line(lw, style, c) #, a)
    GR.setlinetype(gr_linetype[style])
    w, h = gr_plot_size
    GR.setlinewidth(_gr_thickness_scaling[1] * max(0, lw / ((w + h) * 0.001)))
    gr_set_linecolor(c) #, a)
end



function gr_set_fill(c) #, a)
    gr_set_fillcolor(c) #, a)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
end

# this stores the conversion from a font pointsize to "percentage of window height" (which is what GR uses)
const _gr_point_mult = 0.0018 * ones(1)
const _gr_thickness_scaling = ones(1)

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

const gr_colorbar_ratio = 0.1

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
        viewport[2] -= gr_colorbar_ratio
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

struct GRColorbar
    gradients
    fills
    lines
    GRColorbar() = new([],[],[])
end

function gr_update_colorbar!(cbar::GRColorbar, series::Series)
    style = colorbar_style(series)
    style === nothing && return
    list = style == cbar_gradient ? cbar.gradients :
          style == cbar_fill ? cbar.fills :
          style == cbar_lines ? cbar.lines :
          error("Unknown colorbar style: $style.")
    push!(list, series)
end

function gr_contour_levels(series::Series, clims)
    levels = contour_levels(series, clims)
    if isfilledcontour(series)
        # GR implicitly uses the maximal z value as the highest level
        levels = levels[1:end-1]
    end
    levels
end

function gr_colorbar_colors(series::Series, clims)
    if iscontour(series)
        levels = gr_contour_levels(series, clims)
        if isfilledcontour(series)
            # GR.contourf uses a color range according to supplied levels
            zrange = ignorenan_extrema(levels)
        else
            # GR.contour uses a color range according to data range
            zrange = clims
        end
        colors = 1000 .+ 255 .* (levels .- zrange[1]) ./ (zrange[2] - zrange[1])
    else
        colors = 1000:1255
    end
    round.(Int,colors)
end


function _cbar_unique(values, propname)
    out = last(values)
    if any(x != out for x in values)
        @warn "Multiple series with different $propname share a colorbar. " *
              "Colorbar may not reflect all series correctly."
    end
    out
end

# add the colorbar
function gr_draw_colorbar(cbar::GRColorbar, sp::Subplot, clims)
    GR.savestate()
    xmin, xmax = gr_xy_axislims(sp)[1:2]
    zmin, zmax = clims[1:2]
    gr_set_viewport_cmap(sp)
    GR.setscale(0)
    GR.setwindow(xmin, xmax, zmin, zmax)
    if !isempty(cbar.gradients)
        series = cbar.gradients
        gr_set_gradient(_cbar_unique(gr_get_color.(series),"color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        GR.cellarray(xmin, xmax, zmax, zmin, 1, 256, 1000:1255)
    end

    if !isempty(cbar.fills)
        series = cbar.fills
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        gr_set_gradient(_cbar_unique(gr_get_color.(series), "color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        levels = _cbar_unique(contour_levels.(series, Ref(clims)), "levels")
        # GR implicitly uses the maximal z value as the highest level
        if levels[end] < clims[2]
            @warn("GR: highest contour level less than maximal z value is not supported.")
            # replace levels, rather than assign to levels[end], to ensure type
            # promotion in case levels is an integer array
            levels = [levels[1:end-1]; clims[2]]
        end
        colors = gr_colorbar_colors(last(series), clims)
        for (from, to, color) in zip(levels[1:end-1], levels[2:end], colors)
            GR.setfillcolorind(color)
            GR.fillrect( xmin, xmax, from, to )
        end
    end

    if !isempty(cbar.lines)
        series = cbar.lines
        gr_set_gradient(_cbar_unique(gr_get_color.(series),"color"))
        gr_set_line(_cbar_unique(get_linewidth.(series), "line width"),
                    _cbar_unique(get_linestyle.(series), "line style"),
                    _cbar_unique(get_linecolor.(series, Ref(clims)), "line color"))
        gr_set_transparency(_cbar_unique(get_linealpha.(series), "line alpha"))
        levels = _cbar_unique(contour_levels.(series, Ref(clims)), "levels")
        colors = gr_colorbar_colors(last(series), clims)
        for (line, color) in zip(levels, colors)
            GR.setlinecolorind(color)
            GR.polyline([xmin,xmax], [line,line] )
        end
    end

    ztick = 0.5 * GR.tick(zmin, zmax)
    gr_set_line(1, :solid, plot_color(:black))
    GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)

    gr_set_font(guidefont(sp[:yaxis]))
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    gr_text(viewport_plotarea[2] + gr_colorbar_ratio,
            gr_view_ycenter(), sp[:colorbar_title])

    GR.restorestate()
end

gr_view_xcenter() = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
gr_view_ycenter() = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])

function gr_legend_pos(sp::Subplot, w, h)
    s = sp[:legend]
    typeof(s) <: Symbol || return gr_legend_pos(s, w, h)
    str = string(s)
    if str == "best"
        str = "topright"
    end
    if occursin("outer", str)
        xaxis, yaxis = sp[:xaxis], sp[:yaxis]
        xmirror = xaxis[:guide_position] == :top || (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
        ymirror = yaxis[:guide_position] == :right || (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)
    end
    if occursin("right", str)
        if occursin("outer", str)
            # As per https://github.com/jheinen/GR.jl/blob/master/src/jlgr.jl#L525
            xpos = viewport_plotarea[2] + 0.11 + ymirror * gr_yaxis_width(sp)
        else
            xpos = viewport_plotarea[2] - 0.05 - w
        end
    elseif occursin("left", str)
        if occursin("outer", str)
            xpos = viewport_plotarea[1] - 0.05 - w - !ymirror * gr_yaxis_width(sp)
        else
            xpos = viewport_plotarea[1] + 0.11
        end
    else
        xpos = (viewport_plotarea[2]-viewport_plotarea[1])/2 - w/2 +.04
    end
    if occursin("top", str)
        if s == :outertop
            ypos = viewport_plotarea[4] + 0.02 + h + xmirror * gr_xaxis_height(sp)
        else
            ypos = viewport_plotarea[4] - 0.06
        end
    elseif occursin("bottom", str)
        if s == :outerbottom
            ypos = viewport_plotarea[3] - 0.05 - !xmirror * gr_xaxis_height(sp)
        else
            ypos = viewport_plotarea[3] + h + 0.06
        end
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
    grad = _as_gradient(c)
    for (i,z) in enumerate(range(0, stop=1, length=256))
        c = grad[z]
        GR.setcolorrep(999+i, red(c), green(c), blue(c))
        _gr_gradient_alpha[i] = alpha(c)
    end
    grad
end

function gr_set_gradient(series::Series)
    color = gr_get_color(series)
    color !== nothing && gr_set_gradient(color)
end

function gr_get_color(series::Series)
    st = series[:seriestype]
    if st in (:surface, :heatmap) || isfilledcontour(series)
        series[:fillcolor]
    elseif st in (:contour, :wireframe)
        series[:linecolor]
    elseif series[:marker_z] !== nothing
        series[:markercolor]
    elseif series[:line_z] !==  nothing
        series[:linecolor]
    elseif series[:fill_z] !== nothing
        series[:fillcolor]
    end
end

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot, fmt="")
    GR.clearws()

    _gr_thickness_scaling[1] = plt[:thickness_scaling]
    dpi_factor = plt[:dpi] / Plots.DPI
    if fmt == "svg"
        dpi_factor *= 4
    end

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0,1,0,1]
    w, h = plt[:size]
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
    _gr_point_mult[1] = 1.5 * _gr_thickness_scaling[1] * px_per_pt / max(h,w)

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

function gr_text_size(str)
    GR.savestate()
    GR.selntran(0)
    xs, ys = gr_inqtext(0, 0, string(str))
    l, r = extrema(xs)
    b, t = extrema(ys)
    w = r - l
    h = t - b
    GR.restorestate()
    return w, h
end

function gr_text_size(str, rot)
    GR.savestate()
    GR.selntran(0)
    xs, ys = gr_inqtext(0, 0, string(str))
    l, r = extrema(xs)
    b, t = extrema(ys)
    w = text_box_width(r - l, t - b, rot)
    h = text_box_height(r - l, t - b, rot)
    GR.restorestate()
    return w, h
end

text_box_width(w, h, rot) = abs(cosd(rot)) * w + abs(cosd(rot + 90)) * h
text_box_height(w, h, rot) = abs(sind(rot)) * w + abs(sind(rot + 90)) * h

function gr_get_ticks_size(ticks, rot)
    w, h = 0.0, 0.0
    for (cv, dv) in zip(ticks...)
        wi, hi = gr_text_size(dv, rot)
        w = max(w, wi)
        h = max(h, hi)
    end
    return w, h
end

function gr_xaxis_height(sp)
    xaxis = sp[:xaxis]
    xticks, yticks = axis_drawing_info(sp)[1:2]
    gr_set_font(tickfont(xaxis))
    h = (xticks in (nothing, false, :none) ? 0 : last(gr_get_ticks_size(xticks, xaxis[:rotation])))
    if xaxis[:guide] != ""
        gr_set_font(guidefont(xaxis))
        h += last(gr_text_size(xaxis[:guide]))
    end
    return h
end

function gr_yaxis_width(sp)
    yaxis = sp[:yaxis]
    xticks, yticks = axis_drawing_info(sp)[1:2]
    gr_set_font(tickfont(yaxis))
    w = (xticks in (nothing, false, :none) ? 0 : first(gr_get_ticks_size(yticks, yaxis[:rotation])))
    if yaxis[:guide] != ""
        gr_set_font(guidefont(yaxis))
        w += last(gr_text_size(yaxis[:guide]))
    end
    return w
end

function _update_min_padding!(sp::Subplot{GRBackend})
    dpi = sp.plt[:thickness_scaling]
    if !haskey(ENV, "GKSwstype")
        if isijulia()
            ENV["GKSwstype"] = "svg"
        end
    end
    # Add margin given by the user
    leftpad   = 2mm  + sp[:left_margin]
    toppad    = 2mm  + sp[:top_margin]
    rightpad  = 2mm  + sp[:right_margin]
    bottompad = 2mm  + sp[:bottom_margin]
    # Add margin for title
    if sp[:title] != ""
        gr_set_font(titlefont(sp))
        l = last(last(gr_text_size(sp[:title])))
        h = 1mm + gr_plot_size[2] * l * px
        toppad += h
    end
    # Add margin for x and y ticks
    xticks, yticks = axis_drawing_info(sp)[1:2]
    if !(xticks in (nothing, false, :none))
        flip, mirror = gr_set_xticks_font(sp)
        l = 0.01 + last(gr_get_ticks_size(xticks, sp[:xaxis][:rotation]))
        h = 1mm + gr_plot_size[2] * l * px
        if mirror
            toppad += h
        else
            bottompad += h
        end
    end
    if !(yticks in (nothing, false, :none))
        flip, mirror = gr_set_yticks_font(sp)
        l = 0.01 + first(gr_get_ticks_size(yticks, sp[:yaxis][:rotation]))
        w = 1mm + gr_plot_size[1] * l * px
        if mirror
            rightpad += w
        else
            leftpad += w
        end
    end
    # Add margin for x label
    if sp[:xaxis][:guide] != ""
        gr_set_font(guidefont(sp[:xaxis]))
        l = last(gr_text_size(sp[:xaxis][:guide]))
        h = 1mm + gr_plot_size[2] * l * px
        if sp[:xaxis][:guide_position] == :top || (sp[:xaxis][:guide_position] == :auto && sp[:xaxis][:mirror] == true)
            toppad += h
        else
            bottompad += h
        end
    end
    # Add margin for y label
    if sp[:yaxis][:guide] != ""
        gr_set_font(guidefont(sp[:yaxis]))
        l = last(gr_text_size(sp[:yaxis][:guide]))
        w = 1mm + gr_plot_size[2] * l * px
        if sp[:yaxis][:guide_position] == :right || (sp[:yaxis][:guide_position] == :auto && sp[:yaxis][:mirror] == true)
            rightpad += w
        else
            leftpad += w
        end
    end
    if sp[:colorbar_title] != ""
        rightpad += 4mm
    end
    sp.minpad = Tuple(dpi * [leftpad, toppad, rightpad, bottompad])
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

    # calculate legend size
    # has to be done now due to a potential adjustment to the plotarea given an outer legend.
    legendn = 0
    legendw = 0
    if sp[:legend] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        if sp[:legendtitle] !== nothing
            gr_set_font(legendtitlefont(sp))
            tbx, tby = gr_inqtext(0, 0, string(sp[:legendtitle]))
            legendw = tbx[3] - tbx[1]
            legendn += 1
        end
        gr_set_font(legendfont(sp))
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            legendn += 1
            lab = series[:label]
            tbx, tby = gr_inqtext(0, 0, string(lab))
            legendw = max(legendw, tbx[3] - tbx[1])
        end

        GR.setscale(1)
        GR.selntran(1)
        GR.restorestate()
    end

    dy = _gr_point_mult[1] * sp[:legendfontsize] * 1.75
    legendh = dy * legendn
    leg_str = string(sp[:legend])
    if occursin("outer", leg_str)
        if occursin("right", leg_str)
            viewport_plotarea[2] -= legendw + 0.11
        elseif occursin("left", leg_str)
            viewport_plotarea[1] += legendw + 0.11
        elseif occursin("top", leg_str)
            viewport_plotarea[4] -= legendh + 0.03
        elseif occursin("bottom", leg_str)
            viewport_plotarea[3] += legendh + 0.04
        end
    end

    # fill in the plot area background
    bg = plot_color(sp[:background_color_inside])
    gr_fill_viewport(viewport_plotarea, bg)

    # reduced from before... set some flags based on the series in this subplot
    # TODO: can these be generic flags?
    outside_ticks = false
    cbar = GRColorbar()

    draw_axes = sp[:framestyle] != :none
    # axes_2d = true
    for series in series_list(sp)
        st = series[:seriestype]
        if st == :pie
            draw_axes = false
        end
        if st == :heatmap
            outside_ticks = true
            for ax in (sp[:xaxis], sp[:yaxis])
                v = series[ax[:letter]]
            end
            fx, fy = scalefunc(sp[:xaxis][:scale]), scalefunc(sp[:yaxis][:scale])
            nx, ny = length(series[:x]), length(series[:y])
            z = series[:z]
            use_midpoints = size(z) == (ny, nx)
            use_edges = size(z) == (ny - 1, nx - 1)
            if !use_midpoints && !use_edges
                error("""Length of x & y does not match the size of z. 
                        Must be either `size(z) == (length(y), length(x))` (x & y define midpoints)
                        or `size(z) == (length(y)+1, length(x)+1))` (x & y define edges).""")
            end
            x, y = if use_midpoints
                x_diff, y_diff = diff(series[:x]) ./ 2, diff(series[:y]) ./ 2
                x = [ series[:x][1] - x_diff[1], (series[:x][1:end-1] .+ x_diff)..., series[:x][end] + x_diff[end]  ]
                y = [ series[:y][1] - y_diff[1], (series[:y][1:end-1] .+ y_diff)..., series[:y][end] + y_diff[end]  ]
                x, y
            else
                series[:x], series[:y]
            end
            x, y = map(fx, series[:x]), map(fy, series[:y])
            xy_lims = x[1], x[end], y[1], y[end]
            expand_extrema!(sp[:xaxis], x)
            expand_extrema!(sp[:yaxis], y)
            data_lims = gr_xy_axislims(sp)
        end

        gr_update_colorbar!(cbar,series)
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
    GR.setlinewidth(sp.plt[:thickness_scaling])

    if is3d(sp)
        # TODO do we really need a different clims computation here from the one
        #      computed above using get_clims(sp)?
        zmin, zmax = gr_lims(sp, zaxis, true)
        clims3d = sp[:clims]
        if is_2tuple(clims3d)
            isfinite(clims3d[1]) && (zmin = clims3d[1])
            isfinite(clims3d[2]) && (zmax = clims3d[2])
        end
        GR.setspace(zmin, zmax, round.(Int, sp[:camera])...)
        xtick = GR.tick(xmin, xmax) / 2
        ytick = GR.tick(ymin, ymax) / 2
        ztick = GR.tick(zmin, zmax) / 2
        ticksize = 0.01 * (viewport_plotarea[2] - viewport_plotarea[1])

        if xaxis[:grid]
            gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
            gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
            GR.grid3d(xtick, 0, 0, xmin, ymax, zmin, 2, 0, 0)
        end
        if yaxis[:grid]
            gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
            gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:gridalpha])
            GR.grid3d(0, ytick, 0, xmin, ymax, zmin, 0, 2, 0)
        end
        if zaxis[:grid]
            gr_set_line(zaxis[:gridlinewidth], zaxis[:gridstyle], zaxis[:foreground_color_grid])
            gr_set_transparency(zaxis[:foreground_color_grid], zaxis[:gridalpha])
            GR.grid3d(0, 0, ztick, xmin, ymax, zmin, 0, 0, 2)
        end
        gr_set_line(1, :solid, xaxis[:foreground_color_axis])
        gr_set_transparency(xaxis[:foreground_color_axis])
        GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
        GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)

    elseif ispolar(sp)
        r = gr_set_viewport_polar()
        #rmin, rmax = GR.adjustrange(ignorenan_minimum(r), ignorenan_maximum(r))
        rmin, rmax = axis_limits(sp, :y)
        gr_polaraxes(rmin, rmax, sp)

    elseif draw_axes
        if xmax > xmin && ymax > ymin
            GR.setwindow(xmin, xmax, ymin, ymax)
        end

        xticks, yticks, xspine_segs, yspine_segs, xtick_segs, ytick_segs, xgrid_segs, ygrid_segs, xminorgrid_segs, yminorgrid_segs, xborder_segs, yborder_segs = axis_drawing_info(sp)
        # @show xticks yticks #spine_segs grid_segs

        # draw the grid lines
        if xaxis[:grid]
            # gr_set_linecolor(sp[:foreground_color_grid])
            # GR.grid(xtick, ytick, 0, 0, majorx, majory)
            gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
            gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
            gr_polyline(coords(xgrid_segs)...)
        end
        if yaxis[:grid]
            gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
            gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:gridalpha])
            gr_polyline(coords(ygrid_segs)...)
        end
        if xaxis[:minorgrid]
            # gr_set_linecolor(sp[:foreground_color_grid])
            # GR.grid(xtick, ytick, 0, 0, majorx, majory)
            gr_set_line(xaxis[:minorgridlinewidth], xaxis[:minorgridstyle], xaxis[:foreground_color_minor_grid])
            gr_set_transparency(xaxis[:foreground_color_minor_grid], xaxis[:minorgridalpha])
            gr_polyline(coords(xminorgrid_segs)...)
        end
        if yaxis[:minorgrid]
            gr_set_line(yaxis[:minorgridlinewidth], yaxis[:minorgridstyle], yaxis[:foreground_color_minor_grid])
            gr_set_transparency(yaxis[:foreground_color_minor_grid], yaxis[:minorgridalpha])
            gr_polyline(coords(yminorgrid_segs)...)
        end
        gr_set_transparency(1.0)

        # axis lines
        if xaxis[:showaxis]
            gr_set_line(1, :solid, xaxis[:foreground_color_border])
            GR.setclip(0)
            gr_polyline(coords(xspine_segs)...)
        end
        if yaxis[:showaxis]
            gr_set_line(1, :solid, yaxis[:foreground_color_border])
            GR.setclip(0)
            gr_polyline(coords(yspine_segs)...)
        end
        GR.setclip(1)

        # axis ticks
        if xaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, xaxis[:foreground_color_grid])
                gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:tick_direction] == :out ? xaxis[:gridalpha] : 0)
            else
                gr_set_line(1, :solid, xaxis[:foreground_color_axis])
            end
            GR.setclip(0)
            gr_polyline(coords(xtick_segs)...)
        end
        if  yaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, yaxis[:foreground_color_grid])
                gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:tick_direction] == :out ? yaxis[:gridalpha] : 0)
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
                if xaxis[:ticks] in (:auto, :native)
                    # ensure correct dispatch in gr_text for automatic log ticks
                    if xaxis[:scale] in _logScales
                        dv = string(dv, "\\ ")
                    elseif xaxis[:formatter] in (:scientific, :auto)
                        dv = convert_sci_unicode(dv)
                    end
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
                if yaxis[:ticks] in (:auto, :native)
                    # ensure correct dispatch in gr_text for automatic log ticks
                    if yaxis[:scale] in _logScales
                        dv = string(dv, "\\ ")
                    elseif yaxis[:formatter] in (:scientific, :auto)
                        dv = convert_sci_unicode(dv)
                    end
                end
                gr_text(xi + (mirror ? 1 : -1) * 1e-2 * (yaxis[:tick_direction] == :out ? 1.5 : 1.0), yi, string(dv))
            end
        end

        # border
        intensity = sp[:framestyle] == :semi ? 0.5 : 1.0
        if sp[:framestyle] in (:box, :semi)
            gr_set_line(intensity, :solid, xaxis[:foreground_color_border])
            gr_set_transparency(xaxis[:foreground_color_border], intensity)
            gr_polyline(coords(xborder_segs)...)
            gr_set_line(intensity, :solid, yaxis[:foreground_color_border])
            gr_set_transparency(yaxis[:foreground_color_border], intensity)
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
    if is3d(sp)
        gr_set_font(guidefont(xaxis))
        GR.titles3d(xaxis[:guide], yaxis[:guide], zaxis[:guide])
    else
        xticks, yticks = axis_drawing_info(sp)[1:2]
        if xaxis[:guide] != ""
            h = 0.01 + gr_xaxis_height(sp)
            gr_set_font(guidefont(xaxis))
            if xaxis[:guide_position] == :top || (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
                gr_text(gr_view_xcenter(), viewport_plotarea[4] + h, xaxis[:guide])
            else
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
                gr_text(gr_view_xcenter(), viewport_plotarea[3] - h, xaxis[:guide])
            end
        end

        if yaxis[:guide] != ""
            w = 0.02 + gr_yaxis_width(sp)
            gr_set_font(guidefont(yaxis))
            GR.setcharup(-1, 0)
            if yaxis[:guide_position] == :right || (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
                gr_text(viewport_plotarea[2] + w, gr_view_ycenter(), yaxis[:guide])
            else
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
                gr_text(viewport_plotarea[1] - w, gr_view_ycenter(), yaxis[:guide])
            end
        end
    end
    GR.restorestate()

    gr_set_font(tickfont(xaxis))

    # this needs to be here to point the colormap to the right indices
    GR.setcolormap(1000 + GR.COLORMAP_COOLWARM)

    for (idx, series) in enumerate(series_list(sp))
        st = series[:seriestype]

        # update the current stored gradient
        gr_set_gradient(series)

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

        clims = get_clims(sp, series)

        # add custom frame shapes to markershape?
        series_annotations_shapes!(series)
        # -------------------------------------------------------

        # recompute data
        if typeof(z) <: Surface
            z = vec(transpose_z(series, z.surf, false))
        elseif ispolar(sp)
            if frng !== nothing
                _, frng = convert_to_polar(x, frng, (rmin, rmax))
            end
            x, y = convert_to_polar(x, y, (rmin, rmax))
        end

        if st == :straightline
            x, y = straightline_data(series)
        end

        if st in (:path, :scatter, :straightline)
            if x !== nothing && length(x) > 1
                lz = series[:line_z]
                segments = iter_segments(series)
                # do area fill
                if frng !== nothing
                    GR.setfillintstyle(GR.INTSTYLE_SOLID)
                    fr_from, fr_to = (is_2tuple(frng) ? frng : (y, frng))
                    for (i, rng) in enumerate(segments)
                        fc = get_fillcolor(series, clims, i)
                        gr_set_fillcolor(fc)
                        fx = _cycle(x, vcat(rng, reverse(rng)))
                        fy = vcat(_cycle(fr_from,rng), _cycle(fr_to,reverse(rng)))
                        gr_set_transparency(fc, get_fillalpha(series, i))
                        GR.fillarea(fx, fy)
                    end
                end

                # draw the line(s)
                if st in (:path, :straightline)
                    for (i, rng) in enumerate(segments)
                        lc = get_linecolor(series, clims, i)
                        gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc) #, series[:linealpha])
                        arrowside = isa(series[:arrow], Arrow) ? series[:arrow].side : :none
                        arrowstyle = isa(series[:arrow], Arrow) ? series[:arrow].style : :simple
                        gr_set_fillcolor(lc)
                        gr_set_transparency(lc, get_linealpha(series, i))
                        gr_polyline(x[rng], y[rng]; arrowside = arrowside, arrowstyle = arrowstyle)
                    end
                end
            end

            if series[:markershape] != :none
                gr_draw_markers(series, x, y, clims)
            end

        elseif st == :contour
            GR.setspace(clims[1], clims[2], 0, 90)
            GR.setlinetype(gr_linetype[get_linestyle(series)])
            GR.setlinewidth(max(0, get_linewidth(series) / (sum(gr_plot_size) * 0.001)))
            is_lc_black = let black=plot_color(:black)
                plot_color(series[:linecolor]) in (black,[black])
            end
            h = gr_contour_levels(series, clims)
            if series[:fillrange] !== nothing
                if series[:fillcolor] != series[:linecolor] && !is_lc_black
                    @warn("GR: filled contour only supported with black contour lines")
                end
                GR.contourf(x, y, h, z, series[:contour_labels] == true ? 1 : 0)
            else
                coff = is_lc_black ? 0 : 1000
                GR.contour(x, y, h, z, coff + (series[:contour_labels] == true ? 1 : 0))
            end

        elseif st in [:surface, :wireframe]
            if st == :surface
                if length(x) == length(y) == length(z)
                    GR.trisurface(x, y, z)
                else
                    try
                        GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
                    catch
                        GR.surface(x, y, z, GR.OPTION_COLORED_MESH)
                    end
                end
            else
                GR.setfillcolorind(0)
                GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
            end

        elseif st == :volume
            sp[:legend] = :none
            GR.gr3.clear()
            dmin, dmax = GR.gr3.volume(y.v, 0)

        elseif st == :heatmap
            zmin, zmax = clims
            nx, ny = length(series[:x]), length(series[:y])
            use_midpoints = length(z) == ny * nx
            if !ispolar(sp)
                GR.setspace(zmin, zmax, 0, 90)
                x, y = if use_midpoints
                    x_diff, y_diff = diff(series[:x]) ./ 2, diff(series[:y]) ./ 2
                    x = [ series[:x][1] - x_diff[1], (series[:x][1:end-1] .+ x_diff)..., series[:x][end] + x_diff[end] ]
                    y = [ series[:y][1] - y_diff[1], (series[:y][1:end-1] .+ y_diff)..., series[:y][end] + y_diff[end] ]
                    x, y
                else
                    series[:x], series[:y]
                end
                w, h = length(x) - 1, length(y) - 1
                z_normalized = map(x -> GR.jlgr.normalize_color(x, zmin, zmax), z)
                colors = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
                GR.nonuniformcellarray(x, y, w, h, colors)
            else
                phimin, phimax = 0.0, 360.0 # nonuniform polar array is not yet supported in GR.jl
                z_normalized = map(x -> GR.jlgr.normalize_color(x, zmin, zmax), z)
                colors = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
                xmin, xmax, ymin, ymax = xy_lims 
                rmax = data_lims[4]
                GR.setwindow(-rmax, rmax, -rmax, rmax)
                if ymin > 0 
                    @warn "'ymin[1] > 0' (rmin) is not yet supported."
                end
                @show series[:y][end]
                if series[:y][end] != ny
                    @warn "Right now only the maximum value of y (r) is taken into account."
                end
                # GR.polarcellarray(0, 0, phimin, phimax, ymin, ymax, nx, ny, colors)
                GR.polarcellarray(0, 0, phimin, phimax, 0, ymax, nx, ny, colors)
                # Right now only the maximum value of y (r) is taken into account. 
                # This is certainly not perfect but nonuniform polar array is not yet supported in GR.jl
            end

        elseif st in (:path3d, :scatter3d)
            # draw path
            if st == :path3d
                if length(x) > 1
                    lz = series[:line_z]
                    segments = iter_segments(series)
                    for (i, rng) in enumerate(segments)
                        lc = get_linecolor(series, clims, i)
                        gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc) #, series[:linealpha])
                        gr_set_transparency(lc, get_linealpha(series, i))
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
            x, y = shape_data(series)
            for (i,rng) in enumerate(iter_segments(x, y))
                if length(rng) > 1
                    # connect to the beginning
                    rng = vcat(rng, rng[1])

                    # get the segments
                    xseg, yseg = x[rng], y[rng]

                    # draw the interior
                    fc = get_fillcolor(series, clims, i)
                    gr_set_fill(fc)
                    gr_set_transparency(fc, get_fillalpha(series, i))
                    GR.fillarea(xseg, yseg)

                    # draw the shapes
                    lc = get_linecolor(series, clims, i)
                    gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc)
                    gr_set_transparency(lc, get_linealpha(series, i))
                    GR.polyline(xseg, yseg)
                end
            end


        elseif st == :image
            z = transpose_z(series, series[:z].surf, true)'
            w, h = size(z)
            xmin, xmax = ignorenan_extrema(series[:x]); ymin, ymax = ignorenan_extrema(series[:y])
            if eltype(z) <: Colors.AbstractGray
                grey = round.(UInt8, clamp.(float(z) * 255, 0, 255))
                rgba = map(c -> UInt32( 0xff000000 + UInt(c)<<16 + UInt(c)<<8 + UInt(c) ), grey)
            else
                rgba = map(c -> UInt32( round(UInt, clamp(alpha(c) * 255, 0, 255)) << 24 +
                                        round(UInt,  clamp(blue(c) * 255, 0, 255)) << 16 +
                                        round(UInt, clamp(green(c) * 255, 0, 255)) << 8  +
                                        round(UInt,   clamp(red(c) * 255, 0, 255)) ), z)
            end
            GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)
        end

        # this is all we need to add the series_annotations text
        anns = series[:series_annotations]
        for (xi,yi,str,fnt) in EachAnn(anns, x, y)
            gr_set_font(fnt)
            gr_text(GR.wctondc(xi, yi)..., str)
        end

        GR.restorestate()
    end

    # draw the colorbar
    hascolorbar(sp) && gr_draw_colorbar(cbar, sp, get_clims(sp))

    # add the legend
    if sp[:legend] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        gr_set_font(legendfont(sp))
        w = legendw
        n = legendn
        if w > 0
            dy = _gr_point_mult[1] * sp[:legendfontsize] * 1.75
            h = dy*n
            xpos, ypos = gr_legend_pos(sp, w, h)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            gr_set_fillcolor(sp[:background_color_legend])
            GR.fillrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            gr_set_line(1, :solid, sp[:foreground_color_legend])
            GR.drawrect(xpos - 0.08, xpos + w + 0.02, ypos + dy, ypos - dy * n)
            i = 0
            if sp[:legendtitle] !== nothing
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
                gr_set_font(legendtitlefont(sp))
                gr_text(xpos - 0.03 + 0.5*w, ypos, string(sp[:legendtitle]))
                ypos -= dy
                gr_set_font(legendfont(sp))
            end
            for series in series_list(sp)
                clims = get_clims(sp, series)
                should_add_to_legend(series) || continue
                st = series[:seriestype]
                lc = get_linecolor(series, clims)
                gr_set_line(get_linewidth(series), get_linestyle(series), lc) #, series[:linealpha])

                if (st == :shape || series[:fillrange] !== nothing) && series[:ribbon] === nothing
                    fc = get_fillcolor(series, clims)
                    gr_set_fill(fc) #, series[:fillalpha])
                    l, r = xpos-0.07, xpos-0.01
                    b, t = ypos-0.4dy, ypos+0.4dy
                    x = [l, r, r, l, l]
                    y = [b, b, t, t, b]
                    gr_set_transparency(fc, get_fillalpha(series))
                    gr_polyline(x, y, GR.fillarea)
                    lc = get_linecolor(series, clims)
                    gr_set_transparency(lc, get_linealpha(series))
                    gr_set_line(get_linewidth(series), get_linestyle(series), lc)
                    st == :shape && gr_polyline(x, y)
                end

                if st in (:path, :straightline)
                    gr_set_transparency(lc, get_linealpha(series))
                    if series[:fillrange] === nothing || series[:ribbon] !== nothing
                        GR.polyline([xpos - 0.07, xpos - 0.01], [ypos, ypos])
                    else
                        GR.polyline([xpos - 0.07, xpos - 0.01], [ypos+0.4dy, ypos+0.4dy])
                    end
                end

                if series[:markershape] != :none
                    gr_draw_markers(series, xpos - .035, ypos, clims, 6)
                end

                lab = series[:label]
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
        x, y, val = locate_annotation(sp, ann...)
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

const _gr_wstype = Ref(get(ENV, "GKSwstype", ""))
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
        write(io, read(filepath, String))
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
        if _gr_wstype[] != ""
            ENV["GKSwstype"] = _gr_wstype[]
        end
        gr_display(plt)
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
