

# [WEBSITE]

supported_args(::GLVisualizeBackend) = merge_with_base_supported([
    # :annotations,
    # :background_color_legend, :background_color_inside, :background_color_outside,
    # :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    # :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    # :label,
    # :linecolor, :linestyle, :linewidth, :linealpha,
    # :markershape, :markercolor, :markersize, :markeralpha,
    # :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    # :fillrange, :fillcolor, :fillalpha,
    # :bins, :bar_width, :bar_edges, :bar_position,
    # :title, :title_location, :titlefont,
    # :window_title,
    # :guide, :lims, :ticks, :scale, :flip, :rotation,
    # :tickfont, :guidefont, :legendfont,
    # :grid, :legend, :colorbar,
    # :marker_z, :levels,
    # :ribbon, :quiver, :arrow,
    # :orientation,
    # :overwrite_figure,
    # :polar,
    # :normalize, :weights,
    # :contours, :aspect_ratio,
    # :match_dimensions,
    # :clims,
    # :inset_subplots,
  ])
supported_types(::GLVisualizeBackend) = [:surface, :scatter, :scatter3d, :path, :path3d]
supported_styles(::GLVisualizeBackend) = [:auto, :solid]
supported_markers(::GLVisualizeBackend) = vcat([:none, :auto, :circle], collect(keys(_gl_marker_map)))
supported_scales(::GLVisualizeBackend) = [:identity]
is_subplot_supported(::GLVisualizeBackend) = true

# --------------------------------------------------------------------------------------


function _initialize_backend(::GLVisualizeBackend; kw...)
    @eval begin
        import GLVisualize, GeometryTypes, GLAbstraction, GLWindow
        import GeometryTypes: Point2f0, Point3f0, Vec2f0, Vec3f0
        export GLVisualize

        # TODO: remove this when PlotUtils is registered
        import PlotUtils
    end
end

# ---------------------------------------------------------------------------

# initialize the figure/window
function _create_backend_figure(plt::Plot{GLVisualizeBackend})
    # init a screen
    screen = if isdefined(GLVisualize, :ROOT_SCREEN)
        GLVisualize.ROOT_SCREEN
    else
        s = GLVisualize.glscreen()
        @async GLVisualize.renderloop(s)
        s
    end
    empty!(screen)
    screen
end

# ---------------------------------------------------------------------------

# size as a percentage of the window size
function gl_relative_size(plt::Plot{GLVisualizeBackend}, msize::Number)
    winsz = min(plt[:size]...)
    Float32(msize / winsz)
end

const _gl_marker_map = KW(
  :rect => '■',
  :star5 => '★',
  :diamond => '◆',
  :hexagon => '⬢',
  :cross => '✚',
  :xcross => '❌',
  :utriangle => '▲',
  :dtriangle => '▼',
  :pentagon => '⬟',
  :octagon => '⯄',
  :star4 => '✦',
  :star6 => '✶',
  :star8 => '✷',
  :vline => '┃',
  :hline => '━',
)


# create a marker/shape type
function gl_marker(shape::Symbol, msize::Number, _3d::Bool)
    GeometryTypes.HyperSphere((_3d ? Point3f0 : Point2f0)(0), msize)
end

gl_color(c::RGBA{Float32}) = c

# convert to RGBA
function gl_color(c, a=nothing)
    c = convertColor(c, a)
    RGBA{Float32}(getColor(c))
end

function gl_viewport(bb, rect)
    l, b, bw, bh = bb
    rw, rh = rect.w, rect.h
    GLVisualize.SimpleRectangle(
        round(Int, rect.x + rw * l),
        round(Int, rect.y + rh * b),
        round(Int, rw * bw),
        round(Int, rh * bh)
    )
end

gl_make_points(x, y) = Point2f0[Point2f0(x[i], y[i]) for i=1:length(x)]
gl_make_points(x, y, z) = Point3f0[Point3f0(x[i], y[i], z[i]) for i=1:length(x)]

function gl_draw_lines_2d(x, y, color, linewidth, sp_screen)
    color = gl_color(color)
    thickness = Float32(linewidth)
    for rng in iter_segments(x, y)
        n = length(rng)
        n < 2 && continue
        viz = GLVisualize.visualize(
            gl_make_points(x[rng], y[rng]),
            n==2 ? :linesegment : :lines,
            color=color,
            thickness = Float32(linewidth)
        )
        GLVisualize.view(viz, sp_screen, camera=:orthographic_pixel)
    end
end

function gl_draw_lines_3d(x, y, z, color, linewidth, sp_screen)
    color = gl_color(color)
    thickness = Float32(linewidth)
    for rng in iter_segments(x, y, z)
        n = length(rng)
        n < 2 && continue
        viz = GLVisualize.visualize(
            gl_make_points(x[rng], y[rng], z[rng]),
            n==2 ? :linesegment : :lines,
            color=color,
            thickness = Float32(linewidth)
        )
        GLVisualize.view(viz, sp_screen, camera=:perspective)
    end
end

