
# https://github.com/jheinen/GR.jl

# significant contributions by @jheinen

import GR
export GR

# --------------------------------------------------------------------------------------

gr_linetype(k) = (auto = 1, solid = 1, dash = 2, dot = 3, dashdot = 4, dashdotdot = -1)[k]

gr_markertype(k) = (
    auto = 1,
    none = -1,
    circle = -1,
    rect = -7,
    diamond = -13,
    utriangle = -3,
    dtriangle = -5,
    ltriangle = -18,
    rtriangle = -17,
    pentagon = -21,
    hexagon = -22,
    heptagon = -23,
    octagon = -24,
    cross = 2,
    xcross = 5,
    (+) = 2,
    x = 5,
    star4 = -25,
    star5 = -26,
    star6 = -27,
    star7 = -28,
    star8 = -29,
    vline = -30,
    hline = -31,
)[k]

gr_halign(k) = (left = 1, hcenter = 2, right = 3)[k]
gr_valign(k) = (top = 1, vcenter = 3, bottom = 5)[k]

const gr_font_family = Dict(
    # compat:
    "times" => 101,
    "helvetica" => 105,
    "courier" => 109,
    "bookman" => 114,
    "newcenturyschlbk" => 118,
    "avantgarde" => 122,
    "palatino" => 126,
    "serif-roman" => 232,
    "sans-serif" => 233,
    # https://gr-framework.org/fonts.html:
    "times roman" => 101,
    "times italic" => 102,
    "times bold" => 103,
    "times bold italic" => 104,
    "helvetica" => 105,
    "helvetica oblique" => 106,
    "helvetica bold" => 107,
    "helvetica bold oblique" => 108,
    "courier" => 109,
    "courier oblique" => 110,
    "courier bold" => 111,
    "courier bold oblique" => 112,
    "symbol" => 113,
    "bookman light" => 114,
    "bookman light italic" => 115,
    "bookman demi" => 116,
    "bookman demi italic" => 117,
    "new century schoolbook roman" => 118,
    "new century schoolbook italic" => 119,
    "new century schoolbook bold" => 120,
    "new century schoolbook bold italic" => 121,
    "avantgarde book" => 122,
    "avantgarde book oblique" => 123,
    "avantgarde demi" => 124,
    "avantgarde demi oblique" => 125,
    "palatino roman" => 126,
    "palatino italic" => 127,
    "palatino bold" => 128,
    "palatino bold italic" => 129,
    "zapf chancery medium italic" => 130,
    "zapf dingbats" => 131,
    "computer modern" => 232,
    "dejavu sans" => 233,
)

# --------------------------------------------------------------------------------------

gr_color(c) = gr_color(c, color_type(c))

gr_color(c, ::Type{<:AbstractRGB}) = UInt32(
    round(UInt, clamp(alpha(c) * 255, 0, 255)) << 24 +
    round(UInt, clamp(blue(c) * 255, 0, 255)) << 16 +
    round(UInt, clamp(green(c) * 255, 0, 255)) << 8 +
    round(UInt, clamp(red(c) * 255, 0, 255)),
)
function gr_color(c, ::Type{<:AbstractGray})
    g = round(UInt, clamp(gray(c) * 255, 0, 255))
    α = round(UInt, clamp(alpha(c) * 255, 0, 255))
    rgba = UInt32(α << 24 + g << 16 + g << 8 + g)
end
gr_color(c, ::Type) = gr_color(RGBA(c), RGB)

set_RGBA_alpha(alpha, c::RGBA) = RGBA(red(c), green(c), blue(c), alpha)
set_RGBA_alpha(alpha::Nothing, c::RGBA) = c

function gr_getcolorind(c)
    gr_set_transparency(float(alpha(c)))
    convert(Int, GR.inqcolorfromrgb(red(c), green(c), blue(c)))
end

gr_set_linecolor(c) = GR.setlinecolorind(gr_getcolorind(_cycle(c, 1)))
gr_set_fillcolor(c) = GR.setfillcolorind(gr_getcolorind(_cycle(c, 1)))
gr_set_markercolor(c) = GR.setmarkercolorind(gr_getcolorind(_cycle(c, 1)))
gr_set_bordercolor(c) = GR.setbordercolorind(gr_getcolorind(_cycle(c, 1)))
gr_set_textcolor(c) = GR.settextcolorind(gr_getcolorind(_cycle(c, 1)))
gr_set_transparency(α::Real) = GR.settransparency(clamp(α, 0, 1))
gr_set_transparency(::Nothing) = GR.settransparency(1)
gr_set_transparency(c, α) = gr_set_transparency(α)
gr_set_transparency(c::Colorant, ::Nothing) = gr_set_transparency(c)
gr_set_transparency(c::Colorant) = GR.settransparency(alpha(c))

gr_set_arrowstyle(s::Symbol) = GR.setarrowstyle(
    get(
        (
            simple = 1,
            hollow = 3,
            filled = 4,
            triangle = 5,
            filledtriangle = 6,
            closed = 6,
            open = 5,
        ),
        s,
        1,
    ),
)

gr_set_fillstyle(::Nothing) = GR.setfillintstyle(GR.INTSTYLE_SOLID)
function gr_set_fillstyle(s::Symbol)
    GR.setfillintstyle(GR.INTSTYLE_HATCH)
    GR.setfillstyle(get(((/) = 9, (\) = 10, (|) = 7, (-) = 8, (+) = 11, (x) = 6), s, 9))
end

# --------------------------------------------------------------------------------------

# draw line segments, splitting x/y into contiguous/finite segments
# note: this can be used for shapes by passing func `GR.fillarea`
function gr_polyline(x, y, func = GR.polyline; arrowside = :none, arrowstyle = :simple)
    iend = 0
    n = length(x)
    while iend < n - 1
        # set istart to the first index that is finite
        istart = -1
        for j in (iend + 1):n
            if isfinite(x[j]) && isfinite(y[j])
                istart = j
                break
            end
        end

        if istart > 0
            # iend is the last finite index
            iend = -1
            for j in (istart + 1):n
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
            if arrowside in (:head, :both)
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[iend - 1], y[iend - 1], x[iend], y[iend])
            end
            if arrowside in (:tail, :both)
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[istart + 1], y[istart + 1], x[istart], y[istart])
            end
        else
            break
        end
    end
end

function gr_polyline3d(x, y, z, func = GR.polyline3d)
    iend = 0
    n = length(x)
    while iend < n - 1
        # set istart to the first index that is finite
        istart = -1
        for j in (iend + 1):n
            if isfinite(x[j]) && isfinite(y[j]) && isfinite(z[j])
                istart = j
                break
            end
        end

        if istart > 0
            # iend is the last finite index
            iend = -1
            for j in (istart + 1):n
                if isfinite(x[j]) && isfinite(y[j]) && isfinite(z[j])
                    iend = j
                else
                    break
                end
            end
        end

        # if we found a start and end, draw the line segment, otherwise we're done
        if istart > 0 && iend > 0
            func(x[istart:iend], y[istart:iend], z[istart:iend])
        else
            break
        end
    end
end

gr_inqtext(x, y, s) = gr_inqtext(x, y, string(s))

function gr_inqtext(x, y, s::AbstractString)
    if (occursin('\\', s) || occursin("10^{", s)) &&
       match(r".*\$[^\$]+?\$.*", String(s)) == nothing
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

gr_text(x, y, s) = gr_text(x, y, string(s))

function gr_text(x, y, s::AbstractString)
    if (occursin('\\', s) || occursin("10^{", s)) &&
       match(r".*\$[^\$]+?\$.*", String(s)) == nothing
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
    rtick_values, rtick_labels = get_ticks(sp, yaxis, update = false)

    #draw angular grid
    if xaxis[:grid]
        gr_set_line(
            xaxis[:gridlinewidth],
            xaxis[:gridstyle],
            xaxis[:foreground_color_grid],
            sp,
        )
        gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
        for i in eachindex(α)
            GR.polyline([sinf[i], 0], [cosf[i], 0])
        end
    end

    #draw radial grid
    if yaxis[:grid]
        gr_set_line(
            yaxis[:gridlinewidth],
            yaxis[:gridstyle],
            yaxis[:foreground_color_grid],
            sp,
        )
        gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:gridalpha])
        for i in eachindex(rtick_values)
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
        for i in eachindex(α)
            x, y = GR.wctondc(1.1 * sinf[i], 1.1 * cosf[i])
            GR.textext(x, y, string((360 - α[i]) % 360, "^o"))
        end
    end

    #draw radial ticks
    if yaxis[:showaxis]
        for i in eachindex(rtick_values)
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
function gr_draw_marker(series, xi, yi, clims, i, msize, strokewidth, shape::Shape)
    sx, sy = coords(shape)
    # convert to ndc coords (percentages of window) ...
    w, h = get_size(series)
    f = msize / (w + h)

    xi, yi = GR.wctondc(xi, yi)

    # ... convert back to world coordinates
    xs_ys = GR.ndctowc.(xi .+ sx .* f, yi .+ sy .* f)
    xs, ys = getindex.(xs_ys, 1), getindex.(xs_ys, 2)

    # draw the interior
    mc = get_markercolor(series, clims, i)
    gr_set_fill(mc)
    gr_set_transparency(mc, get_markeralpha(series, i))
    GR.fillarea(xs, ys)

    # draw the shapes
    msc = get_markerstrokecolor(series, i)
    gr_set_line(strokewidth, :solid, msc, series)
    gr_set_transparency(msc, get_markerstrokealpha(series, i))
    GR.polyline(xs, ys)
