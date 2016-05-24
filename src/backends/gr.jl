
# https://github.com/jheinen/GR.jl


supportedArgs(::GRBackend) = [
    :annotations,
    :background_color, :foreground_color, :color_palette,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :group,
    :label,
    :seriestype,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :n, :nc, :nr, :layout,
    :smooth,
    :title, :window_title, :show, :size,
    :x, :xguide, :xlims, :xticks, :xscale, :xflip,
    :y, :yguide, :ylims, :yticks, :yscale, :yflip,
    # :axis, :yrightlabel,
    :z, :zguide, :zlims, :zticks, :zscale, :zflip,
    :z,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :xerror, :yerror,
    :ribbon, :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :aspect_ratio
]
supportedAxes(::GRBackend) = _allAxes
supportedTypes(::GRBackend) = [
    :none, :line, :path, :steppre, :steppost,
    :scatter, :hist2d, :hexbin, :hist, :density,
    :bar, :sticks,
    :hline, :vline, :heatmap, :pie, :image, #:ohlc,
    :contour, :path3d, :scatter3d, :surface, :wireframe
]
supportedStyles(::GRBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GRBackend) = vcat(_allMarkers, Shape)
supportedScales(::GRBackend) = [:identity, :log10]
subplotSupported(::GRBackend) = true
nativeImagesSupported(::GRBackend) = true



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
    :ellipse => -1,
    :rect => -7,
    :diamond => -13,
    :utriangle => -3,
    :dtriangle => -5,
    :pentagon => -21,
    :hexagon => -22,
    :heptagon => -23,
    :octagon => -24,
    :cross => 2,
    :xcross => 5,
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

function gr_getcolorind(v)
    c = getColor(v)
    return convert(Int, GR.inqcolorfromrgb(c.r, c.g, c.b))
end

function gr_getaxisind(p)
    axis = :left
    if axis in [:none, :left]
        return 1
    else
        return 2
    end
end

function gr_setmarkershape(p)
    if p[:markershape] != :none
        shape = p[:markershape]
        if isa(shape, Shape)
            p[:vertices] = vertices(shape)
        else
            GR.setmarkertype(gr_markertype[shape])
            p[:vertices] = :none
        end
    end
end

function gr_polymarker(p, x, y)
    if p[:vertices] != :none
        vertices= p[:vertices]
        dx = Float64[el[1] for el in vertices] * 0.01
        dy = Float64[el[2] for el in vertices] * 0.01
        GR.selntran(0)
        GR.setfillcolorind(gr_getcolorind(p[:markercolor]))
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        for i = 1:length(x)
            xn, yn = GR.wctondc(x[i], y[i])
            GR.fillarea(xn + dx, yn + dy)
        end
        GR.selntran(1)
    else
        GR.polymarker(x, y)
    end
end

# TODO: simplify
function gr_polyline(x, y)
    if NaN in x || NaN in y
        i = 1
        j = 1
        n = length(x)
        while i < n
            while j < n && x[j] != Nan && y[j] != NaN
                j += 1
            end
            if i < j
                GR.polyline(x[i:j], y[i:j])
            end
            i = j + 1
        end
    else
        GR.polyline(x, y)
    end
end

function gr_polaraxes(rmin, rmax)
    GR.savestate()
    GR.setlinetype(GR.LINETYPE_SOLID)
    GR.setlinecolorind(88)
    tick = 0.5 * GR.tick(rmin, rmax)
    n = round(Int, (rmax - rmin) / tick + 0.5)
    for i in 0:n
        r = float(i) / n
        if i % 2 == 0
            GR.setlinecolorind(88)
            if i > 0
                GR.drawarc(-r, r, -r, r, 0, 359)
            end
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            x, y = GR.wctondc(0.05, r)
            GR.text(x, y, string(signif(rmin + i * tick, 12)))
        else
            GR.setlinecolorind(90)
            GR.drawarc(-r, r, -r, r, 0, 359)
        end
    end
    for alpha in 0:45:315
        a = alpha + 90
        sinf = sin(a * pi / 180)
        cosf = cos(a * pi / 180)
        GR.polyline([sinf, 0], [cosf, 0])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
        x, y = GR.wctondc(1.1 * sinf, 1.1 * cosf)
        GR.textext(x, y, string(alpha, "^o"))
    end
    GR.restorestate()
end

function gr_getzlims(d, zmin, zmax, adjust)
    if d[:zlims] != :auto
        zlims = d[:zlims]
        if zlims[1] != NaN
            zmin = zlims[1]
        end
        if zlims[2] != NaN
            zmax = zlims[2]
        end
        adjust = false
    end
    if adjust
        zmin, zmax = GR.adjustrange(zmin, zmax)
    end
    zmin, zmax
end

