# https://github.com/jheinen/GR.jl - significant contributions by @jheinen

const gr_projections = (auto = 1, ortho = 1, orthographic = 1, persp = 2, perspective = 2)
const gr_linetypes = (auto = 1, solid = 1, dash = 2, dot = 3, dashdot = 4, dashdotdot = -1)
const gr_fill_styles = ((/) = 9, (\) = 10, (|) = 7, (-) = 8, (+) = 11, (x) = 6)
const gr_x_log_scales =
    (ln = GR.OPTION_X_LN, log2 = GR.OPTION_X_LOG2, log10 = GR.OPTION_X_LOG)
const gr_y_log_scales =
    (ln = GR.OPTION_Y_LN, log2 = GR.OPTION_Y_LOG2, log10 = GR.OPTION_Y_LOG)
const gr_z_log_scales =
    (ln = GR.OPTION_Z_LN, log2 = GR.OPTION_Z_LOG2, log10 = GR.OPTION_Z_LOG)

const gr_arrowstyles = (
    simple = 1,
    hollow = 3,
    filled = 4,
    triangle = 5,
    filledtriangle = 6,
    closed = 6,
    open = 5,
)
const gr_markertypes = (
    auto = 1,
    pixel = 1,
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
)
const gr_haligns = (
    left = GR.TEXT_HALIGN_LEFT,
    hcenter = GR.TEXT_HALIGN_CENTER,
    center = GR.TEXT_HALIGN_CENTER,
    right = GR.TEXT_HALIGN_RIGHT,
)
const gr_valigns = (
    top = GR.TEXT_VALIGN_TOP,
    vcenter = GR.TEXT_VALIGN_HALF,
    center = GR.TEXT_VALIGN_HALF,
    bottom = GR.TEXT_VALIGN_BOTTOM,
)
const gr_font_family = Dict(
    # compat
    "times" => 101,
    "helvetica" => 105,
    "courier" => 109,
    "bookman" => 114,
    "newcenturyschlbk" => 118,
    "avantgarde" => 122,
    "palatino" => 126,
    "serif-roman" => 232,
    "sans-serif" => 233,
    # https://gr-framework.org/fonts.html
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

mutable struct GRViewport{T}
    xmin::T
    xmax::T
    ymin::T
    ymax::T
end

width(vp::GRViewport) = vp.xmax - vp.xmin
height(vp::GRViewport) = vp.ymax - vp.ymin

xcenter(vp::GRViewport) = 0.5(vp.xmin + vp.xmax)
ycenter(vp::GRViewport) = 0.5(vp.ymin + vp.ymax)

xposition(vp::GRViewport, pos) = vp.xmin + pos * width(vp)
yposition(vp::GRViewport, pos) = vp.ymin + pos * height(vp)

# --------------------------------------------------------------------------------------
gr_is3d(st) = RecipesPipeline.is3d(st)

gr_color(c, ::Type) = gr_color(RGBA(c), RGB)
gr_color(c) = gr_color(c, color_type(c))
gr_color(c, ::Type{<:AbstractRGB}) = UInt32(
    round(UInt, clamp(255alpha(c), 0, 255)) << 24 +
        round(UInt, clamp(255blue(c), 0, 255)) << 16 +
        round(UInt, clamp(255green(c), 0, 255)) << 8 +
        round(UInt, clamp(255red(c), 0, 255)),
)
gr_color(c, ::Type{<:AbstractGray}) =
let g = round(UInt, clamp(255gray(c), 0, 255)),
        α = round(UInt, clamp(255alpha(c), 0, 255))

    UInt32(α << 24 + g << 16 + g << 8 + g)
end

set_RGBA_alpha(alpha, c::RGBA) = RGBA(red(c), green(c), blue(c), alpha)
set_RGBA_alpha(alpha::Nothing, c::RGBA) = c

function gr_getcolorind(c)
    gr_set_transparency(float(alpha(c)))
    return convert(Int, GR.inqcolorfromrgb(red(c), green(c), blue(c)))
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

gr_set_arrowstyle(style::Symbol) = GR.setarrowstyle(get(gr_arrowstyles, style, 1))

gr_set_fillstyle(::Nothing) = GR.setfillintstyle(GR.INTSTYLE_SOLID)
function gr_set_fillstyle(s::Symbol)
    GR.setfillintstyle(GR.INTSTYLE_HATCH)
    GR.setfillstyle(get(gr_fill_styles, s, 9))
    return nothing
end

# https://gr-framework.org/python-gr.html?highlight=setprojectiontype#gr.setprojectiontype
# PROJECTION_DEFAULT      0 default
# PROJECTION_ORTHOGRAPHIC 1 orthographic
# PROJECTION_PERSPECTIVE  2 perspective
# we choose to unify backends by using a default `orthographic` proj when `:auto`
gr_set_projectiontype(sp) = GR.setprojectiontype(gr_projections[sp[:projection_type]])

# --------------------------------------------------------------------------------------

# draw line segments, splitting x/y into contiguous/finite segments
# note: this can be used for shapes by passing func `GR.fillarea`
function gr_polyline(x, y, func = GR.polyline; arrowside = :none, arrowstyle = :simple)
    draw_head = arrowside in (:head, :both)
    draw_tail = arrowside in (:tail, :both)
    n = length(x)
    iend = 0
    while iend < n - 1
        istart = -1  # set istart to the first index that is finite
        for j in (iend + 1):n
            if ok(x[j], y[j])
                istart = j
                break
            end
        end
        if istart > 0
            iend = -1  # iend is the last finite index
            for j in (istart + 1):n
                if ok(x[j], y[j])
                    iend = j
                else
                    break
                end
            end
        end
        # if we found a start and end, draw the line segment, otherwise we're done
        if istart > 0 && iend > 0
            func(x[istart:iend], y[istart:iend])
            if draw_head
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[iend - 1], y[iend - 1], x[iend], y[iend])
            end
            if draw_tail
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[istart + 1], y[istart + 1], x[istart], y[istart])
            end
        else
            break
        end
    end
    return
end

function gr_polyline3d(x, y, z, func = GR.polyline3d)
    iend = 0
    n = length(x)
    while iend < n - 1
        istart = -1  # set istart to the first index that is finite
        for j in (iend + 1):n
            if ok(x[j], y[j], z[j])
                istart = j
                break
            end
        end
        if istart > 0
            iend = -1  # iend is the last finite index
            for j in (istart + 1):n
                if ok(x[j], y[j], z[j])
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
    return
end

gr_inqtext(x, y, s) = gr_inqtext(x, y, string(s))
gr_inqtext(x, y, s::AbstractString) =
if (occursin('\\', s) || occursin(r"10\^{|2\^{|e\^{", s)) &&
        match(r".*\$[^\$]+?\$.*", String(s)) === nothing
    GR.inqtextext(x, y, s)
else
    GR.inqtext(x, y, s)
end

gr_text(x, y, s) = gr_text(x, y, string(s))
gr_text(x, y, s::AbstractString) =
if (occursin('\\', s) || occursin(r"10\^{|2\^{|e\^{", s)) &&
        match(r".*\$[^\$]+?\$.*", String(s)) === nothing
    GR.textext(x, y, s)
else
    GR.text(x, y, s)
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

    # draw angular grid
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

    # draw radial grid
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
            (r ≤ 1 && r ≥ 0) && GR.drawarc(-r, r, -r, r, 0, 359)
        end
        GR.drawarc(-1, 1, -1, 1, 0, 359)
    end

    # prepare to draw ticks
    gr_set_transparency(1)
    GR.setlinecolorind(90)
    GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)

    # draw angular ticks
    if xaxis[:showaxis]
        GR.drawarc(-1, 1, -1, 1, 0, 359)
        for i in eachindex(α)
            x, y = GR.wctondc(1.1sinf[i], 1.1cosf[i])
            GR.textext(x, y, string((360 - α[i]) % 360, "^o"))
        end
    end

    # draw radial ticks
    yaxis[:showaxis] && for i in eachindex(rtick_values)
        r = (rtick_values[i] - rmin) / (rmax - rmin)
        (r ≤ 1 && r ≥ 0) && gr_text(GR.wctondc(0.05, r)..., _cycle(rtick_labels, i))
    end
    GR.restorestate()
    return nothing
end

# using the axis extrema and limit overrides, return the min/max value for this axis
gr_x_axislims(sp::Subplot) = axis_limits(sp, :x)
gr_y_axislims(sp::Subplot) = axis_limits(sp, :y)
gr_z_axislims(sp::Subplot) = axis_limits(sp, :z)
gr_xy_axislims(sp::Subplot) = gr_x_axislims(sp)..., gr_y_axislims(sp)...