end

function gr_nominal_size(s)
    w, h = get_size(s)
    min(w, h) / 500
end

# draw ONE symbol marker
function gr_draw_marker(series, xi, yi, clims, i, msize, strokewidth, shape::Symbol)
    GR.setborderwidth(strokewidth)
    gr_set_bordercolor(get_markerstrokecolor(series, i))
    gr_set_markercolor(get_markercolor(series, clims, i))
    gr_set_transparency(get_markeralpha(series, i))
    GR.setmarkertype(gr_markertype(shape))
    GR.setmarkersize(0.3msize / gr_nominal_size(series))
    GR.polymarker([xi], [yi])
end

# ---------------------------------------------------------

function gr_set_line(lw, style, c, s) # s can be Subplot or Series
    GR.setlinetype(gr_linetype(style))
    GR.setlinewidth(get_thickness_scaling(s) * max(0, lw / gr_nominal_size(s)))
    gr_set_linecolor(c)
end

function gr_set_fill(c) #, a)
    gr_set_fillcolor(c) #, a)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
end

# this stores the conversion from a font pointsize to "percentage of window height"
# (which is what GR uses). `s` can be a Series, Subplot or Plot
gr_point_mult(s) = 1.5 * get_thickness_scaling(s) * px / pt / maximum(get_size(s))

# set the font attributes.
function gr_set_font(
    f::Font,
    s;
    halign = f.halign,
    valign = f.valign,
    color = f.color,
    rotation = f.rotation,
)
    family = lowercase(f.family)
    GR.setcharheight(gr_point_mult(s) * f.pointsize)
    GR.setcharup(sind(-rotation), cosd(-rotation))
    if haskey(gr_font_family, family)
        GR.settextfontprec(
            gr_font_family[family],
            gr_font_family[family] >= 200 ? 3 : GR.TEXT_PRECISION_STRING,
        )
    end
    gr_set_textcolor(color)
    GR.settextalign(gr_halign(halign), gr_valign(valign))
end

function gr_w3tondc(x, y, z)
    xw, yw, zw = GR.wc3towc(x, y, z)
    x, y = GR.wctondc(xw, yw)
    return x, y
end

# --------------------------------------------------------------------------------------
# viewport plot area
function gr_viewport_from_bbox(
    sp::Subplot{GRBackend},
    bb::BoundingBox,
    w,
    h,
    viewport_canvas,
)
    viewport = zeros(4)
    viewport[1] = viewport_canvas[2] * (left(bb) / w)
    viewport[2] = viewport_canvas[2] * (right(bb) / w)
    viewport[3] = viewport_canvas[4] * (1.0 - bottom(bb) / h)
    viewport[4] = viewport_canvas[4] * (1.0 - top(bb) / h)
    if hascolorbar(sp)
        viewport[2] -= 0.1 * (1 + RecipesPipeline.is3d(sp) / 2)
    end
    viewport
end

# change so we're focused on the viewport area
function gr_set_viewport_cmap(sp::Subplot, viewport_plotarea)
    GR.setviewport(
        viewport_plotarea[2] + (RecipesPipeline.is3d(sp) ? 0.07 : 0.02),
        viewport_plotarea[2] + (RecipesPipeline.is3d(sp) ? 0.10 : 0.05),
        viewport_plotarea[3],
        viewport_plotarea[4],
    )
end

function gr_set_viewport_polar(viewport_plotarea)
    xmin, xmax, ymin, ymax = viewport_plotarea
    ymax -= 0.05 * (xmax - xmin)
    xcenter = 0.5 * (xmin + xmax)
    ycenter = 0.5 * (ymin + ymax)
    r = 0.5 * NaNMath.min(xmax - xmin, ymax - ymin)
    GR.setviewport(xcenter - r, xcenter + r, ycenter - r, ycenter + r)
    GR.setwindow(-1, 1, -1, 1)
    r
end

struct GRColorbar
    gradients
    fills
    lines
    GRColorbar() = new([], [], [])
end

function gr_update_colorbar!(cbar::GRColorbar, series::Series)
    style = colorbar_style(series)
    style === nothing && return
    list =
        style == cbar_gradient ? cbar.gradients :
        style == cbar_fill ? cbar.fills :
        style == cbar_lines ? cbar.lines : error("Unknown colorbar style: $style.")
    push!(list, series)
end

function gr_contour_levels(series::Series, clims)
    levels = contour_levels(series, clims)
    if isfilledcontour(series)
        # GR implicitly uses the maximal z value as the highest level
        levels = levels[1:(end - 1)]
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
    round.(Int, colors)
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
function gr_draw_colorbar(cbar::GRColorbar, sp::Subplot, clims, viewport_plotarea)
    GR.savestate()
    xmin, xmax = gr_xy_axislims(sp)[1:2]
    zmin, zmax = clims[1:2]
    gr_set_viewport_cmap(sp, viewport_plotarea)
    GR.setscale(0)
    GR.setwindow(xmin, xmax, zmin, zmax)
    if !isempty(cbar.gradients)
        series = cbar.gradients
        gr_set_gradient(_cbar_unique(get_colorgradient.(series), "color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        GR.cellarray(xmin, xmax, zmax, zmin, 1, 256, 1000:1255)
    end

    if !isempty(cbar.fills)
        series = cbar.fills
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        gr_set_gradient(_cbar_unique(get_colorgradient.(series), "color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        levels = _cbar_unique(contour_levels.(series, Ref(clims)), "levels")
        # GR implicitly uses the maximal z value as the highest level
        if levels[end] < clims[2]
            @warn "GR: highest contour level less than maximal z value is not supported."
            # replace levels, rather than assign to levels[end], to ensure type
            # promotion in case levels is an integer array
            levels = [levels[1:(end - 1)]; clims[2]]
        end
        colors = gr_colorbar_colors(last(series), clims)
        for (from, to, color) in zip(levels[1:(end - 1)], levels[2:end], colors)
            GR.setfillcolorind(color)
            GR.fillrect(xmin, xmax, from, to)
        end
    end

    if !isempty(cbar.lines)
        series = cbar.lines
        gr_set_gradient(_cbar_unique(get_colorgradient.(series), "color"))
        gr_set_line(
            _cbar_unique(get_linewidth.(series), "line width"),
            _cbar_unique(get_linestyle.(series), "line style"),
            _cbar_unique(get_linecolor.(series, Ref(clims)), "line color"),
            sp,
        )
        gr_set_transparency(_cbar_unique(get_linealpha.(series), "line alpha"))
        levels = _cbar_unique(contour_levels.(series, Ref(clims)), "levels")
        colors = gr_colorbar_colors(last(series), clims)
        for (line, color) in zip(levels, colors)
            GR.setlinecolorind(color)
            GR.polyline([xmin, xmax], [line, line])
        end
    end

    ztick = 0.5 * GR.tick(zmin, zmax)
    gr_set_line(1, :solid, plot_color(:black), sp)
    if sp[:colorbar_scale] == :log10
        GR.setscale(2)
    end
    GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)

    title = if isa(sp[:colorbar_title], PlotText)
        sp[:colorbar_title]
    else
        text(sp[:colorbar_title], colorbartitlefont(sp))
    end
    gr_set_font(title.font, sp)
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    gr_text(viewport_plotarea[2] + 0.1, gr_view_ycenter(viewport_plotarea), title.str)

    GR.restorestate()
end

gr_view_xcenter(viewport_plotarea) = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
gr_view_ycenter(viewport_plotarea) = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])

gr_view_xposition(viewport_plotarea, position) =
    viewport_plotarea[1] + position * (viewport_plotarea[2] - viewport_plotarea[1])
gr_view_yposition(viewport_plotarea, position) =
    viewport_plotarea[3] + position * (viewport_plotarea[4] - viewport_plotarea[3])

function position(symb)
    if symb == :top || symb == :right
        return 0.95
    elseif symb == :left || symb == :bottom
        return 0.05
    end
    return 0.5
end

function alignment(symb)
    if symb == :top || symb == :right
        return GR.TEXT_HALIGN_RIGHT
    elseif symb == :left || symb == :bottom
        return GR.TEXT_HALIGN_LEFT
    end
    return GR.TEXT_HALIGN_CENTER
end

# --------------------------------------------------------------------------------------

function gr_set_gradient(c)
    grad = _as_gradient(c)
    for (i, z) in enumerate(range(0, stop = 1, length = 256))
        c = grad[z]
        GR.setcolorrep(999 + i, red(c), green(c), blue(c))
    end
    grad
end

function gr_set_gradient(series::Series)
    color = get_colorgradient(series)
    color !== nothing && gr_set_gradient(color)
end

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot, fmt = "")
    GR.clearws()

    dpi_factor = fmt == "png" ? plt[:dpi] / Plots.DPI : 1

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px =
        GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0, 1, 0, 1]
    w, h = get_size(plt)
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

    # subplots:
    for sp in plt.subplots
        gr_display(sp, w * px, h * px, viewport_canvas)
    end

    GR.updatews()
end

