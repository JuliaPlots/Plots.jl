
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

const gr_vector_font = Dict(
    "serif-roman" => 232,
    "sans-serif" => 233
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

function gr_polyline3d(x, y, z, func = GR.polyline3d; arrowside = :none, arrowstyle = :simple)
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
            if arrowside in (:head,:both)
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[iend-1], y[iend-1], z[iend-1], x[iend], y[iend], z[iend])
            end
            if arrowside in (:tail,:both)
                gr_set_arrowstyle(arrowstyle)
                GR.drawarrow(x[istart+1], y[istart+1], z[istart+1], x[istart], y[istart], z[istart])
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
    rtick_labels = gr_tick_label.((yaxis,), rtick_labels)

    #draw angular grid
    if xaxis[:grid]
        gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
        gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
        for i in eachindex(α)
            GR.polyline([sinf[i], 0], [cosf[i], 0])
        end
    end

    #draw radial grid
    if yaxis[:grid]
        gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
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
function gr_draw_marker(series, xi, yi, clims, i, msize, shape::Shape)
    sx, sy = coords(shape)
    # convert to ndc coords (percentages of window)
    GR.selntran(0)
    w, h = gr_plot_size
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
    gr_set_line(get_markerstrokewidth(series, i), :solid, msc)
    gr_set_transparency(msc, get_markerstrokealpha(series, i))
    GR.polyline(xs, ys)
    GR.selntran(1)
end

function nominal_size()
    w, h = gr_plot_size
    min(w, h) / 500
end

# draw ONE symbol marker
function gr_draw_marker(series, xi, yi, clims, i, msize::Number, shape::Symbol)
    GR.setborderwidth(series[:markerstrokewidth]);
    gr_set_bordercolor(get_markerstrokecolor(series, i));
    gr_set_markercolor(get_markercolor(series, clims, i));
    gr_set_transparency(get_markeralpha(series, i))
    GR.setmarkertype(gr_markertype[shape])
    GR.setmarkersize(0.3msize / nominal_size())
    GR.polymarker([xi], [yi])
end


# draw the markers, one at a time
function gr_draw_markers(series::Series, x, y, clims, msize = series[:markersize])

    isempty(x) && return
    GR.setfillintstyle(GR.INTSTYLE_SOLID)

    shapes = series[:markershape]
    if shapes != :none
        for i=eachindex(x)
            msi = _cycle(msize, i)
            shape = _cycle(shapes, i)
            gr_draw_marker(series, x[i], y[i], clims, i, msi, shape)
        end
    end
end

# ---------------------------------------------------------

function gr_set_line(lw, style, c) #, a)
    GR.setlinetype(gr_linetype[style])
    w, h = gr_plot_size
    GR.setlinewidth(_gr_thickness_scaling[1] * max(0, lw / nominal_size()))
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
    elseif haskey(gr_vector_font, family)
        GR.settextfontprec(gr_vector_font[family], 3)
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

function gr_w3tondc(x, y, z)
    xw, yw, zw = GR.wc3towc(x, y, z)
    x, y = GR.wctondc(xw, yw)
    return x, y
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
    if hascolorbar(sp)
        viewport[2] -= gr_colorbar_ratio * (1 + RecipesPipeline.is3d(sp) / 2)
    end
    viewport
end

