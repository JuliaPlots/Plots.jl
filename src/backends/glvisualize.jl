

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
supported_types(::GLVisualizeBackend) = [:surface, :scatter, :scatter3d]
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
    # init a window
    window = GLVisualize.glscreen()
    @async GLVisualize.renderloop(window)
    window
end

function gl_relative_size(plt::Plot{GLVisualizeBackend}, msize::Number)
    winsz = min(plt[:size]...)
    Float32(msize / winsz)
end

function gl_marker(shape::Symbol, msize::Number)
    GeometryTypes.Circle(Point2f0(0), msize)
end

function gl_display(plt::Plot{GLVisualizeBackend})
    window = plt.o
    for sp in plt.subplots
        # TODO: setup subplot

        for series in series_list(sp)
            d = series.d
            st = d[:seriestype]
            x, y, z = map(Float32, d[:x]), map(Float32, d[:y]), d[:z]
            msize = gl_relative_size(plt, d[:markersize])

            viz = if st == :surface
                ismatrix(x) || (x = repmat(x', length(y), 1))
                ismatrix(y) || (y = repmat(y, 1, length(x)))
                z = transpose_z(d, map(Float32, z.surf), false)
                GLVisualize.visualize((x, y, z), :surface)

            elseif st in (:scatter, :scatter3d)
                marker = gl_marker(d[:markershape], msize)
                @show marker msize
                # GLVisualize.visualize((marker ,(x, y, z)))
                points = if is3d(st)
                    z = map(Float32, z)
                    Point3f0[Point3f0(xi,yi,zi) for (xi,yi,zi) in zip(x, y, z)]
                else
                    Point2f0[Point2f0(xi,yi) for (xi,yi) in zip(x, y)]
                end
                GLVisualize.visualize((marker, points))
                #GLVisualize.visualize((marker , map(Point3f0, zip(x, y, z),
                # billboard=true
                #))                

            else
                error("Series type $st not supported by GLVisualize")
            end

            GLVisualize.view(viz, window, camera = :perspective)

        end
    end
    # GLAbstraction.center!(window)

    # TODO: render one frame at a time?  (no renderloop)
    # GLWindow.render_frame(window)
end


# ----------------------------------------------------------------

# function _writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{GLVisualizeBackend})
#     # TODO: write a png to io
# end

function _display(plt::Plot{GLVisualizeBackend})
    gl_display(plt)
end