function gr_set_tickfont(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    gr_set_font(
        tickfont(axis),
        sp,
        rotation = axis[:rotation],
        color = axis[:tickfontcolor],
    )
end

# size of the text with no rotation
function gr_text_size(str)
    GR.savestate()
    GR.selntran(0)
    GR.setcharup(0, 1)
    xs, ys = gr_inqtext(0, 0, string(str))
    l, r = extrema(xs)
    b, t = extrema(ys)
    w = r - l
    h = t - b
    GR.restorestate()
    return w, h
end

# size of the text with rotation applied
function gr_text_size(str, rot)
    GR.savestate()
    GR.selntran(0)
    GR.setcharup(0, 1)
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

function gr_get_3d_axis_angle(cvs, nt, ft, letter)
    length(cvs) < 2 && return 0
    tickpoints = [gr_w3tondc(sort_3d_axes(cv, nt, ft, letter)...) for cv in cvs]

    dx = tickpoints[2][1] - tickpoints[1][1]
    dy = tickpoints[2][2] - tickpoints[1][2]
    return atand(dy, dx)
end

function gr_get_ticks_size(ticks, rot)
    w, h = 0.0, 0.0
    for (cv, dv) in zip(ticks...)
        wi, hi = gr_text_size(dv, rot)
        w = NaNMath.max(w, wi)
        h = NaNMath.max(h, hi)
    end
    return w, h
end

function labelfunc(scale::Symbol, backend::GRBackend)
    texfunc = labelfunc_tex(scale)
    # replace dash with \minus (U+2212)
    label -> replace(texfunc(label), "-" => "−")
end

function gr_axis_height(sp, axis)
    GR.savestate()
    ticks = get_ticks(sp, axis, update = false)
    gr_set_font(tickfont(axis), sp)
    h = (
        ticks in (nothing, false, :none) ? 0 :
        last(gr_get_ticks_size(ticks, axis[:rotation]))
    )
    if axis[:guide] != ""
        gr_set_font(guidefont(axis), sp)
        h += last(gr_text_size(axis[:guide]))
    end
    GR.restorestate()
    return h
end

function gr_axis_width(sp, axis)
    GR.savestate()
    ticks = get_ticks(sp, axis, update = false)
    gr_set_font(tickfont(axis), sp)
    w = (
        ticks in (nothing, false, :none) ? 0 :
        first(gr_get_ticks_size(ticks, axis[:rotation]))
    )
    if axis[:guide] != ""
        gr_set_font(guidefont(axis), sp)
        w += last(gr_text_size(axis[:guide]))
    end
    GR.restorestate()
    return w
end

function _update_min_padding!(sp::Subplot{GRBackend})
    dpi = sp.plt[:thickness_scaling]
    ENV["GKS_ENCODING"] = "utf8"
    if !haskey(ENV, "GKSwstype")
        if isijulia()
            ENV["GKSwstype"] = "svg"
        end
    end
    # Add margin given by the user
    leftpad   = 2mm + sp[:left_margin]
    toppad    = 2mm + sp[:top_margin]
    rightpad  = 2mm + sp[:right_margin]
    bottompad = 2mm + sp[:bottom_margin]
    # Add margin for title
    if sp[:title] != ""
        gr_set_font(titlefont(sp), sp)
        l = last(last(gr_text_size(sp[:title])))
        h = 1mm + get_size(sp)[2] * l * px
        toppad += h
    end

    if RecipesPipeline.is3d(sp)
        xaxis, yaxis, zaxis = sp[:xaxis], sp[:yaxis], sp[:zaxis]
        xticks, yticks, zticks =
            get_ticks(sp, xaxis), get_ticks(sp, yaxis), get_ticks(sp, zaxis)
        # Add margin for x and y ticks
        h = 0mm
        if !isempty(first(xticks))
            gr_set_font(
                tickfont(xaxis),
                sp,
                halign = (:left, :hcenter, :right)[sign(xaxis[:rotation]) + 2],
                valign = (xaxis[:mirror] ? :bottom : :top),
                rotation = xaxis[:rotation],
            )
            l = 0.01 + last(gr_get_ticks_size(xticks, xaxis[:rotation]))
            h = max(h, 1mm + get_size(sp)[2] * l * px)
        end
        if !isempty(first(yticks))
            gr_set_font(
                tickfont(yaxis),
                sp,
                halign = (:left, :hcenter, :right)[sign(yaxis[:rotation]) + 2],
                valign = (yaxis[:mirror] ? :bottom : :top),
                rotation = yaxis[:rotation],
            )
            l = 0.01 + last(gr_get_ticks_size(yticks, yaxis[:rotation]))
            h = max(h, 1mm + get_size(sp)[2] * l * px)
        end
        if h > 0mm
            if xaxis[:mirror] || yaxis[:mirror]
                toppad += h
            end
            if !xaxis[:mirror] || !yaxis[:mirror]
                bottompad += h
            end
        end

        if !isempty(first(zticks))
            gr_set_font(
                tickfont(zaxis),
                sp,
                halign = (zaxis[:mirror] ? :left : :right),
                valign = (:top, :vcenter, :bottom)[sign(zaxis[:rotation]) + 2],
                rotation = zaxis[:rotation],
                color = zaxis[:tickfontcolor],
            )
            l = 0.01 + first(gr_get_ticks_size(zticks, zaxis[:rotation]))
            w = 1mm + get_size(sp)[1] * l * px
            if zaxis[:mirror]
                rightpad += w
            else
                leftpad += w
            end
        end

        # Add margin for x or y label
        h = 0mm
        if xaxis[:guide] != ""
            gr_set_font(guidefont(sp[:xaxis]), sp)
            l = last(gr_text_size(sp[:xaxis][:guide]))
            h = max(h, 1mm + get_size(sp)[2] * l * px)
        end
        if yaxis[:guide] != ""
            gr_set_font(guidefont(sp[:yaxis]), sp)
            l = last(gr_text_size(sp[:yaxis][:guide]))
            h = max(h, 1mm + get_size(sp)[2] * l * px)
        end
        if h > 0mm
            if (
                xaxis[:guide_position] == :top ||
                (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
            )
                toppad += h
            else
                bottompad += h
            end
        end
        # Add margin for z label
        if zaxis[:guide] != ""
            gr_set_font(guidefont(sp[:zaxis]), sp)
            l = last(gr_text_size(sp[:zaxis][:guide]))
            w = 1mm + get_size(sp)[2] * l * px
            if (
                zaxis[:guide_position] == :right ||
                (zaxis[:guide_position] == :auto && zaxis[:mirror] == true)
            )
                rightpad += w
            else
                leftpad += w
            end
        end
    else
        # Add margin for x and y ticks
        xticks, yticks = get_ticks(sp, sp[:xaxis]), get_ticks(sp, sp[:yaxis])
        if !isempty(first(xticks))
            gr_set_tickfont(sp, :x)
            l = 0.01 + last(gr_get_ticks_size(xticks, sp[:xaxis][:rotation]))
            h = 1mm + get_size(sp)[2] * l * px
            if sp[:xaxis][:mirror]
                toppad += h
            else
                bottompad += h
            end
        end
        if !isempty(first(yticks))
            gr_set_tickfont(sp, :y)
            l = 0.01 + first(gr_get_ticks_size(yticks, sp[:yaxis][:rotation]))
            w = 1mm + get_size(sp)[1] * l * px
            if sp[:yaxis][:mirror]
                rightpad += w
            else
                leftpad += w
            end
        end

        # Add margin for x label
        if sp[:xaxis][:guide] != ""
            gr_set_font(guidefont(sp[:xaxis]), sp)
            l = last(gr_text_size(sp[:xaxis][:guide]))
            h = 1mm + get_size(sp)[2] * l * px
            if (
                sp[:xaxis][:guide_position] == :top ||
                (sp[:xaxis][:guide_position] == :auto && sp[:xaxis][:mirror] == true)
            )
                toppad += h
            else
                bottompad += h
            end
        end
        # Add margin for y label
        if sp[:yaxis][:guide] != ""
            gr_set_font(guidefont(sp[:yaxis]), sp)
            l = last(gr_text_size(sp[:yaxis][:guide]))
            w = 1mm + get_size(sp)[2] * l * px
            if (
                sp[:yaxis][:guide_position] == :right ||
                (sp[:yaxis][:guide_position] == :auto && sp[:yaxis][:mirror] == true)
            )
                rightpad += w
            else
                leftpad += w
            end
        end
    end
    if sp[:colorbar_title] != ""
        rightpad += 4mm
    end
    sp.minpad = Tuple(dpi * [leftpad, toppad, rightpad, bottompad])
end

function is_equally_spaced(v)
    d = collect(v[2:end] .- v[1:(end - 1)])
    all(d .≈ d[1])
end

remap(x, lo, hi) = (x - lo) / (hi - lo)
function get_z_normalized(z, clims...)
    isnan(z) && return 256 / 255
    return remap(clamp(z, clims...), clims...)
end

function gr_clims(args...)
    if args[1][:clims] != :auto
        return get_clims(args[1])
    end
    lo, hi = get_clims(args...)
    if lo == hi
        if lo == 0
            hi = one(hi)
        elseif lo < 0
            hi = zero(hi)
        else
            lo = zero(lo)
        end
    end
    return lo, hi
end

function gr_display(sp::Subplot{GRBackend}, w, h, viewport_canvas)
    _update_min_padding!(sp)

    # the viewports for this subplot
    viewport_subplot = gr_viewport_from_bbox(sp, bbox(sp), w, h, viewport_canvas)
    viewport_plotarea = gr_viewport_from_bbox(sp, plotarea(sp), w, h, viewport_canvas)

    # update viewport_plotarea
    leg = gr_get_legend_geometry(viewport_plotarea, sp)
    gr_update_viewport_legend!(viewport_plotarea, sp, leg)
    gr_update_viewport_ratio!(viewport_plotarea, sp)

    # fill in the plot area background
    gr_fill_plotarea(sp, viewport_plotarea)

    # set our plot area view
    GR.setviewport(viewport_plotarea...)

    # set the scale flags and window
    gr_set_window(sp, viewport_plotarea)

    # draw the axes
    gr_draw_axes(sp, viewport_plotarea)
    gr_add_title(sp, viewport_plotarea, viewport_subplot)

    # this needs to be here to point the colormap to the right indices
    GR.setcolormap(1000 + GR.COLORMAP_COOLWARM)

    # init the colorbar
    cbar = GRColorbar()

    for series in series_list(sp)
        gr_add_series(sp, series)
        gr_update_colorbar!(cbar, series)
    end

    # draw the colorbar
    hascolorbar(sp) && gr_draw_colorbar(cbar, sp, gr_clims(sp), viewport_plotarea)

    # add the legend
    gr_add_legend(sp, leg, viewport_plotarea)

    # add annotations
    for ann in sp[:annotations]
        x, y, val = locate_annotation(sp, ann...)
        x, y = if RecipesPipeline.is3d(sp)
            gr_w3tondc(x, y, z)
        else
            GR.wctondc(x, y)
        end
        gr_set_font(val.font, sp)
        gr_text(x, y, val.str)
    end
end

## Legend

function gr_add_legend(sp, leg, viewport_plotarea)
    if !(sp[:legend_position] in (:none, :inline))
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        gr_set_font(legendfont(sp), sp)
        if leg.w > 0
            xpos, ypos = gr_legend_pos(sp, leg, viewport_plotarea)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            gr_set_fillcolor(sp[:legend_background_color])
            GR.fillrect(
                xpos - leg.leftw,
                xpos + leg.textw + leg.rightw,
                ypos + leg.dy,
                ypos - leg.h,
            ) # Allocating white space for actual legend width here
            gr_set_line(1, :solid, sp[:legend_foreground_color], sp)
            GR.drawrect(
                xpos - leg.leftw,
                xpos + leg.textw + leg.rightw,
                ypos + leg.dy,
                ypos - leg.h,
            ) # Drawing actual legend width here
            i = 0
            if sp[:legend_title] !== nothing
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
                gr_set_font(legendtitlefont(sp), sp)
                gr_text(xpos - 0.03 + 0.5 * leg.w, ypos, string(sp[:legend_title]))
                ypos -= leg.dy
                gr_set_font(legendfont(sp), sp)
            end
            for series in series_list(sp)
                clims = gr_clims(sp, series)
                should_add_to_legend(series) || continue
                st = series[:seriestype]
                lc = get_linecolor(series, clims)
                gr_set_line(sp[:legend_font_pointsize] / 8, get_linestyle(series), lc, sp)

                if (
                    (st == :shape || series[:fillrange] !== nothing) &&
                    series[:ribbon] === nothing
                )
                    fc = get_fillcolor(series, clims)
                    gr_set_fill(fc)
                    fs = get_fillstyle(series, i)
                    gr_set_fillstyle(fs)
                    l, r = xpos - leg.width_factor * 3.5, xpos - leg.width_factor / 2
                    b, t = ypos - 0.4 * leg.dy, ypos + 0.4 * leg.dy
                    x = [l, r, r, l, l]
                    y = [b, b, t, t, b]
                    gr_set_transparency(fc, get_fillalpha(series))
                    gr_polyline(x, y, GR.fillarea)
                    lc = get_linecolor(series, clims)
                    gr_set_transparency(lc, get_linealpha(series))
                    gr_set_line(get_linewidth(series), get_linestyle(series), lc, sp)
                    st == :shape && gr_polyline(x, y)
                end

                if st in (:path, :straightline, :path3d)
                    gr_set_transparency(lc, get_linealpha(series))
                    if series[:fillrange] === nothing || series[:ribbon] !== nothing
                        GR.polyline(
                            [xpos - leg.width_factor * 3.5, xpos - leg.width_factor / 2],
                            [ypos, ypos],
                        )
                    else
                        GR.polyline(
                            [xpos - leg.width_factor * 3.5, xpos - leg.width_factor / 2],
                            [ypos + 0.4 * leg.dy, ypos + 0.4 * leg.dy],
                        )
                    end
                end

                if series[:markershape] != :none
                    ms = first(series[:markersize])
                    msw = first(series[:markerstrokewidth])
                    s, sw = if ms > 0
                        0.8 * sp[:legend_font_pointsize],
                        0.8 * sp[:legend_font_pointsize] * msw / ms
                    else
                        0, 0.8 * sp[:legend_font_pointsize] * msw / 8
                    end
                    gr_draw_markers(series, xpos - leg.width_factor * 2, ypos, clims, s, sw)
                end

                lab = series[:label]
                GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                gr_set_textcolor(plot_color(sp[:legend_font_color]))
                gr_text(xpos, ypos, string(lab))
                ypos -= leg.dy
            end
        end
        GR.selntran(1)
        GR.restorestate()
    end
end

function gr_legend_pos(sp::Subplot, leg, viewport_plotarea)
    s = sp[:legend_position]
    s isa Real && return gr_legend_pos(s, leg, viewport_plotarea)
    if s isa Tuple{<:Real,Symbol}
        if s[2] !== :outer
            return gr_legend_pos(s[1], leg, viewport_plotarea)
        end

        xaxis, yaxis = sp[:xaxis], sp[:yaxis]
        xmirror =
            xaxis[:guide_position] == :top ||
            (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
        ymirror =
            yaxis[:guide_position] == :right ||
            (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)
        axisclearance = [
            !ymirror * gr_axis_width(sp, sp[:yaxis]),
            ymirror * gr_axis_width(sp, sp[:yaxis]),
            !xmirror * gr_axis_height(sp, sp[:xaxis]),
            xmirror * gr_axis_height(sp, sp[:xaxis]),
        ]
        return gr_legend_pos(s[1], leg, viewport_plotarea; axisclearance)
    end
    s isa Symbol || return gr_legend_pos(s, viewport_plotarea)
    str = string(s)
    if str == "best"
        str = "topright"
    end
    if occursin("outer", str)
        xaxis, yaxis = sp[:xaxis], sp[:yaxis]
        xmirror =
            xaxis[:guide_position] == :top ||
            (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
        ymirror =
            yaxis[:guide_position] == :right ||
            (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)
    end
    if occursin("right", str)
        if occursin("outer", str)
            # As per https://github.com/jheinen/GR.jl/blob/master/src/jlgr.jl#L525
            xpos =
                viewport_plotarea[2] +
                leg.xoffset +
                leg.leftw +
                ymirror * gr_axis_width(sp, sp[:yaxis])
        else
            xpos = viewport_plotarea[2] - leg.rightw - leg.textw - leg.xoffset
        end
    elseif occursin("left", str)
        if occursin("outer", str)
            xpos =
                viewport_plotarea[1] - !ymirror * gr_axis_width(sp, sp[:yaxis]) -
                leg.xoffset * 2 - leg.rightw - leg.textw
        else
            xpos = viewport_plotarea[1] + leg.leftw + leg.xoffset
        end
    else
        xpos =
            (viewport_plotarea[2] - viewport_plotarea[1]) / 2 +
            viewport_plotarea[1] +
            leg.leftw - leg.rightw - leg.textw - leg.xoffset * 2
    end
    if occursin("top", str)
        if s == :outertop
            ypos =
                viewport_plotarea[4] +
                leg.yoffset +
                leg.h +
                xmirror * gr_axis_height(sp, sp[:xaxis])
        else
            ypos = viewport_plotarea[4] - leg.yoffset - leg.dy
        end
    elseif occursin("bottom", str)
        if s == :outerbottom
            ypos =
                viewport_plotarea[3] - leg.yoffset - leg.dy -
                !xmirror * gr_axis_height(sp, sp[:xaxis])
        else
            ypos = viewport_plotarea[3] + leg.yoffset + leg.h
        end
    else
        # Adding min y to shift legend pos to correct graph (#2377)
        ypos =
            (viewport_plotarea[4] - viewport_plotarea[3] + leg.h) / 2 + viewport_plotarea[3]
    end
    return xpos, ypos
end

function gr_legend_pos(v::Tuple{S,T}, viewport_plotarea) where {S<:Real,T<:Real}
    xpos = v[1] * (viewport_plotarea[2] - viewport_plotarea[1]) + viewport_plotarea[1]
    ypos = v[2] * (viewport_plotarea[4] - viewport_plotarea[3]) + viewport_plotarea[3]
    (xpos, ypos)
end

function gr_legend_pos(theta::Real, leg, viewport_plotarea; axisclearance = nothing)
    xcenter = +(viewport_plotarea[1:2]...) / 2
    ycenter = +(viewport_plotarea[3:4]...) / 2

    if isnothing(axisclearance)
        # Inner
        # rectangle where the anchor can legally be
        xmin = viewport_plotarea[1] + leg.xoffset + leg.leftw
        xmax = viewport_plotarea[2] - leg.xoffset - leg.rightw - leg.textw
        ymin = viewport_plotarea[3] + leg.yoffset + leg.h
        ymax = viewport_plotarea[4] - leg.yoffset - leg.dy
    else
        # Outer
        xmin =
            viewport_plotarea[1] - leg.xoffset - leg.rightw - leg.textw - axisclearance[1]
        xmax = viewport_plotarea[2] + leg.xoffset + leg.leftw + axisclearance[2]
        ymin = viewport_plotarea[3] - leg.yoffset - leg.dy - axisclearance[3]
        ymax = viewport_plotarea[4] + leg.yoffset + leg.h + axisclearance[4]
    end
    return legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax)
end

function gr_get_legend_geometry(viewport_plotarea, sp)
    legendn = legendw = dy = 0
    if sp[:legend_position] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setcharup(0, 1)
        GR.setscale(0)
        if sp[:legend_title] !== nothing
            gr_set_font(legendtitlefont(sp), sp)
            legendn += 1
            tbx, tby = gr_inqtext(0, 0, string(sp[:legend_title]))
            l, r = extrema(tbx)
            b, t = extrema(tby)
            legendw = r - l
            dy = t - b
        end
        gr_set_font(legendfont(sp), sp)
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            legendn += 1
            tbx, tby = gr_inqtext(0, 0, string(series[:label]))
            l, r = extrema(tbx)
            b, t = extrema(tby)
            legendw = max(legendw, r - l) # Holds text width right now
            dy = max(dy, t - b)
        end

        GR.setscale(1)
        GR.selntran(1)
        GR.restorestate()
    end

    legend_width_factor = (viewport_plotarea[2] - viewport_plotarea[1]) / 45 # Determines the width of legend box
    legend_textw = legendw
    legend_rightw = legend_width_factor
    legend_leftw = legend_width_factor * 4
    total_legendw = legend_textw + legend_leftw + legend_rightw

    x_legend_offset = (viewport_plotarea[2] - viewport_plotarea[1]) / 30
    y_legend_offset = (viewport_plotarea[4] - viewport_plotarea[3]) / 30

    dy *= get(sp[:extra_kwargs], :legend_hfactor, 1)
    legendh = dy * legendn

    return (
        w = legendw,
        h = legendh,
        dy = dy,
        leftw = legend_leftw,
        textw = legend_textw,
        rightw = legend_rightw,
        xoffset = x_legend_offset,
        yoffset = y_legend_offset,
        width_factor = legend_width_factor,
    )
end

## Viewport, window and scale

function gr_update_viewport_legend!(viewport_plotarea, sp, leg)
    s = sp[:legend_position]

    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    xmirror =
        xaxis[:guide_position] == :top ||
        (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
    ymirror =
        yaxis[:guide_position] == :right ||
        (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)

    if s isa Tuple{<:Real,Symbol}
        if s[2] === :outer
            (x, y) = gr_legend_pos(sp, leg, viewport_plotarea) # Dry run, to figure out
            if x < viewport_plotarea[1]
                viewport_plotarea[1] +=
                    leg.leftw +
                    leg.textw +
                    leg.rightw +
                    leg.xoffset +
                    !ymirror * gr_axis_width(sp, sp[:yaxis])
            elseif x > viewport_plotarea[2]
                viewport_plotarea[2] -= leg.leftw + leg.textw + leg.rightw + leg.xoffset
            end
            if y < viewport_plotarea[3]
                viewport_plotarea[3] +=
                    leg.h + leg.dy + leg.yoffset + !xmirror * gr_axis_height(sp, sp[:xaxis])
            elseif y > viewport_plotarea[4]
                viewport_plotarea[4] -= leg.h + leg.dy + leg.yoffset
            end
        end
    end
    leg_str = string(s)
    if occursin("outer", leg_str)
        if occursin("right", leg_str)
            viewport_plotarea[2] -= leg.leftw + leg.textw + leg.rightw + leg.xoffset
        elseif occursin("left", leg_str)
            viewport_plotarea[1] +=
                leg.leftw +
                leg.textw +
                leg.rightw +
                leg.xoffset +
                !ymirror * gr_axis_width(sp, sp[:yaxis])
        elseif occursin("top", leg_str)
            viewport_plotarea[4] -= leg.h + leg.dy + leg.yoffset
        elseif occursin("bottom", leg_str)
            viewport_plotarea[3] +=
                leg.h + leg.dy + leg.yoffset + !xmirror * gr_axis_height(sp, sp[:xaxis])
        end
    end
    if s == :inline
        if sp[:yaxis][:mirror]
            viewport_plotarea[1] += leg.w
        else
            viewport_plotarea[2] -= leg.w
        end
    end
end

function gr_update_viewport_ratio!(viewport_plotarea, sp)
    ratio = get_aspect_ratio(sp)
    if ratio != :none
        xmin, xmax, ymin, ymax = gr_xy_axislims(sp)
        if ratio == :equal
            ratio = 1
        end
        viewport_ratio =
            (viewport_plotarea[2] - viewport_plotarea[1]) /
            (viewport_plotarea[4] - viewport_plotarea[3])
        window_ratio = (xmax - xmin) / (ymax - ymin) / ratio
        if window_ratio < viewport_ratio
            viewport_center = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
            viewport_size =
                (viewport_plotarea[2] - viewport_plotarea[1]) * window_ratio /
                viewport_ratio
            viewport_plotarea[1] = viewport_center - 0.5 * viewport_size
            viewport_plotarea[2] = viewport_center + 0.5 * viewport_size
        elseif window_ratio > viewport_ratio
            viewport_center = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])
            viewport_size =
                (viewport_plotarea[4] - viewport_plotarea[3]) * viewport_ratio /
                window_ratio
            viewport_plotarea[3] = viewport_center - 0.5 * viewport_size
            viewport_plotarea[4] = viewport_center + 0.5 * viewport_size
        end
    end
end

function gr_set_window(sp, viewport_plotarea)
    if ispolar(sp)
        gr_set_viewport_polar(viewport_plotarea)
    else
        xmin, xmax, ymin, ymax = gr_xy_axislims(sp)
        needs_3d = needs_any_3d_axes(sp)
        if needs_3d
            zmin, zmax = gr_z_axislims(sp)
            zok = zmax > zmin
        else
            zok = true
        end

        scaleop = 0
        if xmax > xmin && ymax > ymin && zok
            sp[:xaxis][:scale] == :log10 && (scaleop |= GR.OPTION_X_LOG)
            sp[:yaxis][:scale] == :log10 && (scaleop |= GR.OPTION_Y_LOG)
            needs_3d && sp[:zaxis][:scale] == :log10 && (scaleop |= GR.OPTION_Z_LOG)
            sp[:xaxis][:flip] && (scaleop |= GR.OPTION_FLIP_X)
            sp[:yaxis][:flip] && (scaleop |= GR.OPTION_FLIP_Y)
            needs_3d && sp[:zaxis][:flip] && (scaleop |= GR.OPTION_FLIP_Z)
            # NOTE: setwindow sets the "data coordinate" limits of the current "viewport"
            GR.setwindow(xmin, xmax, ymin, ymax)
            GR.setscale(scaleop)
        end
    end
end

function gr_fill_plotarea(sp, viewport_plotarea)
    if !RecipesPipeline.is3d(sp)
        gr_fill_viewport(viewport_plotarea, plot_color(sp[:background_color_inside]))
    end
end

## Axes

function gr_draw_axes(sp, viewport_plotarea)
    GR.setlinewidth(sp.plt[:thickness_scaling])

    if RecipesPipeline.is3d(sp)
        # set space
        xmin, xmax, ymin, ymax = gr_xy_axislims(sp)
        zmin, zmax = gr_z_axislims(sp)

        camera = round.(Int, sp[:camera])

        warn_invalid(val) =
            if val < 0 || val > 90
                @warn "camera: $(val)° ∉ [0°, 90°]"
            end
        warn_invalid.(camera)

        GR.setspace(zmin, zmax, camera...)

        # fill the plot area
        gr_set_fill(plot_color(sp[:background_color_inside]))
        plot_area_x = [xmin, xmin, xmin, xmax, xmax, xmax, xmin]
        plot_area_y = [ymin, ymin, ymax, ymax, ymax, ymin, ymin]
        plot_area_z = [zmin, zmax, zmax, zmax, zmin, zmin, zmin]
        x_bg, y_bg =
            RecipesPipeline.unzip(GR.wc3towc.(plot_area_x, plot_area_y, plot_area_z))
        GR.fillarea(x_bg, y_bg)

        for letter in (:x, :y, :z)
            gr_draw_axis_3d(sp, letter, viewport_plotarea)
        end
    elseif ispolar(sp)
        r = gr_set_viewport_polar(viewport_plotarea)
        #rmin, rmax = GR.adjustrange(ignorenan_minimum(r), ignorenan_maximum(r))
        rmin, rmax = axis_limits(sp, :y)
        gr_polaraxes(rmin, rmax, sp)
    elseif sp[:framestyle] != :none
        for letter in (:x, :y)
            gr_draw_axis(sp, letter, viewport_plotarea)
        end
    end
end

function gr_draw_axis(sp, letter, viewport_plotarea)
    ax = axis_drawing_info(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]

    # draw segments
    gr_draw_grid(sp, axis, ax.grid_segments)
    gr_draw_minorgrid(sp, axis, ax.minorgrid_segments)
    gr_draw_spine(sp, axis, ax.segments)
    gr_draw_border(sp, axis, ax.border_segments)
    gr_draw_ticks(sp, axis, ax.tick_segments)

    # labels
    gr_label_ticks(sp, letter, ax.ticks)
    gr_label_axis(sp, letter, viewport_plotarea)
end

function gr_draw_axis_3d(sp, letter, viewport_plotarea)
    ax = axis_drawing_info_3d(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]

    # draw segments
    gr_draw_grid(sp, axis, ax.grid_segments, gr_polyline3d)
    gr_draw_minorgrid(sp, axis, ax.minorgrid_segments, gr_polyline3d)
    gr_draw_spine(sp, axis, ax.segments, gr_polyline3d)
    gr_draw_border(sp, axis, ax.border_segments, gr_polyline3d)
    gr_draw_ticks(sp, axis, ax.tick_segments, gr_polyline3d)

    # labels
    GR.setscale(0)
    gr_label_ticks_3d(sp, letter, ax.ticks)
    gr_label_axis_3d(sp, letter)
    gr_set_window(sp, viewport_plotarea)
end

function gr_draw_grid(sp, axis, segments, func = gr_polyline)
    if axis[:grid]
        gr_set_line(
            axis[:gridlinewidth],
            axis[:gridstyle],
            axis[:foreground_color_grid],
            sp,
        )
        gr_set_transparency(axis[:foreground_color_grid], axis[:gridalpha])
        func(coords(segments)...)
    end
end

function gr_draw_minorgrid(sp, axis, segments, func = gr_polyline)
    if axis[:minorgrid]
        gr_set_line(
            axis[:minorgridlinewidth],
            axis[:minorgridstyle],
            axis[:foreground_color_minor_grid],
            sp,
        )
        gr_set_transparency(axis[:foreground_color_minor_grid], axis[:minorgridalpha])
        func(coords(segments)...)
    end
end

function gr_draw_spine(sp, axis, segments, func = gr_polyline)
    if axis[:showaxis]
        gr_set_line(1, :solid, axis[:foreground_color_border], sp)
        gr_set_transparency(1.0)
        GR.setclip(0)
        func(coords(segments)...)
        GR.setclip(1)
    end
end

function gr_draw_border(sp, axis, segments, func = gr_polyline)
    intensity = sp[:framestyle] == :semi ? 0.5 : 1
    if sp[:framestyle] in (:box, :semi)
        GR.setclip(0)
        gr_set_line(intensity, :solid, axis[:foreground_color_border], sp)
        gr_set_transparency(axis[:foreground_color_border], intensity)
        func(coords(segments)...)
        GR.setclip(1)
    end
end

function gr_draw_ticks(sp, axis, segments, func = gr_polyline)
    if axis[:showaxis]
        if sp[:framestyle] in (:zerolines, :grid)
            gr_set_line(1, :solid, axis[:foreground_color_grid], sp)
            gr_set_transparency(
                axis[:foreground_color_grid],
                axis[:tick_direction] == :out ? axis[:gridalpha] : 0,
            )
        else
            gr_set_line(1, :solid, axis[:foreground_color_axis], sp)
        end
        GR.setclip(0)
        func(coords(segments)...)
        GR.setclip(1)
    end
end

function gr_label_ticks(sp, letter, ticks)
    axis = sp[get_attr_symbol(letter, :axis)]
    isy = letter === :y
    oletter = isy ? :x : :y
    oaxis = sp[get_attr_symbol(oletter, :axis)]
    oamin, oamax = axis_limits(sp, oletter)
    gr_set_tickfont(sp, letter)
    out_factor = ifelse(axis[:tick_direction] === :out, 1.5, 1)
    x_base_offset = isy ? -1.5e-2 * out_factor : 0
    y_base_offset = isy ? 0 : -8e-3 * out_factor

    rot = axis[:rotation] % 360
    ov = sp[:framestyle] == :origin ? 0 : xor(oaxis[:flip], axis[:mirror]) ? oamax : oamin
    sgn = axis[:mirror] ? -1 : 1
    sgn2 = iseven(Int(floor(rot / 90))) ? -1 : 1
    sgn3 = if isy
        -360 < rot < -180 || 0 < rot < 180 ? 1 : -1
    else
        rot < -270 || -90 < rot < 90 || rot > 270 ? 1 : -1
    end
    for (cv, dv) in zip(ticks...)
        x, y = GR.wctondc(reverse_if((cv, ov), isy)...)
        sz_rot = gr_text_size(dv, rot)
        sz = gr_text_size(dv)
        x_offset = x_base_offset
        y_offset = y_base_offset
        if isy
            x_offset += -first(sz_rot) / 2
            if rot % 90 != 0
                y_offset += sgn2 * last(sz_rot) / 2 + sgn3 * last(sz) * cosd(rot) / 2
            end
        else
            if rot % 90 != 0
                x_offset += sgn2 * first(sz_rot) / 2 + sgn3 * last(sz) * sind(rot) / 2
            end
            y_offset += -last(sz_rot) / 2
        end
        gr_text(x + sgn * x_offset, y + sgn * y_offset, dv)
    end
end

function gr_label_ticks(sp, letter, ticks::Nothing) end

function gr_label_ticks_3d(sp, letter, ticks)
    near_letter = letter in (:x, :z) ? :y : :x
    far_letter = letter in (:x, :y) ? :z : :x

    isy = letter === :y
    isz = letter === :z

    ax = sp[get_attr_symbol(letter, :axis)]
    nax = sp[get_attr_symbol(near_letter, :axis)]
    fax = sp[get_attr_symbol(far_letter, :axis)]

    amin, amax = axis_limits(sp, letter)
    namin, namax = axis_limits(sp, near_letter)
    famin, famax = axis_limits(sp, far_letter)
    n0, n1 = isy ? (namax, namin) : (namin, namax)

    # find out which axes we are dealing with
    i = findfirst(==(letter), (:x, :y, :z))
    letters = axes_shift((:x, :y, :z), 1 - i)
    asyms = get_attr_symbol.(letters, :axis)

    # get axis objects, ticks and minor ticks
    # regardless of the `letter` we now use the convention that `x` in variable names refer to
    # the first axesm `y` to the second, etc ...
    ylims, zlims = axis_limits.(Ref(sp), letters[2:3])
    xax, yax, zax = getindex.(Ref(sp), asyms)

    gr_set_tickfont(sp, letter)
    nt = sp[:framestyle] == :origin ? 0 : ax[:mirror] ? n1 : n0
    ft = sp[:framestyle] == :origin ? 0 : ax[:mirror] ? famax : famin

    rot = mod(ax[:rotation], 360)
    sgn = ax[:mirror] ? -1 : 1

    cvs, dvs = ticks
    ax[:flip] && reverse!(cvs)

    axisθ = isz ? 270 : mod(gr_get_3d_axis_angle(cvs, nt, ft, letter), 360) # issue: doesn't work with 1 tick
    axisϕ = mod(axisθ - 90, 360)

    out_factor = ifelse(ax[:tick_direction] === :out, 1.5, 1)
    axisoffset = out_factor * 1.2e-2
    x_base_offset = axisoffset * cosd(axisϕ)
    y_base_offset = axisoffset * sind(axisϕ)

    sgn2a = sgn2b = sgn3 = 0
    if axisθ != 0 || rot % 90 != 0
        sgn2a =
            (axisθ != 90) && (axisθ == 0 && (rot < 90 || 180 ≤ rot < 270)) ||
            (axisθ == 270) ||
            (axisθ < 90 && (axisθ < rot < 90 || axisθ + 180 < rot < 270)) ||
            (axisθ > 270 && (rot < 90 || axisθ - 180 < rot < 270 || rot > axisθ)) ? -1 : 1
    end

    if (axisθ - 90) % 180 != 0 || (rot - 90) % 180 != 0
        sgn2b =
            axisθ == 0 ||
            (axisθ == 90 && (90 ≤ rot < 180 || 270 ≤ rot < 360)) ||
            (axisθ == 270 && (rot < 90 || 180 ≤ rot < 270)) ||
            (axisθ < 90 && (axisθ < rot < 180 || axisθ + 180 < rot)) ||
            (axisθ > 270 && (rot < axisθ - 180 || 180 ≤ rot < axisθ)) ? -1 : 1
    end

    if !(axisθ == 0 && rot % 180 == 0) && ((rot - 90) % 180 != 0)
        sgn3 =
            (axisθ == 0 && 90 < rot < 270) ||
            (axisθ == 90 && rot < 180) ||
            (axisθ == 270 && rot > 180) ||
            (axisθ < 90 && (rot < axisθ || 90 ≤ rot < 180 || axisθ + 180 < rot < 270)) ||
            (axisθ > 270 && (90 ≤ rot < axisθ - 180 || 180 ≤ rot < 270 || rot > axisθ)) ?
            -1 : 1
    end

    for (cv, dv) in zip((cvs, dvs)...)
        xi, yi = gr_w3tondc(sort_3d_axes(cv, nt, ft, letter)...)
        sz_rot = gr_text_size(dv, rot)
        sz = gr_text_size(dv)
        x_offset =
            x_base_offset + sgn2a * first(sz_rot) / 2 + sgn3 * last(sz) * sind(rot) / 2
        y_offset =
            y_base_offset + sgn2b * last(sz_rot) / 2 + sgn3 * last(sz) * cosd(rot) / 2
        gr_text(xi + sgn * x_offset, yi + sgn * y_offset, dv)
    end
end

function gr_label_axis(sp, letter, viewport_plotarea)
    axis = sp[get_attr_symbol(letter, :axis)]
    mirror = axis[:mirror]
    # guide
    if axis[:guide] != ""
        GR.savestate()
        gr_set_font(guidefont(axis), sp)
        guide_position = axis[:guide_position]
        angle = float(axis[:guidefontrotation])  # github.com/JuliaPlots/Plots.jl/issues/3089
        if letter === :y
            angle += 180.0  # default angle = 0. should yield GR.setcharup(-1, 0) i.e. 180°
            GR.setcharup(cosd(angle), sind(angle))
            ypos = gr_view_yposition(viewport_plotarea, position(axis[:guidefontvalign]))
            yalign = alignment(axis[:guidefontvalign])
            if guide_position === :right || (guide_position == :auto && mirror)
                GR.settextalign(yalign, GR.TEXT_VALIGN_BOTTOM)
                xpos = viewport_plotarea[2] + 0.03 + mirror * gr_axis_width(sp, axis)
            else
                GR.settextalign(yalign, GR.TEXT_VALIGN_TOP)
                xpos = viewport_plotarea[1] - 0.03 - !mirror * gr_axis_width(sp, axis)
            end
        else
            angle += 90.0  # default angle = 0. should yield GR.setcharup(0, 1) i.e. 90°
            GR.setcharup(cosd(angle), sind(angle))
            xpos = gr_view_xposition(viewport_plotarea, position(axis[:guidefonthalign]))
            xalign = alignment(axis[:guidefonthalign])
            if guide_position === :top || (guide_position == :auto && mirror)
                GR.settextalign(xalign, GR.TEXT_VALIGN_TOP)
                ypos =
                    viewport_plotarea[4] +
                    0.015 +
                    (mirror ? gr_axis_height(sp, axis) : 0.015)
            else
                GR.settextalign(xalign, GR.TEXT_VALIGN_BOTTOM)
                ypos =
                    viewport_plotarea[3] - 0.015 -
                    (mirror ? 0.015 : gr_axis_height(sp, axis))
            end
        end
        gr_text(xpos, ypos, axis[:guide])
        GR.restorestate()
    end
end

function gr_label_axis_3d(sp, letter)
    ax = sp[get_attr_symbol(letter, :axis)]
    if ax[:guide] != ""
        near_letter = letter in (:x, :z) ? :y : :x
        far_letter = letter in (:x, :y) ? :z : :x

        nax = sp[get_attr_symbol(near_letter, :axis)]
        fax = sp[get_attr_symbol(far_letter, :axis)]

        amin, amax = axis_limits(sp, letter)
        namin, namax = axis_limits(sp, near_letter)
        famin, famax = axis_limits(sp, far_letter)
        n0, n1 = letter === :y ? (namax, namin) : (namin, namax)

        GR.savestate()
        gr_set_font(
            guidefont(ax),
            sp,
            halign = (:left, :hcenter, :right)[sign(ax[:rotation]) + 2],
            valign = ax[:mirror] ? :bottom : :top,
            rotation = ax[:rotation],
            # color = ax[:guidefontcolor],
        )
        ag = (amin + amax) / 2
        ng = ax[:mirror] ? n1 : n0
        fg = ax[:mirror] ? famax : famin
        x, y = gr_w3tondc(sort_3d_axes(ag, ng, fg, letter)...)
        if letter in (:x, :y)
            h = gr_axis_height(sp, ax)
            x_offset = letter === :x ? -h : h
            y_offset = -h
        else
            x_offset = -0.03 - gr_axis_width(sp, ax)
            y_offset = 0
        end
        letter === :z && GR.setcharup(-1, 0)
        sgn = ax[:mirror] ? -1 : 1
        gr_text(x + sgn * x_offset, y + sgn * y_offset, ax[:guide])
        GR.restorestate()
    end
end

function gr_add_title(sp, viewport_plotarea, viewport_subplot)
    if sp[:title] != ""
        GR.savestate()
        gr_set_font(titlefont(sp), sp)
        loc = sp[:titlelocation]
        if loc == :left
            xpos = viewport_plotarea[1]
            halign = GR.TEXT_HALIGN_LEFT
        elseif loc == :right
            xpos = viewport_plotarea[2]
            halign = GR.TEXT_HALIGN_RIGHT
        else
            xpos = gr_view_xcenter(viewport_plotarea)
            halign = GR.TEXT_HALIGN_CENTER
        end
        GR.settextalign(halign, GR.TEXT_VALIGN_TOP)
        gr_text(xpos, viewport_subplot[4], sp[:title])
        GR.restorestate()
    end
end

## Series

function gr_add_series(sp, series)
    st = series[:seriestype]

    # update the current stored gradient
    gr_set_gradient(series)

    GR.savestate()

    x, y, z = (handle_surface(series[letter]) for letter in (:x, :y, :z))
    xscale, yscale = sp[:xaxis][:scale], sp[:yaxis][:scale]
    frng = series[:fillrange]

    # recompute data
    if ispolar(sp) && z === nothing
        rmin, rmax = axis_limits(sp, :y)
        if frng !== nothing
            _, frng = convert_to_polar(x, frng, (rmin, rmax))
        end
        x, y = convert_to_polar(x, y, (rmin, rmax))
    end

    clims = gr_clims(sp, series)

    # add custom frame shapes to markershape?
    series_annotations_shapes!(series)
    # -------------------------------------------------------

    # draw the series
    if st in (:path, :scatter, :straightline)
        if st === :straightline
            x, y = straightline_data(series)
        end
        gr_draw_segments(series, x, y, frng, clims)
        if series[:markershape] !== :none
            gr_draw_markers(series, x, y, clims)
        end
    elseif st === :shape
        gr_draw_shapes(series, clims)
    elseif st in (:path3d, :scatter3d)
        gr_draw_segments_3d(series, x, y, z, clims)
        if st === :scatter3d || series[:markershape] !== :none
            # TODO: Do we need to transform to 2d coordinates here?
            x2, y2 = RecipesPipeline.unzip(map(GR.wc3towc, x, y, z))
            gr_draw_markers(series, x2, y2, clims)
        end
    elseif st === :contour
        gr_draw_contour(series, x, y, z, clims)
    elseif st in (:surface, :wireframe, :mesh3d)
        gr_draw_surface(series, x, y, z, clims)
    elseif st === :volume
        sp[:legend_position] = :none
        GR.gr3.clear()
        dmin, dmax = GR.gr3.volume(y.v, 0)
    elseif st === :heatmap
        # `z` is already transposed, so we need to reverse before passing its size.
        x, y = heatmap_edges(x, xscale, y, yscale, reverse(size(z)), ispolar(series))
        gr_draw_heatmap(series, x, y, z, clims)
    elseif st === :image
        gr_draw_image(series, x, y, z, clims)
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi, yi, str, fnt) in EachAnn(anns, x, y)
        gr_set_font(fnt, sp)
        gr_text(GR.wctondc(xi, yi)..., str)
    end

    if sp[:legend_position] == :inline && should_add_to_legend(series)
        gr_set_font(legendfont(sp), sp)
        gr_set_textcolor(plot_color(sp[:legend_font_color]))
        if sp[:yaxis][:mirror]
            (_, i) = sp[:xaxis][:flip] ? findmax(x) : findmin(x)
            GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
            offset = -0.01
        else
            (_, i) = sp[:xaxis][:flip] ? findmin(x) : findmax(x)
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            offset = 0.01
        end
        (x_l, y_l) = GR.wctondc(x[i], y[i])
        gr_text(x_l + offset, y_l, series[:label])
    end
    GR.restorestate()
end

function gr_draw_segments(series, x, y, fillrange, clims)
    st = series[:seriestype]
    if x !== nothing && length(x) > 1
        segments = series_segments(series, st; check = true)
        # do area fill
        if fillrange !== nothing
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            fr_from, fr_to = (is_2tuple(fillrange) ? fillrange : (y, fillrange))
            for segment in segments
                i, rng = segment.attr_index, segment.range
                fc = get_fillcolor(series, clims, i)
                gr_set_fillcolor(fc)
                fs = get_fillstyle(series, i)
                gr_set_fillstyle(fs)
                fx = _cycle(x, vcat(rng, reverse(rng)))
                fy = vcat(_cycle(fr_from, rng), _cycle(fr_to, reverse(rng)))
                gr_set_transparency(fc, get_fillalpha(series, i))
                GR.fillarea(fx, fy)
            end
        end

        # draw the line(s)
        if st in (:path, :straightline)
            for segment in segments
                i, rng = segment.attr_index, segment.range
                lc = get_linecolor(series, clims, i)
                gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc, series)
                arrowside = isa(series[:arrow], Arrow) ? series[:arrow].side : :none
                arrowstyle = isa(series[:arrow], Arrow) ? series[:arrow].style : :simple
                gr_set_fillcolor(lc)
                gr_set_transparency(lc, get_linealpha(series, i))
                gr_polyline(x[rng], y[rng]; arrowside = arrowside, arrowstyle = arrowstyle)
            end
        end
    end
