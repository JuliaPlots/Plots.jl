

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
supported_markers(::GLVisualizeBackend) = [:none, :auto, :circle]
supported_scales(::GLVisualizeBackend) = [:identity]
is_subplot_supported(::GLVisualizeBackend) = false

# --------------------------------------------------------------------------------------


function _initialize_backend(::GLVisualizeBackend; kw...)
    @eval begin
        import GLVisualize, GeometryTypes, GLAbstraction, GLWindow
        import GeometryTypes: Point2f0, Point3f0
        export GLVisualize
    end
end

# ---------------------------------------------------------------------------


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
end

function gl_relative_size(plt::Plot{GLVisualizeBackend}, msize::Number)
    winsz = min(plt[:size]...)
    Float32(msize / winsz)
end

function gl_marker(shape::Symbol, msize::Number, _3d::Bool)
    GeometryTypes.HyperSphere((_3d ? Point3f0 : Point2f0)(0), msize)
end

function gl_color(c, a)
    c = convertColor(c, a)[1]
    @show typeof(c)
    RGBA{Float32}(c)
end

function gl_display(plt::Plot{GLVisualizeBackend})
    screen = plt.o
    # for sp in plt.subplots
    for (name, sp) in plt.spmap
        # TODO: setup subplot

        f = rect -> gl_viewport(bbox(sp), rect)
        sp_screen = Screen(
            screen,
            name = name,
            area = GLVisualize.const_lift(f, screen.area)
        )

        for series in series_list(sp)
            d = series.d
            st = d[:seriestype]
            x, y = map(Float32, d[:x]), map(Float32, d[:y])
            msize = gl_relative_size(plt, d[:markersize])

            viz = if st == :surface
                ismatrix(x) || (x = repmat(x', length(y), 1))
                ismatrix(y) || (y = repmat(y, 1, length(x)))
                z = transpose_z(d, map(Float32, d[:z].surf), false)
                viz = GLVisualize.visualize((x, y, z), :surface)
                GLVisualize.view(viz, sp_screen, camera = :perspective)

            else
                points = if is3d(st)
                    z = map(Float32, d[:z])
                    Point3f0[Point3f0(xi,yi,zi) for (xi,yi,zi) in zip(x, y, z)]
                else
                    Point2f0[Point2f0(xi,yi) for (xi,yi) in zip(x, y)]
                end

                camera = is3d(st) ? :perspective : :orthographic_pixel
                
                # markers?
                if st in (:scatter, :scatter3d) || d[:markershape] != :none
                    marker = gl_marker(d[:markershape], msize, is3d(st))
                    viz = GLVisualize.visualize((marker, points), color = gl_color(d[:markercolor], d[:markeralpha]))
                    GLVisualize.view(viz, sp_screen, camera = camera)

                    # TODO: might need to switch to these forms later?
                    # GLVisualize.visualize((marker ,(x, y, z)))
                    #GLVisualize.visualize((marker , map(Point3f0, zip(x, y, z),
                    # billboard=true
                    #))
                end

                # paths
                lw = d[:linewidth]
                if !(st in (:scatter, :scatter3d)) && lw > 0
                    viz = GLVisualize.visualize(points, :lines) #, color=colors, model=rotation)
                    GLVisualize.view(viz, sp_screen, camera = camera)
                end
            end
        end
    end
    # GLAbstraction.center!(screen)

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

# function _display(plt::Plot{GLVisualizeBackend})
#     gl_display(plt)
# end
