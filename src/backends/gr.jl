
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
    + = 2,
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

gr_color(c, ::Type{<:AbstractRGB}) = UInt32( round(UInt, clamp(alpha(c) * 255, 0, 255)) << 24 +
                                   round(UInt,  clamp(blue(c) * 255, 0, 255)) << 16 +
                                   round(UInt, clamp(green(c) * 255, 0, 255)) << 8  +
                                   round(UInt,   clamp(red(c) * 255, 0, 255)) )
function gr_color(c, ::Type{<:AbstractGray})
    g = round(UInt, clamp(gray(c) * 255, 0, 255))
    α = round(UInt, clamp(alpha(c) * 255, 0, 255))
    rgba = UInt32( α<<24 + g<<16 + g<<8 + g )
end
gr_color(c, ::Type) = gr_color(RGBA(c), RGB)

function gr_getcolorind(c)
    gr_set_transparency(float(alpha(c)))
    convert(Int, GR.inqcolorfromrgb(red(c), green(c), blue(c)))
end

gr_set_linecolor(c)   = GR.setlinecolorind(gr_getcolorind(_cycle(c,1)))
gr_set_fillcolor(c)   = GR.setfillcolorind(gr_getcolorind(_cycle(c,1)))
gr_set_markercolor(c) = GR.setmarkercolorind(gr_getcolorind(_cycle(c,1)))
gr_set_bordercolor(c) = GR.setbordercolorind(gr_getcolorind(_cycle(c,1)))
gr_set_textcolor(c)   = GR.settextcolorind(gr_getcolorind(_cycle(c,1)))
gr_set_transparency(α::Real) = GR.settransparency(clamp(α, 0, 1))
gr_set_transparency(::Nothing) = GR.settransparency(1)
gr_set_transparency(c, α) = gr_set_transparency(α)
gr_set_transparency(c::Colorant, ::Nothing) = gr_set_transparency(c)
gr_set_transparency(c::Colorant) = GR.settransparency(alpha(c))

gr_set_arrowstyle(s::Symbol) = GR.setarrowstyle(get(
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
))

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

function gr_polyline3d(x, y, z, func = GR.polyline3d)
    iend = 0
    n = length(x)
    while iend < n-1
        # set istart to the first index that is finite
        istart = -1
        for j = iend+1:n
            if isfinite(x[j]) && isfinite(y[j]) && isfinite(z[j])
                istart = j
                break
            end
        end

        if istart > 0
            # iend is the last finite index
            iend = -1
            for j = istart+1:n
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
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.inqmathtex(x, y, s[2:end-1])
    elseif occursin('\\', s) || occursin("10^{", s)
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

gr_text(x, y, s) = gr_text(x, y, string(s))

function gr_text(x, y, s::AbstractString)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.mathtex(x, y, s[2:end-1])
    elseif occursin('\\', s) || occursin("10^{", s)
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
            xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid], sp
        )
        gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
        for i in eachindex(α)
            GR.polyline([sinf[i], 0], [cosf[i], 0])
        end
    end

    #draw radial grid
    if yaxis[:grid]
        gr_set_line(
            yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid], sp
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
            GR.textext(x, y, string((360-α[i])%360, "^o"))
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
    # convert to ndc coords (percentages of window)
    GR.selntran(0)
    w, h = get_size(series)
    f = msize / (w + h)
    xi, yi = GR.wctondc(xi, yi)
    xs = xi .+ sx .* f
    ys = yi .+ sy .* f

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
    GR.selntran(1)
end

function gr_nominal_size(s)
    w, h = get_size(s)
    min(w, h) / 500
end

# draw ONE symbol marker
function gr_draw_marker(series, xi, yi, clims, i, msize, strokewidth, shape::Symbol)
    GR.setborderwidth(strokewidth);
    gr_set_bordercolor(get_markerstrokecolor(series, i));
    gr_set_markercolor(get_markercolor(series, clims, i));
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
function gr_set_font(f::Font, s; halign = f.halign, valign = f.valign,
                              color = f.color, rotation = f.rotation)
    family = lowercase(f.family)
    GR.setcharheight(gr_point_mult(s) * f.pointsize)
    GR.setcharup(sind(-rotation), cosd(-rotation))
    if haskey(gr_font_family, family)
        GR.settextfontprec(
            gr_font_family[family],
            gr_font_family[family] >= 200 ? 3 : GR.TEXT_PRECISION_STRING
        )
    end
    gr_set_textcolor(color)
    GR.settextalign(gr_halign(halign), gr_valign(valign))