end

function gr_draw_segments_3d(series, x, y, z, clims)
    if series[:seriestype] === :path3d && length(x) > 1
        lz = series[:line_z]
        segments = series_segments(series, :path3d; check = true)
        for segment in segments
            i, rng = segment.attr_index, segment.range
            lc = get_linecolor(series, clims, i)
            gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc, series)
            gr_set_transparency(lc, get_linealpha(series, i))
            GR.polyline3d(x[rng], y[rng], z[rng])
        end
    end
end

function gr_draw_markers(
    series::Series,
    x,
    y,
    clims,
    msize = series[:markersize],
    strokewidth = series[:markerstrokewidth],
)
    isempty(x) && return
    GR.setfillintstyle(GR.INTSTYLE_SOLID)

    shapes = series[:markershape]
    if shapes != :none
        for segment in series_segments(series, :scatter)
            i = segment.attr_index
            rng = intersect(eachindex(x), segment.range)
            if !isempty(rng)
                ms = get_thickness_scaling(series) * _cycle(msize, i)
                msw = get_thickness_scaling(series) * _cycle(strokewidth, i)
                shape = _cycle(shapes, i)
                for j in rng
                    gr_draw_marker(
                        series,
                        _cycle(x, j),
                        _cycle(y, j),
                        clims,
                        i,
                        ms,
                        msw,
                        shape,
                    )
                end
            end
        end
    end