function gr_fill_viewport(vp::GRViewport, c)
    if alpha(c) == 0
        return nothing
    end
    GR.savestate()
    GR.selntran(0)
    GR.setscale(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    gr_set_fillcolor(c)
    GR.fillrect(vp.xmin, vp.xmax, vp.ymin, vp.ymax)
    GR.selntran(1)
    GR.restorestate()
    return nothing
end

gr_fill_plotarea(sp, vp::GRViewport) =
    gr_is3d(sp) || gr_fill_viewport(vp, plot_color(sp[:background_color_inside]))

# ---------------------------------------------------------

gr_nominal_size(s) = minimum(get_size(s)) / 500

# draw ONE Shape
function gr_draw_marker(series, xi, yi, zi, clims, i, msize, strokewidth, shape::Shape)
    # convert to ndc coords (percentages of window) ...
    xi, yi = if zi === nothing
        GR.wctondc(xi, yi)
    else
        gr_w3tondc(xi, yi, zi)
    end
    f = msize / sum(get_size(series))

    # ... convert back to world coordinates
    sx, sy = coords(shape)
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
    return nothing
end

# draw ONE symbol marker
function gr_draw_marker(series, xi, yi, zi, clims, i, msize, strokewidth, shape::Symbol)
    GR.setborderwidth(strokewidth)
    gr_set_bordercolor(get_markerstrokecolor(series, i))
    gr_set_markercolor(get_markercolor(series, clims, i))
    gr_set_transparency(get_markeralpha(series, i))
    GR.setmarkertype(gr_markertypes[shape])
    GR.setmarkersize(0.3msize / gr_nominal_size(series))
    if zi === nothing
        GR.polymarker([xi], [yi])
    else
        GR.polymarker3d([xi], [yi], [zi])
    end
    return nothing
end

# ---------------------------------------------------------

function gr_set_line(lw, style, c, s)  # s can be Subplot or Series
    GR.setlinetype(gr_linetypes[style])
    GR.setlinewidth(get_thickness_scaling(s) * max(0, lw / gr_nominal_size(s)))
    gr_set_linecolor(c)
    return nothing
end

gr_set_fill(c) = (gr_set_fillcolor(c); GR.setfillintstyle(GR.INTSTYLE_SOLID); nothing)

# this stores the conversion from a font pointsize to "percentage of window height"
# (which is what GR uses). `s` can be a Series, Subplot or Plot
gr_point_mult(s) = 1.5get_thickness_scaling(s) * px / pt / maximum(get_size(s))

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
    GR.setcharup(sincosd(-rotation)...)
    if !haskey(gr_font_family, family)
        gr_font_family[family] = GR.loadfont(string(f.family, ".ttf"))
    end
    haskey(gr_font_family, family) && GR.settextfontprec(
        gr_font_family[family],
        gr_font_family[family] ≥ 200 ? 3 : GR.TEXT_PRECISION_STRING,
    )
    gr_set_textcolor(plot_color(color))
    GR.settextalign(gr_haligns[halign], gr_valigns[valign])
    return nothing
end

function gr_w3tondc(x, y, z)
    xw, yw, _ = GR.wc3towc(x, y, z)
    return GR.wctondc(xw, yw)  # x, y
end

# --------------------------------------------------------------------------------------
# viewport plot area

function gr_viewport_from_bbox(sp::Subplot{GRBackend}, bb::BoundingBox, w, h, vp_canvas)
    viewport = GRViewport(
        vp_canvas.xmax * (left(bb) / w),
        vp_canvas.xmax * (right(bb) / w),
        vp_canvas.ymax * (1 - bottom(bb) / h),
        vp_canvas.ymax * (1 - top(bb) / h),
    )
    hascolorbar(sp) && (viewport.xmax -= 0.1(1 + 0.5gr_is3d(sp)))
    return viewport
end

# change so we're focused on the viewport area

# in case someone wants to modify these hardcoded factors
const gr_cbar_width = Ref(0.03)
const gr_cbar_offsets = Ref((0.02, 0.07))

function gr_set_viewport_cmap(sp::Subplot, vp::GRViewport)
    offset = gr_cbar_offsets[][gr_is3d(sp) ? 2 : 1]
    args = vp.xmax + offset, vp.xmax + offset + gr_cbar_width[], vp.ymin, vp.ymax
    GR.setviewport(args...)
    return GRViewport(args...)
end

function gr_set_viewport_polar(vp)
    x_ctr = xcenter(vp)
    dist = vp.ymax - 0.05width(vp)
    y_ctr = 0.5(vp.ymin + dist)
    r = 0.5NaNMath.min(width(vp), dist - vp.ymin)
    GR.setviewport(x_ctr - r, x_ctr + r, y_ctr - r, y_ctr + r)
    GR.setwindow(-1, 1, -1, 1)
    return r
end

struct GRColorbar
    gradients
    fills
    lines
    GRColorbar() = new([], [], [])
end

function gr_update_colorbar!(cbar::GRColorbar, series::Series)
    (style = colorbar_style(series)) === nothing && return
    list =
        style == cbar_gradient ? cbar.gradients :
        style == cbar_fill ? cbar.fills :
        style == cbar_lines ? cbar.lines : error("Unknown colorbar style: $style.")
    return push!(list, series)
end

function gr_contour_levels(series::Series, clims)
    levels = collect(contour_levels(series, clims))
    # GR implicitly uses the maximal z value as the highest level
    isfilledcontour(series) && pop!(levels)
    return levels
end

function gr_colorbar_colors(series::Series, clims)
    colors = if iscontour(series)
        levels = gr_contour_levels(series, clims)
        zrange = if isfilledcontour(series)
            ignorenan_extrema(levels)  # GR.contourf uses a color range according to supplied levels
        else
            clims  # GR.contour uses a color range according to data range
        end
        @. 1_000 + 255 * (levels - zrange[1]) / (zrange[2] - zrange[1])
    else
        1_000:1_255  # 256 values
    end
    return round.(Int, colors)
end

function _cbar_unique(values, propname)
    out = last(values)
    if any(x != out for x in values)
        @warn """
        Multiple series with different $propname share a colorbar.
        Colorbar may not reflect all series correctly.
        """
    end
    return out
end

const gr_colorbar_tick_size = Ref(0.005)

function gr_colorbar_title(sp::Subplot)
    title = if (ttl = sp[:colorbar_title]) isa PlotText
        ttl
    else
        text(ttl, colorbartitlefont(sp))
    end
    title.font.rotation += 90  # default rotated by 90° (vertical)
    return title
end

function gr_colorbar_info(sp::Subplot)
    clims = gr_clims(sp)
    return maximum(first.(gr_text_size.(clims))), clims
end

# add the colorbar
function gr_draw_colorbar(cbar::GRColorbar, sp::Subplot, vp::GRViewport)
    GR.savestate()
    x_min, x_max = gr_x_axislims(sp)
    tick_max_width, clims = gr_colorbar_info(sp)
    z_min, z_max = clims
    vp_cmap = gr_set_viewport_cmap(sp, vp)
    GR.setscale(0)
    GR.setwindow(x_min, x_max, z_min, z_max)
    if !isempty(cbar.gradients)
        series = cbar.gradients
        gr_set_gradient(_cbar_unique(get_colorgradient.(series), "color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        GR.cellarray(x_min, x_max, z_max, z_min, 1, 256, 1_000:1_255)
    end

    if !isempty(cbar.fills)
        series = cbar.fills
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        gr_set_gradient(_cbar_unique(get_colorgradient.(series), "color"))
        gr_set_transparency(_cbar_unique(get_fillalpha.(series), "fill alpha"))
        levels = _cbar_unique(contour_levels.(series, Ref(clims)), "levels")
        # GR implicitly uses the maximal z value as the highest level
        if last(levels) < z_max
            @warn "GR: highest contour level less than maximal z value is not supported."
            # replace levels, rather than assign to last(levels), to ensure type
            # promotion in case levels is an integer array
            pop!(levels)
            push!(levels, z_max)
        end
        colors = gr_colorbar_colors(last(series), clims)
        for (from, to, color) in zip(levels[1:(end - 1)], levels[2:end], colors)
            GR.setfillcolorind(color)
            GR.fillrect(x_min, x_max, from, to)
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
            GR.polyline([x_min, x_max], [line, line])
        end
    end

    if _has_ticks(sp[:colorbar_ticks])
        z_tick = 0.5GR.tick(z_min, z_max)
        gr_set_line(1, :solid, plot_color(:black), sp)
        (yscale = sp[:colorbar_scale]) ∈ _logScales && GR.setscale(gr_y_log_scales[yscale])
        # signature: gr.axes(x_tick, y_tick, x_org, y_org, major_x, major_y, tick_size)
        GR.axes(0, z_tick, x_max, z_min, 0, 1, gr_colorbar_tick_size[])
    end

    title = gr_colorbar_title(sp)
    gr_set_font(title.font, sp; halign = :center, valign = :top)
    gr_text(vp.xmax + 0.1, ycenter(vp), title.str)

    GR.restorestate()
    return nothing
end

position(symb) =
if symb === :top || symb === :right
    0.95
elseif symb === :left || symb === :bottom
    0.05
else
    0.5
end

alignment(symb) =
if symb === :top || symb === :right
    :right
elseif symb === :left || symb === :bottom
    :left
else
    :center
end

# --------------------------------------------------------------------------------------

function gr_set_gradient(c)
    grad = _as_gradient(c)
    for (i, z) in enumerate(range(0, 1; length = 256))
        c = grad[z]
        GR.setcolorrep(999 + i, red(c), green(c), blue(c))
    end
    return grad
end

gr_set_gradient(series::Series) =
    (color = get_colorgradient(series)) !== nothing && gr_set_gradient(color)

# this is our new display func... set up the viewport_canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot, dpi_factor = 1)
    GR.clearws()

    # collect some monitor/display sizes in meters and pixels
    dsp_width_meters, dsp_height_meters, dsp_width_px, dsp_height_px = GR.inqdspsize()
    dsp_width_ratio = dsp_width_meters / dsp_width_px
    dsp_height_ratio = dsp_height_meters / dsp_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    vp_canvas = GRViewport(0.0, 1.0, 0.0, 1.0)
    w, h = get_size(plt)
    if w > h
        ratio = float(h) / w
        msize = dsp_width_ratio * w * dpi_factor
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        vp_canvas.ymin *= ratio
        vp_canvas.ymax *= ratio
    else
        ratio = float(w) / h
        msize = dsp_height_ratio * h * dpi_factor
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        vp_canvas.xmin *= ratio
        vp_canvas.xmax *= ratio
    end

    # fill in the viewport_canvas background
    gr_fill_viewport(vp_canvas, plt[:background_color_outside])

    # subplots
    foreach(sp -> gr_display(sp, w * px, h * px, vp_canvas), plt.subplots)

    GR.updatews()
    return nothing
end

gr_set_tickfont(sp, ax::Axis; kw...) = gr_set_font(
    tickfont(ax),
    sp;
    rotation = ax[:rotation],
    color = ax[:tickfontcolor],
    kw...,
)

function gr_set_tickfont(sp, letter::Symbol; kw...)
    axis = sp[get_attr_symbol(letter, :axis)]
    return gr_set_font(
        tickfont(axis),
        sp;
        rotation = axis[:rotation],
        color = axis[:tickfontcolor],
        kw...,
    )
end

# size of the text with no rotation
function gr_text_size(str)
    GR.savestate()
    GR.selntran(0)
    GR.setcharup(0, 1)
    (l, r), (b, t) = extrema.(gr_inqtext(0, 0, string(str)))
    GR.restorestate()
    return r - l, t - b  # w, h
end

# size of the text with rotation applied
function gr_text_size(str, rot)
    GR.savestate()
    GR.selntran(0)
    GR.setcharup(0, 1)
    (l, r), (b, t) = extrema.(gr_inqtext(0, 0, string(str)))
    GR.restorestate()
    return text_box_width(r - l, t - b, rot), text_box_height(r - l, t - b, rot)  # w, h
end

text_box_width(w, h, rot) = abs(cosd(rot)) * w + abs(cosd(rot + 90)) * h
text_box_height(w, h, rot) = abs(sind(rot)) * w + abs(sind(rot + 90)) * h

function gr_get_3d_axis_angle(cvs, nt, ft, letter)
    length(cvs) < 2 && return 0
    tickpoints = map(cv -> gr_w3tondc(sort_3d_axes(cv, nt, ft, letter)...), cvs)
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
    return label -> replace(texfunc(label), "-" => "−")
end

function gr_axis_height(sp, axis)
    GR.savestate()
    ticks = get_ticks(sp, axis, update = false)
    gr_set_font(tickfont(axis), sp)
    h = (
        ticks in (nothing, false, :none) ? 0 :
            last(gr_get_ticks_size(ticks, axis[:rotation]))
    )
    if (guide = Plots.get_guide(axis)) != ""
        gr_set_font(guidefont(axis), sp)
        h += last(gr_text_size(guide))
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
    if (guide = Plots.get_guide(axis)) != ""
        gr_set_font(guidefont(axis), sp)
        w += last(gr_text_size(guide))
    end
    GR.restorestate()
    return w
end

function _update_min_padding!(sp::Subplot{GRBackend})
    dpi = sp.plt[:thickness_scaling]
    width, height = sp_size = get_size(sp)

    # Add margin given by the user
    padding = (
        left = Ref(2mm + sp[:left_margin]),
        top = Ref(2mm + sp[:top_margin]),
        right = Ref(2mm + sp[:right_margin]),
        bottom = Ref(2mm + sp[:bottom_margin]),
    )

    # Add margin for title
    if (title = sp[:title]) != ""
        gr_set_font(titlefont(sp), sp)
        l = last(gr_text_size(title))
        padding.top[] += 1mm + height * l * px
    end

    xaxis, yaxis, zaxis = axes = sp[:xaxis], sp[:yaxis], sp[:zaxis]
    xticks, yticks, zticks = get_ticks.(Ref(sp), axes)

    if gr_is3d(sp)
        # Add margin for x and y ticks
        m = 0mm
        for (ax, tc) in ((xaxis, xticks), (yaxis, yticks))
            isempty(first(tc)) && continue
            rot = ax[:rotation]
            gr_set_tickfont(
                sp,
                ax;
                halign = (:left, :hcenter, :right)[sign(rot) + 2],
                valign = ax[:mirror] ? :bottom : :top,
            )
            l = 0.01 + last(gr_get_ticks_size(tc, rot))
            m = max(m, 1mm + height * l * px)
        end
        if m > 0mm
            (xaxis[:mirror] || yaxis[:mirror]) && (padding.top[] += m)
            (!xaxis[:mirror] || !yaxis[:mirror]) && (padding.bottom[] += m)
        end

        if !isempty(first(zticks))
            rot = zaxis[:rotation]
            gr_set_tickfont(
                sp,
                zaxis;
                halign = zaxis[:mirror] ? :left : :right,
                valign = (:top, :vcenter, :bottom)[sign(rot) + 2],
            )
            l = 0.01 + first(gr_get_ticks_size(zticks, rot))
            padding[zaxis[:mirror] ? :right : :left][] += 1mm + width * l * px
        end

        # Add margin for x or y label
        m = 0mm
        for ax in (xaxis, yaxis)
            (guide = Plots.get_guide(ax) == "") && continue
            gr_set_font(guidefont(ax), sp)
            l = last(gr_text_size(guide))
            m = max(m, 1mm + height * l * px)
        end
        if m > 0mm
            # NOTE: `xaxis` arbitrary here ?
            padding[mirrored(xaxis, :top) ? :top : :bottom][] += m
        end
        # Add margin for z label
        if (guide = Plots.get_guide(zaxis)) != ""
            gr_set_font(guidefont(zaxis), sp)
            l = last(gr_text_size(guide))
            padding[mirrored(zaxis, :right) ? :right : :left][] += 1mm + height * l * px  # NOTE:  why `height` here ?
        end
    else
        # Add margin for x/y ticks & labels
        for (ax, tc, (a, b)) in
            ((xaxis, xticks, (:top, :bottom)), (yaxis, yticks, (:right, :left)))
            if !isempty(first(tc))
                isy = ax[:letter] === :y
                gr_set_tickfont(sp, ax)
                ts = gr_get_ticks_size(tc, ax[:rotation])
                l = 0.01 + (isy ? first(ts) : last(ts))
                padding[ax[:mirror] ? a : b][] += 1mm + sp_size[isy ? 1 : 2] * l * px
            end
            if (guide = Plots.get_guide(ax)) != ""
                gr_set_font(guidefont(ax), sp)
                l = last(gr_text_size(guide))
                padding[mirrored(ax, a) ? a : b][] += 1mm + height * l * px  # NOTE: using `height` is arbitrary
            end
        end
    end
    if (title = gr_colorbar_title(sp)).str != ""
        padding.right[] += @static if false
            sz = gr_text_size(title)
            l = is_horizontal(title) ? first(sz) : last(sz)
            l * width * px
        else
            4mm
        end
    end

    return sp.minpad = (
        dpi * padding.left[],
        dpi * padding.top[],
        dpi * padding.right[],
        dpi * padding.bottom[],
    )
end

remap(x, lo, hi) = (x - lo) / (hi - lo)
get_z_normalized(z, clims...) = isnan(z) ? 256 / 255 : remap(clamp(z, clims...), clims...)

function gr_clims(sp, args...)
    sp[:clims] === :auto || return get_clims(sp)
    lo, hi = get_clims(sp, args...)
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

function gr_viewport_bbox(vp, sp, color)
    GR.savestate()
    GR.selntran(0)
    GR.setscale(0)
    gr_set_line(1, :solid, plot_color(color), sp)
    GR.drawrect(vp.xmin, vp.xmax, vp.ymin, vp.ymax)
    GR.selntran(1)
    GR.restorestate()
    return nothing
end

function gr_display(sp::Subplot{GRBackend}, w, h, vp_canvas::GRViewport)
    _update_min_padding!(sp)

    # the viewports for this subplot and the whole plot
    vp_sp = gr_viewport_from_bbox(sp, bbox(sp), w, h, vp_canvas)
    vp_plt = gr_viewport_from_bbox(sp, plotarea(sp), w, h, vp_canvas)

    # update plot viewport
    leg = gr_get_legend_geometry(vp_plt, sp)
    gr_update_viewport_legend!(vp_plt, sp, leg)
    gr_update_viewport_ratio!(vp_plt, sp)

    # fill in the plot area background
    gr_fill_plotarea(sp, vp_plt)

    # set our plot area view
    GR.setviewport(vp_plt.xmin, vp_plt.xmax, vp_plt.ymin, vp_plt.ymax)

    # set the scale flags and window
    gr_set_window(sp, vp_plt)

    # draw the axes
    gr_draw_axes(sp, vp_plt)
    gr_add_title(sp, vp_plt, vp_sp)

    _debug[] && gr_viewport_bbox(vp_sp, sp, :red)
    _debug[] && gr_viewport_bbox(vp_plt, sp, :green)

    # this needs to be here to point the colormap to the right indices
    GR.setcolormap(1_000 + GR.COLORMAP_COOLWARM)

    # init the colorbar
    cbar = GRColorbar()

    for series in series_list(sp)
        gr_add_series(sp, series)
        gr_update_colorbar!(cbar, series)
    end

    # draw the colorbar
    hascolorbar(sp) && gr_draw_colorbar(cbar, sp, vp_plt)

    # add the legend
    gr_add_legend(sp, leg, vp_plt)

    # add annotations
    for ann in sp[:annotations]
        x, y = if is3d(sp)
            x, y, z, val = locate_annotation(sp, ann...)
            GR.setwindow(-1, 1, -1, 1)
            gr_w3tondc(x, y, z)
        else
            x, y, val = locate_annotation(sp, ann...)
            GR.wctondc(x, y)
        end
        gr_set_font(val.font, sp)
        gr_text(x, y, val.str)
    end
    return
end

## Legend

gr_legend_bbox(xpos, ypos, leg) = GR.drawrect(
    xpos - leg.space - leg.span,  # see ref(1)
    xpos + leg.textw,
    ypos - 0.5leg.dy,
    ypos + 0.5leg.dy,
)

const gr_lw_clamp_factor = Ref(5)

function gr_add_legend(sp, leg, viewport_area)
    sp[:legend_position] ∈ (:none, :inline) && return
    GR.savestate()
    GR.selntran(0)
    GR.setscale(0)
    vertical = leg.vertical
    legend_rows, legend_cols = leg.column_layout
    if leg.w > 0 || leg.h > 0
        xpos, ypos = gr_legend_pos(sp, leg, viewport_area)  # position between the legend line and text (see ref(1))
        #@show vertical leg.w leg.h leg.pad leg.span leg.entries (legend_rows, legend_cols) (xpos, ypos) leg.dx leg.dy leg.textw leg.texth
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        gr_set_fillcolor(sp[:legend_background_color])
        # ymax
        # |
        # |
        # o ----- xmax
        xs = xpos - leg.pad - leg.span, xpos + leg.w + leg.pad
        ys = ypos - leg.h, ypos + leg.dy
        # xmin, xmax, ymin, ymax
        GR.fillrect(xs..., ys...)  # allocating white space for actual legend width here
        gr_set_line(1, :solid, sp[:legend_foreground_color], sp)
        GR.drawrect(xs..., ys...)  # drawing actual legend width here
        if (ttl = sp[:legend_title]) !== nothing
            shift = legend_rows > 1 ? 0.5(legend_cols - 1) * leg.dx : 0 # shifting title to center if multi-column
            gr_set_font(legendtitlefont(sp), sp)
            _debug[] && gr_legend_bbox(xpos, ypos, leg)
            gr_text(xpos - leg.pad - leg.space + 0.5leg.textw + shift, ypos, string(ttl))
            if vertical || legend_rows != 1
                legend_rows -= 1
                ypos -= leg.dy
            else
                xpos += leg.dx
            end
        end
        gr_set_font(legendfont(sp), sp; halign = :left, valign = :center)

        lft, rgt, bot, top = -leg.space - leg.span, -leg.space, -0.4leg.dy, 0.4leg.dy
        lfps = sp[:legend_font_pointsize]

        min_lw = DEFAULT_LINEWIDTH[] / gr_lw_clamp_factor[]
        max_lw = DEFAULT_LINEWIDTH[] * gr_lw_clamp_factor[]

        nentry = 1

        for series in series_list(sp)
            should_add_to_legend(series) || continue
            st = series[:seriestype]
            clims = gr_clims(sp, series)
            lc = get_linecolor(series, clims)
            lw = get_linewidth(series)
            ls = get_linestyle(series)
            la = get_linealpha(series)
            clamped_lw = (lfps / 8) * clamp(lw, min_lw, max_lw)
            gr_set_line(clamped_lw, ls, lc, sp)  # see github.com/JuliaPlots/Plots.jl/issues/3003
            _debug[] && gr_legend_bbox(xpos, ypos, leg)

            if (
                    (st === :shape || series[:fillrange] !== nothing) &&
                        series[:ribbon] === nothing
                )
                (fc = get_fillcolor(series, clims)) |> gr_set_fill
                gr_set_fillstyle(get_fillstyle(series, 0))
                l, r = xpos + lft, xpos + rgt
                b, t = ypos + bot, ypos + top
                #   4     <--     3
                # (l,t) ------- (r,t)
                #   |             |
                #   |             |
                # (l,b) ------- (r,b)
                #   1     -->     2
                x, y = [l, r, r, l, l], [b, b, t, t, b]
                gr_set_transparency(fc, get_fillalpha(series))
                gr_polyline(x, y, GR.fillarea)
                gr_set_transparency(lc, la)
                gr_set_line(clamped_lw, ls, lc, sp)
                st === :shape && gr_polyline(x, y)
            end

            max_markersize = Inf
            if st in (:path, :straightline, :path3d)
                max_markersize = leg.base_markersize
                gr_set_transparency(lc, la)
                filled = series[:fillrange] !== nothing && series[:ribbon] === nothing
                GR.polyline(xpos .+ [lft, rgt], ypos .+ (filled ? [top, top] : [0, 0]))
            end

            if (msh = series[:markershape]) !== :none
                msz = max(first(series[:markersize]), 0)
                msw = max(first(series[:markerstrokewidth]), 0)
                mfac = 0.8 * lfps / (msz + 0.5 * msw + 1.0e-20)
                gr_draw_marker(
                    series,
                    xpos - 2leg.base_factor,
                    ypos,
                    nothing,
                    clims,
                    1,
                    min(max_markersize, mfac * msz),
                    min(max_markersize, mfac * msw),
                    Plots._cycle(msh, 1),
                )
            end

            gr_set_textcolor(plot_color(sp[:legend_font_color]))
            gr_text(xpos, ypos, string(series[:label]))
            if vertical
                ypos -= leg.dy
            else
                # println(string(series[:label]), " ", nentry, " ", nentry % legend_cols)
                xpos += nentry % legend_cols == 0 ? -(legend_cols - 1) * leg.dx : leg.dx
                ypos -= nentry % legend_cols == 0 ? leg.dy : 0
                nentry += 1
            end
        end
    end
    GR.selntran(1)
    GR.restorestate()
    return nothing
end

mirrored(ax::Axis, sym::Symbol) =
    ax[:guide_position] === sym || (ax[:guide_position] === :auto && ax[:mirror])

function gr_legend_pos(sp::Subplot, leg, vp)
    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    xmirror = mirrored(xaxis, :top)
    ymirror = mirrored(yaxis, :right)
    if (lp = sp[:legend_position]) isa Real
        return gr_legend_pos(lp, leg, vp)
    elseif lp isa Tuple{<:Real, Symbol}
        axisclearance = if lp[2] === :outer
            [
                !ymirror * gr_axis_width(sp, yaxis),
                ymirror * gr_axis_width(sp, yaxis),
                !xmirror * gr_axis_height(sp, xaxis),
                xmirror * gr_axis_height(sp, xaxis),
            ]
        else
            nothing
        end
        return gr_legend_pos(lp[1], leg, vp; axisclearance)
    elseif !(lp isa Symbol)
        return gr_legend_pos(lp, vp)
    end

    leg_str = string(_guess_best_legend_position(lp, sp))

    xpos = if occursin("left", leg_str)
        vp.xmin + if occursin("outer", leg_str)
            -leg.pad - leg.w - leg.xoffset - !ymirror * gr_axis_width(sp, yaxis)
        else
            leg.pad + leg.span + leg.xoffset
        end
    elseif occursin("right", leg_str)  # default / best
        vp.xmax + if occursin("outer", leg_str)  # per github.com/jheinen/GR.jl/blob/master/src/jlgr.jl#L525
            leg.pad + leg.span + leg.xoffset + ymirror * gr_axis_width(sp, yaxis)
        else
            -leg.pad - leg.w - leg.xoffset
        end
    else
        vp.xmin + 0.5width(vp) - 0.5leg.w + leg.xoffset
    end
    ypos = if occursin("bottom", leg_str)
        vp.ymin + if lp === :outerbottom
            -leg.yoffset - leg.dy - !xmirror * gr_axis_height(sp, xaxis)
        else
            leg.yoffset + leg.h
        end
    elseif occursin("top", leg_str)  # default / best
        vp.ymax + if lp === :outertop
            leg.yoffset + leg.h + xmirror * gr_axis_height(sp, xaxis)
        else
            -leg.yoffset - leg.dy
        end
    else
        # adding min y to shift legend pos to correct graph (#2377)
        vp.ymin + 0.5height(vp) + 0.5leg.h - leg.yoffset
    end
    return xpos, ypos
end

gr_legend_pos(v::NTuple{2, Real}, vp) =
    (vp.xmin + v[1] * (vp.xmax - vp.xmin), vp.ymin + v[2] * (vp.ymax - vp.ymin))

function gr_legend_pos(theta::Real, leg, vp; axisclearance = nothing)
    if isnothing(axisclearance)  # inner
        # rectangle where the anchor can legally be
        xmin = vp.xmin + leg.xoffset + leg.pad + leg.span
        xmax = vp.xmax - leg.xoffset - leg.pad - leg.textw
        ymin = vp.ymin + leg.yoffset + leg.h
        ymax = vp.ymax - leg.yoffset - leg.dy
    else  # outer
        xmin = vp.xmin - leg.xoffset - leg.pad - leg.textw - axisclearance[1]
        xmax = vp.xmax + leg.xoffset + leg.pad + leg.span + axisclearance[2]
        ymin = vp.ymin - leg.yoffset - leg.dy - axisclearance[3]
        ymax = vp.ymax + leg.yoffset + leg.h + axisclearance[4]
    end
    return legend_pos_from_angle(theta, xmin, xcenter(vp), xmax, ymin, ycenter(vp), ymax)
end

const gr_legend_marker_to_line_factor = Ref(2.0)

function gr_get_legend_geometry(vp, sp)
    vertical = (legend_column = sp[:legend_column]) == 1
    textw = texth = 0.0
    has_title = false
    nseries = 0
    if sp[:legend_position] !== :none
        GR.savestate()
        GR.selntran(0)
        GR.setcharup(0, 1)
        GR.setscale(0)
        ttl = sp[:legend_title]
        if (has_title = ttl !== nothing)
            gr_set_font(legendtitlefont(sp), sp)
            (l, r), (b, t) = extrema.(gr_inqtext(0, 0, string(ttl)))
            texth = t - b
            textw = r - l
        end
        gr_set_font(legendfont(sp), sp)
        for series in series_list(sp)
            should_add_to_legend(series) || continue
            (l, r), (b, t) = extrema.(gr_inqtext(0, 0, string(series[:label])))
            texth = max(texth, t - b)
            textw = max(textw, r - l)  # holds text width right now
            nseries += 1
        end
        GR.setscale(GR.OPTION_X_LOG)
        GR.selntran(1)
        GR.restorestate()
    end
    # deal with layout
    column_layout = if legend_column == -1
        (1, has_title + nseries)
    elseif legend_column > nseries && nseries != 0 # catch plot_title here
        @warn "n° of legend_column=$legend_column is larger than n° of series=$nseries"
        (1 + has_title, nseries)
    elseif legend_column == 0
        @warn "n° of legend_column=$legend_column. Assuming vertical layout."
        vertical = true
        (has_title + nseries, 1)
    else
        (ceil(Int64, nseries / legend_column) + has_title, legend_column)
    end
    #println(column_layout)

    base_factor = width(vp) / 45  # determines legend box base width (arbitrarily based on `width`)

    # legend box conventions ref(1)
    #  ______________________________
    # |<pad><span><space><text> <pad>|
    # |     ---o--       ⋅ y1        |
    # |__________________↑___________|
    #               (xpos,ypos)

    pad = 1base_factor  # legend padding
    span = 3base_factor  # horizontal span of the legend line: line x marker x line = 3base_factor
    space = 0.5base_factor  # white space between text and legend / markers

    # increment between each legend entry
    ekw = sp[:extra_kwargs]
    dy = texth * get(ekw, :legend_hfactor, 1)
    span_hspace = span + pad  # part of the horizontal increment
    dx = (textw + (vertical ? 0 : span_hspace)) * get(ekw, :legend_wfactor, 1)

    # This is to prevent that linestyle is obscured by large markers.
    # We are trying to get markers to not be larger than half the line length.
    # 1 / leg.dy translates base_factor to line length units (important in the context of size kwarg)
    # gr_legend_marker_to_line_factor is an empirical constant to translate between line length unit and marker size unit
    base_markersize = gr_legend_marker_to_line_factor[] * span / dy  # NOTE: arbitrarily based on horizontal measures !

    entries = has_title + nseries  # number of legend entries

    # NOTE: subtract `span_hspace`, since it joins labels in horizontal mode
    w = dx * column_layout[2] - space - !vertical * span_hspace
    h = dy * column_layout[1]

    return (
        yoffset = height(vp) / 30,
        xoffset = width(vp) / 30,
        base_markersize,
        base_factor,
        has_title,
        vertical,
        entries,
        column_layout,
        space,
        texth,
        textw,
        span,
        pad,
        dy,
        dx,
        w,
        h,
    )
end

## Viewport, window and scale

function gr_update_viewport_legend!(vp, sp, leg)
    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    xmirror = mirrored(xaxis, :top)
    ymirror = mirrored(yaxis, :right)
    leg_str = if (lp = sp[:legend_position]) isa Tuple{<:Real, Symbol} && lp[2] === :outer
        x, y = gr_legend_pos(sp, leg, vp)  # dry run, to figure out
        horz = x < vp.xmin ? "left" : (x > vp.xmax ? "right" : "")
        vert = y < vp.ymin ? "bot" : (y > vp.ymax ? "top" : "")
        "outer" * vert * horz
    else
        string(lp)
    end
    if occursin("outer", leg_str)
        xoff = leg.xoffset + leg.w + leg.pad + leg.span + leg.pad
        yoff = leg.yoffset + leg.h + leg.dy
        if occursin("right", leg_str)
            vp.xmax -= xoff
        elseif occursin("left", leg_str)
            vp.xmin += xoff + !ymirror * gr_axis_width(sp, yaxis)
        elseif occursin("top", leg_str)
            vp.ymax -= yoff
        elseif occursin("bot", leg_str)  # NOTE: matches `bottom` or `bot`
            vp.ymin += yoff + !xmirror * gr_axis_height(sp, xaxis)
        end
    end
    if lp === :inline
        if yaxis[:mirror]
            vp.xmin += leg.textw
        else
            vp.xmax -= leg.textw
        end
    end
    return nothing
end

gr_update_viewport_ratio!(vp, sp) =
if (ratio = get_aspect_ratio(sp)) !== :none
    ratio === :equal && (ratio = 1)
    x_min, x_max, y_min, y_max = gr_xy_axislims(sp)
    viewport_ratio = width(vp) / height(vp)
    window_ratio = (x_max - x_min) / (y_max - y_min) / ratio
    if window_ratio < viewport_ratio
        viewport_center = xcenter(vp)
        viewport_size = width(vp) * window_ratio / viewport_ratio
        vp.xmin = viewport_center - 0.5viewport_size
        vp.xmax = viewport_center + 0.5viewport_size
    elseif window_ratio > viewport_ratio
        viewport_center = ycenter(vp)
        viewport_size = height(vp) * viewport_ratio / window_ratio
        vp.ymin = viewport_center - 0.5viewport_size
        vp.ymax = viewport_center + 0.5viewport_size
    end
end

gr_set_window(sp, vp) =
if ispolar(sp)
    gr_set_viewport_polar(vp)
else
    x_min, x_max, y_min, y_max = gr_xy_axislims(sp)
    zok = if (needs_3d = needs_any_3d_axes(sp))
        z_min, z_max = gr_z_axislims(sp)
        z_max > z_min
    else
        true
    end
    if x_max > x_min && y_max > y_min && zok
        scaleop = 0
        if (xscale = sp[:xaxis][:scale]) ∈ _logScales
            scaleop |= gr_x_log_scales[xscale]
        end
        if (yscale = sp[:yaxis][:scale]) ∈ _logScales
            scaleop |= gr_y_log_scales[yscale]
        end
        if needs_3d && ((zscale = sp[:zaxis][:scale]) ∈ _logScales)
            scaleop |= gr_z_log_scales[zscale]
        end
        sp[:xaxis][:flip] && (scaleop |= GR.OPTION_FLIP_X)
        sp[:yaxis][:flip] && (scaleop |= GR.OPTION_FLIP_Y)
        (needs_3d && sp[:zaxis][:flip]) && (scaleop |= GR.OPTION_FLIP_Z)
        # NOTE: setwindow sets the "data coordinate" limits of the current "viewport"
        GR.setwindow(x_min, x_max, y_min, y_max)
        GR.setscale(scaleop)
    end
end

## Axes

function gr_draw_axes(sp, vp)
    GR.setlinewidth(sp.plt[:thickness_scaling])
    if gr_is3d(sp)
        # set space
        x_min, x_max, y_min, y_max = gr_xy_axislims(sp)
        z_min, z_max = gr_z_axislims(sp)

        azimuth, elevation = sp[:camera]

        GR.setwindow3d(x_min, x_max, y_min, y_max, z_min, z_max)
        fov = (isortho(sp) || isautop(sp)) ? NaN : 30
        cam = (isortho(sp) || isautop(sp)) ? 0 : NaN
        GR.setspace3d(-90 + azimuth, 90 - elevation, fov, cam)
        gr_set_projectiontype(sp)

        # fill the plot area
        gr_set_fill(plot_color(sp[:background_color_inside]))
        area_x = [x_min, x_min, x_min, x_max, x_max, x_max, x_min]
        area_y = [y_min, y_min, y_max, y_max, y_max, y_min, y_min]
        area_z = [z_min, z_max, z_max, z_max, z_min, z_min, z_min]
        x_bg, y_bg = RecipesPipeline.unzip(GR.wc3towc.(area_x, area_y, area_z))
        GR.fillarea(x_bg, y_bg)

        foreach(letter -> gr_draw_axis_minorgrid_3d(sp, letter, vp), (:x, :y, :z))
        foreach(letter -> gr_draw_axis_grid_3d(sp, letter, vp), (:x, :y, :z))
        foreach(letter -> gr_draw_axis_3d(sp, letter, vp), (:x, :y, :z))
    elseif ispolar(sp)
        r = gr_set_viewport_polar(vp)
        # rmin, rmax = GR.adjustrange(ignorenan_minimum(r), ignorenan_maximum(r))
        rmin, rmax = axis_limits(sp, :y)
        gr_polaraxes(rmin, rmax, sp)
    elseif sp[:framestyle] !== :none
        foreach(letter -> gr_draw_axis_minorgrid(sp, letter, vp), (:x, :y))
        foreach(letter -> gr_draw_axis_grid(sp, letter, vp), (:x, :y))
        foreach(letter -> gr_draw_axis(sp, letter, vp), (:x, :y))
    end
    GR.settransparency(1.0)
    return nothing
end

function gr_draw_axis_minorgrid_3d(sp, letter, vp)
    ax = axis_drawing_info_3d(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    return gr_draw_minorgrid(sp, axis, ax.minorgrid_segments, gr_polyline3d)
end

function gr_draw_axis_grid_3d(sp, letter, vp)
    ax = axis_drawing_info_3d(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    return gr_draw_grid(sp, axis, ax.grid_segments, gr_polyline3d)
end

function gr_draw_axis_minorgrid(sp, letter, vp)
    ax = axis_drawing_info(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    return gr_draw_minorgrid(sp, axis, ax.minorgrid_segments)
end

function gr_draw_axis_grid(sp, letter, vp)
    ax = axis_drawing_info(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    return gr_draw_grid(sp, axis, ax.grid_segments)
end

function gr_draw_axis(sp, letter, vp)
    ax = axis_drawing_info(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]

    # draw segments
    gr_draw_spine(sp, axis, ax.segments)
    gr_draw_border(sp, axis, ax.border_segments)
    gr_draw_ticks(sp, axis, ax.tick_segments)

    # labels
    gr_label_ticks(sp, letter, ax.ticks)
    gr_label_axis(sp, letter, vp)
    return nothing
end

function gr_draw_axis_3d(sp, letter, vp)
    ax = axis_drawing_info_3d(sp, letter)
    axis = sp[get_attr_symbol(letter, :axis)]

    # draw segments
    gr_draw_spine(sp, axis, ax.segments, gr_polyline3d)
    gr_draw_border(sp, axis, ax.border_segments, gr_polyline3d)
    gr_draw_ticks(sp, axis, ax.tick_segments, gr_polyline3d)

    # labels
    GR.setscale(0)
    gr_label_ticks_3d(sp, letter, ax.ticks)
    gr_label_axis_3d(sp, letter)
    gr_set_window(sp, vp)
    return nothing
end

gr_draw_grid(sp, axis, segments, func = gr_polyline) =
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

gr_draw_minorgrid(sp, axis, segments, func = gr_polyline) =
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

gr_draw_spine(sp, axis, segments, func = gr_polyline) =
if axis[:showaxis]
    gr_set_line(1, :solid, axis[:foreground_color_border], sp)
    gr_set_transparency(1.0)
    GR.setclip(0)
    func(coords(segments)...)
    GR.setclip(1)
end

gr_draw_border(sp, axis, segments, func = gr_polyline) =
if sp[:framestyle] in (:box, :semi)
    intensity = sp[:framestyle] === :semi ? 0.5 : 1
    GR.setclip(0)
    gr_set_line(intensity, :solid, axis[:foreground_color_border], sp)
    gr_set_transparency(axis[:foreground_color_border], intensity)
    func(coords(segments)...)
    GR.setclip(1)
end

gr_draw_ticks(sp, axis, segments, func = gr_polyline) =
if axis[:showaxis]
    if sp[:framestyle] in (:zerolines, :grid)
        gr_set_line(1, :solid, axis[:foreground_color_grid], sp)
        gr_set_transparency(
            axis[:foreground_color_grid],
            axis[:tick_direction] === :out ? axis[:gridalpha] : 0,
        )
    else
        gr_set_line(1, :solid, axis[:foreground_color_axis], sp)
    end
    GR.setclip(0)
    func(coords(segments)...)
    GR.setclip(1)
end

function gr_label_ticks(sp, letter, ticks)
    letters = axes_letters(sp, letter)
    ax, oax = map(l -> sp[get_attr_symbol(l, :axis)], letters)
    ax[:showaxis] || return
    _, (oamin, oamax) = map(l -> axis_limits(sp, l), letters)

    gr_set_tickfont(sp, letter)
    out_factor = ifelse(ax[:tick_direction] === :out, 1.5, 1)

    isy = letter === :y
    x_offset = isy ? -0.015out_factor : 0
    y_offset = isy ? 0 : -0.008out_factor

    rot = ax[:rotation] % 360
    ov = sp[:framestyle] === :origin ? 0 : xor(oax[:flip], ax[:mirror]) ? oamax : oamin
    sgn = ax[:mirror] ? -1 : 1
    sgn2 = iseven(Int(floor(rot / 90))) ? -1 : 1
    sgn3 = if isy
        -360 < rot < -180 || 0 < rot < 180 ? 1 : -1
    else
        rot < -270 || -90 < rot < 90 || rot > 270 ? 1 : -1
    end
    for (cv, dv) in zip(ticks...)
        x, y = GR.wctondc(reverse_if((cv, ov), isy)...)
        sz_rot, sz = gr_text_size(dv, rot), gr_text_size(dv)
        x_off, y_off = x_offset, y_offset
        if isy
            x_off += -first(sz_rot) / 2
            if rot % 90 != 0
                y_off += 0.5(sgn2 * last(sz_rot) + sgn3 * last(sz) * cosd(rot))
            end
        else
            if rot % 90 != 0
                x_off += 0.5(sgn2 * first(sz_rot) + sgn3 * last(sz) * sind(rot))
            end
            y_off += -last(sz_rot) / 2
        end
        gr_text(x + sgn * x_off, y + sgn * y_off, dv)
    end
    return
end

gr_label_ticks(sp, letter, ticks::Nothing) = nothing

function gr_label_ticks_3d(sp, letter, ticks)
    letters = axes_letters(sp, letter)
    _, (namin, namax), (famin, famax) = map(l -> axis_limits(sp, l), letters)
    ax = sp[get_attr_symbol(letter, :axis)]
    ax[:showaxis] || return

    isy, isz = letter .=== (:y, :z)
    n0, n1 = isy ? (namax, namin) : (namin, namax)

    gr_set_tickfont(sp, letter)
    nt = sp[:framestyle] === :origin ? 0 : ax[:mirror] ? n1 : n0
    ft = sp[:framestyle] === :origin ? 0 : ax[:mirror] ? famax : famin

    rot = mod(ax[:rotation], 360)
    sgn = ax[:mirror] ? -1 : 1

    cvs, dvs = ticks

    axisθ = isz ? 270 : mod(gr_get_3d_axis_angle(cvs, nt, ft, letter), 360)  # issue: doesn't work with 1 tick
    axisϕ = mod(axisθ - 90, 360)

    out_factor = ifelse(ax[:tick_direction] === :out, 1.5, 1)
    axis_offset = 0.012out_factor
    y_offset, x_offset = axis_offset .* sincosd(axisϕ)

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

    if !(axisθ == 0 && rot % 180 == 0) && (rot - 90) % 180 != 0
        sgn3 =
            (axisθ == 0 && 90 < rot < 270) ||
            (axisθ == 90 && rot < 180) ||
            (axisθ == 270 && rot > 180) ||
            (axisθ < 90 && (rot < axisθ || 90 ≤ rot < 180 || axisθ + 180 < rot < 270)) ||
            (axisθ > 270 && (90 ≤ rot < axisθ - 180 || 180 ≤ rot < 270 || rot > axisθ)) ?
            -1 : 1
    end

    GR.setwindow(-1, 1, -1, 1)
    for (cv, dv) in zip((ax[:flip] ? reverse(cvs) : cvs, dvs)...)
        xi, yi = gr_w3tondc(sort_3d_axes(cv, nt, ft, letter)...)
        sz_rot, sz = gr_text_size(dv, rot), gr_text_size(dv)
        x_off = x_offset + 0.5(sgn2a * first(sz_rot) + sgn3 * last(sz) * sind(rot))
        y_off = y_offset + 0.5(sgn2b * last(sz_rot) + sgn3 * last(sz) * cosd(rot))
        gr_text(xi + sgn * x_off, yi + sgn * y_off, dv)
    end
    return
end

function gr_label_axis(sp, letter, vp)
    ax = sp[get_attr_symbol(letter, :axis)]
    return if Plots.get_guide(ax) != ""
        mirror = ax[:mirror]
        GR.savestate()
        guide_position = ax[:guide_position]
        rotation = float(ax[:guidefontrotation])  # github.com/JuliaPlots/Plots.jl/issues/3089
        if letter === :x
            # default rotation = 0. should yield GR.setcharup(0, 1) i.e. 90°
            xpos = xposition(vp, position(ax[:guidefonthalign]))
            halign = alignment(ax[:guidefonthalign])
            ypos, valign =
            if guide_position === :top || (guide_position === :auto && mirror)
                vp.ymax + 0.015 + (mirror ? gr_axis_height(sp, ax) : 0.015), :top
            else
                vp.ymin - 0.015 - (mirror ? 0.015 : gr_axis_height(sp, ax)), :bottom
            end
        else
            rotation += 90  # default rotation = 0. should yield GR.setcharup(-1, 0) i.e. 180°
            ypos = yposition(vp, position(ax[:guidefontvalign]))
            halign = alignment(ax[:guidefontvalign])
            xpos, valign =
            if guide_position === :right || (guide_position === :auto && mirror)
                vp.xmax + 0.03 + mirror * gr_axis_width(sp, ax), :bottom
            else
                vp.xmin - 0.03 - !mirror * gr_axis_width(sp, ax), :top
            end
        end
        gr_set_font(guidefont(ax), sp; rotation, halign, valign)
        gr_text(xpos, ypos, Plots.get_guide(ax))
        GR.restorestate()
    end
end

function gr_label_axis_3d(sp, letter)
    ax = sp[get_attr_symbol(letter, :axis)]
    return if Plots.get_guide(ax) != ""
        letters = axes_letters(sp, letter)
        (amin, amax), (namin, namax), (famin, famax) = map(l -> axis_limits(sp, l), letters)
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
        ag = 0.5(amin + amax)
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
        gr_text(x + sgn * x_offset, y + sgn * y_offset, Plots.get_guide(ax))
        GR.restorestate()
    end
end

gr_add_title(sp, vp_plt, vp_sp) =
if (title = sp[:title]) != ""
    GR.savestate()
    xpos, ypos, halign, valign = if (loc = sp[:titlelocation]) === :left
        vp_plt.xmin, vp_sp.ymax, :left, :top
    elseif loc === :center
        xcenter(vp_plt), vp_sp.ymax, :center, :top
    elseif loc === :right
        vp_plt.xmax, vp_sp.ymax, :right, :top
    else
        xposition(vp_plt, loc[1]),
            yposition(vp_plt, loc[2]),
            sp[:titlefonthalign],
            sp[:titlefontvalign]
    end
    gr_set_font(titlefont(sp), sp; halign, valign)
    gr_text(xpos, ypos, title)
    GR.restorestate()
end

## Series

function gr_add_series(sp, series)
    # update the current stored gradient
    gr_set_gradient(series)

    GR.savestate()

    x, y, z = map(letter -> handle_surface(series[letter]), (:x, :y, :z))
    xscale, yscale = sp[:xaxis][:scale], sp[:yaxis][:scale]
    frng = series[:fillrange]

    # recompute data
    if ispolar(sp) && z === nothing
        extrema_r = gr_y_axislims(sp)
        if frng !== nothing
            _, frng = convert_to_polar(x, frng, extrema_r)
        end
        x, y = convert_to_polar(x, y, extrema_r)
    end

    # add custom frame shapes to markershape?
    series_annotations_shapes!(series)
    # -------------------------------------------------------

    gr_is3d(sp) && gr_set_projectiontype(sp)

    # draw the series
    clims = gr_clims(sp, series)
    if (st = series[:seriestype]) in (:path, :scatter, :straightline)
        if st === :straightline
            x, y = straightline_data(series)
        end
        gr_draw_segments(series, x, y, nothing, frng, clims)
        if series[:markershape] !== :none
            gr_draw_markers(series, x, y, nothing, clims)
        end
    elseif st === :shape
        gr_draw_shapes(series, clims)
    elseif st in (:path3d, :scatter3d)
        gr_draw_segments(series, x, y, z, nothing, clims)
        if st === :scatter3d || series[:markershape] !== :none
            gr_draw_markers(series, x, y, z, clims)
        end
    elseif st === :contour
        gr_draw_contour(series, x, y, z, clims)
    elseif st in (:surface, :wireframe, :mesh3d)
        GR.setwindow(-1, 1, -1, 1)
        gr_draw_surface(series, x, y, z, clims)
    elseif st === :volume
        sp[:legend_position] = :none
        GR.gr3.clear()
    elseif st === :heatmap
        # `z` is already transposed, so we need to reverse before passing its size.
        x, y = heatmap_edges(x, xscale, y, yscale, reverse(size(z)), ispolar(series))
        gr_draw_heatmap(series, x, y, z, clims)
    elseif st === :image
        gr_draw_image(series, x, y, z, clims)
    end

    # this is all we need to add the series_annotations text
    for (xi, yi, str, fnt) in EachAnn(series[:series_annotations], x, y)
        gr_set_font(fnt, sp)
        gr_text(GR.wctondc(xi, yi)..., str)
    end

    if sp[:legend_position] === :inline && should_add_to_legend(series)
        gr_set_textcolor(plot_color(sp[:legend_font_color]))
        offset, halign, valign = if sp[:yaxis][:mirror]
            _, i = sp[:xaxis][:flip] ? findmax(x) : findmin(x)
            -0.01, :right, :center
        else
            _, i = sp[:xaxis][:flip] ? findmin(x) : findmax(x)
            +0.01, :left, :center
        end
        gr_set_font(legendfont(sp), sp; halign, valign)
        x_l, y_l = GR.wctondc(x[i], y[i])
        gr_text(x_l + offset, y_l, series[:label])
    end
    GR.restorestate()
    return nothing
end

function gr_draw_segments(series, x, y, z, fillrange, clims)
    (x === nothing || length(x) ≤ 1) && return
    if fillrange !== nothing  # prepare fill-in
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        fr_from, fr_to = is_2tuple(fillrange) ? fillrange : (y, fillrange)
    end

    # draw the line(s)
    st = series[:seriestype]
    for segment in series_segments(series, st; check = true)
        i, rng = segment.attr_index, segment.range
        isempty(rng) && continue
        is3d = st === :path3d && z !== nothing
        is2d = st === :path || st === :straightline
        if is2d && fillrange !== nothing
            (fc = get_fillcolor(series, clims, i)) |> gr_set_fillcolor
            gr_set_fillstyle(get_fillstyle(series, i))
            fx = _cycle(x, vcat(rng, reverse(rng)))
            fy = vcat(_cycle(fr_from, rng), _cycle(fr_to, reverse(rng)))
            gr_set_transparency(fc, get_fillalpha(series, i))
            GR.fillarea(fx, fy)
        end
        (lc = get_linecolor(series, clims, i)) |> gr_set_fillcolor
        gr_set_line(get_linewidth(series, i), get_linestyle(series, i), lc, series)
        gr_set_transparency(lc, get_linealpha(series, i))
        if is3d
            GR.polyline3d(x[rng], y[rng], z[rng])
        elseif is2d
            arrowside, arrowstyle = if (arrow = series[:arrow]) isa Arrow
                arrow.side, arrow.style
            else
                :none, :simple
            end
            gr_polyline(x[rng], y[rng]; arrowside = arrowside, arrowstyle = arrowstyle)
        end
    end
    return
end

function gr_draw_markers(
        series::Series,
        x,
        y,
        z,
        clims,
        msize = series[:markersize],
        strokewidth = series[:markerstrokewidth],
    )
    isempty(x) && return
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    (shapes = series[:markershape]) === :none && return
    for segment in series_segments(series, :scatter)
        rng = intersect(eachindex(IndexLinear(), x), segment.range)
        isempty(rng) && continue
        i = segment.attr_index
        ms = get_thickness_scaling(series) * _cycle(msize, i)
        msw = get_thickness_scaling(series) * _cycle(strokewidth, i)
        shape = _cycle(shapes, i)
        for j in rng
            gr_draw_marker(
                series,
                _cycle(x, j),
                _cycle(y, j),
                _cycle(z, j),
                clims,
                i,
                ms,
                msw,
                shape,
            )
        end
    end
    return
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
    return
end

function gr_draw_contour(series, x, y, z, clims)
    GR.setprojectiontype(0)
    GR.setspace(clims[1], clims[2], 0, 90)
    gr_set_line(get_linewidth(series), get_linestyle(series), get_linecolor(series), series)
    gr_set_transparency(get_fillalpha(series))
    h = gr_contour_levels(series, clims)
    if series[:fillrange] !== nothing
        GR.contourf(x, y, h, z, Int(series[:contour_labels] == true))
    else
        black = plot_color(:black)
        coff = plot_color(series[:linecolor]) in (black, [black]) ? 0 : 1_000
        GR.contour(x, y, h, z, coff + Int(series[:contour_labels] == true))
    end
    return nothing
end

function gr_draw_surface(series, x, y, z, clims)
    e_kwargs = series[:extra_kwargs]
    if (st = series[:seriestype]) === :surface
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
            cns = map(cns -> [length(cns), cns...], series[:connections])
        elseif series[:connections] isa AbstractVector{NTuple{N, Int}} where {N}
            # Only N-gons - connections have to be 1-based (indexing)
            N = length(series[:connections][1])
            cns = map(cns -> [N, cns...], series[:connections])
        elseif series[:connections] isa NTuple{3, <:AbstractVector{Int}}
            # Only triangles - connections have to be 0-based (indexing)
            ci, cj, ck = series[:connections]
            if !(length(ci) == length(cj) == length(ck))
                "Argument connections must consist of equally sized arrays." |>
                    ArgumentError |>
                    throw
            end
            cns = map(i -> ([3, ci[i] + 1, cj[i] + 1, ck[i] + 1]), eachindex(ci))
        else
            "Unsupported `:connections` type $(typeof(series[:connections])) for seriestype=$st" |>
                ArgumentError |>
                throw
        end
        facecolor = if series[:fillcolor] isa AbstractArray
            series[:fillcolor]
        else
            fill(series[:fillcolor], length(cns))
        end
        fillalpha = get_fillalpha(series)
        facecolor = map(fc -> set_RGBA_alpha(fillalpha, fc), facecolor)
        GR.setborderwidth(get_linewidth(series))
        GR.setbordercolorind(gr_getcolorind(get_linecolor(series)))
        GR.polygonmesh3d(x, y, z, vcat(cns...), signed.(gr_color.(facecolor)))
    else
        throw(ArgumentError("Not handled !"))
    end
    return nothing
end

function gr_z_normalized_log_scaled(scale, z, clims)
    sf = RecipesPipeline.scale_func(scale)
    z_log = replace(x -> isinf(x) ? NaN : x, sf.(z))
    loglims = (
        !isfinite(sf(clims[1])) ? minimum(z_log) : sf(clims[1]),
        !isfinite(sf(clims[2])) ? maximum(z_log) : sf(clims[2]),
    )
    any(x -> !isfinite(x), loglims) && throw(
        DomainError(
            loglims,
            "Non-finite value in colorbar limits. Please provide explicits limits via `clims`.",
        ),
    )
    return z_log, get_z_normalized.(z_log, loglims...)
end

function gr_draw_heatmap(series, x, y, z, clims)
    fillgrad = _as_gradient(series[:fillcolor])
    GR.setprojectiontype(0)
    GR.setspace(clims..., 0, 90)
    w, h = length(x) - 1, length(y) - 1
    sp = series[:subplot]
    if !ispolar(series) && is_uniformly_spaced(x) && is_uniformly_spaced(y)
        # For uniformly spaced data use GR.drawimage, which can be
        # much faster than GR.nonuniformcellarray, especially for
        # pdf output, and also supports alpha values.
        # Note that drawimage draws uniformly spaced data correctly
        # even on log scales, where it is visually non-uniform.
        _z, colors = if (scale = sp[:colorbar_scale]) === :identity
            z, plot_color.(get(fillgrad, z, clims), series[:fillalpha])
        elseif scale ∈ _logScales
            z_log, z_normalized = gr_z_normalized_log_scaled(scale, z, clims)
            z_log, plot_color.(map(z -> get(fillgrad, z), z_normalized), series[:fillalpha])
        end
        for i in eachindex(colors)
            isnan(_z[i]) && (colors[i] = set_RGBA_alpha(0, colors[i]))
        end
        GR.drawimage(first(x), last(x), last(y), first(y), w, h, gr_color.(colors))
    else
        if something(series[:fillalpha], 1) < 1
            @warn "GR: transparency not supported in non-uniform heatmaps. Alpha values ignored."
        end
        _z, z_normalized = if (scale = sp[:colorbar_scale]) === :identity
            z, get_z_normalized.(z, clims...)
        elseif scale ∈ _logScales
            gr_z_normalized_log_scaled(scale, z, clims)
        end
        rgba = map(x -> round(Int32, 1_000 + 255x), z_normalized)
        bg_rgba = gr_getcolorind(plot_color(sp[:background_color_inside]))
        for i in eachindex(rgba)
            isnan(_z[i]) && (rgba[i] = bg_rgba)
        end
        if ispolar(series)
            y[1] < 0 && @warn "'y[1] < 0' (rmin) is not yet supported."
            rad_max = gr_y_axislims(sp)[2]
            GR.setwindow(-rad_max, rad_max, -rad_max, rad_max)  # square ar
            # nonuniformpolarcellarray(θ, ρ, nx, ny, color)
            GR.nonuniformpolarcellarray(rad2deg.(x), y, w, h, rgba)
        else
            GR.nonuniformcellarray(x, y, w, h, rgba)
        end
    end
    return nothing
end

function gr_draw_image(series, x, y, z, clims)
    x_min, x_max = ignorenan_extrema(x)
    y_min, y_max = ignorenan_extrema(y)
    GR.drawimage(x_min, x_max, y_max, y_min, size(z)..., gr_color.(z))
    return nothing
end

# ----------------------------------------------------------------

for (mime, fmt) in (
        "application/pdf" => "pdf",
        "image/png" => "png",
        "application/postscript" => "ps",
        "image/svg+xml" => "svg",
    )
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GRBackend})
        dpi_factor = $fmt == "png" ? plt[:dpi] / Plots.DPI : 1
        filepath = tempname() * "." * $fmt
        # workaround  windows bug github.com/JuliaLang/julia/issues/46989
        touch(filepath)
        GR.emergencyclosegks()
        withenv(
            "GKS_FILEPATH" => filepath,
            "GKS_ENCODING" => "utf8",
            "GKSwstype" => $fmt,
        ) do
            gr_display(plt, dpi_factor)
        end
        GR.emergencyclosegks()
        write(io, read(filepath, String))
        return rm(filepath)
    end
end

function _display(plt::Plot{GRBackend})
    return if plt[:display_type] === :inline
        filepath = tempname() * ".pdf"
        GR.emergencyclosegks()
        withenv(
            "GKS_FILEPATH" => filepath,
            "GKS_ENCODING" => "utf8",
            "GKSwstype" => "pdf",
        ) do
            gr_display(plt)
        end
        GR.emergencyclosegks()
        println(
            "\033]1337;File=inline=1;preserveAspectRatio=0:",
            base64encode(open(read, filepath)),
            "\a",
        )
        rm(filepath)
    else
        withenv("GKS_ENCODING" => "utf8", "GKS_DOUBLE_BUF" => true) do
            gr_display(plt)
        end
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