end

function gr_nans_to_infs!(z)
    for (i,zi) in enumerate(z)
        if zi == NaN
            z[i] = Inf
        end
    end
end

function gr_w3tondc(x, y, z)
    xw, yw, zw = GR.wc3towc(x, y, z)
    x, y = GR.wctondc(xw, yw)
    return x, y
end

# --------------------------------------------------------------------------------------
# viewport plot area
function gr_viewport_from_bbox(sp::Subplot{GRBackend}, bb::BoundingBox, w, h, viewport_canvas)
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
        viewport_plotarea[4]
    )
end

function gr_set_viewport_polar(viewport_plotarea)
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
function gr_draw_colorbar(cbar::GRColorbar, sp::Subplot, clims, viewport_plotarea)
    GR.savestate()
    xmin, xmax = gr_xy_axislims(sp)[1:2]
    zmin, zmax = clims[1:2]
    gr_set_viewport_cmap(sp, viewport_plotarea)
    GR.setscale(0)
    GR.setwindow(xmin, xmax, zmin, zmax)
    if !isempty(cbar.gradients)
        series = cbar.gradients
        gr_set_gradient(_cbar_unique(get_colorgradient.(series),"color"))
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
        gr_set_gradient(_cbar_unique(get_colorgradient.(series),"color"))
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
            GR.polyline([xmin,xmax], [line,line] )
        end
    end

    ztick = 0.5 * GR.tick(zmin, zmax)
    gr_set_line(1, :solid, plot_color(:black), sp)
    GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)

    gr_set_font(guidefont(sp[:yaxis]), sp)
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    GR.setcharup(-1, 0)
    gr_text(
        viewport_plotarea[2] + 0.1, gr_view_ycenter(viewport_plotarea), sp[:colorbar_title]
    )

    GR.restorestate()
end

gr_view_xcenter(viewport_plotarea) = 0.5 * (viewport_plotarea[1] + viewport_plotarea[2])
gr_view_ycenter(viewport_plotarea) = 0.5 * (viewport_plotarea[3] + viewport_plotarea[4])


# --------------------------------------------------------------------------------------

function gr_set_gradient(c)
    grad = _as_gradient(c)
    for (i,z) in enumerate(range(0, stop=1, length=256))
        c = grad[z]
        GR.setcolorrep(999+i, red(c), green(c), blue(c))
    end
    grad
end

function gr_set_gradient(series::Series)
    color = get_colorgradient(series)
    color !== nothing && gr_set_gradient(color)
end

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot, fmt="")
    GR.clearws()

    dpi_factor = plt[:dpi] / Plots.DPI

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0,1,0,1]
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
        gr_display(sp, w*px, h*px, viewport_canvas)
    end

    GR.updatews()
end

function gr_set_tickfont(sp, letter)
    axis = sp[Symbol(letter, :axis)]
    if letter === :x || (RecipesPipeline.is3d(sp) && letter === :y)
        halign = (:left, :hcenter, :right)[sign(axis[:rotation]) + 2]
        valign = (axis[:mirror] ? :bottom : :top)
    else
        halign = (axis[:mirror] ? :left : :right)
        valign = (:top, :vcenter, :bottom)[sign(axis[:rotation]) + 2]
    end
    gr_set_font(
        tickfont(axis),
        sp,
        halign = halign,
        valign = valign,
        rotation = axis[:rotation],
        color = axis[:tickfontcolor],
    )
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

function labelfunc(scale::Symbol, backend::GRBackend)
    texfunc = labelfunc_tex(scale)
    # replace dash with \minus (U+2212)
    label -> replace(texfunc(label), "-" => "−")
end