end

function gr_draw_shapes(series, clims)
    x, y = shape_data(series)
    for segment in series_segments(series, :shape)
        i, rng = segment.attr_index, segment.range
        if length(rng) > 1
            # connect to the beginning
            rng = vcat(rng, rng[1])

            # get the segments
            xseg, yseg = x[rng], y[rng]

            # draw the interior
            fc = get_fillcolor(series, clims, i)
            gr_set_fill(fc)
            fs = get_fillstyle(series, i)
            gr_set_fillstyle(fs)
            gr_set_transparency(fc, get_fillalpha(series, i))
            GR.fillarea(xseg, yseg)

            # draw the shapes
            lc = get_linecolor(series, clims, i)
            gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc, series)
            gr_set_transparency(lc, get_linealpha(series, i))
            GR.polyline(xseg, yseg)
        end
    end
end

function gr_draw_contour(series, x, y, z, clims)
    GR.setspace(clims[1], clims[2], 0, 90)
    gr_set_line(get_linewidth(series), get_linestyle(series), get_linecolor(series), series)
    gr_set_transparency(get_fillalpha(series))
    is_lc_black = let black = plot_color(:black)
        plot_color(series[:linecolor]) in (black, [black])
    end
    h = gr_contour_levels(series, clims)
    if series[:fillrange] !== nothing
        if series[:fillcolor] != series[:linecolor] && !is_lc_black
            @warn "GR: filled contour only supported with black contour lines"
        end
        GR.contourf(x, y, h, z, series[:contour_labels] == true ? 1 : 0)
    else
        coff = is_lc_black ? 0 : 1000
        GR.contour(x, y, h, z, coff + (series[:contour_labels] == true ? 1 : 0))
    end