# change so we're focused on the viewport area
function gr_set_viewport_cmap(sp::Subplot)
    GR.setviewport(
        viewport_plotarea[2] + (RecipesPipeline.is3d(sp) ? 0.07 : 0.02),
        viewport_plotarea[2] + (RecipesPipeline.is3d(sp) ? 0.10 : 0.05),
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
            xpos = viewport_plotarea[2] + 0.11 + ymirror * gr_axis_width(sp, sp[:yaxis])
        else
            xpos = viewport_plotarea[2] - 0.05 - w
        end
    elseif occursin("left", str)
        if occursin("outer", str)
            xpos = viewport_plotarea[1] - 0.05 - w - !ymirror * gr_axis_width(sp, sp[:yaxis])
        else
            xpos = viewport_plotarea[1] + 0.11
        end
    else
        xpos = (viewport_plotarea[2]-viewport_plotarea[1])/2 - w/2 +.04
    end
    if occursin("top", str)
        if s == :outertop
            ypos = viewport_plotarea[4] + 0.02 + h + xmirror * gr_axis_height(sp, sp[:xaxis])
        else
            ypos = viewport_plotarea[4] - 0.06
        end
    elseif occursin("bottom", str)
        if s == :outerbottom
            ypos = viewport_plotarea[3] - 0.05 - !xmirror * gr_axis_height(sp, sp[:xaxis])
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
    color = get_colorgradient(series)
    color !== nothing && gr_set_gradient(color)
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

gr_tick_label(axis,label) = (axis[:formatter] in (:scientific, :auto)) ?
                                gr_convert_sci_tick_label(label) :
                                label

function gr_convert_sci_tick_label(label)
    caret_split = split(label,'^')
    if length(caret_split) == 2
        base, exponent = caret_split
        label = "$base^{$exponent}"
    end
    convert_sci_unicode(label)
end

function gr_axis_height(sp, axis)
    ticks = get_ticks(sp, axis)
    gr_set_font(tickfont(axis))
    h = (ticks in (nothing, false, :none) ? 0 : last(gr_get_ticks_size(ticks, axis[:rotation])))
    if axis[:guide] != ""
        gr_set_font(guidefont(axis))
        h += last(gr_text_size(axis[:guide]))
    end
    return h
end

function gr_axis_width(sp, axis)
    ticks = get_ticks(sp, axis)
    gr_set_font(tickfont(axis))
    w = (ticks in (nothing, false, :none) ? 0 : first(gr_get_ticks_size(ticks, axis[:rotation])))
    if axis[:guide] != ""
        gr_set_font(guidefont(axis))
        w += last(gr_text_size(axis[:guide]))
    end
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
        gr_set_font(titlefont(sp))
        l = last(last(gr_text_size(sp[:title])))
        h = 1mm + gr_plot_size[2] * l * px
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
                rotation = xaxis[:rotation]
            )
            l = 0.01 + last(gr_get_ticks_size(xticks, xaxis[:rotation]))
            h = max(h, 1mm + gr_plot_size[2] * l * px)
        end
        if !(yticks in (nothing, false, :none))
            gr_set_font(
                tickfont(yaxis),
                halign = (:left, :hcenter, :right)[sign(yaxis[:rotation]) + 2],
                valign = (yaxis[:mirror] ? :bottom : :top),
                rotation = yaxis[:rotation]
            )
            l = 0.01 + last(gr_get_ticks_size(yticks, yaxis[:rotation]))
            h = max(h, 1mm + gr_plot_size[2] * l * px)
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
            )
            l = 0.01 + first(gr_get_ticks_size(zticks, zaxis[:rotation]))
            w = 1mm + gr_plot_size[1] * l * px
            if zaxis[:mirror]
                rightpad += w
            else
                leftpad += w
            end
        end

        # Add margin for x or y label
        h = 0mm
        if xaxis[:guide] != ""
            gr_set_font(guidefont(sp[:xaxis]))
            l = last(gr_text_size(sp[:xaxis][:guide]))
            h = max(h, 1mm + gr_plot_size[2] * l * px)
        end
        if yaxis[:guide] != ""
            gr_set_font(guidefont(sp[:yaxis]))
            l = last(gr_text_size(sp[:yaxis][:guide]))
            h = max(h, 1mm + gr_plot_size[2] * l * px)
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
            gr_set_font(guidefont(sp[:zaxis]))
            l = last(gr_text_size(sp[:zaxis][:guide]))
            w = 1mm + gr_plot_size[2] * l * px
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