function gr_axis_height(sp, axis)
    GR.savestate()
    ticks = get_ticks(sp, axis, update = false)
    gr_set_font(tickfont(axis), sp)
    h = (ticks in (nothing, false, :none) ? 0 : last(gr_get_ticks_size(ticks, axis[:rotation])))
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
    w = (ticks in (nothing, false, :none) ? 0 : first(gr_get_ticks_size(ticks, axis[:rotation])))
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
    leftpad   = 2mm  + sp[:left_margin]
    toppad    = 2mm  + sp[:top_margin]
    rightpad  = 2mm  + sp[:right_margin]
    bottompad = 2mm  + sp[:bottom_margin]
    # Add margin for title
    if sp[:title] != ""
        gr_set_font(titlefont(sp), sp)
        l = last(last(gr_text_size(sp[:title])))
        h = 1mm + get_size(sp)[2] * l * px
        toppad += h
    end

    if RecipesPipeline.is3d(sp)
        xaxis, yaxis, zaxis = sp[:xaxis], sp[:yaxis], sp[:zaxis]
        xticks, yticks, zticks = get_ticks(sp, xaxis), get_ticks(sp, yaxis), get_ticks(sp, zaxis)
        # Add margin for x and y ticks
        h = 0mm
        if !(xticks in (nothing, false, :none))
            gr_set_font(
                tickfont(xaxis),
                halign = (:left, :hcenter, :right)[sign(xaxis[:rotation]) + 2],
                valign = (xaxis[:mirror] ? :bottom : :top),
                rotation = xaxis[:rotation],
                sp
            )
            l = 0.01 + last(gr_get_ticks_size(xticks, xaxis[:rotation]))
            h = max(h, 1mm + get_size(sp)[2] * l * px)
        end
        if !(yticks in (nothing, false, :none))
            gr_set_font(
                tickfont(yaxis),
                halign = (:left, :hcenter, :right)[sign(yaxis[:rotation]) + 2],
                valign = (yaxis[:mirror] ? :bottom : :top),
                rotation = yaxis[:rotation],
                sp
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

        if !(zticks in (nothing, false, :none))
            gr_set_font(
                tickfont(zaxis),
                halign = (zaxis[:mirror] ? :left : :right),
                valign = (:top, :vcenter, :bottom)[sign(zaxis[:rotation]) + 2],
                rotation = zaxis[:rotation],
                color = zaxis[:tickfontcolor],
                sp
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
            if xaxis[:guide_position] == :top || (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
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
            if zaxis[:guide_position] == :right || (zaxis[:guide_position] == :auto && zaxis[:mirror] == true)
                rightpad += w
            else
                leftpad += w
            end
        end
    else
        # Add margin for x and y ticks
        xticks, yticks = get_ticks(sp, sp[:xaxis]), get_ticks(sp, sp[:yaxis])
        if !(xticks in (nothing, false, :none))
            gr_set_tickfont(sp, :x)
            l = 0.01 + last(gr_get_ticks_size(xticks, sp[:xaxis][:rotation]))
            h = 1mm + get_size(sp)[2] * l * px
            if sp[:xaxis][:mirror]
                toppad += h
            else
                bottompad += h
            end
        end
        if !(yticks in (nothing, false, :none))
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
            if sp[:xaxis][:guide_position] == :top || (sp[:xaxis][:guide_position] == :auto && sp[:xaxis][:mirror] == true)
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
            if sp[:yaxis][:guide_position] == :right || (sp[:yaxis][:guide_position] == :auto && sp[:yaxis][:mirror] == true)
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
    d = collect(v[2:end] .- v[1:end-1])
    all(d .≈ d[1])
end

remap(x, lo, hi) = (x - lo) / (hi - lo)
function get_z_normalized(z, clims...)
    isnan(z) && return 256 / 255
    return remap(clamp(z, clims...), clims...)
end

function gr_clims(args...)
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
    gr_update_viewport_ratio!(viewport_plotarea, sp)
    leg = gr_get_legend_geometry(viewport_plotarea, sp)
    gr_update_viewport_legend!(viewport_plotarea, sp, leg)
    
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
    if !(sp[:legend] in(:none, :inline))
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        gr_set_font(legendfont(sp), sp)
        if leg.w > 0
            xpos, ypos = gr_legend_pos(sp, leg, viewport_plotarea)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            gr_set_fillcolor(sp[:background_color_legend])
            GR.fillrect(
                xpos - leg.leftw, xpos + leg.textw + leg.rightw,
                ypos + leg.dy, ypos - leg.h
            ) # Allocating white space for actual legend width here
            gr_set_line(1, :solid, sp[:foreground_color_legend], sp)
            GR.drawrect(
                xpos - leg.leftw, xpos + leg.textw + leg.rightw,
                ypos + leg.dy, ypos - leg.h
            ) # Drawing actual legend width here
            i = 0
            if sp[:legendtitle] !== nothing
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
                gr_set_font(legendtitlefont(sp), sp)
                gr_text(xpos - 0.03 + 0.5 * leg.w, ypos, string(sp[:legendtitle]))
                ypos -= leg.dy
                gr_set_font(legendfont(sp), sp)
            end
            for series in series_list(sp)
                clims = gr_clims(sp, series)
                should_add_to_legend(series) || continue
                st = series[:seriestype]
                lc = get_linecolor(series, clims)
                gr_set_line(sp[:legendfontsize] / 8, get_linestyle(series), lc, sp)

                if (st == :shape || series[:fillrange] !== nothing) && series[:ribbon] === nothing
                    fc = get_fillcolor(series, clims)
                    gr_set_fill(fc) #, series[:fillalpha])
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
                        0.8 * sp[:legendfontsize], 0.8 * sp[:legendfontsize] * msw / ms
                    else
                        0, 0.8 * sp[:legendfontsize] * msw / 8
                    end
                    gr_draw_markers(series, xpos - leg.width_factor * 2, ypos, clims, s, sw)
                end

                lab = series[:label]
                GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                gr_set_textcolor(plot_color(sp[:legendfontcolor]))
                gr_text(xpos, ypos, string(lab))
                ypos -= leg.dy
            end
        end
        GR.selntran(1)
        GR.restorestate()
    end
end

function gr_legend_pos(sp::Subplot, leg, viewport_plotarea)
    s = sp[:legend]
    typeof(s) <: Symbol || return gr_legend_pos(s, viewport_plotarea)
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
            xpos = viewport_plotarea[2] + leg.xoffset + leg.leftw + ymirror * gr_axis_width(sp, sp[:yaxis])
        else
            xpos = viewport_plotarea[2] - leg.rightw - leg.textw - leg.xoffset
        end
    elseif occursin("left", str)
        if occursin("outer", str)
            xpos = viewport_plotarea[1] - !ymirror * gr_axis_width(sp, sp[:yaxis]) - leg.xoffset * 2 - leg.rightw - leg.textw
        else
            xpos = viewport_plotarea[1] + leg.leftw + leg.xoffset
        end
    else
        xpos = (viewport_plotarea[2] - viewport_plotarea[1]) / 2 + viewport_plotarea[1] + leg.leftw - leg.rightw - leg.textw - leg.xoffset * 2
    end
    if occursin("top", str)
        if s == :outertop
            ypos = viewport_plotarea[4] + leg.yoffset + leg.h + xmirror * gr_axis_height(sp, sp[:xaxis])
        else
            ypos = viewport_plotarea[4] - leg.yoffset - leg.dy
        end
    elseif occursin("bottom", str)
        if s == :outerbottom
            ypos = viewport_plotarea[3] - leg.yoffset - leg.h - !xmirror * gr_axis_height(sp, sp[:xaxis])
        else
            ypos = viewport_plotarea[3] + leg.yoffset + leg.h
        end
    else
        # Adding min y to shift legend pos to correct graph (#2377)
        ypos = (viewport_plotarea[4] - viewport_plotarea[3] + leg.h) / 2 + viewport_plotarea[3]
    end
    return xpos, ypos
end

function gr_legend_pos(v::Tuple{S,T}, viewport_plotarea) where {S<:Real, T<:Real}
    xpos = v[1] * (viewport_plotarea[2] - viewport_plotarea[1]) + viewport_plotarea[1]
    ypos = v[2] * (viewport_plotarea[4] - viewport_plotarea[3]) + viewport_plotarea[3]
    (xpos,ypos)
end

function gr_get_legend_geometry(viewport_plotarea, sp)
    legendn = 0
    legendw = 0
    if sp[:legend] != :none
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        if sp[:legendtitle] !== nothing
            gr_set_font(legendtitlefont(sp), sp)
            tbx, tby = gr_inqtext(0, 0, string(sp[:legendtitle]))
            legendw = tbx[3] - tbx[1]
            legendn += 1
        end
        gr_set_font(legendfont(sp), sp)
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            legendn += 1
            lab = series[:label]
            tbx, tby = gr_inqtext(0, 0, string(lab))
            legendw = max(legendw, tbx[3] - tbx[1]) # Holds text width right now
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

    dy = gr_point_mult(sp) * sp[:legendfontsize] * 1.75
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
    leg_str = string(sp[:legend])

    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    xmirror = xaxis[:guide_position] == :top || (xaxis[:guide_position] == :auto && xaxis[:mirror] == true)
    ymirror = yaxis[:guide_position] == :right || (yaxis[:guide_position] == :auto && yaxis[:mirror] == true)

    if occursin("outer", leg_str)
        if occursin("right", leg_str)
            viewport_plotarea[2] -= leg.leftw + leg.textw + leg.rightw + leg.xoffset
        elseif occursin("left", leg_str)
            viewport_plotarea[1] += leg.leftw + leg.textw + leg.rightw + leg.xoffset + !ymirror * gr_axis_width(sp, sp[:yaxis])
        elseif occursin("top", leg_str)
            viewport_plotarea[4] -= leg.h + leg.dy + leg.yoffset
        elseif occursin("bottom", leg_str)
            viewport_plotarea[3] += leg.h + leg.dy + leg.yoffset + !xmirror * gr_axis_height(sp, sp[:xaxis])
        end
    end
    if sp[:legend] == :inline
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
        viewport_ratio = (viewport_plotarea[2] - viewport_plotarea[1]) / (viewport_plotarea[4] - viewport_plotarea[3])
        window_ratio = (xmax - xmin) / (ymax - ymin) / ratio
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
end

function gr_set_window(sp, viewport_plotarea)
    if ispolar(sp)
        gr_set_viewport_polar(viewport_plotarea)
    else
        xmin, xmax, ymin, ymax = gr_xy_axislims(sp)
        scaleop = 0
        if xmax > xmin && ymax > ymin
            sp[:xaxis][:scale] == :log10 && (scaleop |= GR.OPTION_X_LOG)
            sp[:yaxis][:scale] == :log10 && (scaleop |= GR.OPTION_Y_LOG)
            sp[:xaxis][:flip]            && (scaleop |= GR.OPTION_FLIP_X)
            sp[:yaxis][:flip]            && (scaleop |= GR.OPTION_FLIP_Y)
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
        zmin, zmax = axis_limits(sp, :z)
        GR.setspace(zmin, zmax, round.(Int, sp[:camera])...)

        # fill the plot area
        gr_set_fill(plot_color(sp[:background_color_inside]))
        plot_area_x = [xmin, xmin, xmin, xmax, xmax, xmax, xmin]
        plot_area_y = [ymin, ymin, ymax, ymax, ymax, ymin, ymin]
        plot_area_z = [zmin, zmax, zmax, zmax, zmin, zmin, zmin]
        x_bg, y_bg = RecipesPipeline.unzip(GR.wc3towc.(plot_area_x, plot_area_y, plot_area_z))
        GR.fillarea(x_bg, y_bg)

        for letter in (:x, :y, :z)
            gr_draw_axis_3d(sp, letter)
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
    axis = sp[Symbol(letter, :axis)]

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

function gr_draw_axis_3d(sp, letter)
    ax = axis_drawing_info_3d(sp, letter)
    axis = sp[Symbol(letter, :axis)]

    # draw segments
    gr_draw_grid(sp, axis, ax.grid_segments, gr_polyline3d)
    gr_draw_minorgrid(sp, axis, ax.minorgrid_segments, gr_polyline3d)
    gr_draw_spine(sp, axis, ax.segments, gr_polyline3d)
    gr_draw_border(sp, axis, ax.border_segments, gr_polyline3d)
    gr_draw_ticks(sp, axis, ax.tick_segments, gr_polyline3d)

    # labels
    gr_label_ticks_3d(sp, letter, ax.ticks)
    gr_label_axis_3d(sp, letter)
end

function gr_draw_grid(sp, axis, segments, func = gr_polyline)
    if axis[:grid]
        gr_set_line(
            axis[:gridlinewidth],
            axis[:gridstyle],
            axis[:foreground_color_grid],
            sp
        )
        gr_set_transparency(axis[:foreground_color_grid], axis[:gridalpha])
        func(coords(segments)...)
    end
end

function gr_draw_minorgrid(sp, axis, segments, func = gr_polyline)
    if axis[:grid]
        gr_set_line(
            axis[:minorgridlinewidth],
            axis[:minorgridstyle],
            axis[:foreground_color_minor_grid],
            sp
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
    axis = sp[Symbol(letter, :axis)]
    isy = letter === :y
    oletter = isy ? :x : :y
    oaxis = sp[Symbol(oletter, :axis)]
    oamin, oamax = axis_limits(sp, oletter)
    gr_set_tickfont(sp, letter)
    out_factor = ifelse(axis[:tick_direction] === :out, 1.5, 1)
    x_offset = isy ? (axis[:mirror] ? 1 : -1) * 1.5e-2 * out_factor : 0
    y_offset = isy ? 0 : (axis[:mirror] ? 1 : -1) * 8e-3 * out_factor

    ov = sp[:framestyle] == :origin ? 0 : xor(oaxis[:flip], axis[:mirror]) ? oamax : oamin
    for (cv, dv) in zip(ticks...)
        x, y = GR.wctondc(reverse_if((cv, ov), isy)...)
        gr_text(x + x_offset, y + y_offset, dv)
    end
end

function gr_label_ticks(sp, letter, ticks::Nothing) end

function gr_label_ticks_3d(sp, letter, ticks)
    near_letter = letter in (:x, :z) ? :y : :x
    far_letter = letter in (:x, :y) ? :z : :x

    ax = sp[Symbol(letter, :axis)]
    nax = sp[Symbol(near_letter, :axis)]
    fax = sp[Symbol(far_letter, :axis)]

    amin, amax = axis_limits(sp, letter)
    namin, namax = axis_limits(sp, near_letter)
    famin, famax = axis_limits(sp, far_letter)
    n0, n1 = letter === :y ? (namax, namin) : (namin, namax)


    # find out which axes we are dealing with
    i = findfirst(==(letter), (:x, :y, :z))
    letters = axes_shift((:x, :y, :z), 1 - i)
    asyms = Symbol.(letters, :axis)

    # get axis objects, ticks and minor ticks
    # regardless of the `letter` we now use the convention that `x` in variable names refer to
    # the first axesm `y` to the second, etc ...
    ylims, zlims = axis_limits.(Ref(sp), letters[2:3])
    xax, yax, zax = getindex.(Ref(sp), asyms)

    gr_set_tickfont(sp, letter)
    nt = sp[:framestyle] == :origin ? 0 : xor(ax[:mirror], nax[:flip]) ? n1 : n0
    ft = sp[:framestyle] == :origin ? 0 : xor(ax[:mirror], fax[:flip]) ? famax : famin

    xoffset = if letter === :x
        (sp[:yaxis][:mirror] ? 1 : -1) * 1e-2 * (sp[:xaxis][:tick_direction] == :out ? 1.5 : 1)
    elseif letter === :y
        (sp[:yaxis][:mirror] ? -1 : 1) * 1e-2 * (sp[:yaxis][:tick_direction] == :out ? 1.5 : 1)
    else
        (sp[:zaxis][:mirror] ? 1 : -1) * 1e-2 * (sp[:zaxis][:tick_direction] == :out ? 1.5 : 1)
    end
    yoffset = if letter === :x
        (sp[:xaxis][:mirror] ? 1 : -1) * 1e-2 * (sp[:xaxis][:tick_direction] == :out ? 1.5 : 1)
    elseif letter === :y
        (sp[:yaxis][:mirror] ? 1 : -1) * 1e-2 * (sp[:yaxis][:tick_direction] == :out ? 1.5 : 1)
    else
        0
    end

    for (cv, dv) in zip(ticks...)
        xi, yi = gr_w3tondc(sort_3d_axes(cv, nt, ft, letter)...)
        gr_text(xi + xoffset, yi + yoffset, dv)
    end
end

function gr_label_axis(sp, letter, viewport_plotarea)
    axis = sp[Symbol(letter, :axis)]
    # guide
    if axis[:guide] != ""
        GR.savestate()
        gr_set_font(guidefont(axis), sp)
        guide_position = axis[:guide_position]
        if letter === :y
            w = 0.03 + gr_axis_width(sp, axis)
            GR.setcharup(-1, 0)
            if guide_position == :right || (guide_position == :auto && axis[:mirror])
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
                gr_text(viewport_plotarea[2] + w, gr_view_ycenter(viewport_plotarea), axis[:guide])
            else
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
                gr_text(viewport_plotarea[1] - w, gr_view_ycenter(viewport_plotarea), axis[:guide])
            end
        else
            h = 0.015 + gr_axis_height(sp, axis)
            if guide_position == :top || (guide_position == :auto && axis[:mirror])
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
                gr_text(gr_view_xcenter(viewport_plotarea), viewport_plotarea[4] + h, axis[:guide])
            else
                GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
                gr_text(gr_view_xcenter(viewport_plotarea), viewport_plotarea[3] - h, axis[:guide])
            end
        end
        GR.restorestate()
    end
end

function gr_label_axis_3d(sp, letter)
    ax = sp[Symbol(letter, :axis)]
    if ax[:guide] != ""
        near_letter = letter in (:x, :z) ? :y : :x
        far_letter = letter in (:x, :y) ? :z : :x
    
        nax = sp[Symbol(near_letter, :axis)]
        fax = sp[Symbol(far_letter, :axis)]
    
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
        ng = xor(ax[:mirror], nax[:flip]) ? n1 : n0
        fg = xor(ax[:mirror], fax[:flip]) ? famax : famin
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
        gr_text(x + x_offset, y + y_offset, ax[:guide])
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
        gr_draw_shapes(series, x, y, clims)
    elseif st in (:path3d, :scatter3d)
        gr_draw_segments_3d(series, x, y, z, clims)
        if st === :scatter3d || series[:markershape] !== :none
            # TODO: Do we need to transform to 2d coordinates here?
            x2, y2 = RecipesPipeline.unzip(map(GR.wc3towc, x, y, z))
            gr_draw_markers(series, x2, y2, clims)
        end
    elseif st === :contour
        gr_draw_contour(series, x, y, z, clims)
    elseif st in (:surface, :wireframe)
        gr_draw_surface(series, x, y, z, clims)
    elseif st === :volume
        sp[:legend] = :none
        GR.gr3.clear()
        dmin, dmax = GR.gr3.volume(y.v, 0)
    elseif st === :heatmap
        if !ispolar(series)
            # `z` is already transposed, so we need to reverse before passing its size.
            x, y = heatmap_edges(x, xscale, y, yscale, reverse(size(z)))
        end
        gr_draw_heatmap(series, x, y, z, clims)
    elseif st === :image
        gr_draw_image(series, x, y, z, clims)
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi,yi,str,fnt) in EachAnn(anns, x, y)
        gr_set_font(fnt, sp)
        gr_text(GR.wctondc(xi, yi)..., str)
    end

    if sp[:legend] == :inline && should_add_to_legend(series)
        gr_set_font(legendfont(sp), sp)
        gr_set_textcolor(plot_color(sp[:legendfontcolor]))
        if sp[:yaxis][:mirror]
            (_,i) = sp[:xaxis][:flip] ? findmax(x) : findmin(x)
            GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
            offset = -0.01
        else
            (_,i) = sp[:xaxis][:flip] ? findmin(x) : findmax(x)
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            offset = 0.01
        end
        (x_l,y_l) = GR.wctondc(x[i],y[i])
        gr_text(x_l+offset,y_l,series[:label])
    end
    GR.restorestate()
end

function gr_draw_segments(series, x, y, fillrange, clims)
    st = series[:seriestype]
    if x !== nothing && length(x) > 1
        segments = iter_segments(series, st)
        # do area fill
        if fillrange !== nothing
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            fr_from, fr_to = (is_2tuple(fillrange) ? fillrange : (y, fillrange))
            for (i, rng) in enumerate(segments)
                fc = get_fillcolor(series, clims, i)
                gr_set_fillcolor(fc)
                fx = _cycle(x, vcat(rng, reverse(rng)))
                fy = vcat(_cycle(fr_from, rng), _cycle(fr_to, reverse(rng)))
                gr_set_transparency(fc, get_fillalpha(series, i))
                GR.fillarea(fx, fy)
            end
        end

        # draw the line(s)
        if st in (:path, :straightline)
            for (i, rng) in enumerate(segments)
                lc = get_linecolor(series, clims, i)
                gr_set_line(
                    get_linewidth(series, i), get_linestyle(series, i), lc, series
                )
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
        segments = iter_segments(series, :path3d)
        for (i, rng) in enumerate(segments)
            lc = get_linecolor(series, clims, i)
            gr_set_line(
                get_linewidth(series, i), get_linestyle(series, i), lc, series
            )
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
        for (i, rng) in enumerate(iter_segments(series, :scatter))
            rng = intersect(eachindex(x), rng)
            if !isempty(rng)
                ms = get_thickness_scaling(series) * _cycle(msize, i)
                msw = get_thickness_scaling(series) * _cycle(strokewidth, i)
                shape = _cycle(shapes, i)
                for j in rng
                    gr_draw_marker(series, _cycle(x, j), _cycle(y, j), clims, i, ms, msw, shape)
                end
            end
        end
    end
end

function gr_draw_shapes(series, x, y, clims)
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
            gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc, series)
            gr_set_transparency(lc, get_linealpha(series, i))
            GR.polyline(xseg, yseg)
        end
    end
end

function gr_draw_contour(series, x, y, z, clims)
    GR.setspace(clims[1], clims[2], 0, 90)
    gr_set_line(get_linewidth(series), get_linestyle(series), get_linecolor(series), series)
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
end

function gr_draw_surface(series, x, y, z, clims)
    if series[:seriestype] === :surface
        if length(x) == length(y) == length(z)
            GR.trisurface(x, y, z)
        else
            try
                GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
            catch
                GR.surface(x, y, z, GR.OPTION_COLORED_MESH)
            end
        end
    else # wireframe
        GR.setfillcolorind(0)
        GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
    end
end

function gr_draw_heatmap(series, x, y, z, clims)
    fillgrad = _as_gradient(series[:fillcolor])
    if !ispolar(series)
        GR.setspace(clims..., 0, 90)
        w, h = length(x) - 1, length(y) - 1
        if is_uniformly_spaced(x) && is_uniformly_spaced(y)
            # For uniformly spaced data use GR.drawimage, which can be
            # much faster than GR.nonuniformcellarray, especially for
            # pdf output, and also supports alpha values.
            # Note that drawimage draws uniformly spaced data correctly
            # even on log scales, where it is visually non-uniform.
            colors = plot_color.(get(fillgrad, z, clims), series[:fillalpha])
            rgba = gr_color.(colors)
            GR.drawimage(first(x), last(x), last(y), first(y), w, h, rgba)
        else
            if something(series[:fillalpha], 1) < 1
                @warn "GR: transparency not supported in non-uniform heatmaps. Alpha values ignored."
            end
            z_normalized = get_z_normalized.(z, clims...)
            rgba = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
            GR.nonuniformcellarray(x, y, w, h, rgba)
        end
    else
        phimin, phimax = 0.0, 360.0 # nonuniform polar array is not yet supported in GR.jl
        nx, ny = length(series[:x]), length(series[:y])
        xmin, xmax, ymin, ymax = gr_xy_axislims(series[:subplot])
        GR.setwindow(-ymax, ymax, -ymax, ymax)
        if ymin > 0
            @warn "'ymin[1] > 0' (rmin) is not yet supported."
        end
        if series[:y][end] != ny
            @warn "Right now only the maximum value of y (r) is taken into account."
        end
        z_normalized = get_z_normalized.(z, clims...)
        rgba = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
        GR.polarcellarray(0, 0, phimin, phimax, 0, ymax, nx, ny, rgba)
        # Right now only the maximum value of y (r) is taken into account.
        # This is certainly not perfect but nonuniform polar array is not yet supported in GR.jl
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
        content = string("\033]1337;File=inline=1;preserveAspectRatio=0:", base64encode(open(read, filepath)), "\a")
        println(content)
        rm(filepath)
    else
        ENV["GKS_DOUBLE_BUF"] = true
        gr_display(plt)
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