function gl_draw_axes_2d(sp::Subplot{GLVisualizeBackend}, sp_screen)
    xaxis = sp[:xaxis]
    xmin, xmax = axis_limits(xaxis)
    yaxis = sp[:yaxis]
    ymin, ymax = axis_limits(yaxis)

    # x axis
    xsegs, ysegs = Segments(), Segments()
    ticksz = 0.03*(ymax-ymin)
    push!(xsegs, [xmin,xmax]); push!(ysegs, [ymin,ymin])
    for tick in PlotUtils.optimize_ticks(xmin, xmax)[1]
        push!(xsegs, [tick,tick]); push!(ysegs, [ymin,ymin+ticksz])
        # TODO: add the ticklabel
    end
    gl_draw_lines_2d(xsegs.pts, ysegs.pts, xaxis[:foreground_color_border], 1, sp_screen)

    # y axis
    xsegs, ysegs = Segments(), Segments()
    push!(xsegs, [xmin,xmin]); push!(ysegs, [ymin,ymax])
    for tick in PlotUtils.optimize_ticks(xmin, xmax)[1]
        push!(xsegs, [xmin,xmin+ticksz]); push!(ysegs, [tick,tick])
        # TODO: add the ticklabel
    end
    gl_draw_lines_2d(xsegs.pts, ysegs.pts, yaxis[:foreground_color_border], 1, sp_screen)

    # # x axis
    # gl_draw_lines_2d([xmin, xmax], [ymin, ymin], xaxis[:foreground_color_border], 1, sp_screen)

    # # y axis
    # gl_draw_lines_2d([xmin, xmin], [ymin, ymax], yaxis[:foreground_color_border], 1, sp_screen)
end

# ---------------------------------------------------------------------------

# draw everything
function gl_display(plt::Plot{GLVisualizeBackend})
    screen = plt.o
    sw, sh = plt[:size]
    sw, sh = sw*px, sh*px
    for (name, sp) in plt.spmap

        _3d = is3d(sp)
        camera = _3d ? :perspective : :orthographic_pixel
        # camera = :perspective

        # initialize the sub-screen for this subplot
        # note: we create a lift function to update the size on resize
        rel_bbox = bbox_to_pcts(bbox(sp), sw, sh)
        f = rect -> gl_viewport(rel_bbox, rect)
        sp_screen = GLVisualize.Screen(
            screen,
            name = name,
            area = GLVisualize.const_lift(f, screen.area)
        )

        if !is3d(sp)
            gl_draw_axes_2d(sp, sp_screen)
        end

        # loop over the series and add them to the subplot
        for series in series_list(sp)
            d = series.d
            st = d[:seriestype]
            x, y = map(Float32, d[:x]), map(Float32, d[:y])
            msize = gl_relative_size(plt, d[:markersize])

            viz = if st == :surface
                # TODO: can pass just the ranges and surface
                ismatrix(x) || (x = repmat(x', length(y), 1))
                ismatrix(y) || (y = repmat(y, 1, length(x)))
                z = transpose_z(d, map(Float32, d[:z].surf), false)
                viz = GLVisualize.visualize((x, y, z), :surface)
                GLVisualize.view(viz, sp_screen, camera = :perspective)

            else
                # paths and scatters

                _3d && (z = map(Float32, d[:z]))

                # paths?
                lw = d[:linewidth]
                if lw > 0
                    c = gl_color(d[:linecolor], d[:linealpha])
                    if _3d
                        gl_draw_lines_3d(x, y, z, c, lw, sp_screen)
                    else
                        gl_draw_lines_2d(x, y, c, lw, sp_screen)
                    end
                end
                
                # markers?
                if st in (:scatter, :scatter3d) || d[:markershape] != :none
                    extrakw = KW()
                    c = gl_color(d[:markercolor], d[:markeralpha])

                    # get the marker
                    shape = d[:markershape] 
                    shape = get(_gl_marker_map, shape, shape)
                    marker = if isa(shape, Char)
                        # extrakw[:scale] = Vec2f0(_3d ? 0.6*d[:markersize] : msize)
                        extrakw[:scale] = Vec2f0(msize)
                        shape
                    else
                        gl_marker(d[:markershape], msize, _3d)
                    end

                    if !_3d
                        extrakw[:billboard] = true
                    end

                    points = _3d ? gl_make_points(x,y,z) : gl_make_points(x,y)
                    viz = GLVisualize.visualize(
                        (marker, points);
                        color = c,
                        extrakw...
                    )
                    GLVisualize.view(viz, sp_screen, camera = camera)

                    # TODO: might need to switch to these forms later?
                    # GLVisualize.visualize((marker ,(x, y, z)))
                    #GLVisualize.visualize((marker , map(Point3f0, zip(x, y, z),
                    # billboard=true
                    #))
                end
            end
        end
        GLAbstraction.center!(sp_screen, camera)
    end

    # TODO: render one frame at a time?  (no renderloop)
    # GLWindow.render_frame(screen)
end


# ----------------------------------------------------------------

function _update_plot_object(plt::Plot{GLVisualizeBackend})
    gl_display(plt)
end

# function _writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{GLVisualizeBackend})
#     # TODO: write a png to io
# end

function _display(plt::Plot{GLVisualizeBackend})
end