function gr_display(sp::Subplot{GRBackend}, w, h, viewport_canvas)
    _update_min_padding!(sp)

    # the viewports for this subplot
    viewport_subplot = gr_viewport_from_bbox(sp, bbox(sp), w, h, viewport_canvas)
    viewport_plotarea[:] = gr_viewport_from_bbox(sp, plotarea(sp), w, h, viewport_canvas)
    # get data limits
    data_lims = gr_xy_axislims(sp)
    xy_lims = data_lims

    ratio = get_aspect_ratio(sp)
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
            viewport_plotarea[2] -= legendw + 0.12
        elseif occursin("left", leg_str)
            viewport_plotarea[1] += legendw + 0.11
        elseif occursin("top", leg_str)
            viewport_plotarea[4] -= legendh + 0.03
        elseif occursin("bottom", leg_str)
            viewport_plotarea[3] += legendh + 0.04
        end
    end
    if sp[:legend] == :inline
        if sp[:yaxis][:mirror]
            viewport_plotarea[1] += legendw
        else
            viewport_plotarea[2] -= legendw
        end
    end

    # fill in the plot area background
    bg = plot_color(sp[:background_color_inside])
    RecipesPipeline.is3d(sp) || gr_fill_viewport(viewport_plotarea, bg)

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
        if st in (:heatmap, :image)
            outside_ticks = true
            x, y = heatmap_edges(series[:x], sp[:xaxis][:scale], series[:y], sp[:yaxis][:scale], size(series[:z]))
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

    if RecipesPipeline.is3d(sp)
        zmin, zmax = axis_limits(sp, :z)
        GR.setspace(zmin, zmax, round.(Int, sp[:camera])...)

        xticks, yticks, zticks, xaxis_segs, yaxis_segs, zaxis_segs, xtick_segs, ytick_segs, ztick_segs, xgrid_segs, ygrid_segs, zgrid_segs, xminorgrid_segs, yminorgrid_segs, zminorgrid_segs, xborder_segs, yborder_segs, zborder_segs = axis_drawing_info_3d(sp)

        # fill the plot area
        gr_set_fill(sp[:background_color_inside])
        plot_area_x = [xmin, xmin, xmin, xmax, xmax, xmax, xmin]
        plot_area_y = [ymin, ymin, ymax, ymax, ymax, ymin, ymin]
        plot_area_z = [zmin, zmax, zmax, zmax, zmin, zmin, zmin]
        x_bg, y_bg = RecipesPipeline.unzip(GR.wc3towc.(plot_area_x, plot_area_y, plot_area_z))
        GR.fillarea(x_bg, y_bg)

        # draw the grid lines
        if xaxis[:grid]
            gr_set_line(xaxis[:gridlinewidth], xaxis[:gridstyle], xaxis[:foreground_color_grid])
            gr_set_transparency(xaxis[:foreground_color_grid], xaxis[:gridalpha])
            gr_polyline3d(coords(xgrid_segs)...)
        end
        if yaxis[:grid]
            gr_set_line(yaxis[:gridlinewidth], yaxis[:gridstyle], yaxis[:foreground_color_grid])
            gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:gridalpha])
            gr_polyline3d(coords(ygrid_segs)...)
        end
        if zaxis[:grid]
            gr_set_line(zaxis[:gridlinewidth], zaxis[:gridstyle], zaxis[:foreground_color_grid])
            gr_set_transparency(zaxis[:foreground_color_grid], zaxis[:gridalpha])
            gr_polyline3d(coords(zgrid_segs)...)
        end

        if xaxis[:minorgrid]
            gr_set_line(xaxis[:minorgridlinewidth], xaxis[:minorgridstyle], xaxis[:foreground_color_minor_grid])
            gr_set_transparency(xaxis[:foreground_color_minor_grid], xaxis[:minorgridalpha])
            gr_polyline3d(coords(xminorgrid_segs)...)
        end
        if yaxis[:minorgrid]
            gr_set_line(yaxis[:minorgridlinewidth], yaxis[:minorgridstyle], yaxis[:foreground_color_minor_grid])
            gr_set_transparency(yaxis[:foreground_color_minor_grid], yaxis[:minorgridalpha])
            gr_polyline3d(coords(yminorgrid_segs)...)
        end
        if zaxis[:minorgrid]
            gr_set_line(zaxis[:minorgridlinewidth], zaxis[:minorgridstyle], zaxis[:foreground_color_minor_grid])
            gr_set_transparency(zaxis[:foreground_color_minor_grid], zaxis[:minorgridalpha])
            gr_polyline3d(coords(zminorgrid_segs)...)
        end
        gr_set_transparency(1.0)

        # axis lines
        if xaxis[:showaxis]
            gr_set_line(1, :solid, xaxis[:foreground_color_border])
            GR.setclip(0)
            gr_polyline3d(coords(xaxis_segs)...)
        end
        if yaxis[:showaxis]
            gr_set_line(1, :solid, yaxis[:foreground_color_border])
            GR.setclip(0)
            gr_polyline3d(coords(yaxis_segs)...)
        end
        if zaxis[:showaxis]
            gr_set_line(1, :solid, zaxis[:foreground_color_border])
            GR.setclip(0)
            gr_polyline3d(coords(zaxis_segs)...)
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
            gr_polyline3d(coords(xtick_segs)...)
        end
        if  yaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, yaxis[:foreground_color_grid])
                gr_set_transparency(yaxis[:foreground_color_grid], yaxis[:tick_direction] == :out ? yaxis[:gridalpha] : 0)
            else
                gr_set_line(1, :solid, yaxis[:foreground_color_axis])
            end
            GR.setclip(0)
            gr_polyline3d(coords(ytick_segs)...)
        end
        if  zaxis[:showaxis]
            if sp[:framestyle] in (:zerolines, :grid)
                gr_set_line(1, :solid, zaxis[:foreground_color_grid])
                gr_set_transparency(zaxis[:foreground_color_grid], zaxis[:tick_direction] == :out ? zaxis[:gridalpha] : 0)
            else
                gr_set_line(1, :solid, zaxis[:foreground_color_axis])
            end
            GR.setclip(0)
            gr_polyline3d(coords(ztick_segs)...)
        end
        GR.setclip(1)

        # tick marks
        if !(xticks in (:none, nothing, false)) && xaxis[:showaxis]
            # x labels
            gr_set_font(
                tickfont(xaxis),
                halign = (:left, :hcenter, :right)[sign(xaxis[:rotation]) + 2],
                valign = (xaxis[:mirror] ? :bottom : :top),
                rotation = xaxis[:rotation],
                color = xaxis[:tickfontcolor],
            )
            yt = if sp[:framestyle] == :origin
                0
            elseif xor(xaxis[:mirror], yaxis[:flip])
                ymax
            else
                ymin
            end
            zt = if sp[:framestyle] == :origin
                0
            elseif xor(xaxis[:mirror], zaxis[:flip])
                zmax
            else
                zmin
            end
            for (cv, dv) in zip(xticks...)
                xi, yi = gr_w3tondc(cv, yt, zt)
                xi += (yaxis[:mirror] ? 1 : -1) * 1e-2 * (xaxis[:tick_direction] == :out ? 1.5 : 1.0)
                yi += (xaxis[:mirror] ? 1 : -1) * 5e-3 * (xaxis[:tick_direction] == :out ? 1.5 : 1.0)
                gr_text(xi, yi, gr_tick_label(xaxis, dv))
            end
        end

        if !(yticks in (:none, nothing, false)) && yaxis[:showaxis]
            # y labels
            gr_set_font(
                tickfont(yaxis),
                halign = (:left, :hcenter, :right)[sign(yaxis[:rotation]) + 2],
                valign = (yaxis[:mirror] ? :bottom : :top),
                rotation = yaxis[:rotation],
                color = yaxis[:tickfontcolor],
            )
            xt = if sp[:framestyle] == :origin
                0
            elseif xor(yaxis[:mirror], xaxis[:flip])
                xmin
            else
                xmax
            end
            zt = if sp[:framestyle] == :origin
                0
            elseif xor(yaxis[:mirror], zaxis[:flip])
                zmax
            else
                zmin
            end
            for (cv, dv) in zip(yticks...)
                xi, yi = gr_w3tondc(xt, cv, zt)
                gr_text(xi + (yaxis[:mirror] ? -1 : 1) * 1e-2 * (yaxis[:tick_direction] == :out ? 1.5 : 1.0),
                        yi + (yaxis[:mirror] ? 1 : -1) * 5e-3 * (yaxis[:tick_direction] == :out ? 1.5 : 1.0),
                        gr_tick_label(yaxis, dv))
            end
        end

        if !(zticks in (:none, nothing, false)) && zaxis[:showaxis]
            # z labels
            gr_set_font(
                tickfont(zaxis),
                halign = (zaxis[:mirror] ? :left : :right),
                valign = (:top, :vcenter, :bottom)[sign(zaxis[:rotation]) + 2],
                rotation = zaxis[:rotation],
                color = zaxis[:tickfontcolor],
            )
            xt = if sp[:framestyle] == :origin
                0
            elseif xor(zaxis[:mirror], xaxis[:flip])
                xmax
            else
                xmin
            end
            yt = if sp[:framestyle] == :origin
                0
            elseif xor(zaxis[:mirror], yaxis[:flip])
                ymax
            else
                ymin
            end
            for (cv, dv) in zip(zticks...)
                xi, yi = gr_w3tondc(xt, yt, cv)
                gr_text(xi + (zaxis[:mirror] ? 1 : -1) * 1e-2 * (zaxis[:tick_direction] == :out ? 1.5 : 1.0),
                        yi, gr_tick_label(zaxis, dv))
            end
        end
        #
        # # border
        # intensity = sp[:framestyle] == :semi ? 0.5 : 1.0
        # if sp[:framestyle] in (:box, :semi)
        #     gr_set_line(intensity, :solid, xaxis[:foreground_color_border])
        #     gr_set_transparency(xaxis[:foreground_color_border], intensity)
        #     gr_polyline3d(coords(xborder_segs)...)
        #     gr_set_line(intensity, :solid, yaxis[:foreground_color_border])
        #     gr_set_transparency(yaxis[:foreground_color_border], intensity)
        #     gr_polyline3d(coords(yborder_segs)...)
        # end

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
                xi, yi = GR.wctondc(cv, sp[:framestyle] == :origin ? 0 : xor(flip, mirror) ? ymax : ymin)
                gr_text(xi, yi + (mirror ? 1 : -1) * 5e-3 * (xaxis[:tick_direction] == :out ? 1.5 : 1.0),
                        gr_tick_label(xaxis, dv))
            end
        end

        if !(yticks in (:none, nothing, false)) && yaxis[:showaxis]
            # y labels
            flip, mirror = gr_set_yticks_font(sp)
            for (cv, dv) in zip(yticks...)
                xi, yi = GR.wctondc(sp[:framestyle] == :origin ? 0 : xor(flip, mirror) ? xmax : xmin, cv)
                gr_text(xi + (mirror ? 1 : -1) * 1e-2 * (yaxis[:tick_direction] == :out ? 1.5 : 1.0),
                        yi,
                        gr_tick_label(yaxis, dv))
            end
        end

        # border
        intensity = sp[:framestyle] == :semi ? 0.5 : 1
        if sp[:framestyle] in (:box, :semi)
            GR.setclip(0)
            gr_set_line(intensity, :solid, xaxis[:foreground_color_border])
            gr_set_transparency(xaxis[:foreground_color_border], intensity)
            gr_polyline(coords(xborder_segs)...)
            gr_set_line(intensity, :solid, yaxis[:foreground_color_border])
            gr_set_transparency(yaxis[:foreground_color_border], intensity)
            gr_polyline(coords(yborder_segs)...)
            GR.setclip(1)
        end
    end
    # end

    # add the guides
    GR.savestate()
    if sp[:title] != ""
        gr_set_font(titlefont(sp))
        loc = sp[:titlelocation]
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
    if RecipesPipeline.is3d(sp)
        if xaxis[:guide] != ""
            gr_set_font(
                guidefont(xaxis),
                halign = (:left, :hcenter, :right)[sign(xaxis[:rotation]) + 2],
                valign = (xaxis[:mirror] ? :bottom : :top),
                rotation = xaxis[:rotation]
            )
            yg = xor(xaxis[:mirror], yaxis[:flip]) ? ymax : ymin
            zg = xor(xaxis[:mirror], zaxis[:flip]) ? zmax : zmin
            xg = (xmin + xmax) / 2
            xndc, yndc = gr_w3tondc(xg, yg, zg)
            h = gr_axis_height(sp, xaxis)
            gr_text(xndc - h, yndc - h, xaxis[:guide])
        end

        if yaxis[:guide] != ""
            gr_set_font(
                guidefont(yaxis),
                halign = (:left, :hcenter, :right)[sign(yaxis[:rotation]) + 2],
                valign = (yaxis[:mirror] ? :bottom : :top),
                rotation = yaxis[:rotation]
            )
            xg = xor(yaxis[:mirror], xaxis[:flip]) ? xmin : xmax
            yg = (ymin + ymax) / 2
            zg = xor(yaxis[:mirror], zaxis[:flip]) ? zmax : zmin
            xndc, yndc = gr_w3tondc(xg, yg, zg)
            h = gr_axis_height(sp, yaxis)
            gr_text(xndc + h, yndc - h, yaxis[:guide])
        end

        if zaxis[:guide] != ""
            gr_set_font(
                guidefont(zaxis),
                halign = (:left, :hcenter, :right)[sign(zaxis[:rotation]) + 2],
                valign = (zaxis[:mirror] ? :bottom : :top),
                rotation = zaxis[:rotation]
            )
            xg = xor(zaxis[:mirror], xaxis[:flip]) ? xmax : xmin
            yg = xor(zaxis[:mirror], yaxis[:flip]) ? ymax : ymin
            zg = (zmin + zmax) / 2
            xndc, yndc = gr_w3tondc(xg, yg, zg)
            w = gr_axis_width(sp, zaxis)
            GR.setcharup(-1, 0)
            gr_text(xndc - w, yndc, zaxis[:guide])
        end
    else
        if xaxis[:guide] != ""
            h = 0.01 + gr_axis_height(sp, xaxis)
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
            w = 0.02 + gr_axis_width(sp, yaxis)
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
            GR.setlinewidth(max(0, get_linewidth(series)) / nominal_size())
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
            fillgrad = _as_gradient(series[:fillcolor])
            if !ispolar(sp)
                GR.setspace(clims..., 0, 90)
                x, y = heatmap_edges(series[:x], sp[:xaxis][:scale], series[:y], sp[:yaxis][:scale], size(series[:z]))
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
                    if something(series[:fillalpha],1) < 1 || any(_gr_gradient_alpha .< 1)
                        @warn "GR: transparency not supported in non-uniform heatmaps. Alpha values ignored."
                    end
                    colors = get(fillgrad, z, clims)
                    z_normalized = map(c -> c == invisible() ? 256/255 : getinverse(fillgrad, c), colors)
                    rgba = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
                    GR.nonuniformcellarray(x, y, w, h, rgba)
                end
            else
                phimin, phimax = 0.0, 360.0 # nonuniform polar array is not yet supported in GR.jl
                nx, ny = length(series[:x]), length(series[:y])
                xmin, xmax, ymin, ymax = xy_lims
                rmax = data_lims[4]
                GR.setwindow(-rmax, rmax, -rmax, rmax)
                if ymin > 0
                    @warn "'ymin[1] > 0' (rmin) is not yet supported."
                end
                if series[:y][end] != ny
                    @warn "Right now only the maximum value of y (r) is taken into account."
                end
                colors = get(fillgrad, z, clims)
                z_normalized = map(c -> c == invisible() ? 256/255 : getinverse(fillgrad.colors, c), colors)
                rgba = Int32[round(Int32, 1000 + _i * 255) for _i in z_normalized]
                # GR.polarcellarray(0, 0, phimin, phimax, ymin, ymax, nx, ny, colors)
                GR.polarcellarray(0, 0, phimin, phimax, 0, ymax, nx, ny, rgba)
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
                x2, y2 = RecipesPipeline.unzip(map(GR.wc3towc, x, y, z))
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
            x, y = heatmap_edges(series[:x], sp[:xaxis][:scale], series[:y], sp[:yaxis][:scale], size(z))
            w, h = size(z)
            xmin, xmax = ignorenan_extrema(x)
            ymin, ymax = ignorenan_extrema(y)
            rgba = gr_color.(z)
            GR.drawimage(xmin, xmax, ymax, ymin, w, h, rgba)
        end

        # this is all we need to add the series_annotations text
        anns = series[:series_annotations]
        for (xi,yi,str,fnt) in EachAnn(anns, x, y)
            gr_set_font(fnt)
            gr_text(GR.wctondc(xi, yi)..., str)
        end

        if sp[:legend] == :inline && should_add_to_legend(series)
            gr_set_font(legendfont(sp))
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

    # draw the colorbar
    hascolorbar(sp) && gr_draw_colorbar(cbar, sp, get_clims(sp))

    # add the legend
    if !(sp[:legend] in(:none, :inline))
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
                gr_set_textcolor(plot_color(sp[:legendfontcolor]))
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
        x, y = if RecipesPipeline.is3d(sp)
            gr_w3tondc(x, y, z)
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
            pop!(ENV,"GKSwstype")
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
        if _gr_wstype[] != ""
            ENV["GKSwstype"] = _gr_wstype[]
        end
        gr_display(plt)
    end
end

closeall(::GRBackend) = GR.emergencyclosegks()