end

function gr_draw_surface(series, x, y, z, clims)
    e_kwargs = series[:extra_kwargs]
    st = series[:seriestype]
    if st === :surface
        if ndims(x) == ndims(y) == ndims(z) == 2
            GR.gr3.surface(x', y', z, GR.OPTION_3D_MESH)
        else
            fillalpha = get_fillalpha(series)
            fillcolor = get_fillcolor(series)
            # NOTE: setting nx = 0 or ny = 0 disables GR.gridit interpolation
            nx, ny = get(e_kwargs, :nx, 200), get(e_kwargs, :ny, 200)
            if length(x) == length(y) == length(z) && nx > 0 && ny > 0
                x, y, z = GR.gridit(x, y, z, nx, ny)
            end
            d_opt = get(e_kwargs, :display_option, GR.OPTION_COLORED_MESH)
            if (!isnothing(fillalpha) && fillalpha < 1) || alpha(first(fillcolor)) < 1
                gr_set_transparency(fillcolor, fillalpha)
                GR.surface(x, y, z, d_opt)
            else
                GR.gr3.surface(x, y, z, d_opt)
            end
        end
    elseif st === :wireframe
        GR.setfillcolorind(0)
        GR.surface(x, y, z, get(e_kwargs, :display_option, GR.OPTION_FILLED_MESH))
    elseif st === :mesh3d
        if series[:connections] isa AbstractVector{<:AbstractVector{Int}}
            # Combination of any polygon types
            cns = [[length(polyinds), polyinds...] for polyinds in series[:connections]]
        elseif series[:connections] isa AbstractVector{NTuple{N,Int}} where {N}
            # Only N-gons - connections have to be 1-based (indexing)
            N = length(series[:connections][1])
            cns = [[N, polyinds...] for polyinds in series[:connections]]
        elseif series[:connections] isa NTuple{3,<:AbstractVector{Int}}
            # Only triangles - connections have to be 0-based (indexing)
            ci, cj, ck = series[:connections]
            if !(length(ci) == length(cj) == length(ck))
                throw(
                    ArgumentError(
                        "Argument connections must consist of equally sized arrays.",
                    ),
                )
            end
            cns = [([3, ci[i] + 1, cj[i] + 1, ck[i] + 1]) for i in eachindex(ci)]
        else
            throw(
                ArgumentError(
                    "Unsupported `:connections` type $(typeof(series[:connections])) for seriestype=$st",
                ),
            )
        end
        fillalpha = get_fillalpha(series)
        n_polygons = length(cns)
        facecolor = if series[:fillcolor] isa AbstractArray
            series[:fillcolor]
        else
            fill(series[:fillcolor], n_polygons)
        end
        facecolor = map(fc -> set_RGBA_alpha(fillalpha, fc), facecolor)
        GR.setborderwidth(get_linewidth(series))
        GR.setbordercolorind(gr_getcolorind(get_linecolor(series)))
        GR.polygonmesh3d(x, y, z, vcat(cns...), signed.(gr_color.(facecolor)))
    else
        throw(ArgumentError("Not handled !"))
    end