function gr_fill_viewport(vp::AVec{Float64}, c)
    GR.savestate()
    GR.selntran(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(gr_getcolorind(c))
    GR.fillrect(vp...)
    GR.selntran(1)
    GR.restorestate()
end

# --------------------------------------------------------------------------------------

function _update_min_padding!(sp::Subplot{GRBackend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end

# --------------------------------------------------------------------------------------

# # convert a bounding box from absolute coords to percentages...
# # returns an array of percentages of figure size: [left, bottom, width, height]
# function bbox_to_pcts(bb::BoundingBox, figw, figh, flipy = true)
#     mms = Float64[f(bb).value for f in (left,bottom,width,height)]
#     if flipy
#         mms[2] = figh.value - mms[2]  # flip y when origin in bottom-left
#     end
#     mms ./ Float64[figw.value, figh.value, figw.value, figh.value]
# end

function gr_viewport_from_bbox(bb::BoundingBox, w, h, canvas)
    viewport = zeros(4)
    viewport[1] = canvas[2] * (left(bb) / w)
    viewport[2] = canvas[2] * (right(bb) / w)
    viewport[3] = canvas[4] * (1.0 - bottom(bb) / h)
    viewport[4] = canvas[4] * (1.0 - top(bb) / h)
    viewport
end

# this is our new display func... set up the canvas, compute bounding boxes, and display each subplot
function gr_display(plt::Plot)
    # before starting, lets compute bounding boxes for the full layout tree
    w, h = plt.attr[:size]
    plt.layout.bbox = BoundingBox(0px, 0px, w*px, h*px)
    update_child_bboxes!(plt.layout)

    # collect some monitor/display sizes in meters and pixels
    display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
    display_width_ratio = display_width_meters / display_width_px
    display_height_ratio = display_height_meters / display_height_px

    # compute the viewport_canvas, normalized to the larger dimension
    viewport_canvas = Float64[0,1,0,1]
    if w > h
        ratio = float(h) / w
        msize = display_width_ratio * w
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        viewport_canvas[3] *= ratio
        viewport_canvas[4] *= ratio
    else
        ratio = float(w) / h
        msize = display_height_meters * h / display_height_px
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        viewport_canvas[1] *= ratio
        viewport_canvas[2] *= ratio
    end

    # fill in the canvas background
    gr_fill_viewport(viewport_canvas, plt.attr[:background_color_outside])
    @show "PLOT SETUP" plt.layout.bbox ratio viewport_canvas

    # subplots:

    for sp in plt.subplots
        gr_display(sp, w*px, h*px, viewport_canvas)

    end
end

# using the axis extrema and limit overrides, return the min/max value for this axis
gr_x_axislims(sp::Subplot) = axis_limits(sp.attr[:xaxis], :x)
gr_y_axislims(sp::Subplot) = axis_limits(sp.attr[:yaxis], :y)
gr_z_axislims(sp::Subplot) = axis_limits(sp.attr[:zaxis], :z)
gr_xy_axislims(sp::Subplot) = gr_x_axislims(sp)..., gr_y_axislims(sp)...

function gr_display(sp::Subplot{GRBackend}, w, h, canvas)
    # the viewports for this subplot
    viewport_subplot = gr_viewport_from_bbox(bbox(sp), w*px, h*px, viewport_canvas)
    viewport_plotarea = gr_viewport_from_bbox(plotarea(sp), w*px, h*px, viewport_canvas)
    @show "SUBPLOT",sp.attr[:subplot_index] bbox(sp) plotarea(sp) viewport_subplot viewport_plotarea

    # fill in the plot area background
    gr_fill_viewport(viewport_plotarea, sp.attr[:background_color_inside])

# end
#
# function gr_old_display(plt::Plot{GRBackend}, subplot=[0, 1, 0, 1])
#     # clear=true, update=true,
#     #                 subplot=[0, 1, 0, 1])
#     # d = plt.attr
#
#     # clear && GR.clearws()
#
#     # tbreloff notes:
#     # - `GR.selntran(0)` changes the commands to be relative to the canvas, 1 means go back to the viewport you set
#
#     # display_width_meters, display_height_meters, display_width_px, display_height_px = GR.inqdspsize()
#     # w, h = plt.attr[:size]
#     # display_width_ratio = display_width_meters / display_width_px
#     # display_height_ratio = display_height_meters / display_height_px
#     #
#     # viewport_plotarea = zeros(4)
#     # viewport_canvas = float(subplot)
#     # if w > h
#     #     ratio = float(h) / w
#     #     msize = display_width_ratio * w
#     #     GR.setwsviewport(0, msize, 0, msize * ratio)
#     #     GR.setwswindow(0, 1, 0, ratio)
#     #     viewport_canvas[3] *= ratio
#     #     viewport_canvas[4] *= ratio
#     # else
#     #     ratio = float(w) / h
#     #     msize = display_height_meters * h / display_height_px
#     #     GR.setwsviewport(0, msize * ratio, 0, msize)
#     #     GR.setwswindow(0, ratio, 0, 1)
#     #     viewport_canvas[1] *= ratio
#     #     viewport_canvas[2] *= ratio
#     # end
#     #
#     # # note: these seem to be the "minpadding" computations!
#     # #       I think the midpadding is in percentages, and is: (l,r,b,t) = (0.125, 0.05, 0.125, 0.05)
#     # viewport_plotarea[1] = viewport_canvas[1] + 0.125 * (viewport_canvas[2] - viewport_canvas[1])
#     # viewport_plotarea[2] = viewport_canvas[1] + 0.95  * (viewport_canvas[2] - viewport_canvas[1])
#     # viewport_plotarea[3] = viewport_canvas[3] + 0.125 * (viewport_canvas[4] - viewport_canvas[3])
#     # if w > h
#     #     viewport_plotarea[3] += (1 - (subplot[4] - subplot[3])^2) * 0.02
#     # end
#     # viewport_plotarea[4] = viewport_canvas[3] + 0.95  * (viewport_canvas[4] - viewport_canvas[3])
#     # @show viewport_plotarea viewport_canvas
#     #
#     # # bg = gr_getcolorind(plt.attr[:background_color]) # TODO: background for all subplots?
#     # # fg = gr_getcolorind(plt.attr[:foreground_color])
#     #
#     # # GR.savestate()
#     # # GR.selntran(0)
#     # # GR.setfillintstyle(GR.INTSTYLE_SOLID)
#     # # GR.setfillcolorind(gr_getcolorind(plt.attr[:background_color_outside]))
#     # # GR.fillrect(viewport_canvas[1], viewport_canvas[2], viewport_canvas[3], viewport_canvas[4])
#     # gr_fill_viewport(viewport_canvas, plt.attr[:background_color_outside])
#     #
#     # # # c = getColor(d[:background_color_inside])
#     # # # dark_bg = 0.21 * c.r + 0.72 * c.g + 0.07 * c.b < 0.9
#     # # GR.setfillcolorind(gr_getcolorind(d[:background_color_inside]))
#     # # GR.fillrect(viewport_plotarea[1], viewport_plotarea[2], viewport_plotarea[3], viewport_plotarea[4])
#     # # GR.selntran(1)
#     # # GR.restorestate()
#     # gr_fill_viewport(viewport_plotarea, sp.attr[:background_color_inside])

    extrema = zeros(2, 4)
    num_axes = 1
    grid_flag = sp.attr[:grid]

    # reduced from before... set some flags based on the series in this subplot
    # TODO: can these be generic flags?
    outside_ticks = false
    cmap = false
    axes_2d = true
    for series in series_list(sp)
        st = ispolar(sp) ? :polar : series.d[:seriestype]
        if st in (:hist2d, :hexbin, :contour, :surface, :heatmap)
            cmap = true
        end
        if st in (:pie, :polar, :surface, :wireframe, :path3d, :scatter3d)
            axes_2d = false
        end
        if st == :heatmap
            outside_ticks = true
        end
    end



    # # section: compute axis extrema
    # for axis = 1:2
    #     xmin = ymin = typemax(Float64)
    #     xmax = ymax = typemin(Float64)
    #     for p in plt.seriesargs
    #         st = p[:seriestype]
    #         if get(d, :polar, false)
    #             st = :polar
    #         end
    #         if axis == gr_getaxisind(p)
    #             if axis == 2
    #                 num_axes = 2
    #             end
    #             if st == :bar
    #                 x, y = 1:length(p[:y]), p[:y]
    #             elseif st in [:hist, :density]
    #                 x, y = Base.hist(p[:y], p[:bins])
    #             elseif st in [:hist2d, :hexbin]
    #                 E = zeros(length(p[:x]),2)
    #                 E[:,1] = p[:x]
    #                 E[:,2] = p[:y]
    #                 if isa(p[:bins], Tuple)
    #                     xbins, ybins = p[:bins]
    #                 else
    #                     xbins = ybins = p[:bins]
    #                 end
    #                 cmap = true
    #                 x, y, H = Base.hist2d(E, xbins, ybins)
    #             elseif st in [:pie, :polar]
    #                 axes_2d = false
    #                 xmin, xmax, ymin, ymax = 0, 1, 0, 1
    #                 x, y = p[:x], p[:y]
    #             else
    #                 if st in [:contour, :surface, :heatmap]
    #                     cmap = true
    #                 end
    #                 if st in [:surface, :wireframe, :path3d, :scatter3d]
    #                     axes_2d = false
    #                 end
    #                 if st == :heatmap
    #                     outside_ticks = true
    #                 end
    #                 x, y = p[:x], p[:y]
    #             end
    #             if !(st in [:pie, :polar])
    #                 xmin = min(minimum(x), xmin)
    #                 xmax = max(maximum(x), xmax)
    #                 ymin = min(minimum(y), ymin)
    #                 ymax = max(maximum(y), ymax)
    #                 if p[:xerror] != nothing || p[:yerror] != nothing
    #                     dx = xmax - xmin
    #                     xmin -= 0.02 * dx
    #                     xmax += 0.02 * dx
    #                     dy = ymax - ymin
    #                     ymin -= 0.02 * dy
    #                     ymax += 0.02 * dy
    #                 end
    #             end
    #         end
    #     end
    #     if d[:xlims] != :auto
    #         xmin, xmax = d[:xlims]
    #     end
    #     if d[:ylims] != :auto
    #         ymin, ymax = d[:ylims]
    #     end
    #     if xmax <= xmin
    #         xmax = xmin + 1
    #     end
    #     if ymax <= ymin
    #         ymax = ymin + 1
    #     end
    #     extrema[axis,:] = [xmin, xmax, ymin, ymax]
    # end



    # compute extrema
    lims = gr_xy_axislims(sp)
    for i=1:4
        extrema[:,i] = lims[i]
    end

    if num_axes == 2 || !axes_2d
        # note: add extra midpadding on the right for a second (right) axis
        viewport_plotarea[2] -= 0.0525
    end
    if cmap
        # note: add extra midpadding on the right for the colorbar
        viewport_plotarea[2] -= 0.1
    end
    GR.setviewport(viewport_plotarea[1], viewport_plotarea[2], viewport_plotarea[3], viewport_plotarea[4])

    scale = 0
    d[:xscale] == :log10 && (scale |= GR.OPTION_X_LOG)
    d[:yscale] == :log10 && (scale |= GR.OPTION_Y_LOG)
    get(d, :xflip, false) && (scale |= GR.OPTION_FLIP_X)
    get(d, :yflip, false) && (scale |= GR.OPTION_FLIP_Y)

    for axis = 1:num_axes
        xmin, xmax, ymin, ymax = extrema[axis,:]
        if scale & GR.OPTION_X_LOG == 0
            xmin, xmax = GR.adjustlimits(xmin, xmax)
            majorx = 5
            xtick = GR.tick(xmin, xmax) / majorx
        else
            xtick = majorx = 1
        end
        if scale & GR.OPTION_Y_LOG == 0
            ymin, ymax = GR.adjustlimits(ymin, ymax)
            majory = 5
            ytick = GR.tick(ymin, ymax) / majory
        else
            ytick = majory = 1
        end
        if scale & GR.OPTION_FLIP_X == 0
            xorg = (xmin, xmax)
        else
            xorg = (xmax, xmin)
        end
        if scale & GR.OPTION_FLIP_Y == 0
            yorg = (ymin, ymax)
        else
            yorg = (ymax, ymin)
        end

        extrema[axis,:] = [xmin, xmax, ymin, ymax]
        GR.setwindow(xmin, xmax, ymin, ymax)
        GR.setscale(scale)

        diag = sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
        charheight = max(0.018 * diag, 0.01)
        GR.setcharheight(charheight)
        GR.settextcolorind(fg)

        if axes_2d
            GR.setlinewidth(1)
            GR.setlinecolorind(gr_getcolorind(d[:foreground_color_grid]))
            ticksize = 0.0075 * diag
            if outside_ticks
                ticksize = -ticksize
            end
            if grid_flag
                if dark_bg
                    GR.grid(xtick * majorx, ytick * majory, 0, 0, 1, 1)
                else
                    GR.grid(xtick, ytick, 0, 0, majorx, majory)
                end
            end
            GR.setlinecolorind(gr_getcolorind(d[:foreground_color_axis]))
            if num_axes == 1
                GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
                GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, -majory, -ticksize)
            elseif axis == 1
                GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
            else
                GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, majory, -ticksize)
            end
        end
    end

    if get(d, :title, "") != ""
        GR.savestate()
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        GR.settextcolorind(fg)
        GR.text(0.5 * (viewport_plotarea[1] + viewport_plotarea[2]), viewport_canvas[4], d[:title])
        GR.restorestate()
    end
    if get(d, :xguide, "") != ""
        GR.savestate()
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
        GR.settextcolorind(fg)
        GR.text(0.5 * (viewport_plotarea[1] + viewport_plotarea[2]), viewport_canvas[3], d[:xguide])
        GR.restorestate()
    end
    if get(d, :yguide, "") != ""
        GR.savestate()
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        GR.setcharup(-1, 0)
        GR.settextcolorind(fg)
        GR.text(viewport_canvas[1], 0.5 * (viewport_plotarea[3] + viewport_plotarea[4]), d[:yguide])
        GR.restorestate()
    end
    # if get(d, :yrightlabel, "") != ""
    #   GR.savestate()
    #   GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
    #   GR.setcharup(1, 0)
    #   GR.settextcolorind(fg)
    #   GR.text(viewport_canvas[2], 0.5 * (viewport_plotarea[3] + viewport_plotarea[4]), d[:yrightlabel])
    #   GR.restorestate()
    # end

    GR.setcolormap(1000 + GR.COLORMAP_COOLWARM)

    legend = falses(length(plt.seriesargs))

    for (ind, p) in enumerate(plt.seriesargs)
        st = p[:seriestype]
        if st in (:hist2d, :hexbin, :contour, :surface, :wireframe, :heatmap)
            if isa(p[:fillcolor], ColorGradient)
                grad = p[:fillcolor]
            else
                grad = default_gradient()
            end
            cs = [getColorZ(grad, z) for z in linspace(0, 1, 256)]
            for (i, c) in enumerate(cs)
                GR.setcolorrep(999+i, red(c), green(c), blue(c))
            end
        end
        if get(d, :polar, false)
            st = :polar
        end
        GR.savestate()
        xmin, xmax, ymin, ymax = extrema[gr_getaxisind(p),:]
        GR.setwindow(xmin, xmax, ymin, ymax)
        if st in [:path, :line, :steppre, :steppost, :sticks, :hline, :vline, :polar]
            GR.setlinetype(gr_linetype[p[:linestyle]])
            GR.setlinewidth(p[:linewidth])
            GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
        end
        if st == :path
            if length(p[:x]) > 1
                if p[:fillrange] != nothing
                    GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
                    GR.setfillintstyle(GR.INTSTYLE_SOLID)
                    GR.fillarea([p[:x][1]; p[:x]; p[:x][length(p[:x])]], [p[:fillrange]; p[:y]; p[:fillrange]])
                end
                GR.polyline(p[:x], p[:y])
            end
            legend[ind] = true
        end
        if st == :line
            if length(p[:x]) > 1
                gr_polyline(p[:x], p[:y])
            end
            legend[ind] = true
        elseif st in [:steppre, :steppost]
            n = length(p[:x])
            x = zeros(2*n + 1)
            y = zeros(2*n + 1)
            x[1], y[1] = p[:x][1], p[:y][1]
            j = 2
            for i = 2:n
                if st == :steppre
                    x[j], x[j+1] = p[:x][i-1], p[:x][i]
                    y[j], y[j+1] = p[:y][i],   p[:y][i]
                else
                    x[j], x[j+1] = p[:x][i],   p[:x][i]
                    y[j], y[j+1] = p[:y][i-1], p[:y][i]
                end
                j += 2
            end
            if n > 1
                GR.polyline(x, y)
            end
            legend[ind] = true
        elseif st == :sticks
            x, y = p[:x], p[:y]
            for i = 1:length(y)
                GR.polyline([x[i], x[i]], [ymin, y[i]])
            end
            legend[ind] = true
        elseif st == :scatter || (p[:markershape] != :none && axes_2d)
            GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
            gr_setmarkershape(p)
            if typeof(p[:markersize]) <: Number
                GR.setmarkersize(p[:markersize] / 4.0)
                if length(p[:x]) > 0
                    gr_polymarker(p, p[:x], p[:y])
                end
            else
                c = p[:markercolor]
                GR.setcolormap(-GR.COLORMAP_GLOWING)
                for i = 1:length(p[:x])
                    if isa(c, ColorGradient) && p[:marker_z] != nothing
                        ci = round(Int, 1000 + p[:marker_z][i] * 255)
                        GR.setmarkercolorind(ci)
                    end
                    GR.setmarkersize(p[:markersize][i] / 4.0)
                    gr_polymarker(p, [p[:x][i]], [p[:y][i]])
                end
            end
            legend[ind] = true

        # NOTE: these should just use the series recipes
        # elseif st == :bar
        #     y = p[:y]
        #     for i = 1:length(y)
        #         GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        #         GR.setfillintstyle(GR.INTSTYLE_SOLID)
        #         GR.fillrect(i-0.4, i+0.4, max(0, ymin), y[i])
        #         GR.setfillcolorind(fg)
        #         GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        #         GR.fillrect(i-0.4, i+0.4, max(0, ymin), y[i])
        #     end
        # elseif st in [:hist, :density]
        #     h = Base.hist(p[:y], p[:bins])
        #     x, y = float(collect(h[1])), float(h[2])
        #     for i = 2:length(y)
        #         GR.setfillcolorind(gr_getcolorind(p[:fillcolor]))
        #         GR.setfillintstyle(GR.INTSTYLE_SOLID)
        #         GR.fillrect(x[i-1], x[i], ymin, y[i])
        #         GR.setfillcolorind(fg)
        #         GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        #         GR.fillrect(x[i-1], x[i], ymin, y[i])
        #     end
        # elseif st in [:hline, :vline]
        #     for xy in p[:y]
        #         if st == :hline
        #             GR.polyline([xmin, xmax], [xy, xy])
        #         else
        #             GR.polyline([xy, xy], [ymin, ymax])
        #         end
        #     end
        # elseif st in [:hist2d, :hexbin]
        #     E = zeros(length(p[:x]),2)
        #     E[:,1] = p[:x]
        #     E[:,2] = p[:y]
        #     if isa(p[:bins], Tuple)
        #         xbins, ybins = p[:bins]
        #     else
        #         xbins = ybins = p[:bins]
        #     end
        #     x, y, H = Base.hist2d(E, xbins, ybins)
        #     counts = round(Int32, 1000 + 255 * H / maximum(H))
        #     n, m = size(counts)
        #     GR.cellarray(xmin, xmax, ymin, ymax, n, m, counts)
        #
        #     # NOTE: set viewport to the colorbar area, get character height, draw it, then reset viewport
        #     GR.setviewport(viewport_plotarea[2] + 0.02, viewport_plotarea[2] + 0.05, viewport_plotarea[3], viewport_plotarea[4])
        #     zmin, zmax = gr_getzlims(d, 0, maximum(counts), false)
        #     GR.setspace(zmin, zmax, 0, 90)
        #     diag = sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
        #     charheight = max(0.016 * diag, 0.01)
        #     GR.setcharheight(charheight)
        #     GR.colormap()
        #     GR.setviewport(viewport_plotarea[1], viewport_plotarea[2], viewport_plotarea[3], viewport_plotarea[4])

        elseif st == :contour
            x, y, z = p[:x], p[:y], transpose_z(p, p[:z].surf, false)
            zmin, zmax = gr_getzlims(d, minimum(z), maximum(z), false)
            GR.setspace(zmin, zmax, 0, 90)
            if typeof(p[:levels]) <: Array
                h = p[:levels]
            else
                h = linspace(zmin, zmax, p[:levels])
            end
            GR.contour(x, y, h, reshape(z, length(x) * length(y)), 1000)
            GR.setviewport(viewport_plotarea[2] + 0.02, viewport_plotarea[2] + 0.05, viewport_plotarea[3], viewport_plotarea[4])
            l = round(Int32, 1000 + (h - minimum(h)) / (maximum(h) - minimum(h)) * 255)
            GR.setwindow(xmin, xmax, zmin, zmax)
            GR.cellarray(xmin, xmax, zmax, zmin, 1, length(l), l)
            ztick = 0.5 * GR.tick(zmin, zmax)
            diag = sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
            charheight = max(0.016 * diag, 0.01)
            GR.setcharheight(charheight)
            GR.axes(0, ztick, xmax, zmin, 0, 1, 0.005)
            GR.setviewport(viewport_plotarea[1], viewport_plotarea[2], viewport_plotarea[3], viewport_plotarea[4])
        elseif st in [:surface, :wireframe]
            x, y, z = p[:x], p[:y], transpose_z(p, p[:z].surf, false)
            zmin, zmax = gr_getzlims(d, minimum(z), maximum(z), true)
            GR.setspace(zmin, zmax, 40, 70)
            xtick = GR.tick(xmin, xmax) / 2
            ytick = GR.tick(ymin, ymax) / 2
            ztick = GR.tick(zmin, zmax) / 2
            diag = sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
            charheight = max(0.018 * diag, 0.01)
            ticksize = 0.01 * (viewport_plotarea[2] - viewport_plotarea[1])
            GR.setlinewidth(1)
            if grid_flag
                GR.grid3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2)
                GR.grid3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0)
            end
            z = reshape(z, length(x) * length(y))
            if st == :surface
                GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
            else
                GR.setfillcolorind(0)
                GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
            end
            GR.setlinewidth(1)
            GR.setcharheight(charheight)
            GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
            GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)
            if cmap
                GR.setviewport(viewport_plotarea[2] + 0.07, viewport_plotarea[2] + 0.1, viewport_plotarea[3], viewport_plotarea[4])
                GR.colormap()
            end
        elseif st == :heatmap
            x, y, z = p[:x], p[:y], transpose_z(p, p[:z].surf, false)
            zmin, zmax = gr_getzlims(d, minimum(z), maximum(z), true)
            GR.setspace(zmin, zmax, 0, 90)
            z = reshape(z, length(x) * length(y))
            GR.surface(x, y, z, GR.OPTION_COLORED_MESH)
            if cmap
                GR.setviewport(viewport_plotarea[2] + 0.02, viewport_plotarea[2] + 0.05, viewport_plotarea[3], viewport_plotarea[4])
                GR.colormap()
                GR.setviewport(viewport_plotarea[1], viewport_plotarea[2], viewport_plotarea[3], viewport_plotarea[4])
            end
        elseif st in [:path3d, :scatter3d]
            x, y, z = p[:x], p[:y], p[:z]
            zmin, zmax = gr_getzlims(d, minimum(z), maximum(z), true)
            GR.setspace(zmin, zmax, 40, 70)
            xtick = GR.tick(xmin, xmax) / 2
            ytick = GR.tick(ymin, ymax) / 2
            ztick = GR.tick(zmin, zmax) / 2
            diag = sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
            charheight = max(0.018 * diag, 0.01)
            ticksize = 0.01 * (viewport_plotarea[2] - viewport_plotarea[1])
            GR.setlinewidth(1)
            if grid_flag && st == :path3d
                GR.grid3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2)
                GR.grid3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0)
            end
            if st == :scatter3d
                GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
                gr_setmarkershape(p)
                for i = 1:length(z)
                    px, py = GR.wc3towc(x[i], y[i], z[i])
                    gr_polymarker(p, [px], [py])
                end
            else
                if length(x) > 0
                    GR.setlinewidth(p[:linewidth])
                    GR.polyline3d(x, y, z)
                end
            end
            GR.setlinewidth(1)
            GR.setcharheight(charheight)
            GR.axes3d(xtick, 0, ztick, xmin, ymin, zmin, 2, 0, 2, -ticksize)
            GR.axes3d(0, ytick, 0, xmax, ymin, zmin, 0, 2, 0, ticksize)
        elseif st == :pie
            GR.selntran(0)
            GR.setfillintstyle(GR.INTSTYLE_SOLID)
            xmin, xmax, ymin, ymax = viewport_plotarea
            ymax -= 0.05 * (xmax - xmin)
            xcenter = 0.5 * (xmin + xmax)
            ycenter = 0.5 * (ymin + ymax)
            if xmax - xmin > ymax - ymin
                r = 0.5 * (ymax - ymin)
                xmin, xmax = xcenter - r, xcenter + r
            else
                r = 0.5 * (xmax - xmin)
                ymin, ymax = ycenter - r, ycenter + r
            end
            labels, slices = p[:x], p[:y]
            numslices = length(slices)
            total = sum(slices)
            a1 = 0
            x = zeros(3)
            y = zeros(3)
            for i in 1:numslices
                a2 = round(Int, a1 + (slices[i] / total) * 360.0)
                GR.setfillcolorind(980 + (i-1) % 20)
                GR.fillarc(xmin, xmax, ymin, ymax, a1, a2)
                alpha = 0.5 * (a1 + a2)
                cosf = r * cos(alpha * pi / 180)
                sinf = r * sin(alpha * pi / 180)
                x[1] = xcenter + cosf
                y[1] = ycenter + sinf
                x[2] = x[1] + 0.1 * cosf
                y[2] = y[1] + 0.1 * sinf
                y[3] = y[2]
                if 90 <= alpha < 270
                    x[3] = x[2] - 0.05
                    GR.settextalign(GR.TEXT_HALIGN_RIGHT, GR.TEXT_VALIGN_HALF)
                    GR.text(x[3] - 0.01, y[3], string(labels[i]))
                else
                    x[3] = x[2] + 0.05
                    GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
                    GR.text(x[3] + 0.01, y[3], string(labels[i]))
                end
                GR.polyline(x, y)
                a1 = a2
            end
            GR.selntran(1)
        elseif st == :image
            img = p[:z].surf
            w, h = size(img)
            if eltype(img) <: Colors.AbstractGray
                grey = round(UInt8, float(img) * 255)
                rgba = map(c -> UInt32( 0xff000000 + Int(c)<<16 + Int(c)<<8 + Int(c) ), grey)
            else
                rgba = map(c -> UInt32( round(Int, alpha(c) * 255) << 24 +
                                        round(Int,  blue(c) * 255) << 16 +
                                        round(Int, green(c) * 255) << 8  +
                                        round(Int,   red(c) * 255) ), img)
            end
            GR.drawimage(xmin, xmax, ymin, ymax, w, h, rgba)
        elseif st == :polar
            xmin, xmax, ymin, ymax = viewport_plotarea
            ymax -= 0.05 * (xmax - xmin)
            xcenter = 0.5 * (xmin + xmax)
            ycenter = 0.5 * (ymin + ymax)
            r = 0.5 * min(xmax - xmin, ymax - ymin)
            GR.setviewport(xcenter -r, xcenter + r, ycenter - r, ycenter + r)
            GR.setwindow(-1, 1, -1, 1)
            rmin, rmax = GR.adjustrange(minimum(r), maximum(r))
            gr_polaraxes(rmin, rmax)
            phi, r = p[:x], p[:y]
            r = 0.5 * (r - rmin) / (rmax - rmin)
            n = length(r)
            x = zeros(n)
            y = zeros(n)
            for i in 1:n
                x[i] = r[i] * cos(phi[i])
                y[i] = r[i] * sin(phi[i])
            end
            GR.polyline(x, y)
        end
        GR.restorestate()
    end

    if d[:legend] != :none && any(legend) == true
        GR.savestate()
        GR.selntran(0)
        GR.setscale(0)
        w = 0
        i = 0
        n = 0
        for (ind, p) in enumerate(plt.seriesargs)
            if !legend[ind] || p[:label] == ""
                continue
            end
            n += 1
            if typeof(p[:label]) <: Array
                i += 1
                lab = p[:label][i]
            else
                lab = p[:label]
            end
            tbx, tby = GR.inqtext(0, 0, lab)
            w = max(w, tbx[3])
        end
        px = viewport_plotarea[2] - 0.05 - w
        py = viewport_plotarea[4] - 0.06
        dy = 0.03 * sqrt((viewport_plotarea[2] - viewport_plotarea[1])^2 + (viewport_plotarea[4] - viewport_plotarea[3])^2)
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.setfillcolorind(gr_getcolorind(d[:background_color_legend]))
        GR.fillrect(px - 0.08, px + w + 0.02, py + dy, py - dy * n)
        GR.setlinetype(1)
        GR.setlinewidth(1)
        GR.drawrect(px - 0.08, px + w + 0.02, py + dy, py - dy * n)
        i = 0
        for (ind, p) in enumerate(plt.seriesargs)
            if !legend[ind] || p[:label] == ""
                continue
            end
            GR.setlinewidth(p[:linewidth])
            if p[:seriestype] in [:path, :line, :steppre, :steppost, :sticks]
                GR.setlinecolorind(gr_getcolorind(p[:linecolor]))
                GR.setlinetype(gr_linetype[p[:linestyle]])
                GR.polyline([px - 0.07, px - 0.01], [py, py])
            end
            if p[:seriestype] == :scatter || p[:markershape] != :none
                GR.setmarkercolorind(gr_getcolorind(p[:markercolor]))
                gr_setmarkershape(p)
                if p[:seriestype] in [:path, :line, :steppre, :steppost, :sticks]
                    gr_polymarker(p, [px - 0.06, px - 0.02], [py, py])
                else
                    gr_polymarker(p, [px - 0.06, px - 0.04, px - 0.02], [py, py, py])
                end
            end
            if typeof(p[:label]) <: Array
                i += 1
                lab = p[:label][i]
            else
                lab = p[:label]
            end
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            GR.settextcolorind(gr_getcolorind(d[:foreground_color_legend]))
            GR.text(px, py, lab)
            py -= dy
        end
        GR.selntran(1)
        GR.restorestate()
    end

    if haskey(d, :annotations)
        GR.savestate()
        for ann in d[:anns]
            x, y, val = ann
            x, y = GR.wctondc(x, y)
            alpha = val.font.rotation
            family = lowercase(val.font.family)
            GR.setcharheight(0.7 * val.font.pointsize / d[:size][2])
            GR.setcharup(sin(val.font.rotation), cos(val.font.rotation))
            if haskey(gr_font_family, family)
                GR.settextfontprec(100 + gr_font_family[family], GR.TEXT_PRECISION_STRING)
            end
            GR.settextcolorind(gr_getcolorind(val.font.color))
            GR.settextalign(gr_halign[val.font.halign], gr_valign[val.font.valign])
            GR.text(x, y, val.str)
        end
        GR.restorestate()
    end

    # update && GR.updatews()