end

function gr_draw_heatmap(series, x, y, z, clims)
    fillgrad = _as_gradient(series[:fillcolor])
    GR.setspace(clims..., 0, 90)
    w, h = length(x) - 1, length(y) - 1
    if !ispolar(series) && is_uniformly_spaced(x) && is_uniformly_spaced(y)
        # For uniformly spaced data use GR.drawimage, which can be
        # much faster than GR.nonuniformcellarray, especially for
        # pdf output, and also supports alpha values.
        # Note that drawimage draws uniformly spaced data correctly
        # even on log scales, where it is visually non-uniform.
        colors, _z = if series[:subplot][:colorbar_scale] == :identity
            plot_color.(get(fillgrad, z, clims), series[:fillalpha]), z
        elseif series[:subplot][:colorbar_scale] == :log10
            z_log = replace(x -> isinf(x) ? NaN : x, log10.(z))
            z_normalized = get_z_normalized.(z_log, log10.(clims)...)
            plot_color.(map(z -> get(fillgrad, z), z_normalized), series[:fillalpha]), z_log
        end
        for i in eachindex(colors)
            if isnan(_z[i])
                colors[i] = set_RGBA_alpha(0, colors[i])
            end
        end
        rgba = gr_color.(colors)
        GR.drawimage(first(x), last(x), last(y), first(y), w, h, rgba)
    else
        if something(series[:fillalpha], 1) < 1
            @warn "GR: transparency not supported in non-uniform heatmaps. Alpha values ignored."
        end
        z_normalized, _z = if series[:subplot][:colorbar_scale] == :identity
            get_z_normalized.(z, clims...), z
        elseif series[:subplot][:colorbar_scale] == :log10
            z_log = replace(x -> isinf(x) ? NaN : x, log10.(z))
            get_z_normalized.(z_log, log10.(clims)...), z_log
        end
        rgba = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
        background_color_ind =
            gr_getcolorind(plot_color(series[:subplot][:background_color_inside]))
        for i in eachindex(rgba)
            if isnan(_z[i])
                rgba[i] = background_color_ind
            end
        end
        if !ispolar(series)
            GR.nonuniformcellarray(x, y, w, h, rgba)
        else
            if y[1] < 0
                @warn "'y[1] < 0' (rmin) is not yet supported."
            end
            xmin, xmax, ymin, ymax = gr_xy_axislims(series[:subplot])
            GR.setwindow(-ymax, ymax, -ymax, ymax)
            GR.nonuniformpolarcellarray(rad2deg.(x), y, w, h, rgba)
        end
    end
end

function gr_draw_image(series, x, y, z, clims)
    w, h = size(z)
    xmin, xmax = ignorenan_extrema(x)
    ymin, ymax = ignorenan_extrema(y)
    rgba = gr_color.(z)
    GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)
end

# ----------------------------------------------------------------

for (mime, fmt) in (
    "application/pdf" => "pdf",
    "image/png" => "png",
    "application/postscript" => "ps",
    "image/svg+xml" => "svg",
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GRBackend})
        ENV["GKS_ENCODING"] = "utf8"
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
            pop!(ENV, "GKSwstype")
        end
    end
end

function _display(plt::Plot{GRBackend})
    ENV["GKS_ENCODING"] = "utf8"
    if plt[:display_type] == :inline
        GR.emergencyclosegks()
        filepath = tempname() * ".pdf"
        ENV["GKSwstype"] = "pdf"
        ENV["GKS_FILEPATH"] = filepath
        gr_display(plt)
        GR.emergencyclosegks()
        content = string(
            "\033]1337;File=inline=1;preserveAspectRatio=0:",
            base64encode(open(read, filepath)),
            "\a",
        )
        println(content)
        rm(filepath)
    else
        ENV["GKS_DOUBLE_BUF"] = true
        gr_display(plt)
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