end

# ----------------------------------------------------------------

# clear, display, and update the plot... using in all output modes
function gr_finalize(plt::Plot{GRBackend})
    GR.clearws()
    gr_display(plt)
    GR.updatews()
end

# setup and tear down gks before and after displaying... used in IO output
function gr_finalize(plt::Plot{GRBackend}, wstype)
    GR.emergencyclosegks()
    ENV["GKS_WSTYPE"] = wstype
    gr_finalize(plt)
    GR.emergencyclosegks()
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, m::MIME"image/png", plt::Plot{GRBackend})
    gr_finalize(plt, "png")
    write(io, readall("gks.png"))
end

function Base.writemime(io::IO, m::MIME"image/svg+xml", plt::Plot{GRBackend})
    gr_finalize(plt, "svg")
    write(io, readall("gks.svg"))
end

function Base.writemime(io::IO, m::MIME"text/html", plt::Plot{GRBackend})
    writemime(io, MIME("image/svg+xml"), plt)
end

function Base.writemime(io::IO, m::MIME"application/pdf", plt::Plot{GRBackend})
    gr_finalize(plt, "pdf")
    write(io, readall("gks.pdf"))
end

function Base.writemime(io::IO, m::MIME"application/postscript", plt::Plot{GRBackend})
    gr_finalize(plt, "ps")
    write(io, readall("gks.ps"))
end

function Base.display(::PlotsDisplay, plt::Plot{GRBackend})
    # gr_display(plt)
    gr_finalize(plt)
end
